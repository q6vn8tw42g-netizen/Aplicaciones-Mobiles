import os
from pyezviz import EzvizClient

c = EzvizClient(os.environ["EZVIZ_EMAIL"], os.environ["EZVIZ_PASSWORD"],
                os.environ.get("EZVIZ_REGION", "apiisa.ezvizlife.com"))
c.login()
cams = c.load_cameras()

print("Metodos relacionados con video:")
print([m for m in dir(c) if any(k in m.lower() for k in ("url", "stream", "rtsp", "live", "key"))])

info = cams["L42490771"]  # SANGAY
print("\nCampos de la camara (solo nombres):")
print(sorted(info.keys()))