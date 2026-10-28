-- Upgrade in-place from the original BIGINT/PostGIS schema (0001/0002) to
-- the canonical UUID schema. Existing row IDs are mapped to generated UUIDs,
-- and the history foreign key is migrated with them.
create extension if not exists postgis;

do $$
declare
    espacio_id_type text;
begin
    create table if not exists public.perfiles (
        id uuid primary key references auth.users(id) on delete cascade,
        nombre text not null,
        rol text not null default 'conductor'
            check (rol in ('conductor', 'validador', 'admin')),
        puntos_karma integer not null default 0,
        creado_en timestamptz not null default now()
    );

    select data_type into espacio_id_type
    from information_schema.columns
    where table_schema='public' and table_name='espacios' and column_name='id';

    if espacio_id_type = 'bigint' then
        drop function if exists public.espacio_cercano(bigint, double precision, double precision, double precision);
        alter table public.espacios add column id_uuid uuid default gen_random_uuid();
        update public.espacios set id_uuid = gen_random_uuid() where id_uuid is null;
        alter table public.historial_estados add column espacio_uuid uuid;
        update public.historial_estados h
            set espacio_uuid = e.id_uuid
            from public.espacios e
            where h.espacio_id = e.id;
        if exists (select 1 from public.historial_estados where espacio_uuid is null) then
            raise exception 'No se pudo mapear todo el historial a UUID; se revierte la migración.';
        end if;
        alter table public.historial_estados
            drop constraint if exists historial_estados_espacio_id_fkey;
        alter table public.historial_estados drop column espacio_id;
        alter table public.historial_estados rename column espacio_uuid to espacio_id;
        alter table public.espacios drop constraint if exists espacios_pkey;
        alter table public.espacios rename column id to legacy_id;
        alter table public.espacios rename column id_uuid to id;
        alter table public.espacios alter column id set not null;
        alter table public.espacios add constraint espacios_pkey primary key (id);
        alter table public.historial_estados
            add constraint historial_estados_espacio_id_fkey
            foreign key (espacio_id) references public.espacios(id) on delete cascade;
    end if;
end;
$$;

create or replace function public.manejar_nuevo_usuario()
returns trigger language plpgsql security definer set search_path=public as $$
begin
    insert into public.perfiles (id, nombre, rol)
    values (new.id, coalesce(new.raw_user_meta_data->>'nombre', new.email), 'conductor');
    return new;
end;
$$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute function public.manejar_nuevo_usuario();

-- Completa el esquema tanto para la instalación BIGINT como para el script
-- UUID intermedio que existía en supabase/scripts/.
alter table public.espacios add column if not exists codigo text;
alter table public.espacios add column if not exists poligono_roi jsonb not null default '[]'::jsonb;
alter table public.espacios add column if not exists lat double precision;
alter table public.espacios add column if not exists lng double precision;
alter table public.espacios add column if not exists fuente text not null default 'CAMARA';
alter table public.espacios add column if not exists forzado_por uuid references public.perfiles(id);
alter table public.espacios add column if not exists bloqueado_hasta timestamptz;
alter table public.espacios add column if not exists updated_at timestamptz not null default now();

-- Tras el cambio de tipo, legacy_id solo existe en la actualización desde BIGINT.
do $$
begin
    if exists (select 1 from information_schema.columns where table_schema='public'
               and table_name='espacios' and column_name='legacy_id') then
        execute $query$update public.espacios
            set codigo = coalesce(nullif(codigo, ''), nullif(nombre, ''), 'Espacio ' || legacy_id::text)
            where codigo is null or codigo = ''$query$;
        if exists (select 1 from information_schema.columns where table_schema='public'
                   and table_name='espacios' and column_name='ubicacion') then
            execute $query$update public.espacios
                set lat = coalesce(lat, st_y(ubicacion::geometry)),
                    lng = coalesce(lng, st_x(ubicacion::geometry))$query$;
        end if;
        if exists (select 1 from information_schema.columns where table_schema='public'
                   and table_name='espacios' and column_name='actualizado_en') then
            execute $query$update public.espacios
                set updated_at = coalesce(updated_at, actualizado_en, now())$query$;
        end if;
    elsif exists (select 1 from information_schema.columns where table_schema='public'
                  and table_name='espacios' and column_name='nombre') then
        execute $query$update public.espacios
            set codigo = coalesce(nullif(codigo, ''), nullif(nombre, ''), 'Espacio ' || id::text)
            where codigo is null or codigo = ''$query$;
    else
        update public.espacios set codigo = 'Espacio ' || id::text where codigo is null or codigo = '';
    end if;
