from datetime import datetime, timedelta, timezone
import hmac
import json
import logging
import os
import time
from pathlib import Path
import threading
from uuid import UUID

from pydantic import BaseModel, Field
from typing import Literal

from fastapi import Cookie, Depends, FastAPI, Header, HTTPException, Request, Response, status
from fastapi.responses import HTMLResponse, StreamingResponse
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPAuthorizationCredentials

from .auth import obtener_usuario_actual, requerir_rol, security
from .schemas import CalibrarEspacioIn, ForzarEstadoIn, PerfilOut, ReporteConductorIn, ReservarEspacioIn, RoiRectIn, TipoVehiculoEspacioIn
from .supabase_client import get_supabase_admin

app = FastAPI(title="EstacionaYa API", version="0.1.0")
LOG = logging.getLogger("uvicorn.error")
LOG.setLevel(logging.INFO)  # Hace visibles los diagnosticos en docker logs.

RESERVA_MINUTOS = 5
RESERVA_SWEEP_SEGUNDOS = 5
_reserva_stop = threading.Event()
_reserva_thread: threading.Thread | None = None
ADMIN_HTML = Path(__file__).with_name("admin.html")
VIDEO_SESSION_COOKIE = "estacionaya_admin_video"
_video_condition = threading.Condition()
current_frame = b""
_video_frame_version = 0


def _liberar_reservas_expiradas() -> None:
    """Libera reservas vencidas en forma idempotente y deja que Realtime publique el cambio."""
    ultimo_error = 0.0
    while not _reserva_stop.is_set():
        try:
            ahora = datetime.now(timezone.utc).isoformat()
            resultado = (
                get_supabase_admin().table("espacios")
                .update({
                    "estado": "LIBRE",
                    "estado_reserva": "LIBRE",
                    "expiracion_reserva": None,
                    "vehiculo_detectado": None,
                    "fuente": "CONDUCTOR",
                    "forzado_por": None,
                })
                .eq("estado", "RESERVADO")
                .lte("expiracion_reserva", ahora)
                .execute()
            )
            if resultado.data:
                get_supabase_admin().table("reservas_espacios").delete().in_(
                    "espacio_id", [row["id"] for row in resultado.data]
                ).execute()
                LOG.info("Se liberaron %d reservas vencidas.", len(resultado.data))
        except Exception:
            ahora_monotono = time.monotonic()
            if ahora_monotono - ultimo_error >= 30:
                LOG.exception("No se pudieron liberar las reservas expiradas.")
                ultimo_error = ahora_monotono
        _reserva_stop.wait(RESERVA_SWEEP_SEGUNDOS)


@app.on_event("startup")
def iniciar_expiracion_reservas() -> None:
    global _reserva_thread, _reserva_stop
    if _reserva_thread and _reserva_thread.is_alive():
        return
    _reserva_stop = threading.Event()
    _reserva_thread = threading.Thread(
        target=_liberar_reservas_expiradas,
        name="estacionaya-reservas-expiracion",
        daemon=True,
    )
    _reserva_thread.start()


@app.on_event("shutdown")
def detener_expiracion_reservas() -> None:
    _reserva_stop.set()
    if _reserva_thread and _reserva_thread.is_alive():
        _reserva_thread.join(timeout=2)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # ajustar a los orígenes reales (app Flutter / panel Vue) en producción
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/salud")
def salud():
    return {"status": "ok"}


@app.post("/vision/frame", status_code=status.HTTP_204_NO_CONTENT)
async def recibir_frame_vision(
    request: Request,
    x_vision_token: str = Header(default=""),
):
    """Recibe el frame anotado por el proceso que ya posee la webcam."""
    expected = os.getenv("VISION_STREAM_TOKEN", "").strip()
    if not expected:
        raise HTTPException(status_code=503, detail="El stream de visión no está configurado.")
    if not hmac.compare_digest(x_vision_token, expected):
        raise HTTPException(status_code=401, detail="Token de stream inválido.")
    frame = await request.body()
    if not frame.startswith(b"\xff\xd8\xff") or len(frame) > 8 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="El frame JPEG es inválido o demasiado grande.")

    global current_frame, _video_frame_version
    with _video_condition:
        current_frame = frame
        _video_frame_version += 1
        _video_condition.notify_all()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


