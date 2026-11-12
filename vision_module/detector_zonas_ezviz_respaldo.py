
import json
import os
import threading
import time
import queue
import logging
import requests
from dotenv import load_dotenv

import cv2
import numpy as np
import win32gui

from ultralytics import YOLO
from windows_capture import WindowsCapture


# ==========================================
# CONFIGURACION ESTACIONAYA
# ==========================================

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
# Variables cargadas desde el entorno local; nunca escribir secretos en codigo.
load_dotenv(os.path.join(BASE_DIR, ".env"))
load_dotenv(os.path.join(os.path.dirname(BASE_DIR), "api", ".env"))


ARCHIVO_ZONAS = os.path.join(
    BASE_DIR,
    "zonas_ezviz_antizana.json"
)

MODELO_YOLO = "yolov8s.pt"

FRAMES_CONFIRMACION = 10
UMBRAL_SUPERPOSICION = 0.12
CONFIANZA_YOLO = 0.25

# COCO: carro, moto, autobus y camion
CLASES_VEHICULOS = [2, 3, 5, 7]

TITULO_EZVIZ = "ezviz studio"
TITULO_VENTANA = "EstacionaYa - Ocupacion por zonas"

ultimo_frame = None
bloqueo = threading.Lock()

# ==========================================
# ENVIO MJPEG AL PANEL ADMINISTRATIVO
# ==========================================

class PublicadorPanel:
    """Publica solo el JPEG mas reciente sin bloquear la inferencia YOLO."""

    def __init__(self):
        self.url = os.getenv("VISION_STREAM_URL", "http://127.0.0.1:8000/vision/frame").strip()
        self.token = os.getenv("VISION_STREAM_TOKEN", "").strip()
        self.cola = queue.Queue(maxsize=1)
        self.estados = None
        self.ultimo_envio_estados = 0.0
        self.detener = threading.Event()
        self.hilo = None
        if not self.token:
            print("AVISO: VISION_STREAM_TOKEN no configurado; no se enviara video al panel.")
        else:
            self.hilo = threading.Thread(target=self._enviar, name="ezviz-panel-stream", daemon=True)
            self.hilo.start()
            print("Envio al panel habilitado:", self.url)

    def publicar(self, imagen):
        if not self.hilo:
            return
        ok, jpg = cv2.imencode(".jpg", imagen, [cv2.IMWRITE_JPEG_QUALITY, 75])
        if not ok:
            return
        contenido = jpg.tobytes()
        try:
            self.cola.put_nowait(contenido)
        except queue.Full:
            try:
                self.cola.get_nowait()
            except queue.Empty:
                pass
            try:
                self.cola.put_nowait(contenido)
            except queue.Full:
                pass

    def publicar_estados(self, estados):
        # Solo una lectura agregada por zona: no incluye imágenes ni datos personales.
        self.estados = dict(estados)

    def _enviar(self):
        ultimo_aviso = 0.0
        with requests.Session() as sesion:
            while not self.detener.is_set():
                try:
                    contenido = self.cola.get(timeout=0.25)
                except queue.Empty:
                    continue
                try:
                    respuesta = sesion.post(
                        self.url, data=contenido,
                        headers={"Content-Type": "image/jpeg", "X-Vision-Token": self.token},
                        timeout=(1, 3),
                    )
                    respuesta.raise_for_status()
                    if self.estados and time.monotonic() - self.ultimo_envio_estados >= 1:
                        datos = {"camara": "ANTIZANA FRENTE UPEC", "zonas": [
                            {"id": zona, "estado": estado} for zona, estado in sorted(self.estados.items())
                        ]}
                        url_zonas = self.url.rsplit("/vision/frame", 1)[0] + "/vision/zonas"
                        respuesta_zonas = sesion.post(
                            url_zonas, json=datos,
                            headers={"X-Vision-Token": self.token}, timeout=(1, 3),
                        )
                        respuesta_zonas.raise_for_status()
                        self.ultimo_envio_estados = time.monotonic()
                except requests.RequestException as error:
                    if time.monotonic() - ultimo_aviso > 10:
                        print("Aviso: no se pudo enviar video al panel:", error)
                        ultimo_aviso = time.monotonic()

    def cerrar(self):
        self.detener.set()
        if self.hilo:
            self.hilo.join(timeout=3)



# ==========================================
# BUSCAR VENTANA EZVIZ
# ==========================================

