-- SOLO DESPUES de revisar 00_verificar.sql y comprobar que no hay FK con datos.
-- Protege las filas antiguas en una tabla independiente; requiere privilegios de propietario.
CREATE TABLE IF NOT EXISTS public.respaldo_espacios_anteriores_antizana
AS SELECT * FROM public.espacios
WHERE codigo IN ('Hospital Luis G. Dávila','Parque Central de Tulcán',
                 'Terminal Terrestre de Tulcán','Universidad UPEC');

-- Lee el respaldo antes de borrar:
SELECT codigo, camara_id FROM public.respaldo_espacios_anteriores_antizana;

-- Ejecuta la siguiente sentencia SOLO si no existen historiales/referencias dependientes.
-- El ON DELETE CASCADE en una FK podria eliminar datos dependientes.
-- DELETE FROM public.espacios WHERE codigo IN
-- ('Hospital Luis G. Dávila','Parque Central de Tulcán',
--  'Terminal Terrestre de Tulcán','Universidad UPEC');
