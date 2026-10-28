-- Reserva temporal y clasificación de vehículos para EstacionaYa.
-- lat/lng siguen siendo los campos fuente usados por clientes existentes;
-- latitud/longitud son alias generados para clientes que usan esos nombres.

alter table public.espacios
    add column if not exists estado_reserva text not null default 'LIBRE',
    add column if not exists expiracion_reserva timestamptz,
    add column if not exists tipo_vehiculo text not null default 'MIXTO',
    add column if not exists vehiculo_detectado text,
    add column if not exists latitud double precision generated always as (lat) stored,
    add column if not exists longitud double precision generated always as (lng) stored;

update public.espacios set estado_reserva = estado;
-- Reservas preexistentes no tienen propietario ni duración confiable; se vencen
-- al aplicar la migración y el worker del backend las liberará.
update public.espacios
set expiracion_reserva = now()
where estado = 'RESERVADO' and expiracion_reserva is null;

alter table public.espacios
    add constraint espacios_estado_reserva_check
        check (estado_reserva in ('LIBRE', 'OCUPADO', 'RESERVADO', 'SIN_SERVICIO')),
    add constraint espacios_tipo_vehiculo_check
        check (tipo_vehiculo in ('MOTO', 'AUTO', 'CAMIONETA', 'MIXTO')),
    add constraint espacios_vehiculo_detectado_check
        check (vehiculo_detectado is null or vehiculo_detectado in ('MOTO', 'AUTO', 'CAMIONETA'));

create index if not exists espacios_reservas_expiracion_idx
    on public.espacios (expiracion_reserva)
    where estado = 'RESERVADO';

-- Los propietarios de las reservas se guardan en una tabla privada para que
-- el stream público de espacios no exponga identificadores de cuentas.
create table if not exists public.reservas_espacios (
    espacio_id uuid primary key references public.espacios(id) on delete cascade,
    camara_id text not null unique,
    usuario_id uuid not null references public.perfiles(id) on delete cascade,
    creada_en timestamptz not null default now(),
    expiracion timestamptz not null
);
alter table public.reservas_espacios enable row level security;
revoke all on public.reservas_espacios from anon, authenticated;
grant all on public.reservas_espacios to service_role;

create or replace function public.sincronizar_estado_reserva()
returns trigger
language plpgsql
set search_path = public
as $$
begin
    if tg_op = 'INSERT' then
        if new.estado_reserva is distinct from new.estado then
            if new.estado_reserva = 'LIBRE' then
                new.estado_reserva := new.estado;
            else
                new.estado := new.estado_reserva;
            end if;
        end if;
        return new;
    end if;

    if new.estado is distinct from old.estado
       and new.estado_reserva is not distinct from old.estado_reserva then
        new.estado_reserva := new.estado;
    elsif new.estado_reserva is distinct from old.estado_reserva
       and new.estado is not distinct from old.estado then
        new.estado := new.estado_reserva;
    elsif new.estado is distinct from new.estado_reserva then
        raise exception 'estado y estado_reserva deben coincidir';
    end if;

    return new;
end;
$$;

drop trigger if exists espacios_sync_estado_reserva on public.espacios;
create trigger espacios_sync_estado_reserva
    before insert or update of estado, estado_reserva on public.espacios
    for each row execute function public.sincronizar_estado_reserva();

