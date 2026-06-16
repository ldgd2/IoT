import os
import json
from flask import Blueprint, render_template

communication_view_bp = Blueprint('communication_view', __name__)

@communication_view_bp.route("/log")
def log_view():
    from hub.db.database import Database
    cursor = Database.execute("SELECT * FROM rf_logs ORDER BY id DESC LIMIT 100")
    logs = []
    for r in cursor.fetchall():
        d = dict(r)
        if isinstance(d.get("payload"), str):
            try: d["payload"] = json.loads(d["payload"])
            except: pass
        logs.append(d)
    return render_template("views/dashboard/logs/index.html", log=logs)

@communication_view_bp.route("/settings")
def settings_view():
    rf_port = os.getenv("RF_PORT", "/dev/ttyUSB0")
    return render_template("views/dashboard/settings/index.html", rf_port=rf_port)
