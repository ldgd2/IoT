import datetime

class ASTContext:
    """
    Contiene el estado del sistema en tiempo real para evaluar variables.
    Aca se guardaran los estados conocidos de los sensores y variables de entorno.
    """
    def __init__(self):
        # Ej: {"device.5.smoke": "DETECTED", "weather.raining": False}
        self.variables = {}
        
    def get_var(self, var_name: str):
        # Variables magicas predefinidas
        if var_name == "time.hour":
            return datetime.datetime.now().hour
        if var_name == "time.minute":
            return datetime.datetime.now().minute
            
        return self.variables.get(var_name, None)

    def set_var(self, var_name: str, value):
        self.variables[var_name] = value


class ASTEvaluator:
    """
    Motor Pseint / AST.
    Evalua un bloque condicional JSON usando el contexto actual.
    Soporta operaciones logicas y acceso a variables.
    """
    def __init__(self, context: ASTContext):
        self.context = context

    def evaluate(self, node):
        """Evalua un nodo AST recursivamente."""
        if not isinstance(node, dict):
            # Es un valor primitivo (True, "FUEGO", 5)
            return node
            
        if "var" in node:
            return self.context.get_var(node["var"])
            
        if "==" in node:
            args = node["=="]
            return self.evaluate(args[0]) == self.evaluate(args[1])
            
        if "!=" in node:
            args = node["!="]
            return self.evaluate(args[0]) != self.evaluate(args[1])
            
        if ">" in node:
            args = node[">"]
            return self.evaluate(args[0]) > self.evaluate(args[1])
            
        if "<" in node:
            args = node["<"]
            return self.evaluate(args[0]) < self.evaluate(args[1])
            
        if "and" in node:
            for arg in node["and"]:
                if not self.evaluate(arg):
                    return False
            return True
            
        if "or" in node:
            for arg in node["or"]:
                if self.evaluate(arg):
                    return True
            return False
            
        if "not" in node:
            return not self.evaluate(node["not"])

        # Si el nodo no coincide con nada, lanzar error o retornar False
        return False
