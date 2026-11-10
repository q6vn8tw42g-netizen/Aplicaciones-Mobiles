
import cv2
import threading
import numpy as np

from windows_capture import WindowsCapture
from ultralytics import YOLO


modelo = YOLO("yolov8n.pt")

ultimo_frame = None
bloqueo = threading.Lock()


def iniciar():

    global ultimo_frame

    print("=== ESTACIONAYA - EZVIZ POR VENTANA ===")

    # Seleccionamos una ventana cuyo titulo sea EZVIZ.
    captura = WindowsCapture(
        cursor_capture=False,
        draw_border=False,
        window_name="EZVIZ"
    )

    @captura.event
    def on_frame_arrived(frame, control):
        global ultimo_frame

        imagen = np.asarray(frame.frame_buffer)

        with bloqueo:
            ultimo_frame = imagen.copy()

    @captura.event
    def on_closed():
        print("Captura de EZVIZ finalizada.")

    control = captura.start()

    nombre = "EstacionaYa - YOLO EZVIZ"
    cv2.namedWindow(nombre, cv2.WINDOW_NORMAL)
    cv2.resizeWindow(nombre, 640, 360)

    print("Detectando vehiculos. Presiona Q para salir.")

    try:
        while True:

            with bloqueo:
                imagen = (
                    ultimo_frame.copy()
                    if ultimo_frame is not None
                    else None
                )

            if imagen is None:
                if cv2.waitKey(30) & 0xFF == ord("q"):
                    break
                continue

            if imagen.shape[2] == 4:
                imagen = cv2.cvtColor(
                    imagen, cv2.COLOR_BGRA2BGR
                )

            resultados = modelo.predict(
                imagen,
                imgsz=416,
                conf=0.35,
                classes=[2, 3, 5, 7],
                verbose=False
            )

            cv2.imshow(
                nombre,
                resultados[0].plot()
            )

            if cv2.waitKey(1) & 0xFF == ord("q"):
                break

    finally:
        control.stop()
        cv2.destroyAllWindows()


if __name__ == "__main__":
    iniciar()
