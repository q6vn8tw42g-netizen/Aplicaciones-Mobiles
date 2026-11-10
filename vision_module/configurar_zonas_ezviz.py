
import json
import os
import threading
import time

import cv2
import numpy as np
import win32gui
from windows_capture import WindowsCapture

ultimo_frame = None
bloqueo = threading.Lock()

CARPETA = "vision_module"
ARCHIVO_ZONAS = os.path.join(
    CARPETA, "zonas_ezviz_antizana.json"
)


def buscar_ezviz():
    ventanas = []

    def callback(hwnd, _):
        titulo = win32gui.GetWindowText(hwnd)
        if (win32gui.IsWindowVisible(hwnd)
                and titulo.strip().lower() == "ezviz studio"):
            ventanas.append(hwnd)

    win32gui.EnumWindows(callback, None)
    return ventanas[0] if ventanas else None


def configurar():
    global ultimo_frame

    hwnd = buscar_ezviz()

    if hwnd is None:
        print("ERROR: Abre EZVIZ PC Studio primero.")
        return

    captura = WindowsCapture(
        cursor_capture=False,
        draw_border=False,
        window_hwnd=hwnd
    )

    @captura.event
    def on_frame_arrived(frame, control):
        global ultimo_frame
        with bloqueo:
            ultimo_frame = np.asarray(
                frame.frame_buffer
            ).copy()

    @captura.event
    def on_closed():
        print("Captura finalizada.")

    control = captura.start_free_threaded()

    try:
        print("Obteniendo imagen de EZVIZ...")

        imagen = None

        for _ in range(100):
            with bloqueo:
                if ultimo_frame is not None:
                    imagen = ultimo_frame.copy()
                    break
            time.sleep(0.1)

        if imagen is None:
            print("No se recibio imagen de EZVIZ.")
            return

        if imagen.shape[2] == 4:
            imagen = cv2.cvtColor(
                imagen, cv2.COLOR_BGRA2BGR
            )

        print("Selecciona SOLO el video de la camara.")

        x, y, w, h = cv2.selectROI(
            "Seleccionar video EZVIZ",
            imagen,
            False,
            False
        )
        cv2.destroyWindow("Seleccionar video EZVIZ")

        if w <= 0 or h <= 0:
            print("Seleccion cancelada.")
            return

        video = imagen[y:y+h, x:x+w].copy()

        zonas = []
        vista = video.copy()

        print("=== CONFIGURAR ESTACIONAMIENTOS ===")
        print("Dibuja cada espacio y presiona ESPACIO.")
        print("Presiona C para terminar.")

        while True:
            rx, ry, rw, rh = cv2.selectROI(
                "Configurar estacionamientos",
                vista,
                False,
                False
            )

            if rw <= 0 or rh <= 0:
                break

            numero = len(zonas) + 1
            identificador = f"ANT-{numero:03d}"

            zonas.append({
                "id": identificador,
                "name": f"Antizana - Espacio {numero}",
                "roi": [rx, ry, rw, rh]
            })

            cv2.rectangle(
                vista,
                (rx, ry),
                (rx + rw, ry + rh),
                (0, 255, 0),
                2
            )

            cv2.putText(
                vista,
                identificador,
                (rx, max(20, ry - 5)),
                cv2.FONT_HERSHEY_SIMPLEX,
                0.5,
                (0, 255, 0),
                2
            )

            print(f"Zona guardada: {identificador}")

        cv2.destroyAllWindows()

        if not zonas:
            print("No se configuraron zonas.")
            return

        configuracion = {
            "camera_index": 0,
            "frame_size": [w, h],
            "zones": zonas
        }

        os.makedirs(CARPETA, exist_ok=True)

        with open(
            ARCHIVO_ZONAS,
            "w",
            encoding="utf-8"
        ) as archivo:
            json.dump(
                configuracion,
                archivo,
                indent=2,
                ensure_ascii=False
            )

        cv2.imwrite(
            os.path.join(CARPETA, "zonas_antizana.png"),
            vista
        )

        print("Configuracion guardada.")
        print("Archivo:", ARCHIVO_ZONAS)
        print("Total de espacios:", len(zonas))

    finally:
        control.stop()
        cv2.destroyAllWindows()


if __name__ == "__main__":
    configurar()
