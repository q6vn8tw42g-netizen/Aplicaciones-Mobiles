-- EstacionaYa: esquema canónico UUID (PostgreSQL + PostGIS).
create extension if not exists postgis;

create table if not exists public.perfiles (
    id uuid primary key references auth.users (id) on delete cascade,
    nombre text not null,
    rol text not null default 'conductor'
        check (rol in ('conductor', 'validador', 'admin')),
    puntos_karma integer not null default 0,
    creado_en timestamptz not null default now()
);

create or replace function public.manejar_nuevo_usuario()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    -- Nunca confiar en raw_user_meta_data para conceder privilegios.
    insert into public.perfiles (id, nombre, rol)
    values (new.id, coalesce(new.raw_user_meta_data ->> 'nombre', new.email), 'conductor');
    return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
    after insert on auth.users
    for each row execute function public.manejar_nuevo_usuario();

create table if not exists public.espacios (
    id uuid primary key default gen_random_uuid(),
    codigo text not null,
    camara_id text not null,
    poligono_roi jsonb not null default '[]'::jsonb,
    lat double precision,
    lng double precision,
    estado text not null default 'LIBRE'
        check (estado in ('LIBRE', 'OCUPADO', 'RESERVADO', 'SIN_SERVICIO')),
    fuente text not null default 'CAMARA'
        check (fuente in ('CAMARA', 'VALIDADOR', 'CONDUCTOR')),
    forzado_por uuid references public.perfiles (id),
    bloqueado_hasta timestamptz,
    updated_at timestamptz not null default now(),
    constraint espacios_latitud_valida check (lat is null or lat between -90 and 90),
    constraint espacios_longitud_valida check (lng is null or lng between -180 and 180)
);
create unique index if not exists espacios_codigo_uidx on public.espacios(codigo);

create table if not exists public.historial_estados (
    id bigint generated always as identity primary key,
    espacio_id uuid not null references public.espacios (id) on delete cascade,
    estado_anterior text,
    estado_nuevo text not null
        check (estado_nuevo in ('LIBRE', 'OCUPADO', 'RESERVADO', 'SIN_SERVICIO')),
    fuente text not null check (fuente in ('CAMARA', 'VALIDADOR', 'CONDUCTOR')),
    usuario_id uuid references public.perfiles (id),
    creado_en timestamptz not null default now()
);

-- Heartbeat separado: permite mostrar una cámara desconectada sin escribir
-- en espacios por frame ni alterar el estado confirmado del puesto.
create table if not exists public.vision_heartbeat (
    camara_id text primary key,
    ultimo_contacto timestamptz not null
);

create or replace function public.registrar_historial_estado()
returns trigger language plpgsql set search_path = public as $$
begin
    if old.estado is distinct from new.estado then
        insert into public.historial_estados (
            espacio_id, estado_anterior, estado_nuevo, fuente, usuario_id
        ) values (
            new.id, old.estado, new.estado, new.fuente,
            case when new.fuente = 'VALIDADOR' then new.forzado_por else null end
        );
    end if;
    return new;
end;
$$;
drop trigger if exists espacios_historial_estado on public.espacios;
create trigger espacios_historial_estado after update of estado on public.espacios
    for each row execute function public.registrar_historial_estado();

create or replace function public.actualizar_timestamp_espacios()
returns trigger language plpgsql set search_path = public as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

drop trigger if exists espacios_updated_at on public.espacios;
create trigger espacios_updated_at before update on public.espacios
    for each row execute function public.actualizar_timestamp_espacios();

create or replace function public.respetar_bloqueo_validador()
returns trigger language plpgsql set search_path = public as $$
begin
    if old.bloqueado_hasta > now() and new.fuente = 'CAMARA' then
        return null;
    end if;
    return new;
end;
$$;
drop trigger if exists espacios_bloqueo_validador on public.espacios;
create trigger espacios_bloqueo_validador before update on public.espacios
    for each row execute function public.respetar_bloqueo_validador();

create or replace function public.espacio_cercano(
    p_espacio_id uuid,
    p_lat double precision,
    p_lon double precision,
    p_max_metros double precision default 30
)
returns boolean language sql stable as $$
    select coalesce(
        st_dwithin(
            st_setsrid(st_makepoint(e.lng, e.lat), 4326)::geography,
            st_setsrid(st_makepoint(p_lon, p_lat), 4326)::geography,
            p_max_metros
        ), false
    )
    from public.espacios e
    where e.id = p_espacio_id and e.lat is not null and e.lng is not null;
$$;

alter table public.perfiles enable row level security;
alter table public.espacios enable row level security;
alter table public.historial_estados enable row level security;
alter table public.vision_heartbeat enable row level security;

drop policy if exists "perfiles_select_propio_o_admin" on public.perfiles;
create policy "perfiles_select_propio_o_admin" on public.perfiles
    for select to authenticated using (auth.uid() = id);
drop policy if exists "perfiles_update_propio" on public.perfiles;
revoke insert, update, delete on public.perfiles from anon, authenticated;
drop policy if exists "espacios_select_autenticados" on public.espacios;
drop policy if exists espacios_lectura_mapa on public.espacios;
create policy espacios_lectura_mapa on public.espacios
    for select to anon, authenticated using (true);
drop policy if exists historial_select_autenticados on public.historial_estados;
create policy historial_select_autenticados on public.historial_estados
    for select to authenticated using (
        exists (select 1 from public.perfiles p
                where p.id = auth.uid() and lower(p.rol) in ('validador', 'admin'))
    );
drop policy if exists vision_heartbeat_lectura on public.vision_heartbeat;
create policy vision_heartbeat_lectura on public.vision_heartbeat
    for select to anon, authenticated using (true);

grant usage on schema public to anon, authenticated;
grant select on public.espacios, public.vision_heartbeat to anon, authenticated;
grant select on public.perfiles, public.historial_estados to authenticated;
grant all on public.perfiles to service_role;
grant all on public.espacios, public.historial_estados, public.vision_heartbeat to service_role;
grant usage, select on all sequences in schema public to service_role;

-- Habilitar Realtime de forma repetible en bases locales y remotas.
do $$
begin
    if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
        create publication supabase_realtime;
    end if;
    if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime'
                   and schemaname = 'public' and tablename = 'espacios') then
        alter publication supabase_realtime add table public.espacios;
    end if;
    if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime'
                   and schemaname = 'public' and tablename = 'vision_heartbeat') then
        alter publication supabase_realtime add table public.vision_heartbeat;
    end if;
end;
$$;
