"""
Prueba de conexión a una cámara IP (celular) con OpenCV.

Uso (cmd), desde C:\estacionaya-infra\estacionaya:
    set CAMERA_URL=http://192.168.1.50:8080/video
    vision_module\.venv\Scripts\python.exe probar_camara_telefono.py

Teclas en la ventana: q = salir, s = guardar una captura (captura_telefono.jpg)
"""
import os
import sys
import time

import cv2

URL = os.environ.get("CAMERA_URL", "").strip()
if not URL:
    sys.exit("Falta la variable CAMERA_URL. Ejemplo: set CAMERA_URL=http://192.168.1.50:8080/video")

# Para RTSP, forzar TCP evita cortes y frames corruptos.
os.environ.setdefault("OPENCV_FFMPEG_CAPTURE_OPTIONS", "rtsp_transport;tcp")


def abrir(url):
    cap = cv2.VideoCapture(url, cv2.CAP_FFMPEG)
    cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)  # menos retraso
    return cap


cap = abrir(URL)
if not cap.isOpened():
    sys.exit(
        "No se pudo abrir la cámara. Revisa: 1) celular y PC en la MISMA red Wi-Fi, "
        "2) la app del celular está transmitiendo, 3) la URL abre en el navegador de la PC, "
        "4) el firewall de Windows no bloquea la conexión."
    )

ok, frame = cap.read()
if not ok or frame is None:
    sys.exit("La cámara abrió pero no entregó imagen.")

alto, ancho = frame.shape[:2]
print(f"Conectado. Resolución: {ancho}x{alto}")
print("Mostrando video. q = salir, s = guardar captura.")

fallos = 0
contador, t0, fps = 0, time.time(), 0.0
while True:
    ok, frame = cap.read()
    if not ok or frame is None:
        fallos += 1
        print(f"Sin frame ({fallos}). Reintentando...")
        cap.release()
        time.sleep(1.0)
        cap = abrir(URL)
        if fallos >= 10:
            sys.exit("Demasiados fallos seguidos. Revisa la conexión del celular.")
        continue
    fallos = 0

    contador += 1
    if time.time() - t0 >= 1.0:
        fps = contador / (time.time() - t0)
        contador, t0 = 0, time.time()

    cv2.putText(frame, f"{frame.shape[1]}x{frame.shape[0]}  {fps:.1f} FPS", (10, 30),
                cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 255, 0), 2)
    cv2.imshow("Camara telefono (q = salir)", frame)

    tecla = cv2.waitKey(1) & 0xFF
    if tecla == ord("q"):
        break
    if tecla == ord("s"):
        cv2.imwrite("captura_telefono.jpg", frame)
        print("Captura guardada: captura_telefono.jpg")

cap.release()
cv2.destroyAllWindows()