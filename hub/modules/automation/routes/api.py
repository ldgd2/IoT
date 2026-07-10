from flask import Blueprint, jsonify, request
from datetime import datetime
import json
from hub.modules.automation.models.skill import Skill
from hub.modules.automation.evaluator import evaluator

automation_bp = Blueprint('automation_api', __name__)

@automation_bp.route("/skills", methods=["GET", "POST"])
def api_skills():
    if request.method == "POST":
        data = request.get_json(silent=True)
        if not data or "name" not in data or "ast" not in data:
            return jsonify({"error": "Petición inválida. Se requiere nombre y estructura AST."}), 400
        
        skill_id = data.get("id")
        skill = None
        if skill_id:
            skill = Skill.get(skill_id)
            
        if skill:
            skill.name = data["name"]
            skill.ast_json = data["ast"]
            if "is_active" in data:
                skill.is_active = int(data["is_active"])
        else:
            skill = Skill(
                name=data["name"],
                ast_json=data["ast"],
                is_active=int(data.get("is_active", 1)),
                created_at=datetime.now().isoformat()
            )
            
        skill.save()
        return jsonify({"ok": True, "id": getattr(skill, "id", "new")})
    
    # GET method
    skills = [s.to_dict() for s in Skill.all()]
    return jsonify(skills)

@automation_bp.route("/skills/<int:skill_id>", methods=["GET", "DELETE"])
def api_skill_detail(skill_id):
    skill = Skill.get(skill_id)
    if not skill:
        return jsonify({"error": "Skill no encontrada"}), 404
        
    if request.method == "DELETE":
        skill.delete()
        return jsonify({"ok": True, "message": f"Skill {skill_id} eliminada exitosamente"})
        
    return jsonify(skill.to_dict())

@automation_bp.route("/skills/<int:skill_id>/toggle", methods=["POST"])
def api_skill_toggle(skill_id):
    skill = Skill.get(skill_id)
    if not skill:
        return jsonify({"error": "Skill no encontrada"}), 404
        
    data = request.get_json(silent=True) or {}
    if "is_active" in data:
        skill.is_active = 1 if data["is_active"] else 0
    else:
        skill.is_active = 0 if getattr(skill, "is_active", 1) == 1 else 1
        
    skill.save()
    return jsonify({"ok": True, "is_active": skill.is_active})

@automation_bp.route("/skills/<int:skill_id>/execute", methods=["POST"])
def api_skill_execute(skill_id):
    skill = Skill.get(skill_id)
    if not skill:
        return jsonify({"error": "Skill no encontrada"}), 404
        
    ast = getattr(skill, "ast_json", {})
    if isinstance(ast, str):
        try:
            ast = json.loads(ast)
        except Exception:
            ast = {}
            
    actions = ast.get("actions", [])
    if not actions:
        return jsonify({"error": "Esta Skill no tiene acciones configuradas."}), 400
        
    evaluator._execute_actions(actions)
    return jsonify({"ok": True, "message": f"Acciones de la Skill '{skill.name}' ejecutadas correctamente."})
