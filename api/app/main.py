from datetime import datetime, timedelta, timezone

from fastapi import Depends, FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware

from .auth import obtener_usuario_actual, requerir_rol
from .schemas import ForzarEstadoIn, PerfilOut, ReporteConductorIn
from .supabase_client import get_supabase_admin

app = FastAPI(title="EstacionaYa API", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # ajustar a los orígenes reales (app Flutter / panel Vue) en producción
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/salud")
def salud():
    return {"status": "ok"}


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
    espacio_id: int,
    body: ForzarEstadoIn,
    usuario: dict = Depends(requerir_rol("VALIDADOR", "ADMIN")),
):
    """RF5: el Validador sobrescribe y bloquea temporalmente un espacio."""
    supabase = get_supabase_admin()

    actual = supabase.table("espacios").select("estado").eq("id", espacio_id).single().execute()
    if not actual.data:
        raise HTTPException(status_code=404, detail="Espacio no encontrado.")

    bloqueado_hasta = datetime.now(timezone.utc) + timedelta(minutes=body.minutos_bloqueo)

    supabase.table("espacios").update(
        {
            "estado": body.estado,
            "fuente": "VALIDADOR",
            "forzado_por": usuario["id"],
            "bloqueado_hasta": bloqueado_hasta.isoformat(),
        }
    ).eq("id", espacio_id).execute()

    supabase.table("historial_estados").insert(
        {
            "espacio_id": espacio_id,
            "estado_anterior": actual.data["estado"],
            "estado_nuevo": body.estado,
            "fuente": "VALIDADOR",
            "usuario_id": usuario["id"],
        }
    ).execute()

    # No hace falta emitir nada manualmente: Supabase Realtime detecta el
    # UPDATE anterior y lo transmite solo a todos los clientes suscritos (RF7).
    return {"detail": "Estado actualizado.", "espacio_id": espacio_id, "estado": body.estado}


@app.post("/espacios/reportar")
def reportar(
    body: ReporteConductorIn,
    usuario: dict = Depends(obtener_usuario_actual),
):
    """RF3/RF4/RF6: reporte de conductor, como respaldo del modelo por cámara."""
    supabase = get_supabase_admin()

    espacio = (
        supabase.table("espacios")
        .select("estado, bloqueado_hasta")
        .eq("id", body.espacio_id)
        .single()
        .execute()
    )
    if not espacio.data:
        raise HTTPException(status_code=404, detail="Espacio no encontrado.")

    bloqueado_hasta = espacio.data.get("bloqueado_hasta")
    if bloqueado_hasta and datetime.fromisoformat(bloqueado_hasta) > datetime.now(timezone.utc):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Este espacio está bloqueado por un validador.",
        )

    cercano = supabase.rpc(
        "espacio_cercano",
        {
            "p_espacio_id": body.espacio_id,
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

    supabase.table("espacios").update(
        {"estado": nuevo_estado, "fuente": "CONDUCTOR"}
    ).eq("id", body.espacio_id).execute()

    supabase.table("historial_estados").insert(
        {
            "espacio_id": body.espacio_id,
            "estado_anterior": espacio.data["estado"],
            "estado_nuevo": nuevo_estado,
            "fuente": "CONDUCTOR",
            "usuario_id": usuario["id"],
        }
    ).execute()

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
