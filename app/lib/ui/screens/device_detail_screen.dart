import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bthapp/src/state/app_state.dart';
import 'package:bthapp/src/models/device.dart';
import '../widgets/inputs/color_picker_wheel.dart';
import '../widgets/inputs/dial_knob_input.dart';
import '../widgets/inputs/vertical_slider_input.dart';
import '../widgets/buttons/primary_action_button.dart';
import '../widgets/dialogs/ota_update_dialog.dart';

class DeviceDetailScreen extends StatefulWidget {
  final String deviceId;

  const DeviceDetailScreen({
    super.key,
    required this.deviceId,
  });

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  Color _lightColor = const Color(0xFF00E5A8);
  double _targetTemp = 22.5;
  double _brightness = 0.8;
  bool _initialized = false;

  void _syncLocalStateWithDevice(Device d) {
    if (_initialized) return;
    _initialized = true;

    if (d.state['temperature'] != null || d.state['target_temp'] != null) {
      final t = (d.state['target_temp'] ?? d.state['temperature'] ?? 22.5) as num;
      _targetTemp = t.toDouble().clamp(16.0, 32.0);
    }
    if (d.state['brightness'] != null) {
      final b = (d.state['brightness'] as num).toDouble();
      _brightness = (b > 1.0 ? b / 255.0 : b).clamp(0.0, 1.0);
    }
    if (d.state['rgb'] is String) {
      final hex = (d.state['rgb'] as String).replaceAll('#', '');
      if (hex.length == 6 || hex.length == 8) {
        final val = int.tryParse(hex, radix: 16);
        if (val != null) {
          _lightColor = Color(hex.length == 6 ? (val | 0xFF000000) : val);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final device = app.getById(widget.deviceId);
    final cs = Theme.of(context).colorScheme;

    if (device == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dispositivo no encontrado')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('El dispositivo ya no está disponible en la red.'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Volver'),
              ),
            ],
          ),
        ),
      );
    }

    _syncLocalStateWithDevice(device);
    final switchNames = app.getSwitchNames(device.id, device.relays.length);
    final isLighting = device.kind == 'Luz' || device.kind == 'Dimmer';
    final isClimate = device.kind == 'Sensor Temperatura' || device.kind == 'Ventilador';

    return Scaffold(
      appBar: AppBar(
        title: Text(device.alias ?? device.id, style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Sincronizar estado real',
            onPressed: () async {
              await context.read<AppState>().refreshDevice(device);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Estado de hardware actualizado en tiempo real.')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.system_update_alt),
            tooltip: 'Actualizar Firmware OTA',
            onPressed: _startOtaDemo,
          ),
          PopupMenuButton<String>(
            onSelected: (val) async {
              if (val == 'rename') {
                _showRenameDialog(context, device);
              } else if (val == 'delete') {
                final confirm = await _showDeleteConfirm(context, device);
                if (confirm == true && context.mounted) {
                  await context.read<AppState>().removeDevice(device.id);
                  if (context.mounted) Navigator.pop(context);
                }
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'rename', child: Text('Renombrar dispositivo')),
              PopupMenuItem(
                value: 'delete',
                child: Text('Desvincular hardware', style: TextStyle(color: cs.error)),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Estado de Conectividad', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(
                          '${device.isRf ? "Hub RF 433MHz" : "Wi-Fi ESP"} (${device.ip}) - ${device.online ? "En Línea" : "Sin Respuesta"}',
                          style: TextStyle(color: device.online ? const Color(0xFF00E5A8) : cs.error, fontSize: 13),
                        ),
                      ],
                    ),
                    Icon(
                      device.online ? Icons.wifi : Icons.wifi_off,
                      color: device.online ? const Color(0xFF00E5A8) : cs.error,
                      size: 28,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Control de Canales y Interruptores', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 12),
            if (device.relays.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Este dispositivo opera en modo lectura o sensor sin relés de conmutación.'),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: device.relays.length,
                itemBuilder: (ctx, i) {
                  final isOn = device.relays[i];
                  final name = i < switchNames.length ? switchNames[i] : 'Canal ${i + 1}';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(
                                  isOn ? Icons.lightbulb : Icons.lightbulb_outline,
                                  color: isOn ? const Color(0xFF00E5A8) : cs.onSurfaceVariant,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                      Text('Interruptor de canal ${i + 1}', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            tooltip: 'Renombrar interruptor',
                            onPressed: () => _showSwitchRenameDialog(context, device, i, name),
                          ),
                          Switch(
                            value: isOn,
                            onChanged: (v) async {
                              final ok = await context.read<AppState>().setRelay(device, i + 1, v);
                              if (!ok && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('No se pudo enviar el comando al hardware de destino.')),
                                );
                              }
                            },
                            activeThumbColor: cs.primary,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 28),
            if (isLighting) ...[
              const Text('Control de Brillo y Color RGB', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ColorPickerWheel(
                    initialColor: _lightColor,
                    onColorSelected: (c) {
                      setState(() => _lightColor = c);
                      final hex = c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2);
                      context.read<AppState>().setDeviceAttribute(device, {'rgb': hex, 'on': true});
                    },
                  ),
                  VerticalSliderInput(
                    value: _brightness,
                    onChanged: (b) {
                      setState(() => _brightness = b);
                      final brightVal = (b * 255).round();
                      context.read<AppState>().setDeviceAttribute(device, {'brightness': brightVal, 'on': brightVal > 0});
                    },
                  ),
                ],
              ),
            ] else if (isClimate) ...[
              const Text('Control de Termostato Digital', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 24),
              DialKnobInput(
                value: _targetTemp,
                onChanged: (t) {
                  setState(() => _targetTemp = t);
                  context.read<AppState>().setDeviceAttribute(device, {'target_temp': t});
                },
              ),
            ],
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              child: PrimaryActionButton(
                label: 'Sincronizar y Guardar Cambios',
                icon: Icons.save_outlined,
                onPressed: () async {
                  await context.read<AppState>().refreshDevice(device);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ajustes y estado verificados directamente en el hardware.')),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context, Device d) {
    final ctrl = TextEditingController(text: d.alias ?? d.id);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renombrar Dispositivo'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Nombre o alias', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          PrimaryActionButton(
            label: 'Guardar',
            onPressed: () async {
              final newName = ctrl.text.trim();
              if (newName.isNotEmpty) {
                await context.read<AppState>().addOrUpdateDevice(d.copyWith(alias: newName));
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
          ),
        ],
      ),
    );
  }

  void _showSwitchRenameDialog(BuildContext context, Device d, int index, String currentName) {
    final ctrl = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Renombrar Interruptor ${index + 1}'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Nombre de luz o canal', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          PrimaryActionButton(
            label: 'Guardar',
            onPressed: () async {
              final newName = ctrl.text.trim();
              if (newName.isNotEmpty) {
                await context.read<AppState>().setSwitchName(d.id, index, newName);
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
          ),
        ],
      ),
    );
  }

  Future<bool?> _showDeleteConfirm(BuildContext context, Device d) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desvincular Dispositivo'),
        content: Text('¿Deseas eliminar "${d.alias ?? d.id}" del control central y de la red Mesh de forma permanente?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _startOtaDemo() {
    double progress = 0.1;
    OtaUpdateDialog.show(
      context,
      version: 'v2.4.1-release',
      progress: progress,
      status: 'Descargando paquete de firmware desde el Hub principal...',
    );
  }
}
