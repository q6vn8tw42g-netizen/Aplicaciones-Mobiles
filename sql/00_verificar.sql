-- Inspeccion SIN CAMBIOS: ejecuta primero en SQL Editor.
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema='public' AND table_name='espacios'
ORDER BY ordinal_position;

SELECT conname, pg_get_constraintdef(oid) AS definicion
FROM pg_constraint
WHERE conrelid='public.espacios'::regclass;

SELECT conrelid::regclass AS tabla_dependiente,
       conname AS clave_foranea,
       pg_get_constraintdef(oid) AS definicion
FROM pg_constraint
WHERE contype='f' AND confrelid='public.espacios'::regclass;

SELECT codigo, camara_id, estado FROM public.espacios ORDER BY codigo;
