# EstacionaYa — Infraestructura (Supabase + FastAPI + Visión YOLOv8)

## Arquitectura

```
[ Cámara IP / Webcam ]
        │
        ▼
[ vision/detectar.py ]  ──(actualiza solo el estado, JSON liviano)──>  [ Supabase (Postgres) ]
                                                                              │
                                                                    (Realtime · suscripción)
                                                                              ▼
                                                                     [ App Flutter / Panel web ]

[ api/ (FastAPI) ] ──> lógica de negocio que no es solo CRUD:
                        forzar-estado (RF5, rol Validador/Admin),
                        reportar (RF3/RF4/RF6, fallback de conductor)
```

Supabase actúa como base de datos + autenticación + tiempo real. FastAPI
existe para las reglas de negocio con permisos por rol que no se pueden
expresar solo con RLS. El servicio de visión es un proceso aparte que
corre donde esté la cámara.

## 1. Requisitos previos

- Docker y Docker Compose
- [Supabase CLI](https://supabase.com/docs/guides/cli) instalado
  (`npm install -g supabase` o el método de tu SO)
- Una cámara (webcam o IP/RTSP) para el servicio de visión

## 2. Levantar Supabase localmente

Supabase se administra con su propio CLI, no con nuestro
`docker-compose.yml` — el CLI ya orquesta sus contenedores internos
(Postgres, GoTrue, Realtime, Studio, etc.) con la configuración correcta.

```bash
supabase init      # solo la primera vez, dentro de este repo
supabase start     # levanta todo el stack de Supabase en Docker
supabase status    # muestra las URLs y las keys (anon, service_role, jwt secret)
```

Copia los valores de `supabase status` a un archivo `.env` en la raíz
del proyecto (usa `.env.example` como plantilla). Solo necesitas dos
valores: `SUPABASE_URL` (el "Project URL") y `SUPABASE_SERVICE_ROLE_KEY`
(la llave **Secret**, `sb_secret_...` — en versiones nuevas del CLI
reemplaza a la antigua `service_role key`, pero funciona igual en el
código). No hace falta la llave "Publishable"/`anon` ni un JWT secret:
la API valida los tokens llamando directamente a Supabase Auth.

## 3. Aplicar el esquema (tablas, RLS, función de cercanía, Realtime)

```bash
supabase db push
```

Esto ejecuta `supabase/migrations/0001_init.sql`, que crea:

- `perfiles` (rol: CONDUCTOR / VALIDADOR / ADMIN, puntos de karma)
- `espacios` (estado LIBRE/OCUPADO, ROI de cámara, ubicación geográfica)
- `historial_estados` (auditoría de cada cambio, con su fuente)
- políticas RLS (lectura para autenticados, escritura solo vía backend)
- la tabla `espacios` publicada en Realtime (RF7)

## 4. Configurar los espacios y la cámara

Edita `vision/config/camaras.json` con el `id_supabase` de cada fila que
insertes en la tabla `espacios` (vía Supabase Studio o SQL) y el
polígono de píxeles (`poligono_roi`) que delimita cada puesto en el
frame de tu cámara.

## 5. Levantar la API y el servicio de visión

```bash
docker compose up --build
```

- API disponible en `http://localhost:8000` (docs interactivas en
  `http://localhost:8000/docs`)
- El servicio de visión empieza a leer la cámara y solo escribe en
  Supabase cuando el estado de un espacio cambia

> **Nota sobre la cámara en Docker:** el passthrough de webcam funciona
> bien en Linux (`/dev/video0`). En Windows/Mac con Docker Desktop no
> es confiable — en ese caso corre `python detectar.py` nativo (fuera
> de Docker) o usa una cámara IP/RTSP como `fuente_video`.

## 6. Probar los endpoints de la API

```bash
# Registro y login los maneja Supabase Auth directamente (no la API)
curl http://localhost:8000/salud

curl -H "Authorization: Bearer <access_token_supabase>" \
     http://localhost:8000/perfil/me

curl -X POST http://localhost:8000/espacios/1/forzar-estado \
     -H "Authorization: Bearer <access_token_de_un_validador>" \
     -H "Content-Type: application/json" \
     -d '{"estado": "OCUPADO", "minutos_bloqueo": 30}'
```

## Pendiente (fuera de este alcance)

- **App Flutter**: ya está en `app/` — pantalla de login/registro y
  pantalla principal (mapa + lista de espacios + botones de reporte),
  conectada a Supabase Realtime y a esta API. Ver `app/README.md` para
  generar los proyectos nativos y correrla.
- **Panel web para Validadores/Admin**: se puede reconstruir en Vue.js
  (como estaba planeado originalmente) apuntando a esta misma API y a
  Supabase, o cubrirse dentro de la propia app Flutter (falta UI para
  RF5, el endpoint ya existe).
- **Pagos (Payphone/Placetopay)**: integración futura, no forma parte
  del MVP.
