-- Seed de espacios compatible con el esquema UUID canónico.
-- Aplicar primero las migraciones con `supabase db push`; después ejecutar
-- este archivo en Supabase Studio > SQL Editor.
begin;

insert into public.espacios (codigo, camara_id, estado, lat, lng)
select datos.codigo, datos.camara_id, datos.estado, datos.lat, datos.lng
from (values
    ('Parque Central de Tulcán', 'CAM-001', 'LIBRE', 0.8119::double precision, -77.7173::double precision),
    ('Universidad UPEC', 'CAM-002', 'OCUPADO', 0.8257::double precision, -77.7159::double precision),
    ('Terminal Terrestre de Tulcán', 'CAM-003', 'RESERVADO', 0.8068::double precision, -77.7207::double precision),
    ('Hospital Luis G. Dávila', 'CAM-004', 'SIN_SERVICIO', 0.8143::double precision, -77.7098::double precision)
) as datos(codigo, camara_id, estado, lat, lng)
where not exists (
    select 1 from public.espacios existentes where existentes.camara_id = datos.camara_id
)
on conflict (codigo) do nothing;

insert into public.vision_heartbeat (camara_id, ultimo_contacto)
values ('CAM-001', 'epoch'::timestamptz)
on conflict (camara_id) do nothing;

commit;
