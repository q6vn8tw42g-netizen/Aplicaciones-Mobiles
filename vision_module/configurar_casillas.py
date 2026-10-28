"""Calibra ROIs rectangulares para cada espacio de parqueo y guarda zonas.json."""

from __future__ import annotations

import json
from pathlib import Path

import cv2


OUTPUT = Path(__file__).with_name("zonas.json")
CAMERA_INDEX = 0
FRAME_SIZE = (640, 480)


def main() -> int:
    camera = cv2.VideoCapture(CAMERA_INDEX)
    if not camera.isOpened():
        raise SystemExit(f"No se pudo abrir la cámara {CAMERA_INDEX}.")

    try:
        ok, frame = camera.read()
        if not ok or frame is None:
            raise SystemExit("No se pudo capturar un frame de la cámara.")
        frame = cv2.resize(frame, FRAME_SIZE)
        cv2.namedWindow("Calibrar casillas - ENTER confirma / ESC cancela", cv2.WINDOW_NORMAL)
        rectangulos = cv2.selectROIs(
            "Calibrar casillas - ENTER confirma / ESC cancela",
            frame,
            showCrosshair=True,
            fromCenter=False,
        )
        cv2.destroyAllWindows()
    finally:
        camera.release()
        cv2.destroyAllWindows()

    if len(rectangulos) == 0:
        print("No se seleccionaron rectángulos; no se guardó ningún archivo.")
        return 1

    zones = []
    seen = set()
    for index, rect in enumerate(rectangulos, start=1):
        x, y, w, h = (int(value) for value in rect)
        if w <= 0 or h <= 0:
            continue
        default_id = f"UPEC-{index:03d}"
        name = input(f"ID/código para ROI {index} [{default_id}]: ").strip() or default_id
        if name in seen:
            raise SystemExit(f"ID repetido: {name}. Ejecuta de nuevo y usa IDs únicos.")
        seen.add(name)
        label = input(f"Nombre visible [{f'UPEC - Espacio {index}'}]: ").strip()
        zones.append({
            "id": name,
            "name": label or f"UPEC - Espacio {index}",
            "roi": [x, y, w, h],
        })

    payload = {"camera_index": CAMERA_INDEX, "frame_size": list(FRAME_SIZE), "zones": zones}
    OUTPUT.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Guardadas {len(zones)} zonas en {OUTPUT}")
    print("Usa cada id como camara_id de su fila en public.espacios.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
