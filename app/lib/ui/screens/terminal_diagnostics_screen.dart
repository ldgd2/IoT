import 'package:flutter/material.dart';

class TerminalDiagnosticsScreen extends StatefulWidget {
  const TerminalDiagnosticsScreen({super.key});

  @override
  State<TerminalDiagnosticsScreen> createState() => _TerminalDiagnosticsScreenState();
}

class _TerminalDiagnosticsScreenState extends State<TerminalDiagnosticsScreen> {
  final List<String> _logs = [
    '[INFO] [15:40:12] Gateway RF 433MHz: Heartbeat recibido OK (RSSI: -54 dBm)',
    '[INFO] [15:40:15] Hub Colmena: Sincronización con servidor cloud completada en 120ms',
    '[WARN] [15:41:02] Sensor Exterior Jardín: Ping timeout (Intento 1 de 3)',
    '[ERROR] [15:41:10] Sensor Exterior Jardín: Nodo marcado como OFFLINE en topología Mesh',
    '[INFO] [15:42:00] Motor de Automatización: Escena "Modo Cine en Casa" evaluada con éxito',
    '[INFO] [15:43:22] Cámara 01: Fragmento de grabación RTSP guardado en almacenamiento local',
    '[INFO] [15:44:05] Watchdog: Todos los servicios internos operando en parámetros normales',
  ];

  final _cmdCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Consola de Logs del Sistema', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Limpiar logs',
                onPressed: () => setState(() => _logs.clear()),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0A0C10),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
              ),
              child: ListView.builder(
                itemCount: _logs.length,
                itemBuilder: (ctx, idx) {
                  final line = _logs[idx];
                  Color textColor = Colors.white70;
                  if (line.contains('[ERROR]')) {
                    textColor = cs.error;
                  } else if (line.contains('[WARN]')) {
                    textColor = const Color(0xFFFFB800);
                  } else if (line.contains('[INFO]')) {
                    textColor = const Color(0xFF00E5A8);
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Text(
                      line,
                      style: TextStyle(fontFamily: 'monospace', fontSize: 13, color: textColor),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cmdCtrl,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Escribir comando de diagnóstico (ej. ping 192.168.1.10)...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: cs.surfaceContainerHigh,
                  ),
                  onSubmitted: _executeCommand,
                ),
              ),
              const SizedBox(height: 8, width: 8),
              FilledButton(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _executeCommand(_cmdCtrl.text),
                child: const Text('Enviar'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _executeCommand(String cmd) {
    if (cmd.trim().isEmpty) return;
    setState(() {
      _logs.add('[USER] > $cmd');
      _logs.add('[INFO] Ejecutando comando en daemon local...');
      _cmdCtrl.clear();
    });
  }
}
