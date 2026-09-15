import os

from supabase import Client, create_client

SUPABASE_URL = os.environ["SUPABASE_URL"]
SUPABASE_SERVICE_ROLE_KEY = os.environ["SUPABASE_SERVICE_ROLE_KEY"]


def get_supabase_admin() -> Client:
    """Cliente con la service_role key: puede saltarse RLS. Úsalo solo en el backend."""
    return create_client(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
