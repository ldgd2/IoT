from flask import Blueprint, jsonify, request
from datetime import datetime
from server.modules.automation.models.skill import Skill

automation_bp = Blueprint('automation_api', __name__)

@automation_bp.route("/skills", methods=["GET", "POST"])
def api_skills():
    if request.method == "POST":
        data = request.get_json(silent=True)
        if not data or "name" not in data or "ast" not in data:
            return jsonify({"error": "bad request"}), 400
        
        skill = Skill(
            name=data["name"],
            ast_json=data["ast"],
            created_at=datetime.now().isoformat()
        )
        skill.save()
        return jsonify({"ok": True, "id": getattr(skill, "id", "new")})
    
    # GET method
    skills = [s.to_dict() for s in Skill.all()]
    return jsonify(skills)
