-- ============================================================
-- EstacionaYa · Esquema inicial de Supabase (Postgres + PostGIS)
-- ============================================================

create extension if not exists postgis;

-- ------------------------------------------------------------
-- Perfiles (extiende auth.users con rol y karma) — RF1
-- ------------------------------------------------------------
create table if not exists public.perfiles (
    id uuid primary key references auth.users (id) on delete cascade,
    nombre text not null,
    rol text not null default 'CONDUCTOR'
        check (rol in ('CONDUCTOR', 'VALIDADOR', 'ADMIN')),
    puntos_karma integer not null default 0,
    creado_en timestamptz not null default now()
);

-- Crea automáticamente un perfil cuando se registra un usuario en auth.users
create or replace function public.manejar_nuevo_usuario()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    insert into public.perfiles (id, nombre, rol)
    values (
        new.id,
        coalesce(new.raw_user_meta_data ->> 'nombre', new.email),
        coalesce(new.raw_user_meta_data ->> 'rol', 'CONDUCTOR')
    );
    return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
    after insert on auth.users
    for each row execute procedure public.manejar_nuevo_usuario();

-- ------------------------------------------------------------
-- Espacios de parqueo (detectados por cámara + forzados por validador)
-- ------------------------------------------------------------
create table if not exists public.espacios (
    id bigint generated always as identity primary key,
    nombre text not null,
    camara_id text not null,
    poligono_roi jsonb not null,          -- coordenadas de píxeles del ROI en el frame de la cámara
    ubicacion geography(point, 4326),      -- ubicación real para mostrarla en el mapa
    estado text not null default 'LIBRE'
        check (estado in ('LIBRE', 'OCUPADO')),
    fuente text not null default 'CAMARA'
        check (fuente in ('CAMARA', 'VALIDADOR', 'CONDUCTOR')),
    forzado_por uuid references public.perfiles (id),
    bloqueado_hasta timestamptz,
    actualizado_en timestamptz not null default now()
);

-- ------------------------------------------------------------
-- Historial de cambios de estado (auditoría / trazabilidad)
-- ------------------------------------------------------------
create table if not exists public.historial_estados (
    id bigint generated always as identity primary key,
    espacio_id bigint not null references public.espacios (id) on delete cascade,
    estado_anterior text,
    estado_nuevo text not null,
    fuente text not null check (fuente in ('CAMARA', 'VALIDADOR', 'CONDUCTOR')),
    usuario_id uuid references public.perfiles (id),
    creado_en timestamptz not null default now()
);

-- ------------------------------------------------------------
-- Row Level Security
-- ------------------------------------------------------------
alter table public.perfiles enable row level security;
alter table public.espacios enable row level security;
alter table public.historial_estados enable row level security;

-- Perfiles: cada usuario ve y edita su propio perfil; los admins ven todo
create policy "perfiles_select_propio_o_admin"
    on public.perfiles for select
    using (
        auth.uid() = id
        or exists (
            select 1 from public.perfiles p
            where p.id = auth.uid() and p.rol = 'ADMIN'
        )
    );

create policy "perfiles_update_propio"
    on public.perfiles for update
    using (auth.uid() = id);

-- Espacios: cualquier usuario autenticado puede leer el estado en tiempo real
create policy "espacios_select_autenticados"
    on public.espacios for select
    to authenticated
    using (true);

-- Las escrituras (INSERT/UPDATE) las hace el backend con la service_role key,
-- que ignora RLS por diseño. No se define policy de escritura para clientes.

-- Historial: lectura para autenticados, sin escritura desde el cliente
create policy "historial_select_autenticados"
    on public.historial_estados for select
    to authenticated
    using (true);

-- ------------------------------------------------------------
-- Función auxiliar: valida cercanía física antes de aceptar un
-- reporte de conductor (RF6 · geolocalización activa)
-- ------------------------------------------------------------
create or replace function public.espacio_cercano(
    p_espacio_id bigint,
    p_lat double precision,
    p_lon double precision,
    p_max_metros double precision default 30
)
returns boolean
language sql
stable
as $$
    select coalesce(
        st_dwithin(
            ubicacion,
            st_setsrid(st_makepoint(p_lon, p_lat), 4326)::geography,
            p_max_metros
        ),
        false
    )
    from public.espacios
    where id = p_espacio_id;
$$;

-- ------------------------------------------------------------
-- Realtime: publicar cambios de la tabla espacios (RF7)
-- ------------------------------------------------------------
alter publication supabase_realtime add table public.espacios;
