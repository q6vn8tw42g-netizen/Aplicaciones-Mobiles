import os, json
from pyezviz import EzvizClient

c = EzvizClient(os.environ["EZVIZ_EMAIL"], os.environ["EZVIZ_PASSWORD"],
                os.environ.get("EZVIZ_REGION", "apiius.ezvizlife.com"))
c.login()
cams = c.load_cameras()
print("Camaras:", len(cams))
for s, i in cams.items():
    print(s, "|", i.get("name"), "|", i.get("status"), "|", (i.get("WIFI") or {}).get("address"))
json.dump(cams, open("ezviz_camaras.json", "w", encoding="utf-8"), indent=2, default=str)