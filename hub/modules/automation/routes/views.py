from flask import Blueprint, render_template
from hub.modules.automation.models.skill import Skill
from hub.modules.devices.models.device import Device

automation_view_bp = Blueprint('automation_view', __name__)

@automation_view_bp.route("/skills")
def skills_view():
    return render_template("views/dashboard/skills/index.html", skills=Skill.all())

@automation_view_bp.route("/skills/builder")
def skills_builder_view():
    return render_template("views/dashboard/skills/builder.html", devices=Device.all())
