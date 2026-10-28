-- RESET DE DESARROLLO: elimina los espacios actuales y su historial asociado.
-- Ejecutar en Supabase SQL Editor. Sustituye/añade filas según los puestos
-- realmente aprobados por UPEC y registra lat/lng de cada puesto en campo.
begin;

delete from public.espacios;
insert into public.espacios (codigo, camara_id, estado, fuente, lat, lng, poligono_roi)
values
  ('UPEC - Espacio 1', 'UPEC-001', 'LIBRE', 'CAMARA', null, null, '[]'::jsonb),
  ('UPEC - Espacio 2', 'UPEC-002', 'LIBRE', 'CAMARA', null, null, '[]'::jsonb),
  ('UPEC - Espacio 3', 'UPEC-003', 'LIBRE', 'CAMARA', null, null, '[]'::jsonb),
  ('UPEC - Espacio 4', 'UPEC-004', 'LIBRE', 'CAMARA', null, null, '[]'::jsonb);

-- Una cámara representa una casilla; evita que el sensor actualice varias filas.
create unique index if not exists espacios_camara_id_uidx on public.espacios(camara_id);
commit;

-- Tras levantar el script configurar_casillas.py, copia cada ROI a la fila
-- correspondiente si deseas persistir también su geometría. El runtime lee
-- las coordenadas de vision_module/zonas.json.
