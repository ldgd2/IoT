# IoT Bridge Server (`server/`) & Solución para Redes Protegidas (NAT / Firewall)

Servidor puente diseñado para conectar de forma transparente la **Aplicación Móvil (Teléfono)** con el **Gateway Hub Colmena (`hub/`)**, resolviendo incluso los escenarios donde **tu red local no tiene IP pública o tiene puertos cerrados (CGNAT/Firewall)**.

---

## ¿Cómo solucionar cuando tu red solo puede realizar peticiones salientes?

Si tu casa o red local está protegida por el router o firewall del proveedor de internet y no puedes abrir puertos entrantes para que el teléfono se conecte directamente desde la calle, existen 2 formas nativas soportadas por este proyecto:

### Solución 1: Modo Outbound Polling / Relay (Incluida aquí)
Como tu red local **sí permite consumir o realizar peticiones salientes hacia afuera**, invertimos la conexión:
1. Instalas el **Bridge Server (`server/main.py`)** en un servidor gratuito en la nube (VPS, Render, Railway, AWS o Heroku).
2. El teléfono se conecta a ese servidor en la nube y le manda la orden (`POST /api/command`).
3. En tu casa, el **Gateway Hub (`hub/`)** se conecta en segundo plano hacia tu servidor en la nube (definido por `CLOUD_BRIDGE_URL`).
4. El worker `cloud_bridge` nativo del Hub consulta continuamente **desde adentro hacia afuera** (`GET /api/hub/poll`) si hay órdenes pendientes.
5. Al detectar una orden, la ejecuta localmente y sube el resultado (`POST /api/hub/response`). El teléfono recibe el OK al instante. ¡Cero puertos abiertos!

### Solución 2: Túnel Seguro (Cloudflare Tunnel o Ngrok)
Si prefieres correr el `server/` dentro de tu casa y tener una URL pública en segundos sin tocar el router:
- Instala Cloudflare Tunnel y ejecuta:
  ```bash
  cloudflared tunnel --url http://localhost:8000
  ```
  Te dará una dirección segura (`https://tu-casa.trycloudflare.com`). Pones esa URL en tu teléfono Flutter y listo.

---

## Despliegue en Producción (Linux / VPS / Raspberry Pi) con Gunicorn

Para que el servidor corra en producción 24/7 sin advertencias de desarrollo (`Flask development server`) y se reinicie automáticamente, hemos creado un gestor automatizado que usa **Gunicorn** y **systemd**:

1. Dar permisos de ejecución al script:
   ```bash
   chmod +x service.sh
   ```
2. Ejecutar el menú interactivo o comandos directos:
   - **Instalar y arrancar el servicio:** `sudo ./service.sh install`
   - **Ver estado en tiempo real:** `sudo ./service.sh status` o `sudo ./service.sh watch`
   - **Ver logs en tiempo real:** `sudo ./service.sh tail`
   - **Ver últimos logs:** `sudo ./service.sh logs`
   - **Detener servicio:** `sudo ./service.sh stop`
   - **Reiniciar servicio:** `sudo ./service.sh restart`
   - **Desinstalar y eliminar servicio:** `sudo ./service.sh remove`

## Ejecución Rápida de Pruebas (Desarrollo)

```bash
python main.py
```
Escuchará en `http://0.0.0.0:8000` y conectará automáticamente con tu Gateway Hub en el puerto `5000`.