# Observaciones temporales de la cámara ANTIZANA; no modifican Supabase.
# Se descartan como observaciones vigentes si no llegan novedades en 8 segundos.
_estado_vision_lock = threading.Lock()
_estado_vision: dict[str, dict] = {}
_estado_vision_actualizado = 0.0
ESTADOS_VISION = {"OCUPADO_PROBABLE", "VERIFICANDO", "SIN_DETECCION"}
ZONAS_ANTIZANA = {f"ANT-{n:03d}" for n in range(1, 6)}

class EstadoZonaIn(BaseModel):
    id: str = Field(min_length=7, max_length=7)
    estado: Literal["OCUPADO_PROBABLE", "VERIFICANDO", "SIN_DETECCION"]

class ObservacionCamaraIn(BaseModel):
    camara: Literal["ANTIZANA FRENTE UPEC"]
    zonas: list[EstadoZonaIn] = Field(min_length=1, max_length=5)

# Asociación explícita ANT -> codigo real de espacios. Nunca se inventa una correspondencia.
# Ejemplo en api/.env: VISION_ZONE_SPACE_MAP={"ANT-002":"UPEC-002"}
# No publiques este mapa hasta comprobar la ubicación física y el código en Supabase.

def _mapa_espacios_vision() -> dict[str, str]:
    raw = os.getenv("VISION_ZONE_SPACE_MAP", "{}").strip() or "{}"
    try:
        mapping = json.loads(raw)
    except (TypeError, ValueError) as exc:
        raise RuntimeError("VISION_ZONE_SPACE_MAP debe ser JSON valido") from exc
    if not isinstance(mapping, dict):
        raise RuntimeError("VISION_ZONE_SPACE_MAP debe ser un objeto JSON")
    if any(key not in ZONAS_ANTIZANA or not isinstance(code, str) or not code.strip()
           for key, code in mapping.items()):
        raise RuntimeError("El mapa necesita zonas ANT-001..005 y codigos no vacios")
    if len(set(mapping.values())) != len(mapping):
        raise RuntimeError("Dos zonas no pueden representar el mismo espacio")
    return mapping


# Los contadores solo avanzan cuando llegan observaciones frescas de la camara.
# La liberacion automatica es OPT-IN, tras revisar los ROI y la visibilidad nocturna.
_inicio_ausencia: dict[str, float] = {}
_ultima_ocupacion: dict[str, float] = {}


