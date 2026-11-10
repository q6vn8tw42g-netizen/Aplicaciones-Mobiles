
import time

import cv2
import mss
import numpy as np
import win32gui
from ultralytics import YOLO


TITULO_EZVIZ = "EZVIZ"
TITULO_DETECTOR = "EstacionaYa - Deteccion YOLO"

modelo = YOLO("yolov8n.pt")


def buscar_ezviz():
    ventanas = []

    def callback(hwnd, _):
        if not win32gui.IsWindowVisible(hwnd):
            return

        titulo = win32gui.GetWindowText(hwnd)

        if (
            "EZVIZ" in titulo.upper()
            and "ESTACIONAYA" not in titulo.upper()
        ):
            ventanas.append(hwnd)

    win32gui.EnumWindows(callback, None)
    return ventanas[0] if ventanas else None


def ejecutar():
    hwnd = buscar_ezviz()

    if hwnd is None:
        print("No se encontro EZVIZ PC Studio.")
        return

    if win32gui.IsIconic(hwnd):
        print("Restaura la ventana de EZVIZ.")
        return

    # Seleccionar la region del video una sola vez.
    with mss.mss() as sct:
        left, top, right, bottom = win32gui.GetWindowRect(hwnd)

        region_inicial = {
            "left": left,
            "top": top,
            "width": right - left,
            "height": bottom - top
        }

        captura = np.array(sct.grab(region_inicial))
        captura = cv2.cvtColor(
            captura, cv2.COLOR_BGRA2BGR
        )

        print("Selecciona el video dentro de EZVIZ.")

        x, y, w, h = cv2.selectROI(
            "Seleccionar video EZVIZ",
            captura,
            False,
            False
        )

        cv2.destroyWindow("Seleccionar video EZVIZ")

        if w <= 0 or h <= 0:
            print("Seleccion cancelada.")
            return

        cv2.namedWindow(
            TITULO_DETECTOR,
            cv2.WINDOW_NORMAL
        )
        cv2.resizeWindow(TITULO_DETECTOR, 480, 270)

        print("Deteccion iniciada. Presiona Q para salir.")

        while True:
            if not win32gui.IsWindow(hwnd):
                print("La ventana EZVIZ se cerro.")
                break

            if win32gui.IsIconic(hwnd):
                time.sleep(0.2)
                continue

            nuevo_left, nuevo_top, _, _ = (
                win32gui.GetWindowRect(hwnd)
            )

            region = {
                "left": nuevo_left + x,
                "top": nuevo_top + y,
                "width": w,
                "height": h
            }

            try:
                imagen = np.array(sct.grab(region))
            except Exception as error:
                print("Error de captura:", error)
                break

            frame = cv2.cvtColor(
                imagen, cv2.COLOR_BGRA2BGR
            )

            resultados = modelo.predict(
                frame,
                imgsz=416,
                conf=0.35,
                classes=[2, 3, 5, 7],
                verbose=False
            )

            frame_detectado = resultados[0].plot()

            cv2.imshow(
                TITULO_DETECTOR,
                frame_detectado
            )

            if cv2.waitKey(1) & 0xFF == ord("q"):
                break

    cv2.destroyAllWindows()


if __name__ == "__main__":
    ejecutar()
