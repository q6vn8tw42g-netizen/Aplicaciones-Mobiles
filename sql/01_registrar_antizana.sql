-- Crea 5 filas de ANTIZANA sin duplicar; conserva filas antiguas para revision.
-- Se registra SIN_SERVICIO hasta que el ROI se valide, para no anunciar falso LIBRE.
-- Si una FK exige una camara distinta, revisa su schema antes de modificarla.
BEGIN;
INSERT INTO public.espacios (codigo, camara_id, estado, poligono_roi)
SELECT v.codigo, 'CAM-005', 'SIN_SERVICIO', '[]'::jsonb
FROM (VALUES ('ANT-001'),('ANT-002'),('ANT-003'),('ANT-004'),('ANT-005')) AS v(codigo)
WHERE NOT EXISTS (SELECT 1 FROM public.espacios e WHERE e.codigo=v.codigo);
COMMIT;
SELECT id,codigo,camara_id,estado FROM public.espacios WHERE codigo LIKE 'ANT-%' ORDER BY codigo;