def buscar_ezviz():
    encontrados = []

    def callback(hwnd, _):
        if not win32gui.IsWindowVisible(hwnd):
            return

        titulo = win32gui.GetWindowText(hwnd)

        if titulo.strip().lower() == TITULO_EZVIZ:
            encontrados.append(hwnd)

    win32gui.EnumWindows(callback, None)

    return encontrados[0] if encontrados else None


# ==========================================
# CALCULAR SUPERPOSICION
# ==========================================

def calcular_superposicion(caja, roi):

    x1, y1, x2, y2 = caja
    x, y, w, h = roi

    inter_x1 = max(x1, x)
    inter_y1 = max(y1, y)

    inter_x2 = min(x2, x + w)
    inter_y2 = min(y2, y + h)

    ancho = max(0, inter_x2 - inter_x1)
    alto = max(0, inter_y2 - inter_y1)

    area_interseccion = ancho * alto
    area_zona = w * h

    if area_zona <= 0:
        return 0.0

    return area_interseccion / area_zona


# ==========================================
# CARGAR CONFIGURACION
# ==========================================

def cargar_zonas():

    if not os.path.exists(ARCHIVO_ZONAS):
        raise FileNotFoundError(
            f"No existe el archivo: {ARCHIVO_ZONAS}"
        )

    with open(
        ARCHIVO_ZONAS,
        "r",
        encoding="utf-8"
    ) as archivo:
        configuracion = json.load(archivo)

    ancho, alto = configuracion["frame_size"]
    zonas = configuracion["zones"]

    print("================================")
    print("CONFIGURACION DE ESTACIONAYA")
    print("================================")
    print(f"Resolucion: {ancho} x {alto}")
    print(f"Total de zonas: {len(zonas)}")

    for zona in zonas:
        print(f" - {zona['id']}: {zona['name']}")

    return ancho, alto, zonas


# ==========================================
# PROGRAMA PRINCIPAL
# ==========================================

