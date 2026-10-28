-- Compatibility con instalaciones que ya aplicaron el esquema BIGINT/PostGIS.
-- El esquema UUID canónico usa lat/lng directamente; esta migración solo
-- conserva las columnas generadas antiguas cuando existe ubicacion.
do $$
begin
    if to_regclass('public.espacios') is not null
       and exists (select 1 from information_schema.columns
                   where table_schema='public' and table_name='espacios'
                     and column_name='ubicacion') then
        alter table public.espacios
            add column if not exists latitud double precision
                generated always as (st_y(ubicacion::geometry)) stored;
        alter table public.espacios
            add column if not exists longitud double precision
                generated always as (st_x(ubicacion::geometry)) stored;
    end if;
end;
$$;