def _sincronizar_espacios_observados(zonas: list[EstadoZonaIn]) -> dict[str, str]:
    mapping = _mapa_espacios_vision()
    if not mapping:
        LOG.warning("ANT MAPA VACIO: no se sincronizaran espacios")
        return {}
    db = get_supabase_admin()
    actualizados: dict[str, str] = {}
    try:
        db.table("vision_heartbeat").upsert({
            "camara_id": "CAM-005",
            "ultimo_contacto": datetime.now(timezone.utc).isoformat(),
        }).execute()
    except Exception:
        LOG.exception("ANT HEARTBEAT: no se pudo renovar CAM-005")
    ahora = datetime.now(timezone.utc)
    ahora_mono = time.monotonic()
    auto_liberar = os.getenv("VISION_AUTO_FREE", "false").strip().lower() == "true"
    tiempo_ausencia = max(45, int(os.getenv("VISION_FREE_SECONDS", "60")))
    for zona in zonas:
        codigo = mapping.get(zona.id)
        if not codigo:
            LOG.warning("ANT SIN MAPEO: zona=%s", zona.id)
            continue
        LOG.info("ANT RECIBIDO: zona=%s, deteccion=%s, codigo=%s", zona.id, zona.estado, codigo)
        if zona.estado == "OCUPADO_PROBABLE":
            _inicio_ausencia.pop(zona.id, None)
            _ultima_ocupacion[zona.id] = ahora_mono
            nuevo_estado = "OCUPADO"
            previo = "LIBRE"
            LOG.info(
                "ANT DIAGNOSTICO: zona=%s, deteccion=%s, destino=%s",
                zona.id, zona.estado, codigo,
            )
        elif zona.estado == "SIN_DETECCION":
            _inicio_ausencia.setdefault(zona.id, ahora_mono)
            if not auto_liberar or ahora_mono - _inicio_ausencia[zona.id] < tiempo_ausencia:
                LOG.info("ANT AUSENCIA NO LIBERADA: zona=%s, auto_liberar=%s, segundos=%.1f/%s",
                         zona.id, auto_liberar, ahora_mono - _inicio_ausencia[zona.id], tiempo_ausencia)
                continue
            nuevo_estado = "LIBRE"
            previo = "OCUPADO"
        else:
            # Un estado VERIFICANDO invalida la ausencia continua.
            _inicio_ausencia.pop(zona.id, None)
            LOG.info("ANT VERIFICANDO: zona=%s; sin cambios en Supabase", zona.id)
            continue

        consulta = (db.table("espacios")
                    .select("id,codigo,estado,fuente,bloqueado_hasta")
                    .eq("codigo", codigo).limit(2).execute())
        rows = consulta.data or []
        if len(rows) != 1:
            LOG.error("Mapa incorrecto: %s -> %s (filas=%s)", zona.id, codigo, len(rows))
            continue
        row = rows[0]
        LOG.info("ANT BD: zona=%s, codigo=%s, estado=%s, fuente=%s, bloqueo=%s",
                 zona.id, codigo, row.get("estado"), row.get("fuente"), row.get("bloqueado_hasta"))
        bloqueo = row.get("bloqueado_hasta")
        if bloqueo:
            try:
                if _parse_datetime(bloqueo) > ahora:
                    LOG.info("ANT BLOQUEADO: zona=%s, hasta=%s", zona.id, bloqueo)
                    continue
            except (ValueError, TypeError):
                LOG.warning("Bloqueo no interpretable para %s; se omite", codigo)
                continue
        if row["estado"] != previo:
            LOG.info(
                "ANT SIN CAMBIO: zona=%s, estado_actual=%s, esperado=%s",
                zona.id, row["estado"], previo,
            )
            continue
        LOG.info(
            "ANT INTENTANDO ACTUALIZAR: zona=%s, %s -> %s",
            zona.id, previo, nuevo_estado,
        )
        # Solo revertir una ocupacion originada por la camara; nunca pisar bloqueos humanos.
        if nuevo_estado == "LIBRE" and row.get("fuente") != "CAMARA":
            LOG.warning("ANT LIBERACION OMITIDA: zona=%s, fuente=%s", zona.id, row.get("fuente"))
            continue
        condicion = (db.table("espacios")
                     .update({"estado": nuevo_estado, "fuente": "CAMARA"})
                     .eq("id", row["id"]).eq("estado", previo))
        if nuevo_estado == "LIBRE":
            condicion = condicion.eq("fuente", "CAMARA")
        try:
            resultado = condicion.execute()  # El builder de UPDATE ya devuelve filas; no admite .select()
        except Exception:
            LOG.exception("ANT ERROR SUPABASE: zona=%s, codigo=%s, cambio=%s->%s",
                          zona.id, codigo, previo, nuevo_estado)
            raise
        if not resultado.data:
            LOG.warning(
                "ANT SIN FILAS ACTUALIZADAS: zona=%s, codigo=%s, cambio=%s->%s; revisar condiciones o triggers",
                zona.id, codigo, previo, nuevo_estado,
            )
        if resultado.data:
            actualizados[zona.id] = codigo
            LOG.info("Observacion ANT %s -> espacio %s: %s", zona.id, codigo, nuevo_estado)
            if nuevo_estado == "LIBRE":
                # Evita escrituras repetidas mientras sigue vacio.
                _inicio_ausencia[zona.id] = ahora_mono
    return actualizados


@app.post("/vision/zonas", status_code=204)
def recibir_estados_vision(
    reporte: ObservacionCamaraIn,
    x_vision_token: str = Header(default=""),
):
    esperado = os.getenv("VISION_STREAM_TOKEN", "").strip()
    if not esperado:
        raise HTTPException(status_code=503, detail="Token de visión no configurado")
    if not hmac.compare_digest(x_vision_token, esperado):
        raise HTTPException(status_code=401, detail="Token de visión inválido")
    identificadores = [z.id for z in reporte.zonas]
    if any(z not in ZONAS_ANTIZANA for z in identificadores) or len(set(identificadores)) != len(identificadores):
        raise HTTPException(status_code=422, detail="Zonas ANT inválidas o duplicadas")
    ahora = datetime.now(timezone.utc).isoformat()
    global _estado_vision, _estado_vision_actualizado
    with _estado_vision_lock:
        _estado_vision = {z.id: {"id": z.id, "estado": z.estado, "observado_en": ahora} for z in reporte.zonas}
        _estado_vision_actualizado = time.monotonic()
    LOG.info("ANT REPORTE: camara=%s, zonas=%s",
             reporte.camara, ", ".join(f"{z.id}:{z.estado}" for z in reporte.zonas))
    try:
        cambios = _sincronizar_espacios_observados(reporte.zonas)
        if cambios:
            LOG.info("ANT SINCRONIZADOS: %s", cambios)
    except Exception:
        LOG.exception("Fallo la sincronizacion ANT -> Supabase; observaciones disponibles en el panel")
        raise HTTPException(status_code=503, detail="No se pudo sincronizar ocupacion con Supabase")
    return Response(status_code=204)

