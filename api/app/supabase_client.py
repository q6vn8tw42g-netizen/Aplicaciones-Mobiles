import os
from pathlib import Path

from dotenv import load_dotenv

from supabase import Client, create_client

_API_DIR = Path(__file__).resolve().parents[1]
_PROJECT_DIR = _API_DIR.parent
# Las variables del proceso/Docker tienen prioridad; para desarrollo local
# carga api/.env y usa el .env raíz como alternativa.
load_dotenv(_API_DIR / ".env")
load_dotenv(_PROJECT_DIR / ".env")

SUPABASE_URL = os.environ["SUPABASE_URL"]
SUPABASE_SERVICE_ROLE_KEY = os.environ["SUPABASE_SERVICE_ROLE_KEY"]
_public_key = os.getenv("SUPABASE_PUBLISHABLE_KEY") or os.getenv("SUPABASE_KEY")
if _public_key and SUPABASE_SERVICE_ROLE_KEY == _public_key:
    raise RuntimeError(
        "SUPABASE_SERVICE_ROLE_KEY no puede ser igual a la clave pública/anon. "
        "Configura la service_role del mismo proyecto en el entorno privado del backend."
    )


def get_supabase_admin() -> Client:
    """Cliente con la service_role key: puede saltarse RLS. Úsalo solo en el backend."""
    return create_client(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