-- Reserva atómica: bloquea la fila para evitar que dos usuarios reclamen el
-- mismo puesto o que la cámara cambie el estado entre la validación y el insert.
create or replace function public.reservar_espacio(
    p_espacio_id uuid,
    p_usuario_id uuid,
    p_tipo_vehiculo text,
    p_duracion_minutos integer
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_espacio public.espacios%rowtype;
    v_usuario_reserva uuid;
    v_expiracion timestamptz;
begin
    select * into v_espacio
    from public.espacios
    where id = p_espacio_id
    for update;

    if not found then
        raise exception 'Espacio no encontrado.' using errcode = 'P0002';
    end if;

    if v_espacio.estado = 'RESERVADO' then
        if v_espacio.expiracion_reserva > now() then
            select usuario_id into v_usuario_reserva
            from public.reservas_espacios
            where espacio_id = p_espacio_id;
            if v_usuario_reserva = p_usuario_id then
                return to_jsonb(v_espacio);
            end if;
            raise exception 'El espacio ya está reservado.' using errcode = 'P0001';
        end if;

        update public.espacios
        set estado = 'LIBRE', estado_reserva = 'LIBRE',
            expiracion_reserva = null, vehiculo_detectado = null
        where id = p_espacio_id
        returning * into v_espacio;
        delete from public.reservas_espacios where espacio_id = p_espacio_id;
    end if;

    if v_espacio.bloqueado_hasta is not null and v_espacio.bloqueado_hasta > now() then
        raise exception 'El espacio está bloqueado por mantenimiento.' using errcode = 'P0001';
    end if;
    if v_espacio.estado <> 'LIBRE' then
        raise exception 'Solo se pueden reservar espacios libres.' using errcode = 'P0001';
    end if;
    if p_tipo_vehiculo is not null
       and v_espacio.tipo_vehiculo not in ('MIXTO', p_tipo_vehiculo) then
        raise exception 'El espacio no admite ese tipo de vehículo.' using errcode = 'P0001';
    end if;
    if p_duracion_minutos < 1 or p_duracion_minutos > 5 then
        raise exception 'La duración de la reserva no es válida.' using errcode = 'P0001';
    end if;

    v_expiracion := now() + make_interval(mins => p_duracion_minutos);
    delete from public.reservas_espacios where espacio_id = p_espacio_id;
    update public.espacios
    set estado = 'RESERVADO', estado_reserva = 'RESERVADO',
        expiracion_reserva = v_expiracion, vehiculo_detectado = null,
        fuente = 'CONDUCTOR', forzado_por = null, bloqueado_hasta = null
    where id = p_espacio_id
    returning * into v_espacio;

    insert into public.reservas_espacios (
        espacio_id, camara_id, usuario_id, expiracion
    ) values (
        v_espacio.id, v_espacio.camara_id, p_usuario_id, v_expiracion
    );

    return to_jsonb(v_espacio);
end;
$$;

revoke all on function public.reservar_espacio(uuid, uuid, text, integer) from public, anon, authenticated;
grant execute on function public.reservar_espacio(uuid, uuid, text, integer) to service_role;

create or replace function public.cancelar_reserva_espacio(
    p_espacio_id uuid,
    p_usuario_id uuid,
    p_es_admin boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_espacio public.espacios%rowtype;
    v_usuario_reserva uuid;
begin
    select * into v_espacio
    from public.espacios
    where id = p_espacio_id
    for update;
    if not found then
        raise exception 'Espacio no encontrado.' using errcode = 'P0002';
    end if;
    if v_espacio.estado <> 'RESERVADO' then
        raise exception 'El espacio no tiene una reserva activa.' using errcode = 'P0001';
    end if;

    select usuario_id into v_usuario_reserva
    from public.reservas_espacios
    where espacio_id = p_espacio_id
    for update;
    if not p_es_admin and v_usuario_reserva is distinct from p_usuario_id then
        raise exception 'Solo quien reservó el espacio puede cancelar la reserva.' using errcode = 'P0001';
    end if;

    update public.espacios
    set estado = 'LIBRE', estado_reserva = 'LIBRE',
        expiracion_reserva = null, vehiculo_detectado = null,
        fuente = case when p_es_admin then 'VALIDADOR' else 'CONDUCTOR' end,
        forzado_por = case when p_es_admin then p_usuario_id else null end
    where id = p_espacio_id
    returning * into v_espacio;
    delete from public.reservas_espacios where espacio_id = p_espacio_id;
    return to_jsonb(v_espacio);
end;
$$;

revoke all on function public.cancelar_reserva_espacio(uuid, uuid, boolean) from public, anon, authenticated;
grant execute on function public.cancelar_reserva_espacio(uuid, uuid, boolean) to service_role;
