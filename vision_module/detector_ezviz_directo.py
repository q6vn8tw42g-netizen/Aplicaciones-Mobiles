
import threading
import time

import cv2
import numpy as np
import win32gui

from windows_capture import WindowsCapture
from ultralytics import YOLO


ultimo_frame = None
bloqueo = threading.Lock()


def buscar_ezviz():
    encontrados = []

    def callback(hwnd, _):
        if win32gui.IsWindowVisible(hwnd):
            titulo = win32gui.GetWindowText(hwnd)
            if titulo.strip().lower() == "ezviz studio":
                encontrados.append(hwnd)

    win32gui.EnumWindows(callback, None)
    return encontrados[0] if encontrados else None


def iniciar():
    global ultimo_frame

    hwnd = buscar_ezviz()

    if hwnd is None:
        print("No se encontro Ezviz Studio.")
        return

    modelo = YOLO("yolov8n.pt")
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

    nombre = "EstacionaYa - YOLO Directo"
    cv2.namedWindow(nombre, cv2.WINDOW_NORMAL)
    cv2.resizeWindow(nombre, 640, 360)

    print("Presiona Q para salir.")

    roi = None

    try:
        while True:
            with bloqueo:
                imagen = (
                    ultimo_frame.copy()
                    if ultimo_frame is not None
                    else None
                )

            if imagen is None:
                time.sleep(0.03)
                if cv2.waitKey(30) & 0xFF == ord("q"):
                    break
                continue

            if imagen.ndim != 3:
                continue

            if imagen.shape[2] == 4:
                imagen = cv2.cvtColor(
                    imagen, cv2.COLOR_BGRA2BGR
                )

            if roi is None:
                print("Selecciona SOLO el video EZVIZ.")

                x, y, w, h = cv2.selectROI(
                    "Seleccionar video",
                    imagen,
                    False,
                    False
                )
                cv2.destroyWindow("Seleccionar video")

                if w <= 0 or h <= 0:
                    break

                roi = (x, y, w, h)

            x, y, w, h = roi

            if (
                x + w > imagen.shape[1]
                or y + h > imagen.shape[0]
            ):
                print("Cambio el tamano de EZVIZ.")
                break

            video = imagen[y:y+h, x:x+w].copy()

            resultados = modelo.predict(
                video,
                imgsz=416,
                conf=0.35,
                classes=[2, 3, 5, 7],
                verbose=False
            )

            procesado = resultados[0].plot()
            cv2.imshow(nombre, procesado)

            if cv2.waitKey(1) & 0xFF == ord("q"):
                break

    finally:
        control.stop()
        cv2.destroyAllWindows()


if __name__ == "__main__":
    iniciar()
