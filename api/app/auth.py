from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from .supabase_client import get_supabase_admin

security = HTTPBearer()


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
    except Exception as exc:  # token inválido, expirado o malformado
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token inválido o expirado.",
        ) from exc

    usuario_auth = respuesta.user if respuesta else None
    if not usuario_auth:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token inválido o expirado.",
        )

    perfil = (
        supabase.table("perfiles").select("rol").eq("id", usuario_auth.id).single().execute()
    )
    rol = perfil.data["rol"] if perfil.data else "CONDUCTOR"

    return {"id": usuario_auth.id, "email": usuario_auth.email, "rol": rol}


def requerir_rol(*roles_permitidos: str):
    """Dependencia de FastAPI para restringir un endpoint a ciertos roles (RF5, RF8)."""

    def verificador(usuario: dict = Depends(obtener_usuario_actual)) -> dict:
        if usuario["rol"] not in roles_permitidos:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Se requiere uno de estos roles: {', '.join(roles_permitidos)}.",
            )
        return usuario

    return verificador
