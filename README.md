# EstacionaYa

MVP de disponibilidad de estacionamientos en el campus UPEC de Tulcán. El monorepo contiene la app Flutter (`app/`), la API FastAPI (`api/`), el esquema Supabase (`supabase/`) y el módulo de visión por ROI (`vision_module/`), que usa YOLOv8 nano para detectar motos, autos y camionetas y conserva el umbral por píxeles como respaldo. El detector anterior (`vision/`) queda fuera del flujo del MVP.

## Arquitectura del MVP

```text
Webcam 0 → vision_module (ROI + YOLO asíncrono + 20 detecciones estables)
         → FastAPI recibe el JPEG anotado y lo distribuye por MJPEG
         → PATCH solo al cambiar estado; heartbeat separado cada segundo
         → Supabase (Postgres + Realtime)
         → Flutter (mapa y lista en vivo; gris si el heartbeat vence)

Flutter autenticado → FastAPI → reportes, cercanía GPS,
                              forzado y bloqueo temporal por validador
```

Las cuentas autenticadas pueden reservar un espacio libre por 10 minutos y cancelar su propia reserva. FastAPI libera las reservas vencidas y Supabase Realtime propaga el cambio a la app. El filtro de vehículo consulta el campo `tipo_vehiculo` del espacio; `MIXTO` se muestra en todos los filtros.

Los IDs de `espacios` y sus referencias usan UUID. La cámara actualiza un espacio después de confirmar 20 frames y la base rechaza cambios de `fuente=CAMARA` mientras un bloqueo de validador esté vigente. Un trigger guarda los cambios de estado en el historial dentro de la misma transacción.

## Supabase local

Requisitos: Docker Desktop activo y Supabase CLI. Desde esta carpeta:

```powershell
./supabase.exe start
./supabase.exe db reset
./supabase.exe status
```

`db reset` aplica las migraciones y el seed local. En una base que ya registró `0001` y `0002`, `supabase db push` aplica `0003_uuid_schema.sql`, convierte los IDs BIGINT existentes a UUID y preserva las relaciones del historial. Si el esquema se creó manualmente con el script UUID anterior y no hay historial de migraciones, primero revisa el estado de la base y alinea el historial de Supabase CLI; no ejecutes `db push` a ciegas. Para poblar registros en un proyecto remoto, aplica el esquema validado y después ejecuta `supabase/scripts/rf01_rf02_rf20_espacios.sql` en el SQL Editor. La conversión cambia los IDs de espacios; actualiza integraciones externas que guardaran IDs numéricos y toma un backup antes de migrar datos reales.

El mapa solo necesita la clave publicable/anon y dispone de lectura anónima mediante RLS. El backend y la cámara usan una clave secreta/service-role únicamente en el equipo de confianza. Nunca pongas esa clave dentro de Flutter.

La migración `supabase/migrations/0006_reservas_vehiculos.sql` agrega reservas temporales, tipos de vehículo y la tabla privada de propietarios de reservas. Debe aplicarse antes de iniciar la nueva versión de FastAPI. Los espacios nuevos comienzan con `tipo_vehiculo = 'MIXTO'`; así se muestran en todos los filtros hasta que se asigne un tipo específico.

## FastAPI

```powershell
Copy-Item .env.example .env
# Copia también VISION_STREAM_TOKEN a api/.env y configúralo en la consola
# donde arrancas vision_module.
docker compose up --build api
```

La API se publica en `http://localhost:8000`; el contrato está en `/docs`. Requiere token Supabase para perfil, reportes, historial y operaciones de validador. La API verifica el rol `VALIDADOR` o `ADMIN` en las operaciones administrativas.

## Flutter

```powershell
cd app
flutter pub get
flutter test
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000 --dart-define=SUPABASE_URL=http://10.0.2.2:54321 --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_TU_CLAVE
```

Para un teléfono físico sustituye `10.0.2.2` por la IP local del computador. El mapa funciona sin cuenta; el botón de inicio de sesión habilita reportes. A los validadores y administradores se les muestran acciones de forzado e historial. El usuario debe recibir su rol desde el SQL Editor, no desde metadatos de registro.

## Módulo de cámara

En otra consola de PowerShell, instala dependencias y define credenciales solo en esa sesión:

```powershell
cd C:\Users\Fercho\Documents\Aplicaciones-Mobiles
./vision_module/.venv/Scripts/python.exe -m pip install -r vision_module/requirements.txt
$env:SUPABASE_URL = "http://127.0.0.1:54321"
$env:SUPABASE_SERVICE_ROLE_KEY = "TU_CLAVE_SECRETA_LOCAL"
$env:VISION_STREAM_TOKEN = "EL_MISMO_SECRETO_CONFIGURADO_EN_api/.env"
./vision_module/.venv/Scripts/python.exe vision_module/main.py
```

Para Supabase remoto usa la URL HTTPS. La consola ya no abre una ventana nativa: el frame anotado llega a `/admin` por `/video_feed`. Ajusta los ROI desde el panel o con las herramientas de calibración; el detector cuenta píxeles contrastados y no clasifica autos semánticamente. Lee `vision_module/README.md` para diagnóstico y límites.

## Validación disponible

- `flutter analyze` y `flutter test` verifican el cliente Flutter.
- El módulo de visión puede probarse con webcam simulada y respuestas HTTP simuladas; ello no demuestra conectividad contra el Supabase del usuario ni calibración física.
- La prueba final requiere Docker/Supabase en marcha, clave local y permiso de cámara. Detener el proceso de visión debe volver gris el marcador tras vencer el heartbeat (3 segundos).

Pagos, reservas permanentes y reconocimiento de placas quedan fuera del MVP.
