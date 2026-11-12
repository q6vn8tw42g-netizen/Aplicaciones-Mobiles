
import uuid
import sys
from getpass import getpass

sys.path.insert(0, "/app")

from app.supabase_client import get_supabase_admin


UID_ADMIN = "f93880dc-f078-4e2b-bb5e-3c4a590219b2"


def recuperar_acceso():
    print("=== ESTACIONAYA - RECUPERAR ADMIN ===")

    uid = str(uuid.UUID(UID_ADMIN))

    password = getpass("Nueva contraseña: ")
    confirmar = getpass("Confirmar contraseña: ")

    if len(password) < 10:
        print("La contraseña debe tener al menos 10 caracteres.")
        return

    if password != confirmar:
        print("Las contraseñas no coinciden.")
        return

    confirmacion = input(
        "¿Confirmas actualizar esta cuenta? (SI/NO): "
    ).strip().upper()

    if confirmacion != "SI":
        print("Operación cancelada.")
        return

    try:
        cliente = get_supabase_admin()

        resultado = cliente.auth.admin.update_user_by_id(
            uid,
            {"password": password}
        )

        if resultado.user is None:
            print("No se pudo confirmar la actualización.")
            return

        print("Contraseña actualizada correctamente.")
        print("El usuario conserva su rol actual.")

    except Exception as error:
        print("No se pudo actualizar la contraseña.")
        print(type(error).__name__)
        print(str(error))


if __name__ == "__main__":
    recuperar_acceso()
