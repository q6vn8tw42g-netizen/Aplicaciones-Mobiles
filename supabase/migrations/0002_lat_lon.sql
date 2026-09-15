-- ============================================================
-- Columnas generadas latitud/longitud a partir de "ubicacion"
--
-- El tipo geography se serializa como WKB hexadecimal en las
-- respuestas de PostgREST y en los payloads de Realtime, lo cual
-- es incómodo de parsear desde Flutter/Dart. Estas columnas
-- generadas exponen lat/lon como double simple, listas para
-- usar en el cliente, sin tocar la columna geography (que se
-- sigue usando para la función espacio_cercano).
-- ============================================================

alter table public.espacios
    add column if not exists latitud double precision
        generated always as (st_y(ubicacion::geometry)) stored;

alter table public.espacios
    add column if not exists longitud double precision
        generated always as (st_x(ubicacion::geometry)) stored;