end;
$$;

-- Hacer códigos únicos preservando nombres repetidos del esquema anterior.
do $$
begin
    if exists (select codigo from public.espacios group by codigo having count(*) > 1) then
        with duplicados as (
            select codigo from public.espacios group by codigo having count(*) > 1
        )
        update public.espacios e set codigo = e.codigo || ' (' || e.id::text || ')'
        where e.codigo in (select codigo from duplicados);
    end if;
end;
$$;
alter table public.espacios alter column codigo set not null;
create unique index if not exists espacios_codigo_uidx on public.espacios(codigo);

-- El estado de reserva/sin servicio ya existe en el cliente y el seed UUID.
do $$
declare c record;
begin
    for c in select conname from pg_constraint
             where conrelid='public.espacios'::regclass and contype='c'
               and pg_get_constraintdef(oid) ilike '%estado%' loop
        execute format('alter table public.espacios drop constraint %I', c.conname);
    end loop;
end;
$$;
alter table public.espacios add constraint espacios_estado_check
    check (estado in ('LIBRE', 'OCUPADO', 'RESERVADO', 'SIN_SERVICIO'));

do $$
declare c record;
begin
    for c in select conname from pg_constraint
             where conrelid='public.espacios'::regclass and contype='c'
               and pg_get_constraintdef(oid) ilike '%fuente%' loop
        execute format('alter table public.espacios drop constraint %I', c.conname);
    end loop;
end;
$$;
alter table public.espacios add constraint espacios_fuente_check
    check (fuente in ('CAMARA', 'VALIDADOR', 'CONDUCTOR'));

create table if not exists public.historial_estados (
    id bigint generated always as identity primary key,
    espacio_id uuid not null references public.espacios(id) on delete cascade,
    estado_anterior text,
    estado_nuevo text not null,
    fuente text not null check (fuente in ('CAMARA', 'VALIDADOR', 'CONDUCTOR')),
    usuario_id uuid references public.perfiles(id),
    creado_en timestamptz not null default now()
);
do $$
declare c record;
begin
    for c in select conname from pg_constraint
             where conrelid='public.historial_estados'::regclass and contype='c'
               and (pg_get_constraintdef(oid) ilike '%estado_nuevo%'
                    or pg_get_constraintdef(oid) ilike '%fuente%') loop
        execute format('alter table public.historial_estados drop constraint %I', c.conname);
    end loop;
end;
$$;
alter table public.historial_estados add constraint historial_estado_nuevo_check
    check (estado_nuevo in ('LIBRE', 'OCUPADO', 'RESERVADO', 'SIN_SERVICIO'));
alter table public.historial_estados add constraint historial_fuente_check
    check (fuente in ('CAMARA', 'VALIDADOR', 'CONDUCTOR'));

create table if not exists public.vision_heartbeat (
    camara_id text primary key,
    ultimo_contacto timestamptz not null
);
insert into public.vision_heartbeat (camara_id, ultimo_contacto)
values ('CAM-001', 'epoch'::timestamptz)
on conflict (camara_id) do nothing;

