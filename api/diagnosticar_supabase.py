"""Verifica sin devolver filas que la clave privada de api/.env sirve para PostgREST."""

import httpx

from app.supabase_client import SUPABASE_SERVICE_ROLE_KEY, SUPABASE_URL


def main() -> int:
    endpoint = f"{SUPABASE_URL.rstrip('/')}/rest/v1/espacios"
    try:
        response = httpx.get(
            endpoint,
            params={"select": "id", "limit": "0"},
            headers={"apikey": SUPABASE_SERVICE_ROLE_KEY, "Accept": "application/json"},
            timeout=10,
            follow_redirects=False,
        )
    except httpx.HTTPError as error:
        print(f"No se pudo conectar con Supabase ({type(error).__name__}). Revisa DNS/red.")
        return 2

    if response.status_code == 200:
        print("HTTP 200: PostgREST acepta la clave de servicio para el proyecto configurado.")
        print("La clave no se imprimió y no se modificaron datos.")
        return 0
    if response.status_code in (401, 403):
        print(f"HTTP {response.status_code}: PostgREST rechazó SUPABASE_SERVICE_ROLE_KEY.")
        print("Copia una clave de servidor vigente del mismo proyecto en api/.env y reinicia FastAPI.")
        return 1
    print(f"Supabase respondió HTTP {response.status_code}; no se modificaron datos.")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