def iniciar():

    global ultimo_frame

    print("===================================")
    print(" ESTACIONAYA - YOLO + EZVIZ")
    print("===================================")

    ancho_esperado, alto_esperado, zonas = cargar_zonas()

    hwnd = buscar_ezviz()

    if hwnd is None:
        print("ERROR: No se encontro EZVIZ Studio.")
        print("Abre EZVIZ PC Studio e intenta nuevamente.")
        return

    print("Ventana EZVIZ encontrada:", hwnd)

    if win32gui.IsIconic(hwnd):
        print("ERROR: Restaura la ventana de EZVIZ.")
        return

    print("Cargando YOLOv8...")
    modelo = YOLO(MODELO_YOLO)

    print("Iniciando captura directa...")

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

    @captura.event
    def on_closed():
        print("Captura de EZVIZ finalizada.")

    publicador = PublicadorPanel()
    try:
        control = captura.start_free_threaded()
    except Exception:
        publicador.cerrar()
        raise

    roi_video = None

    ultimo_diagnostico_ant002 = 0.0

    contadores = {
        zona["id"]: 0
        for zona in zonas
    }

    nombre = TITULO_VENTANA

    cv2.namedWindow(
        nombre,
        cv2.WINDOW_NORMAL
    )

    cv2.resizeWindow(
        nombre,
        900,
        500
    )

    print("-----------------------------------")
    print("Detector iniciado.")
    print("Selecciona el video EZVIZ.")
    print("Presiona Q para salir.")
    print("-----------------------------------")

    try:

        while True:

            # Obtener ultimo fotograma
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

            # Convertir formato de imagen
            if imagen.shape[2] == 4:
                imagen = cv2.cvtColor(
                    imagen,
                    cv2.COLOR_BGRA2BGR
                )

            # ==================================
            # SELECCIONAR EL VIDEO UNA SOLA VEZ
            # ==================================

            if roi_video is None:

                print("Selecciona SOLO el video ANTIZANA.")
                print("Presiona ESPACIO para confirmar.")

                roi_video = cv2.selectROI(
                    "Seleccionar video EZVIZ",
                    imagen,
                    showCrosshair=True,
                    fromCenter=False
                )

                cv2.destroyWindow(
                    "Seleccionar video EZVIZ"
                )

                if roi_video[2] <= 0 or roi_video[3] <= 0:
                    print("Seleccion cancelada.")
                    break

                print(
                    "Resolucion seleccionada:",
                    roi_video[2],
                    "x",
                    roi_video[3]
                )

                print(
                    "Resolucion de trabajo:",
                    ancho_esperado,
                    "x",
                    alto_esperado
                )

            # ==================================
            # RECORTAR VIDEO
            # ==================================

            x0, y0, w0, h0 = roi_video

            alto_imagen, ancho_imagen = imagen.shape[:2]

            if (
                x0 < 0
                or y0 < 0
                or x0 + w0 > ancho_imagen
                or y0 + h0 > alto_imagen
            ):
                print(
                    "ERROR: El video quedo fuera "
                    "de la region capturada."
                )
                break

            video = imagen[
                y0:y0 + h0,
                x0:x0 + w0
            ].copy()

            # ==================================
            # REDIMENSIONAMIENTO AUTOMATICO
            # ==================================

            if (
                video.shape[1] != ancho_esperado
                or video.shape[0] != alto_esperado
            ):

                video = cv2.resize(
                    video,
                    (ancho_esperado, alto_esperado),
                    interpolation=cv2.INTER_LINEAR
                )

            # ==================================
            # DETECCION CON YOLOv8
            # ==================================

            resultados = modelo.predict(
                source=video,
                imgsz=416,
                conf=CONFIANZA_YOLO,
                classes=CLASES_VEHICULOS,
                verbose=False
            )

            cajas = (
                resultados[0]
                .boxes.xyxy
                .cpu()
                .numpy()
            )

            vista = video.copy()

            # Dibujar detecciones YOLO
            for caja in cajas:

                x1, y1, x2, y2 = map(int, caja)

                cv2.rectangle(
                    vista,
                    (x1, y1),
                    (x2, y2),
                    (255, 150, 0),
                    2
                )

            # ==================================
            # ANALIZAR ZONAS
            # ==================================

            estados_actuales = {}
            for zona in zonas:

                identificador = zona["id"]

                x, y, w, h = zona["roi"]

                superposiciones = [
                    calcular_superposicion(caja, zona["roi"])
                    for caja in cajas
                ]
                max_superposicion = max(superposiciones, default=0.0)
                detectado = max_superposicion >= UMBRAL_SUPERPOSICION

                # Diagnostico: se imprime una vez por segundo para no saturar la consola.
                if identificador == "ANT-002" and time.monotonic() - ultimo_diagnostico_ant002 >= 1:
                    print(
                        f"[ANT-002] "
                        f"vehiculos_detectados={len(cajas)} | "
                        f"superposicion_maxima={max_superposicion:.3f} | "
                        f"umbral={UMBRAL_SUPERPOSICION:.3f} | "
                        f"detectado={detectado}",
                        flush=True,
                    )
                    ultimo_diagnostico_ant002 = time.monotonic()

                # Confirmar ocupacion
                if detectado:

                    contadores[identificador] = min(
                        FRAMES_CONFIRMACION,
                        contadores[identificador] + 1
                    )

                else:

                    contadores[identificador] = max(
                        0,
                        contadores[identificador] - 1
                    )

                contador = contadores[identificador]

                # Determinar estado experimental
                if contador >= FRAMES_CONFIRMACION:

                    estado = "OCUPADO_PROBABLE"
                    color = (0, 0, 255)

                elif contador > 0:

                    estado = "VERIFICANDO"
                    color = (0, 255, 255)

                else:

                    estado = "SIN_DETECCION"
                    color = (255, 200, 0)

                estados_actuales[identificador] = estado

                # Dibujar estacionamiento
                cv2.rectangle(
                    vista,
                    (x, y),
                    (x + w, y + h),
                    color,
                    2
                )

                cv2.putText(
                    vista,
                    f"{identificador}: {estado}",
                    (x, max(20, y - 8)),
                    cv2.FONT_HERSHEY_SIMPLEX,
                    0.45,
                    color,
                    1
                )

            # ==================================
            # MOSTRAR RESULTADO
            # ==================================

            # Enviar la misma imagen anotada al backend, sin actualizar Supabase.
            publicador.publicar_estados(estados_actuales)
            publicador.publicar(vista)
            cv2.imshow(
                nombre,
                vista
            )

            if cv2.waitKey(1) & 0xFF == ord("q"):
                print("Detector detenido.")
                break

    except KeyboardInterrupt:
        print("Programa interrumpido.")

    finally:
        control.stop()
        publicador.cerrar()
        cv2.destroyAllWindows()

        print("Captura finalizada correctamente.")


if __name__ == "__main__":
    iniciar()
