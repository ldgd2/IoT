import threading
import time
from rich.console import Console

console = Console()

class SkillsEngine:
    """
    Motor para ejecutar rutinas/macros secuenciales en la Colmena IoT.
    """
    def __init__(self, gateway):
        self.gateway = gateway
        self.active_skills = {}
        
    def execute_skill(self, skill_json):
        """
        Inicia la ejecucion de una skill en un hilo separado.
        skill_json debe tener el formato:
        {
            "skill_name": "Nombre de Rutina",
            "steps": [
                {"node_id": 1, "cmd": 2, "delay_after_sec": 5},
                {"node_id": 2, "cmd": 1, "delay_after_sec": 0}
            ]
        }
        """
        skill_name = skill_json.get("skill_name", "Unknown Skill")
        steps = skill_json.get("steps", [])
        
        if not steps:
            console.print(f"[yellow]Skill '{skill_name}' no tiene pasos para ejecutar.[/yellow]")
            return
            
        thread = threading.Thread(
            target=self._run_skill_loop, 
            args=(skill_name, steps),
            daemon=True
        )
        self.active_skills[skill_name] = thread
        thread.start()
        
    def _run_skill_loop(self, skill_name, steps):
        console.print(f"[blue]>> Iniciando Skill: {skill_name}[/blue]")
        
        for index, step in enumerate(steps):
            node_id = step.get("node_id")
            cmd = step.get("cmd")
            data = step.get("data", [0, 0, 0, 0])
            delay = step.get("delay_after_sec", 0)
            
            if node_id is None or cmd is None:
                console.print(f"[red]Error en Skill '{skill_name}': Paso {index} malformado.[/red]")
                continue
                
            console.print(f"[cyan]  [Paso {index+1}/{len(steps)}] Enviando CMD {cmd} a Nodo {node_id}[/cyan]")
            
            # Enviar el comando atomico a traves del Gateway
            # device_type 0 es generico
            success = self.gateway.send_command(
                dest_id=node_id, 
                command=cmd, 
                device_type=0, 
                data=data
            )
            
            if not success:
                console.print(f"[red]  Fallo al enviar comando a Nodo {node_id}.[/red]")
                
            if delay > 0:
                console.print(f"[dim]  Esperando {delay} segundos...[/dim]")
                time.sleep(delay)
                
        console.print(f"[green]<< Skill '{skill_name}' completada exitosamente.[/green]")
        if skill_name in self.active_skills:
            del self.active_skills[skill_name]
