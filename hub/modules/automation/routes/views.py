from flask import Blueprint, render_template, request
from hub.modules.automation.models.skill import Skill
from hub.modules.devices.models.device import Device
import json

automation_view_bp = Blueprint('automation_view', __name__)

@automation_view_bp.route("/skills")
@automation_view_bp.route("/scenes")
def skills_view():
    return render_template("views/dashboard/skills/index.html", skills=Skill.all())

@automation_view_bp.route("/skills/builder")
def skills_builder_view():
    skill_id = request.args.get("id")
    edit_skill = None
    ast_data = {}
    if skill_id:
        try:
            edit_skill = Skill.get(int(skill_id))
            if edit_skill and edit_skill.ast_json:
                if isinstance(edit_skill.ast_json, str):
                    try:
                        ast_data = json.loads(edit_skill.ast_json)
                    except Exception:
                        ast_data = {}
                elif isinstance(edit_skill.ast_json, dict):
                    ast_data = edit_skill.ast_json
        except Exception:
            pass
            
    return render_template(
        "views/dashboard/skills/builder.html", 
        devices=Device.all(), 
        edit_skill=edit_skill,
        ast_json_str=json.dumps(ast_data)
    )
