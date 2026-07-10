// =============================================================
// lib/ui/flows/devices/network_health_view.dart
// Diagnóstico y monitor de salud de la red Colmena IoT
// =============================================================
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import 'package:bthapp/src/models/device.dart';
import 'package:bthapp/src/services/auth_service.dart';
import 'package:bthapp/src/state/app_state.dart';

class NetworkHealthView extends StatefulWidget {
  const NetworkHealthView({super.key});

  @override
  State<NetworkHealthView> createState() => _NetworkHealthViewState();
}

class _NetworkHealthViewState extends State<NetworkHealthView> {
  bool testingHub = false;
  bool hubOnline = false;

  @override
  void initState() {
    super.initState();
    _testHub();
  }

  Future<void> _testHub() async {
    setState(() => testingHub = true);
    final app = context.read<AppState>();
    final ok = await app.checkHubOnline();
    if (mounted) {
      setState(() {
        hubOnline = ok;
        testingHub = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final devices = app.devices;

    final rfDevices = devices.where((d) => d.commMode == 'rf').toList();
    final wifiDevices = devices.where((d) => d.commMode == 'wifi').toList();
    final onlineCount = devices.where((d) => d.online).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnóstico de Red', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: 'Probar conectividad',
            icon: const Icon(Icons.refresh),
            onPressed: _testHub,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Tarjeta de estado del Gateway RF
          _HealthMetricCard(
            title: 'Central Colmena (Servidor Hogar)',
            subtitle: app.hubHost,
            statusText: testingHub ? 'Probando...' : (hubOnline ? 'ONLINE • Excelente' : 'DESCONECTADO'),
            statusColor: testingHub ? Colors.amberAccent : (hubOnline ? const Color(0xFF00E5A8) : Colors.redAccent),
            icon: Icons.hub_outlined,
            onAction: _testHub,
          ).animate().fadeIn().slideY(begin: 0.05, end: 0),
          const SizedBox(height: 16),

          // Sección para editar y guardar IP Local en la base de datos interna
          const _LocalIpEditorSection(),
          const SizedBox(height: 16),

          // Guía detallada sobre cómo obtener la IP del Router
          const _RouterIpGuideSection(),
          const SizedBox(height: 16),

          // Resumen de nodos
          Row(
            children: [
              Expanded(
                child: _StatBox(
                  icon: Icons.podcasts,
                  label: 'Nodos RF (Colmena)',
                  value: '${rfDevices.length}',
                  color: const Color(0xFF00E5A8),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatBox(
                  icon: Icons.wifi,
                  label: 'Nodos Wi-Fi Directo',
                  value: '${wifiDevices.length}',
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ).animate().fadeIn(delay: 100.ms),
          const SizedBox(height: 12),
          _StatBox(
            icon: Icons.check_circle_outline,
            label: 'Dispositivos en Línea',
            value: '$onlineCount / ${devices.length}',
            color: const Color(0xFF00E5A8),
          ),
          const SizedBox(height: 16),

          // Distribución RSSI
          Text(
            'Fuerza de Señal por Dispositivo (RSSI)',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (devices.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text('No hay dispositivos registrados en la red.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ),
            )
          else
            for (final d in devices) ...[
              _SignalRow(device: d),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _HealthMetricCard extends StatelessWidget {
  const _HealthMetricCard({
    required this.title,
    required this.subtitle,
    required this.statusText,
    required this.statusColor,
    required this.icon,
    required this.onAction,
  });

  final String title;
  final String subtitle;
  final String statusText;
  final Color statusColor;
  final IconData icon;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: statusColor.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: statusColor, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                Text(subtitle, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.icon, required this.label, required this.value, required this.color});
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 10),
          Text(value, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _SignalRow extends StatelessWidget {
  const _SignalRow({required this.device});
  final Device device;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final rssi = device.rssi ?? (device.commMode == 'rf' ? -68 : -55);
    final isGood = rssi > -70;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(device.commMode == 'rf' ? Icons.podcasts : Icons.wifi, color: isGood ? const Color(0xFF00E5A8) : Colors.amberAccent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(device.alias ?? device.id, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('${device.kind ?? "Módulo"} • ${device.room ?? "General"}', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$rssi dBm', style: TextStyle(fontWeight: FontWeight.bold, color: isGood ? const Color(0xFF00E5A8) : Colors.orangeAccent)),
              Text(isGood ? 'Óptima' : 'Regular', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// EDITOR DE IP LOCAL (EN CASA) CON VALIDACIÓN Y GUARDADO INTERNO
// -------------------------------------------------------------
class _LocalIpEditorSection extends StatefulWidget {
  const _LocalIpEditorSection();

  @override
  State<_LocalIpEditorSection> createState() => _LocalIpEditorSectionState();
}

enum _IpTestState { idle, testing, success, error }

class _LocalIpEditorSectionState extends State<_LocalIpEditorSection> {
  late TextEditingController _controller;
  _IpTestState _testState = _IpTestState.idle;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    _controller = TextEditingController(text: app.localHubHost);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _validateAndSave() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() {
        _testState = _IpTestState.error;
        _errorMsg = 'Escribe una dirección IP antes de guardar.';
      });
      return;
    }

    setState(() {
      _testState = _IpTestState.testing;
      _errorMsg = null;
    });

    final reachable = await AuthService.pingHub(text);

    if (!mounted) return;

    if (reachable) {
      final app = context.read<AppState>();
      await app.setHubHost(text);
      setState(() => _testState = _IpTestState.success);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(child: Text('Conectado y guardado: $text')),
            ],
          ),
          backgroundColor: const Color(0xFF00E5A8),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      setState(() {
        _testState = _IpTestState.error;
        _errorMsg = 'No se pudo conectar a $text\n'
            '• Verifica que la Central esté encendida.\n'
            '• Asegúrate de estar en la misma red Wi-Fi.\n'
            '• Comprueba que el puerto sea el correcto (ej. :5000).';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final Color borderColor;
    if (_testState == _IpTestState.success) {
      borderColor = const Color(0xFF00E5A8);
    } else if (_testState == _IpTestState.error) {
      borderColor = cs.error;
    } else {
      borderColor = cs.outlineVariant.withValues(alpha: 0.5);
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: _testState == _IpTestState.idle ? 1 : 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.router,
                  color: _testState == _IpTestState.success
                      ? const Color(0xFF00E5A8)
                      : _testState == _IpTestState.error
                          ? cs.error
                          : cs.primary,
                  size: 22),
              const SizedBox(width: 10),
              Text(
                'Dirección IP de tu Hogar (En Casa)',
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'La app verificará la conexión antes de guardar. '
            'Se conectará directamente a tu Central cuando estés en casa sin usar internet.',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant, height: 1.3),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  onChanged: (_) {
                    if (_testState != _IpTestState.idle) {
                      setState(() {
                        _testState = _IpTestState.idle;
                        _errorMsg = null;
                      });
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'IP y Puerto (Ej. 192.168.1.100:5000)',
                    hintText: '192.168.1.100:5000',
                    prefixIcon: const Icon(Icons.lan_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    errorText: _testState == _IpTestState.error && _errorMsg != null
                        ? _errorMsg
                        : null,
                    errorMaxLines: 4,
                  ),
                  keyboardType: TextInputType.text,
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: _testState == _IpTestState.testing ? null : _validateAndSave,
                icon: _testState == _IpTestState.testing
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(
                        _testState == _IpTestState.success
                            ? Icons.check
                            : _testState == _IpTestState.error
                                ? Icons.wifi_off
                                : Icons.link,
                      ),
                label: Text(
                  _testState == _IpTestState.testing
                      ? 'Probando...'
                      : _testState == _IpTestState.success
                          ? 'Guardado'
                          : _testState == _IpTestState.error
                              ? 'Reintentar'
                              : 'Probar y Guardar',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _testState == _IpTestState.success
                      ? const Color(0xFF00E5A8)
                      : _testState == _IpTestState.error
                          ? cs.error
                          : null,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// GUÍA DETALLADA PARA OBTENER LA DIRECCIÓN IP EN EL ROUTER
// -------------------------------------------------------------
class _RouterIpGuideSection extends StatelessWidget {
  const _RouterIpGuideSection();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 0,
      color: cs.surfaceContainerLow,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.help_outline, color: cs.primary, size: 22),
          ),
          title: Text(
            '¿No sabes tu IP Local? Guía Paso a Paso en tu Router',
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            'Aprende a encontrar la dirección exacta de tu Central en el módem Wi-Fi de tu casa.',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: 20),
            _buildStepItem(
              context,
              step: '1',
              icon: Icons.info_outline,
              title: '¿Por qué la red local es diferente?',
              body: 'Todos los dispositivos en tu casa tienen un número de identificación privado asignado por tu módem o router Wi-Fi (siempre empieza con 192.168.x.x). Al conectar el teléfono a esa IP, la comunicación no sale a internet, siendo instantánea y segura.',
            ),
            const SizedBox(height: 14),
            _buildStepItem(
              context,
              step: '2',
              icon: Icons.router_outlined,
              title: 'Encuentra la dirección de tu Router Wi-Fi',
              body: 'Para ver qué aparatos están conectados a tu casa, debes entrar al panel de administración de tu módem:\n'
                    '• En Android/iPhone: Abre Ajustes > Wi-Fi > Toca el nombre de tu red y busca "Puerta de enlace" o "Router". Generalmente es 192.168.1.1 o 192.168.0.1.\n'
                    '• En una computadora Windows: Abre la consola (cmd) y escribe la orden "ipconfig". La IP correcta es la que dice "Puerta de enlace predeterminada".',
            ),
            const SizedBox(height: 14),
            _buildStepItem(
              context,
              step: '3',
              icon: Icons.login,
              title: 'Accede al panel de control de tu Módem',
              body: 'Abre el navegador web (Chrome, Safari o Edge) y escribe en la barra superior la dirección de tu router (Ejemplo: http://192.168.1.1).\n'
                    'El sistema te pedirá un Usuario y Contraseña:\n'
                    '• Si nunca los cambiaste, revisa la etiqueta adhesiva debajo o detrás de tu módem físico.\n'
                    '• Las combinaciones más comunes de fábrica son: usuario "admin" con clave "admin", o la misma contraseña de tu red Wi-Fi.',
            ),
            const SizedBox(height: 14),
            _buildStepItem(
              context,
              step: '4',
              icon: Icons.devices_other_outlined,
              title: 'Busca tu Central Colmena en la lista',
              body: 'Dentro del menú de tu módem, entra a la sección llamada "Dispositivos Conectados", "Mapa de Red" o "Lista de Clientes DHCP".\n'
                    'Busca en la tabla un equipo con el nombre "RaspberryPi", "ColmenaHub", "ESP32" o el nombre de tu servidor central. En la columna "Dirección IP" verás su número (por ejemplo: 192.168.1.48 o 192.168.1.100).',
            ),
            const SizedBox(height: 14),
            _buildStepItem(
              context,
              step: '5',
              icon: Icons.save_outlined,
              title: 'Escríbela en la casilla y guárdala',
              body: 'Copia esa IP, agrégale los dos puntos y el puerto ":5000" (o ":8000" si utilizas el puente) y colócalo en el campo de texto superior. Presiona el botón "Guardar". ¡Listo! Tu teléfono memorizará esa dirección de por vida.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepItem(BuildContext context, {required String step, required IconData icon, required String title, required String body}) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: cs.primary,
            shape: BoxShape.circle,
          ),
          child: Text(
            step,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: cs.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
