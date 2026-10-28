-- Configuración versionada por espacio para los ROIs rectangulares de OpenCV.
-- El backend FastAPI accede mediante service_role; clientes móviles no necesitan
-- leer ni escribir la configuración interna de cámaras.
create table if not exists public.config_camaras (
    espacio_id uuid primary key references public.espacios(id) on delete cascade,
    camara_id text not null unique,
    x integer not null check (x >= 0),
    y integer not null check (y >= 0),
    width integer not null check (width > 0),
    height integer not null check (height > 0),
    frame_width integer not null check (frame_width > 0 and frame_width <= 16384),
    frame_height integer not null check (frame_height > 0 and frame_height <= 16384),
    updated_at timestamptz not null default now(),
    constraint config_camaras_roi_dentro_frame
        check (x + width <= frame_width and y + height <= frame_height)
);

create or replace function public.config_camaras_set_updated_at()
returns trigger language plpgsql set search_path = public as $$
begin
    new.updated_at = now();
    return new;
end;
$$;
drop trigger if exists config_camaras_updated_at on public.config_camaras;
create trigger config_camaras_updated_at
    before update on public.config_camaras
    for each row execute function public.config_camaras_set_updated_at();

alter table public.config_camaras enable row level security;
revoke all on public.config_camaras from anon, authenticated;
grant all on public.config_camaras to service_role;
