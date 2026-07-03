// =============================================================
// lib/ui/flows/devices/device_detail_view.dart
// Vistas de detalle interactivas especializadas por tipo de dispositivo
// =============================================================
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import 'package:bthapp/ui/components/index.dart';
import 'package:bthapp/src/models/device.dart';
import 'package:bthapp/src/state/app_state.dart';
import 'package:bthapp/ui/flows/devices/devices_widgets.dart' as dvw;

class DeviceDetailView extends StatefulWidget {
  const DeviceDetailView({super.key, required this.deviceId});
  final String deviceId;

  @override
  State<DeviceDetailView> createState() => _DeviceDetailViewState();
}

class _DeviceDetailViewState extends State<DeviceDetailView> {
  bool busy = false;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final d = app.getById(widget.deviceId);

    if (d == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Dispositivo no encontrado')),
      );
    }

    final names = app.getSwitchNames(d.id, d.relays.length);
    final kind = d.kind ?? 'Interruptor';
    final isRf = d.commMode == 'rf';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(d.alias ?? d.id, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text('${d.room ?? "General"} • ${isRf ? "Hub RF" : "Wi-Fi directo"}', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Renombrar dispositivo',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final newAlias = await _promptText(context, title: 'Nombre del dispositivo', initial: d.alias ?? d.id);
              if (newAlias != null && newAlias.trim().isNotEmpty) {
                await context.read<AppState>().addDevice(d.copyWith(alias: newAlias.trim()));
              }
            },
          ),
          IconButton(
            tooltip: 'Eliminar dispositivo',
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('¿Eliminar dispositivo?'),
                  content: Text('Se desvinculará "${d.alias ?? d.id}" de tu app.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Eliminar'),
                    ),
                  ],
                ),
              );
              if (confirm == true && context.mounted) {
                await context.read<AppState>().removeDevice(d.id);
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<AppState>().refreshDevice(d),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            dvw.DeviceHeader(
              kind: kind,
              online: d.online,
              ip: isRf ? 'Hub: ${d.hubIp ?? "Desconocido"} (Nodo ${d.rfNodeId})' : d.ip,
              onKindTap: () => _changeKind(context, d),
            ),
            Gap.l,

            // Vista específica por tipo
            _buildSpecializedControls(context, d, kind, names),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecializedControls(BuildContext context, Device d, String kind, List<String> names) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    switch (kind) {
      case 'Luz':
      case 'Dimmer':
        final brightness = (d.state['brightness'] as num?)?.toDouble() ?? (d.relays.first ? 100.0 : 0.0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Intensidad de Luz', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      Text('${brightness.toInt()}%', style: tt.titleMedium?.copyWith(color: cs.primary)),
                    ],
                  ),
                  Gap.m,
                  Slider(
                    value: brightness.clamp(0.0, 100.0),
                    min: 0,
                    max: 100,
                    divisions: 20,
                    label: '${brightness.toInt()}%',
                    onChanged: (val) {
                      context.read<AppState>().setDeviceAttribute(d, {'brightness': val.toInt(), 'on': val > 0});
                    },
                  ),
                ],
              ),
            ),
            Gap.m,
            Text('Modos Preestablecidos', style: tt.titleSmall),
            Gap.s,
            Row(
              children: [
                Expanded(child: _PresetBtn(label: 'Noche', icon: Icons.nightlight_round, brightness: 15, device: d)),
                Gap.s,
                Expanded(child: _PresetBtn(label: 'Lectura', icon: Icons.menu_book, brightness: 60, device: d)),
                Gap.s,
                Expanded(child: _PresetBtn(label: 'Máximo', icon: Icons.wb_sunny, brightness: 100, device: d)),
              ],
            ),
            Gap.l,
            _buildRelaysList(context, d, names),
          ],
        );

      case 'Sensor Temperatura':
        final temp = (d.state['temperature'] as num?)?.toDouble() ?? 24.5;
        final hum = (d.state['humidity'] as num?)?.toDouble() ?? 48.0;
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: AppCard(
                    child: Column(
                      children: [
                        const Icon(Icons.thermostat, size: 36, color: Colors.orangeAccent),
                        Gap.s,
                        Text('${temp.toStringAsFixed(1)} °C', style: tt.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                        Text('Temperatura', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ),
                Gap.m,
                Expanded(
                  child: AppCard(
                    child: Column(
                      children: [
                        const Icon(Icons.water_drop, size: 36, color: Colors.lightBlueAccent),
                        Gap.s,
                        Text('${hum.toStringAsFixed(0)} %', style: tt.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                        Text('Humedad Relativa', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ),
              ],
            ).animate().slideY(begin: 0.1, end: 0, duration: 300.ms),
            Gap.m,
            AppCard(
              child: Row(
                children: [
                  const Icon(Icons.signal_cellular_alt, color: Color(0xFF00E5A8)),
                  Gap.m,
                  Expanded(child: Text('Calidad de señal RF: ${d.rssi ?? -68} dBm')),
                  const Chip(label: Text('Estable')),
                ],
              ),
            ),
          ],
        );

      case 'Cámara':
        return Column(
          children: [
            Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.videocam, size: 48, color: cs.primary),
                      Gap.s,
                      const Text('Canal RF/IP En Vivo', style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(4)),
                      child: const Text('EN VIVO', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms),
            Gap.m,
            AppButton(label: 'Actualizar Captura', icon: Icons.refresh, onPressed: () => context.read<AppState>().refreshDevice(d)),
          ],
        );

      default:
        return _buildRelaysList(context, d, names);
    }
  }

  Widget _buildRelaysList(BuildContext context, Device d, List<String> names) {
    return Column(
      children: [
        for (var i = 0; i < d.relays.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: dvw.SwitchCard(
              title: names[i],
              value: d.relays[i],
              onChanged: busy
                  ? null
                  : (v) async {
                      setState(() => busy = true);
                      final ok = await context.read<AppState>().setRelay(d, i + 1, v);
                      if (!ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo cambiar el estado')));
                      }
                      if (mounted) setState(() => busy = false);
                    },
              onEdit: () async {
                final newName = await _promptText(context, title: 'Nombre del switch', initial: names[i]);
                if (newName != null && newName.trim().isNotEmpty && context.mounted) {
                  await context.read<AppState>().setSwitchName(d.id, i, newName.trim());
                  if (mounted) setState(() {});
                }
              },
            ),
          ),
      ],
    );
  }

  Future<void> _changeKind(BuildContext context, Device d) async {
    final app = context.read<AppState>();
    final current = d.kind ?? 'Interruptor';
    final kinds = ['Luz', 'Enchufe', 'Interruptor', 'Dimmer', 'Sensor Temperatura', 'Sensor Movimiento', 'Cámara', 'Persiana', 'Ventilador'];

    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).dialogTheme.backgroundColor,
      shape: Theme.of(context).dialogTheme.shape,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final k in kinds)
              ListTile(
                title: Text(k),
                trailing: current == k ? const Icon(Icons.check, color: Color(0xFF00E5A8)) : null,
                onTap: () => Navigator.pop(c, k),
              ),
          ],
        ),
      ),
    );
    if (selected != null && mounted) {
      await app.setDeviceKind(d.id, selected);
      setState(() {});
    }
  }
}

class _PresetBtn extends StatelessWidget {
  const _PresetBtn({required this.label, required this.icon, required this.brightness, required this.device});
  final String label;
  final IconData icon;
  final int brightness;
  final Device device;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        side: BorderSide(color: cs.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: () {
        context.read<AppState>().setDeviceAttribute(device, {'brightness': brightness, 'on': true});
      },
      icon: Icon(icon, size: 16, color: cs.primary),
      label: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}

Future<String?> _promptText(BuildContext context, {required String title, String? initial}) async {
  final ctrl = TextEditingController(text: initial ?? '');
  return showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'Escribe aquí...')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(c, ctrl.text), child: const Text('Guardar')),
      ],
    ),
  );
}
