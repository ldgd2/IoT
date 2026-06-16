import time
import threading
from datetime import datetime
from hub.modules.devices.models.device import Device

OFFLINE_TIMEOUT = 60

def _watchdog_loop():
    while True:
        now = datetime.now()
        for dev in Device.all():
            if dev.last_seen:
                try:
                    dt = (now - datetime.fromisoformat(dev.last_seen)).total_seconds()
                    if dt > OFFLINE_TIMEOUT and dev.status != "offline":
                        dev.status = "offline"
                        dev.save()
                except ValueError:
                    pass
        time.sleep(10)

def start_watchdog():
    threading.Thread(target=_watchdog_loop, daemon=True).start()