@app.get("/admin/vision/zonas")
def ver_estados_vision(usuario: dict = Depends(requerir_rol("admin"))):
    del usuario
    with _estado_vision_lock:
        copia = dict(_estado_vision)
        vigente = bool(copia) and time.monotonic() - _estado_vision_actualizado <= 8
    return {
        "camara": "ANTIZANA FRENTE UPEC",
        "en_linea": vigente,
        "mapeo_espacios": _mapa_espacios_vision(),
        "zonas": [
            copia.get(id, {"id": id, "estado": "SIN_DATOS", "observado_en": None})
            if vigente else {"id": id, "estado": "SIN_DATOS", "observado_en": None}
            for id in sorted(ZONAS_ANTIZANA)
        ],
        "nota": "OCUPADO_PROBABLE es una detección automática, no confirmación humana. SIN_DETECCION no equivale a LIBRE.",
    }


@app.post("/admin/video-session")
def crear_sesion_video_admin(
    request: Request,
    response: Response,
    credenciales: HTTPAuthorizationCredentials = Depends(security),
    usuario: dict = Depends(requerir_rol("admin")),
):
    """Entrega al navegador una cookie de stream solo después del JWT admin."""
    del usuario
    response.set_cookie(
        key=VIDEO_SESSION_COOKIE,
        value=credenciales.credentials,
        max_age=3600,
        httponly=True,
        secure=request.url.scheme == "https",
        samesite="strict",
        path="/video_feed",
    )
    return {"detail": "Sesión de video habilitada."}


@app.post("/admin/video-session/clear", include_in_schema=False)
def borrar_sesion_video_admin(response: Response):
    response.delete_cookie(
        key=VIDEO_SESSION_COOKIE,
        httponly=True,
        samesite="strict",
        path="/video_feed",
    )
    return {"detail": "Sesión de video cerrada."}


def _generar_mjpeg():
    version_enviada = 0
    while True:
        with _video_condition:
            if version_enviada == _video_frame_version:
                _video_condition.wait(timeout=10)
            frame = current_frame
            version_actual = _video_frame_version
        if frame is None or version_actual == version_enviada:
            continue
        version_enviada = version_actual
        yield (
            b"--frame\r\nContent-Type: image/jpeg\r\nContent-Length: "
            + str(len(frame)).encode("ascii")
            + b"\r\n\r\n"
            + frame
            + b"\r\n"
        )


@app.get("/video_feed", include_in_schema=False)
def video_feed(token: str | None = Cookie(default=None, alias=VIDEO_SESSION_COOKIE)):
    if not token:
        raise HTTPException(status_code=401, detail="Inicia sesión como administrador para ver el video.")
    usuario = obtener_usuario_actual(
        HTTPAuthorizationCredentials(scheme="Bearer", credentials=token)
    )
    if usuario.get("rol", "").casefold() != "admin":
        raise HTTPException(status_code=403, detail="Se requiere rol admin para ver el video.")
    with _video_condition:
        if not current_frame:
            _video_condition.wait(timeout=3)
        if not current_frame:
            raise HTTPException(status_code=503, detail="La cámara todavía no envía frames a FastAPI.")
    return StreamingResponse(
        _generar_mjpeg(),
        media_type="multipart/x-mixed-replace; boundary=frame",
        headers={"Cache-Control": "no-store, no-cache, must-revalidate", "X-Accel-Buffering": "no"},
    )


