
import cv2
import numpy as np
import mss

def iniciar_captura():
    print("=== ESTACIONAYA - CAPTURA EZVIZ ===")
    print("Selecciona el area del video EZVIZ.")
    print("Presiona ENTER o ESPACIO para confirmar.")

    with mss.mss() as sct:
        monitor = sct.monitors[1]

        pantalla = np.array(sct.grab(monitor))
        pantalla = cv2.cvtColor(
            pantalla, cv2.COLOR_BGRA2BGR
        )

        x, y, w, h = cv2.selectROI(
            "Seleccionar camara EZVIZ",
            pantalla,
            showCrosshair=True,
            fromCenter=False
        )

        cv2.destroyWindow("Seleccionar camara EZVIZ")

        if w == 0 or h == 0:
            print("No seleccionaste ninguna zona.")
            return

        zona = {
            "left": monitor["left"] + x,
            "top": monitor["top"] + y,
            "width": w,
            "height": h
        }

        print("Capturando camara EZVIZ...")
        print("Presiona Q para salir.")

        nombre = "EstacionaYa - Camara EZVIZ"

        cv2.namedWindow(nombre, cv2.WINDOW_NORMAL)
        cv2.resizeWindow(nombre, 480, 270)

        # Ubicamos la ventana fuera del area
        # de captura, si hay espacio disponible.
        if x > 500:
            cv2.moveWindow(nombre, 0, 0)
        elif x + w + 500 < monitor["width"]:
            cv2.moveWindow(nombre, x + w + 10, 0)

        while True:
            imagen = np.array(sct.grab(zona))
            frame = cv2.cvtColor(
                imagen, cv2.COLOR_BGRA2BGR
            )

            cv2.imshow(nombre, frame)

            if cv2.waitKey(30) & 0xFF == ord("q"):
                break

    cv2.destroyAllWindows()


if __name__ == "__main__":
    iniciar_captura()
