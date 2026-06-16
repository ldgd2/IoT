import threading
import time
from rich.console import Console
from .evaluator import ASTEvaluator, ASTContext
from .eventbus import event_bus

console = Console()

class SkillsEngine:
    """
    Motor Pseint para ejecutar rutinas completas AST en la Colmena IoT.
    """
    def __init__(self, gateway):
        self.gateway = gateway
        self.active_skills = {}
        self.context = ASTContext()
        
        # Suscribir el Engine al bus de eventos globales
        # Cualquier evento que se dispare llegara aca
        event_bus.subscribe("trigger", self._on_event)

    def _on_event(self, payload):
        """
        Invocado cuando ocurre algun evento (ej. sensor_humo envia datos).
        Aca deberiamos consultar la Base de Datos para encontrar qué Skills
        reaccionan a este evento, y ejecutarlas.
        Por ahora, actualiza el contexto y asume ejecucion.
        """
        # payload ejemplo: {"device_id": 5, "var": "smoke", "value": "DETECTED"}
        if "var" in payload and "value" in payload:
            var_key = f"device.{payload.get('device_id')}.{payload.get('var')}"
            self.context.set_var(var_key, payload.get("value"))
            
        # TODO: Buscar skills en la BD que coincidan con este trigger y ejecutarlas
        
    def execute_skill_ast(self, skill_json):
        """
        Inicia la ejecucion de una Skill que tiene logica AST.
        """
        skill_name = skill_json.get("skill_name", "Unknown AST Skill")
        logic = skill_json.get("logic", {})
        
        if not logic:
            return
            
        thread = threading.Thread(
            target=self._run_ast_loop, 
            args=(skill_name, logic),
            daemon=True
        )
        self.active_skills[skill_name] = thread
        thread.start()
        
    def _run_ast_loop(self, skill_name, logic):
        console.print(f"[blue]>> Iniciando AST Skill: {skill_name}[/blue]")
        evaluator = ASTEvaluator(self.context)
        
        # Evaluar bloque IF principal
        if "if" in logic:
            if_block = logic["if"]
            condition = if_block.get("condition")
            
            # Evaluador Pseint resuelve True o False
            is_true = evaluator.evaluate(condition)
            
            console.print(f"[magenta]  Evaluando AST Condicion... Resultado: {is_true}[/magenta]")
            
            branch = if_block.get("then", []) if is_true else if_block.get("else", [])
            
            for action in branch:
                self._execute_action(action)
                
        console.print(f"[green]<< AST Skill '{skill_name}' terminada.[/green]")
        if skill_name in self.active_skills:
            del self.active_skills[skill_name]

    def _execute_action(self, action_node):
        """Ejecuta una accion terminal de AST, como enviar comando a RF"""
        act_type = action_node.get("action")
        
        if act_type == "execute":
            node_id = action_node.get("device_id")
            cmd = action_node.get("cmd")
            
            # Aqui es donde en el futuro consultamos ontology.py 
            # para traducir cmd (string "encender") a cmd_id (0x01)
            # Por simplicidad de la prueba, asumimos que llega el numero.
            if isinstance(cmd, str):
                cmd_id = 1 if cmd == "encender" else 2 # FAKE MAPPING TEMPORAL
            else:
                cmd_id = cmd
                
            console.print(f"[cyan]  Ejecutando Accion AST -> Nodo {node_id} CMD {cmd_id}[/cyan]")
            self.gateway.send_command(dest_id=node_id, command=cmd_id)
            
        elif act_type == "delay":
            secs = action_node.get("seconds", 1)
            console.print(f"[dim]  Delay AST por {secs}s...[/dim]")
            time.sleep(secs)