@app.get("/admin", response_class=HTMLResponse, include_in_schema=False)
def admin_panel():
    """Sirve el panel; todos los datos y cambios siguen protegidos por JWT/rol."""
    if not ADMIN_HTML.exists():
        raise HTTPException(status_code=404, detail="Panel de administración no instalado.")
    html = ADMIN_HTML.read_text(encoding="utf-8")
    publishable_key = os.getenv("SUPABASE_PUBLISHABLE_KEY", "")
    if not publishable_key:
        raise HTTPException(status_code=503, detail="Falta SUPABASE_PUBLISHABLE_KEY en el backend.")
    return html.replace("__SUPABASE_URL__", os.getenv("SUPABASE_PUBLIC_URL") or os.environ["SUPABASE_URL"]).replace(
        "__SUPABASE_PUBLISHABLE_KEY__", publishable_key
    )


@app.get("/admin/espacios")
def listar_espacios_upec(usuario: dict = Depends(requerir_rol("admin"))):
    """Lista del panel restringida a administradores."""
    del usuario
    respuesta = (
        get_supabase_admin()
        .table("espacios")
        .select("id,codigo,camara_id,estado,estado_reserva,expiracion_reserva,tipo_vehiculo,vehiculo_detectado,lat,lng,latitud,longitud,bloqueado_hasta,updated_at")
        .like("codigo", "ANT-%")
        .order("codigo")
        .execute()
    )
    return respuesta.data or []


@app.patch("/admin/espacios/{espacio_id}/tipo-vehiculo")
def actualizar_tipo_vehiculo_espacio(
    espacio_id: UUID,
    body: TipoVehiculoEspacioIn,
    usuario: dict = Depends(requerir_rol("admin")),
):
    """Asigna los tipos de vehículo admitidos por un puesto UPEC."""
    del usuario
    resultado = (
        get_supabase_admin().table("espacios")
        .update({"tipo_vehiculo": body.tipo_vehiculo})
        .eq("id", str(espacio_id))
        .like("codigo", "ANT-%")
        .select("id,codigo,tipo_vehiculo")
        .execute()
    )
    if not resultado.data:
        raise HTTPException(status_code=404, detail="Espacio UPEC no encontrado.")
    return resultado.data[0]



@app.get("/admin/camaras")
def listar_configuracion_camaras(
    usuario: dict = Depends(requerir_rol("admin"))
):
    """Lista los cuatro espacios de estacionamiento y sus ROI."""
    del usuario

    camera_ids = ["CAM-005"]

    espacios = (
        get_supabase_admin()
        .table("espacios")
        .select("id,codigo,camara_id")
        .in_("camara_id", camera_ids)
        .order("camara_id")
        .execute().data or []
    )

    configuraciones = (
        get_supabase_admin()
        .table("config_camaras")
        .select(
            "espacio_id,x,y,width,height,"
            "frame_width,frame_height,updated_at"
        )
        .execute().data or []
    )

    por_espacio = {
        str(config["espacio_id"]): config
        for config in configuraciones
    }

    return [
        {
            **espacio,
            "roi": por_espacio.get(str(espacio["id"]))
        }
        for espacio in espacios
    ]



@app.put("/admin/camaras/{espacio_id}")
def guardar_roi_camara(
    espacio_id: UUID,
    body: RoiRectIn,
    usuario: dict = Depends(requerir_rol("admin")),
):
    """Crea o reemplaza el ROI de una cámara de EstacionaYa."""
    del usuario

    supabase = get_supabase_admin()

    camera_ids = ["CAM-005"]

    espacio = (
        supabase.table("espacios")
        .select("id,camara_id,codigo")
        .eq("id", str(espacio_id))
        .in_("camara_id", camera_ids)
        .maybe_single()
        .execute()
    )

    if not espacio.data:
        raise HTTPException(
            status_code=404,
            detail="Cámara no encontrada entre los espacios configurados."
        )

    valores = {
        "espacio_id": str(espacio_id),
        "camara_id": espacio.data["camara_id"],
        "x": body.x,
        "y": body.y,
        "width": body.width,
        "height": body.height,
        "frame_width": body.frame_width,
        "frame_height": body.frame_height,
    }

    resultado = (
        supabase.table("config_camaras")
        .upsert(valores, on_conflict="espacio_id")
        .select(
            "espacio_id,camara_id,x,y,width,height,"
            "frame_width,frame_height,updated_at"
        )
        .single()
        .execute()
    )

    if not resultado.data:
        raise HTTPException(
            status_code=502,
            detail="No se pudo guardar la configuración del estacionamiento."
        )

    return resultado.data


