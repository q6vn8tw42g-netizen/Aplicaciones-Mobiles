
import time
import threading
import cv2
import numpy as np
import win32gui

from windows_capture import WindowsCapture

ultimo_frame = None
bloqueo = threading.Lock()
activo = True


def buscar_ventana():
    encontrados = []

    def callback(hwnd, _):
        if win32gui.IsWindowVisible(hwnd):
            titulo = win32gui.GetWindowText(hwnd)

            if titulo.strip().lower() == "ezviz studio":
                encontrados.append(hwnd)

    win32gui.EnumWindows(callback, None)

    return encontrados[0] if encontrados else None


def iniciar():
    global ultimo_frame, activo

    print("=== ESTACIONAYA - CAPTURA DIRECTA EZVIZ ===")

    hwnd = buscar_ventana()

    if hwnd is None:
        print("ERROR: No se encontro Ezviz Studio.")
        return

    print("Ventana encontrada:", hwnd, flush=True)

    captura = WindowsCapture(
        cursor_capture=False,
        draw_border=False,
        window_hwnd=hwnd
    )

    @captura.event
    def on_frame_arrived(frame, control):
        global ultimo_frame

        imagen = np.asarray(frame.frame_buffer)

        with bloqueo:
            ultimo_frame = imagen.copy()

        if not activo:
            control.stop()

    @captura.event
    def on_closed():
        print("Captura finalizada.", flush=True)

    try:
        control = captura.start_free_threaded()
    except Exception as error:
        print("Error al iniciar captura:", error)
        return

    nombre = "EstacionaYa - Captura directa"
    cv2.namedWindow(nombre, cv2.WINDOW_NORMAL)
    cv2.resizeWindow(nombre, 640, 360)

    print("Captura iniciada.", flush=True)
    print("Presiona Q para salir.", flush=True)

    try:
        while True:
            with bloqueo:
                imagen = (
                    ultimo_frame.copy()
                    if ultimo_frame is not None
                    else None
                )

            if imagen is not None:
                if imagen.shape[2] == 4:
                    imagen = cv2.cvtColor(
                        imagen, cv2.COLOR_BGRA2BGR
                    )

                cv2.imshow(nombre, imagen)
            else:
                time.sleep(0.03)

            if cv2.waitKey(30) & 0xFF == ord("q"):
                break

    finally:
        activo = False
        control.stop()
        cv2.destroyAllWindows()


if __name__ == "__main__":
    iniciar()
