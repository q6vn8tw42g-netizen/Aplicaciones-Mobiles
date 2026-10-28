import logging

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from .supabase_client import get_supabase_admin

security = HTTPBearer()
logger = logging.getLogger(__name__)


def obtener_usuario_actual(
    credenciales: HTTPAuthorizationCredentials = Depends(security),
) -> dict:
    """Valida el token directamente contra Supabase Auth (no depende de un
    JWT secret local: funciona igual con las llaves legacy o con las nuevas
    publishable/secret) y resuelve el rol consultando la tabla perfiles."""
    token = credenciales.credentials
    supabase = get_supabase_admin()

    try:
        respuesta = supabase.auth.get_user(token)
    except Exception as exc:
        # No registrar el JWT ni el mensaje completo de la excepción.
        auth_status = getattr(exc, "status", None)
        auth_code = str(getattr(exc, "code", ""))
        safe_code = auth_code if auth_code.replace("_", "").isalnum() and len(auth_code) <= 64 else ""
        auth_message = " ".join(str(getattr(exc, "message", "")).split())[:180]
        logger.warning(
            "Supabase get_user rechazó/no pudo validar la sesión (status=%s, code=%s, type=%s, message=%s).",
            auth_status,
            safe_code or "sin_codigo",
            type(exc).__name__,
            auth_message or "sin_mensaje",
        )
        if auth_status == 401:
            detail = (
                f"Supabase rechazó la sesión (código {safe_code or 'sin_codigo'}"
                f", tipo {type(exc).__name__}). "
                f"Respuesta: {auth_message or 'sin detalle'}. Verifica que "
                "SUPABASE_URL y SUPABASE_SERVICE_ROLE_KEY pertenezcan al mismo proyecto."
            )
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=detail) from exc
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="FastAPI no pudo comunicarse con Supabase Auth. Revisa la conexión y los logs del backend.",
        ) from exc

    usuario_auth = respuesta.user if respuesta else None
    if not usuario_auth:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token inválido o expirado.",
        )

    # Auth puede confirmar la identidad aunque el perfil público todavía no
    # exista. Un SELECT normal devuelve una lista vacía en ese caso; evitamos
    # .single(), que lanza PGRST116 cuando no hay filas.
    perfiles = (
        supabase.table("perfiles")
        .select("rol")
        .eq("id", usuario_auth.id)
        .limit(1)
        .execute()
        .data
    ) or []
    perfil = perfiles[0] if isinstance(perfiles, list) and perfiles else (
        perfiles if isinstance(perfiles, dict) else None
    )
    rol = str((perfil or {}).get("rol") or "conductor").strip().lower()

    return {"id": usuario_auth.id, "email": usuario_auth.email, "rol": rol}


def requerir_rol(*roles_permitidos: str):
    """Dependencia de FastAPI para restringir un endpoint a ciertos roles (RF5, RF8)."""

    def verificador(usuario: dict = Depends(obtener_usuario_actual)) -> dict:
        rol_actual = str(usuario.get("rol", "")).strip().casefold()
        roles = {rol.strip().casefold() for rol in roles_permitidos}
        if rol_actual not in roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Se requiere uno de estos roles: {', '.join(roles_permitidos)}.",
            )
        return usuario

    return verificador
