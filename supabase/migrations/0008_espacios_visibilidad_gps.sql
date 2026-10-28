-- Los espacios ya almacenan GPS en lat/lng. Estas columnas generadas ofrecen
-- nombres explícitos sin duplicar ni desincronizar esos valores existentes.
alter table public.espacios
    add column if not exists coordenada_lat double precision
        generated always as (lat) stored,
    add column if not exists coordenada_lng double precision
        generated always as (lng) stored,
    add column if not exists estado_visibilidad boolean not null default false;
