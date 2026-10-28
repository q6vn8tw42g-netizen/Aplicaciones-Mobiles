# Cámara de EstacionaYa (RF18 / RF19)

El detector principal usa `yolov8n.pt` mediante Ultralytics. La inferencia corre en un hilo con una cola de tamaño uno para que la captura y publicación MJPEG continúen sin esperar cada predicción. Se asocian al ROI las clases COCO `motorcycle` → `MOTO`, `car` → `AUTO` y `truck` → `CAMIONETA`. Si Ultralytics o el modelo no pueden cargarse, se conserva el detector por umbral de píxeles como respaldo. La inferencia se ejecuta con `save=False`; no persiste frames ni videos.

Se pueden definir `VISION_YOLO_MODEL` (ruta local o nombre del peso, por defecto `yolov8n.pt`), `VISION_YOLO_IMGSZ` (por defecto `416`) y `VISION_YOLO_CONF` (por defecto `0.35`). La primera carga de un peso por nombre requiere conexión a Internet para descargarlo. Para operar sin conexión, prepara el archivo del modelo y configura una ruta local.

Requiere Python 3.10 o superior y una cámara web. Desde PowerShell, en la raíz del proyecto:

```powershell
py -m venv vision_module/.venv
./vision_module/.venv/Scripts/python.exe -m pip install -r vision_module/requirements.txt
$env:SUPABASE_URL = "https://TU-PROYECTO.supabase.co"
$env:SUPABASE_SERVICE_ROLE_KEY = "TU-CLAVE-SERVICE-ROLE"
$env:VISION_STREAM_TOKEN = "EL-MISMO-SECRETO-LARGO-CONFIGURADO-EN-api/.env"
./vision_module/.venv/Scripts/python.exe vision_module/main.py
```

Configura el mismo `VISION_STREAM_TOKEN` en `api/.env`. La API lo usa para aceptar frames JPEG solo del proceso de visión. El detector conserva la única conexión a la webcam, publica el último frame anotado a FastAPI y ya no abre una ventana local. Inicia FastAPI antes de ejecutar el módulo. Luego abre `http://localhost:8000/admin`, inicia sesión como admin y entra en **Configurar cámaras** para ver el stream y dibujar ROIs.

Obtén la URL del proyecto y la clave `service_role` desde la configuración de API de tu proyecto Supabase. También se admite una clave secreta `sb_secret_...` en `SUPABASE_SERVICE_ROLE_KEY`. La clave del cliente Flutter (`anon` o publicable) no tiene permisos de escritura en el esquema del proyecto. Mantén esta clave únicamente en la computadora/backend de confianza; no la incluyas en Flutter, Git ni capturas de pantalla. Las variables anteriores duran solo la sesión de PowerShell. El script no carga archivos `.env` automáticamente.

Debe existir exactamente una fila con `camara_id = 'CAM-001'` y estado `LIBRE`, `OCUPADO` o `RESERVADO`. Se lee una vez al iniciar. Después de 20 predicciones consecutivas con el estado opuesto, se envía un PATCH a `/rest/v1/espacios`, filtrado por cámara, ID y estado anterior. Si un vehículo entra en un espacio reservado, el cambio confirmado se convierte en `OCUPADO`, cancela la reserva y almacena el tipo detectado. No hay PATCH por frame ni escritura inicial si no cambió el estado. El trigger del esquema UUID actual actualiza `updated_at`.

Ante un error de red, una fila inexistente o un estado remoto incompatible, se detiene el programa sin dar por confirmada la escritura. Corrige el problema y reinicia: el GET inicial comprueba el estado real, incluso si la respuesta de un PATCH anterior se perdió. El filtro por estado anterior evita sobrescribir un cambio externo a `RESERVADO` o `SIN_SERVICIO`; este módulo no implementa sincronización continua con validadores.

## Calibración

1. Fija la cámara. Cada frame se redimensiona a la resolución de procesamiento configurada antes de evaluarlo.
2. Dibuja el ROI desde el panel administrativo. Las coordenadas guardadas en Supabase se escalan desde el tamaño del Canvas hasta la resolución real y la resolución de procesamiento.
3. Ajusta `VISION_YOLO_IMGSZ` y `VISION_YOLO_CONF` si el modelo no detecta los vehículos del encuadre. `truck` se clasifica como `CAMIONETA`, por lo que puede requerirse un modelo ajustado con datos locales para distinguir camionetas de camiones.
4. Si el modelo no está disponible, el detector por píxeles utiliza `UMBRAL_OCUPACION` (12 % inicial). En ese modo, compara el porcentaje de blancos con el puesto vacío y ocupado y ajusta iluminación, encuadre y umbral adaptativo.
5. `FRAMES_CONFIRMACION` define la estabilidad requerida. Para detener el proceso, usa Ctrl+C en la consola.

El modelo preentrenado identifica categorías genéricas COCO; sombras, oclusiones, tamaño del objeto o cambios de iluminación pueden afectar la detección. Las imágenes se procesan exclusivamente en RAM; no se guardan fotos ni videos y se envían a Supabase el estado confirmado y la clase reconocida (RNF12).

Referencias: [umbralización OpenCV](https://docs.opencv.org/4.12.0/d7/d4d/tutorial_py_thresholding.html), [claves de API Supabase](https://supabase.com/docs/guides/getting-started/api-keys).
