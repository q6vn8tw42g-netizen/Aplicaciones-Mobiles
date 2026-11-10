import os
from pyezviz import EzvizClient

c = EzvizClient(os.environ["EZVIZ_EMAIL"], os.environ["EZVIZ_PASSWORD"],
                os.environ.get("EZVIZ_REGION", "apiisa.ezvizlife.com"))
c.login()
for s, i in c.load_cameras().items():
    wan = str(i.get("wan_ip") or "")
    wan = ".".join(wan.split(".")[:2] + ["x", "x"]) if wan.count(".") == 3 else wan
    print(s, "|", i.get("name"), "| local:", i.get("local_ip"),
          "| rtsp:", i.get("local_rtsp_port"), "| wan:", wan,
          "| encrypted:", i.get("encrypted"))