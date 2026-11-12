# EstacionaYa — 5 plazas ANTIZANA reales

1. Ejecuta `sql/00_verificar.sql` en Supabase SQL Editor para ver restricciones y FKs.
2. Ejecuta `sql/01_registrar_antizana.sql` para crear ANT-001..005 en `SIN_SERVICIO` (no se publican como libres falsamente).
3. Ejecuta `sql/02_retirar_antiguos.sql` para respaldar los cuatro sitios históricos. **No ejecutes el DELETE comentado** hasta revisar las claves foráneas y sus referencias. Borrar en cascada puede destruir historial.
4. Detén el detector con Ctrl+C y respalda `api/app/main.py`, `api/app/admin.html` y `vision_module/detector_zonas_ezviz.py`. Copia los tres archivos de este paquete al proyecto en sus rutas respectivas.
5. En `api/.env`, configura:

   VISION_ZONE_SPACE_MAP={"ANT-001":"ANT-001","ANT-002":"ANT-002","ANT-003":"ANT-003","ANT-004":"ANT-004","ANT-005":"ANT-005"}
   VISION_AUTO_FREE=false
   VISION_FREE_SECONDS=60

6. `docker compose up -d --no-deps --force-recreate api` (tras verificar el puerto 8000 libre y la red externa configurada).
7. El detector publica los frames y los estados reales a `/vision/frame` y `/vision/zonas`. Un 204 en ambas rutas confirma recepcion. `VISION_STREAM_TOKEN` debe coincidir en API y detector.
8. Calibra cada ROI verificando que representa SOLO la plaza física (ANT-004 y ANT-005 se ven dudosas en tus capturas). Cuando un espacio esté verificado y realmente disponible, habilítalo en SQL con `UPDATE public.espacios SET estado='LIBRE' WHERE codigo='ANT-00X' AND estado='SIN_SERVICIO';`. Para ANT-002 ocupado actualmente, no marques libre sin confirmacion; habilitalo en una transicion observada de desocupacion o adapta el flujo para iniciar como ocupado confirmado por cámara.
9. Despues de observar por varios ciclos que no hay falsos negativos, habilita `VISION_AUTO_FREE=true`, recrea solo la API, y revisa logs. Esto libera despues de 60 segundos seguidos de `SIN_DETECCION` SOLO las ocupaciones registradas por CAMARA y no bloqueadas manualmente. **La ausencia de deteccion NO prueba plaza vacia**, por lo que esta opcion es experimental y no debe habilitarse sin calibracion.
10. Panel `/admin` ahora lista ANT-% (no UPEC%) y recarga cada 2 segundos. En Flutter la consulta debe filtrar por `codigo.like('ANT-%')`, escuchar Supabase Realtime `public.espacios` y/o consultar periódicamente; hace falta adaptar los archivos Flutter reales del proyecto para asegurar la actualización en pantalla.

**Limitaciones:** Las zonas en imagen no equivalen necesariamente a plazas válidas. El ROI debe validarse in situ. Si la cámara deja de enviar, conserva el último estado pero la app debe mostrarlo como desactualizado, no asumir disponibilidad. Para producción, añadir timestamps de observación, controles de salud y persistencia de evidencias en un registro de eventos.