@app.get("/perfil/me", response_model=PerfilOut)
def obtener_mi_perfil(usuario: dict = Depends(obtener_usuario_actual)):
    supabase = get_supabase_admin()
    respuesta = (
        supabase.table("perfiles").select("*").eq("id", usuario["id"]).single().execute()
    )
    if not respuesta.data:
        raise HTTPException(status_code=404, detail="Perfil no encontrado.")
    return respuesta.data


@app.post("/espacios/{espacio_id}/forzar-estado")
def forzar_estado(
    espacio_id: UUID,
    body: ForzarEstadoIn,
    usuario: dict = Depends(requerir_rol("validador", "admin")),
):
    """RF5: el Validador sobrescribe y bloquea temporalmente un espacio."""
    supabase = get_supabase_admin()

    actual = (
        supabase.table("espacios")
        .select("estado")
        .eq("id", str(espacio_id))
        .maybe_single()
        .execute()
    )
    if not actual.data:
        raise HTTPException(status_code=404, detail="Espacio no encontrado.")

    bloqueado_hasta = datetime.now(timezone.utc) + timedelta(minutes=body.minutos_bloqueo)

    actualizado = supabase.table("espacios").update(
        {
            "estado": body.estado,
            "estado_reserva": body.estado,
            "expiracion_reserva": None,
            "fuente": "VALIDADOR",
            "forzado_por": usuario["id"],
            "bloqueado_hasta": bloqueado_hasta.isoformat(),
        }
    ).eq("id", str(espacio_id)).eq("estado", actual.data["estado"]).select("id").execute()
    if not actualizado.data:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="El espacio cambió mientras se procesaba la solicitud. Intenta de nuevo.",
        )
    supabase.table("reservas_espacios").delete().eq("espacio_id", str(espacio_id)).execute()

    # El trigger de BD guarda el historial en la misma transacción del cambio.
    # Realtime publica el UPDATE de forma automática.
    return {"detail": "Estado actualizado.", "espacio_id": str(espacio_id), "estado": body.estado}


@app.get("/espacios/{espacio_id}/historial")
def historial_espacio(
    espacio_id: UUID,
    usuario: dict = Depends(requerir_rol("validador", "admin")),
):
    """RF8: historial de cambios disponible solo para validadores y admins."""
    del usuario
    supabase = get_supabase_admin()
    respuesta = (
        supabase.table("historial_estados")
        .select("id, espacio_id, estado_anterior, estado_nuevo, fuente, usuario_id, creado_en")
        .eq("espacio_id", str(espacio_id))
        .order("creado_en", desc=True)
        .limit(100)
        .execute()
    )
    return respuesta.data or []


@app.post("/espacios/reportar")
def reportar(
    body: ReporteConductorIn,
    usuario: dict = Depends(obtener_usuario_actual),
):
    """RF3/RF4/RF6: reporte de conductor, como respaldo del modelo por cámara."""
    supabase = get_supabase_admin()

    espacio = (
        supabase.table("espacios")
        .select("estado, bloqueado_hasta, expiracion_reserva")
        .eq("id", str(body.espacio_id))
        .maybe_single()
        .execute()
    )
    if not espacio.data:
        raise HTTPException(status_code=404, detail="Espacio no encontrado.")

    bloqueado_hasta = espacio.data.get("bloqueado_hasta")
    if bloqueado_hasta and _parse_datetime(bloqueado_hasta) > datetime.now(timezone.utc):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Este espacio está bloqueado por un validador.",
        )
    expiracion_reserva = espacio.data.get("expiracion_reserva")
    if (
        espacio.data["estado"] == "RESERVADO"
        and expiracion_reserva
        and _parse_datetime(expiracion_reserva) > datetime.now(timezone.utc)
    ):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="El espacio tiene una reserva activa; la cámara confirmará su ocupación.",
        )

    cercano = supabase.rpc(
        "espacio_cercano",
        {
            "p_espacio_id": str(body.espacio_id),
            "p_lat": body.latitud,
            "p_lon": body.longitud,
        },
    ).execute()
    if not cercano.data:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Debes estar físicamente cerca del espacio para reportar.",
        )

    nuevo_estado = "OCUPADO" if body.tipo == "ME_ESTACIONE" else "LIBRE"

    # Los reintentos o reportes duplicados no deben crear auditoría ni sumar karma.
    if espacio.data["estado"] == nuevo_estado:
        return {"detail": "El espacio ya tenía ese estado.", "estado": nuevo_estado}

    actualizado = supabase.table("espacios").update(
        {
            "estado": nuevo_estado,
            "estado_reserva": nuevo_estado,
            "expiracion_reserva": None,
            "fuente": "CONDUCTOR",
            "forzado_por": None,
            "bloqueado_hasta": None,
        }
    ).eq("id", str(body.espacio_id)).eq("estado", espacio.data["estado"]).select("id").execute()
    if not actualizado.data:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="El espacio cambió mientras se procesaba el reporte. Actualiza e intenta de nuevo.",
        )
    supabase.table("reservas_espacios").delete().eq("espacio_id", str(body.espacio_id)).execute()

    if body.tipo == "VOY_A_SALIR":
        perfil = (
            supabase.table("perfiles")
            .select("puntos_karma")
            .eq("id", usuario["id"])
            .single()
            .execute()
        )
        nuevo_karma = perfil.data["puntos_karma"] + 10
        supabase.table("perfiles").update({"puntos_karma": nuevo_karma}).eq(
            "id", usuario["id"]
        ).execute()

    return {"detail": "Reporte registrado.", "estado": nuevo_estado}