create or replace function public.registrar_historial_estado()
returns trigger language plpgsql set search_path=public as $$
begin
    if old.estado is distinct from new.estado then
        insert into public.historial_estados (
            espacio_id, estado_anterior, estado_nuevo, fuente, usuario_id
        ) values (
            new.id, old.estado, new.estado, new.fuente,
            case when new.fuente='VALIDADOR' then new.forzado_por else null end
        );
    end if;
    return new;
end;
$$;
drop trigger if exists espacios_historial_estado on public.espacios;
create trigger espacios_historial_estado after update of estado on public.espacios
for each row execute function public.registrar_historial_estado();

create or replace function public.actualizar_timestamp_espacios()
returns trigger language plpgsql set search_path=public as $$
begin new.updated_at=now(); return new; end;
$$;
drop trigger if exists espacios_updated_at on public.espacios;
create trigger espacios_updated_at before update on public.espacios
for each row execute function public.actualizar_timestamp_espacios();
create or replace function public.respetar_bloqueo_validador()
returns trigger language plpgsql set search_path=public as $$
begin
    if old.bloqueado_hasta > now() and new.fuente='CAMARA' then return null; end if;
    return new;
end;
$$;
drop trigger if exists espacios_bloqueo_validador on public.espacios;
create trigger espacios_bloqueo_validador before update on public.espacios
for each row execute function public.respetar_bloqueo_validador();

-- Replace the old BIGINT RPC signature with the UUID signature.
drop function if exists public.espacio_cercano(bigint, double precision, double precision, double precision);
create or replace function public.espacio_cercano(
    p_espacio_id uuid, p_lat double precision, p_lon double precision,
    p_max_metros double precision default 30
)
returns boolean language sql stable as $$
    select coalesce(st_dwithin(
        st_setsrid(st_makepoint(e.lng,e.lat),4326)::geography,
        st_setsrid(st_makepoint(p_lon,p_lat),4326)::geography, p_max_metros
    ), false)
    from public.espacios e where e.id=p_espacio_id and e.lat is not null and e.lng is not null;
$$;

alter table public.espacios enable row level security;
alter table public.historial_estados enable row level security;
alter table public.vision_heartbeat enable row level security;
alter table public.perfiles enable row level security;
drop policy if exists perfiles_select_propio_o_admin on public.perfiles;
drop policy if exists "perfiles_select_propio_o_admin" on public.perfiles;
create policy perfiles_select_propio_o_admin on public.perfiles
    for select to authenticated using (auth.uid() = id);
drop policy if exists perfiles_update_propio on public.perfiles;
revoke insert, update, delete on public.perfiles from anon, authenticated;
drop policy if exists espacios_select_autenticados on public.espacios;
drop policy if exists espacios_lectura_mapa on public.espacios;
create policy espacios_lectura_mapa on public.espacios for select to anon, authenticated using (true);
drop policy if exists historial_select_autenticados on public.historial_estados;
create policy historial_select_autenticados on public.historial_estados
    for select to authenticated using (
        exists (select 1 from public.perfiles p
                where p.id=auth.uid() and lower(p.rol) in ('validador', 'admin'))
    );
drop policy if exists vision_heartbeat_lectura on public.vision_heartbeat;
create policy vision_heartbeat_lectura on public.vision_heartbeat for select to anon, authenticated using (true);
grant usage on schema public to anon, authenticated;
grant select on public.espacios, public.vision_heartbeat to anon, authenticated;
grant select on public.historial_estados to authenticated;
grant all on public.perfiles to service_role;
grant all on public.espacios, public.historial_estados, public.vision_heartbeat to service_role;
grant usage, select on all sequences in schema public to service_role;

do $$
begin
    if not exists (select 1 from pg_publication where pubname='supabase_realtime') then
        create publication supabase_realtime;
    end if;
    if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='espacios') then
        alter publication supabase_realtime add table public.espacios;
    end if;
    if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='vision_heartbeat') then
        alter publication supabase_realtime add table public.vision_heartbeat;
    end if;
end;
$$;
