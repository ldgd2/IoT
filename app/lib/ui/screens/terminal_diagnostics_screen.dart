import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bthapp/src/state/app_state.dart';
import 'package:bthapp/src/models/device.dart';

class TerminalDiagnosticsScreen extends StatefulWidget {
  const TerminalDiagnosticsScreen({super.key});

  @override
  State<TerminalDiagnosticsScreen> createState() => _TerminalDiagnosticsScreenState();
}

class _TerminalDiagnosticsScreenState extends State<TerminalDiagnosticsScreen> {
  final List<String> _logs = [];
  final _cmdCtrl = TextEditingController();
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _initRealDiagnostics();
    }
  }

  void _initRealDiagnostics() {
    final app = context.read<AppState>();
    final now = DateTime.now().toLocal().toString().split('.').first;

    setState(() {
      _logs.add('[INFO] [$now] Consola de diagnóstico Colmena IoT iniciada en cliente.');
      _logs.add('[INFO] Host Hub central configurado: ${app.hubHost}');
      _logs.add('[INFO] Dispositivos en caché local: ${app.devices.length} nodos registrados.');
      int onlineCount = app.devices.where((d) => d.online).length;
      _logs.add('[INFO] Nodos en línea: $onlineCount/${app.devices.length}');
      if (app.lastError != null && app.lastError!.isNotEmpty) {
        _logs.add('[ERROR] Última excepción registrada: ${app.lastError}');
      }
    });
  }

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
              const Text('Consola de Logs y Comandos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Sincronizar y generar reporte real',
                    onPressed: _initRealDiagnostics,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Limpiar historial de logs',
                    onPressed: () => setState(() => _logs.clear()),
                  ),
                ],
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
                  } else if (line.contains('[USER]')) {
                    textColor = Colors.lightBlueAccent;
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: SelectableText(
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
                    hintText: 'Comandos disponibles: sync, status, devices, ping <ip>, clear...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: cs.surfaceContainerHigh,
                  ),
                  onSubmitted: _executeCommand,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _executeCommand(_cmdCtrl.text),
                child: const Text('Ejecutar'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _executeCommand(String cmd) async {
    final raw = cmd.trim();
    if (raw.isEmpty) return;

    final app = context.read<AppState>();
    final now = DateTime.now().toLocal().toString().split('.').first;

    setState(() {
      _logs.add('[USER] [$now] > $raw');
      _cmdCtrl.clear();
    });

    final parts = raw.split(' ');
    final action = parts.first.toLowerCase();

    if (action == 'clear') {
      setState(() => _logs.clear());
      return;
    } else if (action == 'sync' || action == 'refresh') {
      setState(() => _logs.add('[INFO] Sincronizando todos los nodos y consultando Hub en paralelo...'));
      final start = DateTime.now();
      await app.refreshAll(parallel: true);
      final elapsed = DateTime.now().difference(start).inMilliseconds;
      if (mounted) {
        setState(() {
          _logs.add('[INFO] Sincronización terminada en ${elapsed}ms. Nodos descubiertos: ${app.devices.length}');
        });
      }
    } else if (action == 'status') {
      int online = app.devices.where((d) => d.online).length;
      setState(() {
        _logs.add('[INFO] Estado global de la red Colmena:');
        _logs.add('       - Dispositivos en línea: $online');
        _logs.add('       - Dispositivos desconectados: ${app.devices.length - online}');
        _logs.add('       - Hub activo: ${!app.loading ? "Sí (Normal)" : "Sincronizando"}');
      });
    } else if (action == 'devices' || action == 'ls') {
      setState(() {
        if (app.devices.isEmpty) {
          _logs.add('[WARN] No hay dispositivos registrados en memoria actualmente.');
        } else {
          _logs.add('[INFO] Lista de nodos vinculados (${app.devices.length}):');
          for (final d in app.devices) {
            final st = d.online ? 'ONLINE ' : 'OFFLINE';
            _logs.add('       - [$st] ID: ${d.id} | IP: ${d.ip} | Tipo: ${d.kind ?? "General"} | Relés: ${d.relays}');
          }
        }
      });
    } else if (action == 'ping') {
      if (parts.length < 2) {
        setState(() => _logs.add('[ERROR] Sintaxis incorrecta. Uso: ping <ip_o_id>'));
        return;
      }
      final target = parts[1];
      final dev = app.devices.cast<Device?>().firstWhere(
        (d) => d?.ip == target || d?.id == target || d?.mdns == target,
        orElse: () => null,
      );
      if (dev != null) {
        setState(() => _logs.add('[INFO] Consultando estado directo de ${dev.alias ?? dev.id} (${dev.ip})...'));
        await app.refreshDevice(dev);
        if (mounted) {
          setState(() {
            _logs.add('[INFO] Ping/refresh completado. Estado actual: ${dev.online ? "ONLINE" : "OFFLINE"} (RSSI: ${dev.rssi ?? "N/A"} dBm)');
          });
        }
      } else {
        setState(() => _logs.add('[WARN] Dispositivo con objetivo "$target" no encontrado en la lista local. Intenta ejecutar "sync" primero.'));
      }
    } else {
      setState(() {
        _logs.add('[ERROR] Comando no reconocido: "$raw"');
        _logs.add('[INFO] Comandos válidos: sync, status, devices, ping <ip>, clear');
      });
    }
  }
}