def _parse_datetime(value: str | datetime) -> datetime:
    parsed = value if isinstance(value, datetime) else datetime.fromisoformat(value.replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        return parsed.replace(tzinfo=timezone.utc)
    return parsed

@app.post("/api/calibrar_espacio")
def calibrar_espacio(
    body: CalibrarEspacioIn,
    usuario: dict = Depends(requerir_rol("admin")),
):
    """Guarda el ROI ligado al espacio seleccionado por un administrador."""
    del usuario
    supabase = get_supabase_admin()
    espacio = (
        supabase.table("espacios")
        .select("id,camara_id,codigo")
        .eq("id", str(body.espacio_id))
        .like("codigo", "ANT-%")
        .maybe_single()
        .execute()
    )
    if not espacio.data:
        raise HTTPException(status_code=404, detail="Espacio UPEC no encontrado.")

    actualizado = (
        supabase.table("espacios")
        .update({
            "codigo": body.nombre.strip(),
            "lat": body.latitud,
            "lng": body.longitud,
            "estado_visibilidad": False,
        })
        .eq("id", str(body.espacio_id))
        .select("id,codigo,camara_id,lat,lng,estado_visibilidad")
        .single()
        .execute()
    )
    if not actualizado.data:
        raise HTTPException(status_code=502, detail="No se pudo actualizar el espacio.")

    tabla = supabase.table("config_camaras")
    coordenadas = {
        "x": body.x,
        "y": body.y,
        "width": body.width,
        "height": body.height,
        "frame_width": body.frame_width,
        "frame_height": body.frame_height,
    }
    columnas = "espacio_id,camara_id,x,y,width,height,frame_width,frame_height,updated_at"
    resultado = (
        tabla.update(coordenadas)
        .eq("espacio_id", str(body.espacio_id))
        .select(columnas)
        .execute()
    )
    if resultado.data:
        fila = resultado.data[0]
    else:
        creado = (
            tabla.insert(
                {
                    "espacio_id": str(body.espacio_id),
                    "camara_id": espacio.data["camara_id"],
                    **coordenadas,
                }
            )
            .select(columnas)
            .single()
            .execute()
        )
        fila = creado.data
    if not fila:
        raise HTTPException(status_code=502, detail="No se pudo guardar la configuración del espacio.")
    return {
        "detail": "Espacio y ROI guardados como pendientes de verificación.",
        "espacio": actualizado.data,
        "roi": fila,
    }


@app.post("/api/espacios/{espacio_id}/reservar")
def reservar_espacio(
    espacio_id: UUID,
    body: ReservarEspacioIn,
    usuario: dict = Depends(obtener_usuario_actual),
):
    """Reserva un espacio libre por cinco minutos para el usuario autenticado."""
    # La identidad se deriva del JWT validado por obtener_usuario_actual; nunca
    # se acepta un usuario_id arbitrario desde el cuerpo enviado por Flutter.
    usuario_id = str(UUID(usuario["id"]))
    try:
        reservado = get_supabase_admin().rpc(
            "reservar_espacio",
            {
                "p_espacio_id": str(espacio_id),
                "p_usuario_id": usuario_id,
                "p_tipo_vehiculo": body.tipo_vehiculo,
                "p_duracion_minutos": RESERVA_MINUTOS,
            },
        ).execute()
    except Exception as error:
        detalle = str(error).casefold()
        if "no encontrado" in detalle:
            raise HTTPException(status_code=404, detail="Espacio no encontrado.") from error
        if any(
            texto in detalle
            for texto in (
                "reservado",
                "libres",
                "bloqueado",
                "admite",
                "duración de la reserva",
                "reserva no puede superar cinco minutos",
            )
        ):
            LOG.warning("Reserva rechazada por Supabase para espacio %s: %s", espacio_id, error)
            raise HTTPException(status_code=409, detail=str(error)) from error
        LOG.exception(
            "Error de Supabase al reservar espacio %s para usuario %s",
            espacio_id,
            usuario_id,
        )
        raise HTTPException(
            status_code=502,
            detail=f"No se pudo completar la reserva en Supabase: {error}",
        ) from error
    if not reservado.data:
        LOG.error("Supabase devolvió una respuesta vacía al reservar espacio %s", espacio_id)
        raise HTTPException(
            status_code=502,
            detail="Supabase devolvió una respuesta vacía al reservar el espacio.",
        )
    if isinstance(reservado.data, dict) and reservado.data.get("estado") == "RESERVADO":
        return {"detail": f"Espacio reservado por {RESERVA_MINUTOS} minutos.", **reservado.data}
    LOG.error(
        "Respuesta inesperada de Supabase al reservar espacio %s: %r",
        espacio_id,
        reservado.data,
    )
    raise HTTPException(status_code=502, detail="La respuesta de la reserva no es válida.")


@app.get("/api/reservas/mias")
def listar_mis_reservas(usuario: dict = Depends(obtener_usuario_actual)):
    """Devuelve solo los identificadores de reservas activas del usuario actual."""
    supabase = get_supabase_admin()
    ahora = datetime.now(timezone.utc).isoformat()
    resultado = (
        supabase.table("reservas_espacios")
        .select("espacio_id,expiracion")
        .eq("usuario_id", usuario["id"])
        .gt("expiracion", ahora)
        .execute()
    )
    reservas = resultado.data or []
    if not reservas:
        return []
    ids = [reserva["espacio_id"] for reserva in reservas]
    activas = (
        supabase.table("espacios")
        .select("id")
        .in_("id", ids)
        .eq("estado", "RESERVADO")
        .gt("expiracion_reserva", ahora)
        .execute()
        .data or []
    )
    activas_ids = {str(espacio["id"]) for espacio in activas}
    return [reserva for reserva in reservas if str(reserva["espacio_id"]) in activas_ids]


@app.patch("/api/espacios/{espacio_id}/cancelar")
@app.delete("/api/espacios/{espacio_id}/reserva")
def cancelar_reserva(
    espacio_id: UUID,
    usuario: dict = Depends(obtener_usuario_actual),
):
    """Cancela una reserva propia; un administrador puede liberar cualquier reserva."""
    es_admin = str(usuario.get("rol", "")).casefold() == "admin"
    try:
        cancelada = get_supabase_admin().rpc(
            "cancelar_reserva_espacio",
            {
                "p_espacio_id": str(espacio_id),
                "p_usuario_id": usuario["id"],
                "p_es_admin": es_admin,
            },
        ).execute()
    except Exception as error:
        detalle = str(error).casefold()
        if "no encontrado" in detalle:
            raise HTTPException(status_code=404, detail="Espacio no encontrado.") from error
        if "solo quien reservó" in detalle:
            raise HTTPException(status_code=403, detail="Solo quien reservó el espacio puede cancelar la reserva.") from error
        if "reserva activa" in detalle:
            raise HTTPException(status_code=409, detail="El espacio no tiene una reserva activa.") from error
        raise HTTPException(status_code=502, detail="No se pudo cancelar la reserva.") from error
    if not cancelada.data:
        raise HTTPException(status_code=502, detail="Supabase no confirmó la cancelación.")
    return {"detail": "Reserva cancelada.", **cancelada.data}
