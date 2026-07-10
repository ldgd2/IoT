// =============================================================
// lib/ui/flows/devices/room_dashboard_view.dart
// Gestión inteligente por Habitaciones y Espacios con control maestro
// =============================================================
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import 'package:bthapp/src/models/device.dart';
import 'package:bthapp/src/state/app_state.dart';
import 'device_detail_view.dart';
import 'devices_widgets.dart' as dvw;

class RoomDashboardView extends StatelessWidget {
  const RoomDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final devices = app.devices;

    // Agrupar dispositivos por habitación
    final Map<String, List<Device>> roomMap = {};
    for (final d in devices) {
      final room = d.room ?? 'General';
      roomMap.putIfAbsent(room, () => []).add(d);
    }

    final rooms = roomMap.keys.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Espacios', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: rooms.isEmpty
          ? Center(
              child: Text(
                'Añade dispositivos y asígnalos a habitaciones para gestionarlos aquí.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: rooms.length,
              itemBuilder: (context, i) {
                final roomName = rooms[i];
                final roomDevices = roomMap[roomName]!;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _RoomCard(
                    roomName: roomName,
                    devices: roomDevices,
                  ),
                );
              },
            ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({required this.roomName, required this.devices});

  final String roomName;
  final List<Device> devices;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    // Calcular estadísticas
    final lights = devices.where((d) => d.kind == 'Luz' || d.kind == 'Dimmer').toList();
    final activeLights = lights.where((d) => d.relays.isNotEmpty && d.relays.first).length;
    
    // Promedio de temperatura si hay sensores
    final tempSensors = devices.where((d) => d.kind == 'Sensor Temperatura' && d.state['temperature'] != null);
    double? avgTemp;
    if (tempSensors.isNotEmpty) {
      final sum = tempSensors.fold(0.0, (prev, d) => prev + ((d.state['temperature'] as num).toDouble()));
      avgTemp = sum / tempSensors.length;
    }

    final allControlledActive = devices
        .where((d) => _supportsMasterToggle(d.kind))
        .any((d) => d.relays.isNotEmpty && d.relays.first);

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _showRoomDetailsSheet(context, roomName, devices),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(_getRoomIcon(roomName), color: cs.primary, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(roomName, style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                          Text('${devices.length} dispositivo${devices.length == 1 ? "" : "s"} vinculados',
                              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    // Interruptor Maestro de Habitación
                    Column(
                      children: [
                        Switch(
                          value: allControlledActive,
                          onChanged: (val) async {
                            final app = context.read<AppState>();
                            for (final d in devices) {
                              if (_supportsMasterToggle(d.kind)) {
                                await app.setRelay(d, 1, val);
                              }
                            }
                          },
                        ),
                        Text('Maestro', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _RoomStatBadge(
                      icon: Icons.lightbulb_outline,
                      label: 'Luces Activas',
                      value: '$activeLights/${lights.length}',
                      color: activeLights > 0 ? Colors.amberAccent : cs.onSurfaceVariant,
                    ),
                    Container(width: 1, height: 24, color: cs.outlineVariant),
                    _RoomStatBadge(
                      icon: Icons.thermostat_outlined,
                      label: 'Clima',
                      value: avgTemp != null ? '${avgTemp.toStringAsFixed(1)} °C' : 'N/D',
                      color: avgTemp != null ? Colors.orangeAccent : cs.onSurfaceVariant,
                    ),
                    Container(width: 1, height: 24, color: cs.outlineVariant),
                    _RoomStatBadge(
                      icon: Icons.hub_outlined,
                      label: 'Conexión',
                      value: '${devices.where((d) => d.online).length} online',
                      color: const Color(0xFF00E5A8),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0);
  }

  bool _supportsMasterToggle(String? kind) {
    return kind == 'Luz' || kind == 'Dimmer' || kind == 'Enchufe' || kind == 'Interruptor' || kind == 'Ventilador';
  }

  IconData _getRoomIcon(String room) {
    final low = room.toLowerCase();
    if (low.contains('sala') || low.contains('living')) return Icons.weekend_outlined;
    if (low.contains('dorm') || low.contains('cuarto')) return Icons.bed_outlined;
    if (low.contains('cocina') || low.contains('kitchen')) return Icons.kitchen_outlined;
    if (low.contains('baño') || low.contains('bath')) return Icons.bathtub_outlined;
    if (low.contains('exterior') || low.contains('jardín')) return Icons.deck_outlined;
    if (low.contains('garaje')) return Icons.garage_outlined;
    return Icons.room_preferences_outlined;
  }

  void _showRoomDetailsSheet(BuildContext context, String roomName, List<Device> devices) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          itemCount: devices.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'Dispositivos en $roomName',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              );
            }
            final d = devices[index - 1];
            final names = context.read<AppState>().getSwitchNames(d.id, d.relays.length);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: dvw.SmartDeviceCard(
                device: d,
                switchNames: names,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => DeviceDetailView(deviceId: d.id)));
                },
                onToggleRelay: (index1, val) =>
                    context.read<AppState>().setRelay(d, index1, val),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RoomStatBadge extends StatelessWidget {
  const _RoomStatBadge({required this.icon, required this.label, required this.value, required this.color});
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            Text(label, style: tt.bodySmall?.copyWith(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      ],
    );
  }
}
