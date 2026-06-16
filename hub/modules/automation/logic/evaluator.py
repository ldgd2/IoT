import datetime
import urllib.request
import json
import time
from hub.core.config import LATITUDE, LONGITUDE

class ASTContext:
    """
    Contiene el estado del sistema en tiempo real para evaluar variables.
    Aca se guardaran los estados conocidos de los sensores y variables de entorno.
    """
    def __init__(self):
        # Ej: {"device.5.smoke": "DETECTED", "weather.raining": False}
        self.variables = {}
        
        # Cache de clima
        self._weather_cache = {}
        self._weather_last_fetch = 0
        
    def _fetch_weather(self):
        """Descarga el clima actual usando Open-Meteo (Sin API Key, Gratis)"""
        now = time.time()
        # Cache de 15 minutos (900 segundos)
        if now - self._weather_last_fetch < 900 and self._weather_cache:
            return self._weather_cache
            
        try:
            url = f"https://api.open-meteo.com/v1/forecast?latitude={LATITUDE}&longitude={LONGITUDE}&current_weather=true"
            req = urllib.request.urlopen(url, timeout=5)
            data = json.loads(req.read())
            self._weather_cache = data.get("current_weather", {})
            self._weather_last_fetch = now
        except Exception as e:
            from rich.console import Console
            Console().print(f"[red]Error obteniendo clima: {e}[/red]")
            
        return self._weather_cache

    def get_var(self, var_name: str):
        # Variables magicas de Tiempo
        if var_name == "time.hour":
            return datetime.datetime.now().hour
        if var_name == "time.minute":
            return datetime.datetime.now().minute
        if var_name == "time.day":
            return datetime.datetime.now().day
            
        # Variables magicas de Clima (weather.temperature, weather.is_day)
        if var_name.startswith("weather."):
            weather = self._fetch_weather()
            prop = var_name.split(".")[1]
            if prop == "temperature":
                return weather.get("temperature", 0)
            if prop == "is_day":
                return bool(weather.get("is_day", 1))
            if prop == "windspeed":
                return weather.get("windspeed", 0)
            if prop == "weathercode":
                return weather.get("weathercode", 0) # WMO Weather interpretation codes
            
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
            
        if ">=" in node:
            args = node[">="]
            return self.evaluate(args[0]) >= self.evaluate(args[1])
            
        if "<" in node:
            args = node["<"]
            return self.evaluate(args[0]) < self.evaluate(args[1])
            
        if "<=" in node:
            args = node["<="]
            return self.evaluate(args[0]) <= self.evaluate(args[1])
            
        if "in_range" in node:
            args = node["in_range"] # Ej: [{"var": "temp"}, 10, 30]
            val = self.evaluate(args[0])
            return args[1] <= val <= args[2]
            
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
