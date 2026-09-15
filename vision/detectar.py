"""
Servicio de visión de EstacionaYa.

Corre en el equipo local conectado a la cámara (laptop de pruebas o
Raspberry Pi/PC). Detecta vehículos con YOLOv8 Nano, calcula si cada
espacio (definido por un polígono ROI) está ocupado, y publica a
Supabase SOLO cuando el estado de un espacio cambia — así el payload
que viaja por red es un JSON liviano, no video ni frames.
"""

import json
import os
import time
from pathlib import Path

import cv2
from dotenv import load_dotenv
from shapely.geometry import Polygon, box
from supabase import Client, create_client
from ultralytics import YOLO

load_dotenv()

SUPABASE_URL = os.environ["SUPABASE_URL"]
SUPABASE_SERVICE_ROLE_KEY = os.environ["SUPABASE_SERVICE_ROLE_KEY"]

# Clases COCO relevantes: car, motorcycle, bus, truck
CLASES_VEHICULO = {2, 3, 5, 7}

CONFIG_PATH = Path(__file__).parent / "config" / "camaras.json"


def cargar_configuracion() -> dict:
    with open(CONFIG_PATH, "r", encoding="utf-8") as f:
        return json.load(f)


def calcular_solapamiento(poligono_roi: Polygon, caja_deteccion) -> float:
    """Fracción del área del ROI cubierta por una caja de detección."""
    caja = box(*caja_deteccion)
    interseccion = poligono_roi.intersection(caja).area
    if poligono_roi.area == 0:
        return 0.0
    return interseccion / poligono_roi.area


def determinar_estado(poligono_roi: Polygon, cajas_detectadas, umbral: float) -> str:
    for caja in cajas_detectadas:
        if calcular_solapamiento(poligono_roi, caja) >= umbral:
            return "OCUPADO"
    return "LIBRE"


def publicar_cambio_estado(supabase: Client, id_supabase: int, estado_anterior: str, estado_nuevo: str):
    supabase.table("espacios").update(
        {"estado": estado_nuevo, "fuente": "CAMARA"}
    ).eq("id", id_supabase).execute()

    supabase.table("historial_estados").insert(
        {
            "espacio_id": id_supabase,
            "estado_anterior": estado_anterior,
            "estado_nuevo": estado_nuevo,
            "fuente": "CAMARA",
        }
    ).execute()

    print(f"[espacio {id_supabase}] {estado_anterior} -> {estado_nuevo}")


def main():
    config = cargar_configuracion()
    supabase = create_client(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

    modelo = YOLO("yolov8n.pt")  # se descarga automáticamente la primera vez

    espacios = [
        {
            **espacio,
            "poligono": Polygon(espacio["poligono_roi"]),
            "estado_actual": "LIBRE",
        }
        for espacio in config["espacios"]
    ]

    captura = cv2.VideoCapture(config["fuente_video"])
    if not captura.isOpened():
        raise RuntimeError(f"No se pudo abrir la fuente de video: {config['fuente_video']}")

    umbral = config.get("umbral_solapamiento", 0.35)
    intervalo = config.get("intervalo_segundos_entre_lecturas", 1.0)

    print("Servicio de visión iniciado. Ctrl+C para detener.")
    try:
        while True:
            ok, frame = captura.read()
            if not ok:
                print("No se pudo leer el frame; reintentando...")
                time.sleep(1)
                continue

            resultados = modelo.predict(frame, classes=list(CLASES_VEHICULO), verbose=False)
            cajas_detectadas = [
                tuple(caja.xyxy[0].tolist()) for caja in resultados[0].boxes
            ]

            for espacio in espacios:
                nuevo_estado = determinar_estado(espacio["poligono"], cajas_detectadas, umbral)
                if nuevo_estado != espacio["estado_actual"]:
                    publicar_cambio_estado(
                        supabase,
                        espacio["id_supabase"],
                        espacio["estado_actual"],
                        nuevo_estado,
                    )
                    espacio["estado_actual"] = nuevo_estado

            time.sleep(intervalo)
    except KeyboardInterrupt:
        print("Deteniendo servicio de visión...")
    finally:
        captura.release()


if __name__ == "__main__":
    main()
