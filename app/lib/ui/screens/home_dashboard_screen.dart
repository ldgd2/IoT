import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bthapp/src/state/app_state.dart';
import 'package:bthapp/src/models/device.dart';
import '../widgets/cards/environment_summary_card.dart';
import '../widgets/buttons/scene_trigger_button.dart';
import 'package:bthapp/ui/flows/provision/add_device_sheet.dart';
import 'device_detail_screen.dart';

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  List<Map<String, dynamic>> _scenes = [];
  bool _loadingScenes = true;
  int? _activeSceneId;

  @override
  void initState() {
    super.initState();
    _loadSkills();
  }

  Future<void> _loadSkills() async {
    final app = context.read<AppState>();
    final list = await app.fetchSkills();
    if (mounted) {
      setState(() {
        _scenes = list;
        _loadingScenes = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final devices = app.devices;
    final cs = Theme.of(context).colorScheme;

    // Obtener promedio de temperatura / humedad real de sensores
    double? avgTemp;
    double? avgHum;
    int climateSensorCount = 0;

    for (final d in devices) {
      if (d.kind == 'Sensor Temperatura' || d.state['temperature'] != null || d.state['humidity'] != null) {
        final t = (d.state['temperature'] as num?)?.toDouble();
        final h = (d.state['humidity'] as num?)?.toDouble();
        if (t != null || h != null) {
          climateSensorCount++;
          avgTemp = (avgTemp ?? 0) + (t ?? 24.0);
          avgHum = (avgHum ?? 0) + (h ?? 50.0);
        }
      }
    }

    if (climateSensorCount > 0) {
      avgTemp = (avgTemp! / climateSensorCount);
      avgHum = (avgHum! / climateSensorCount);
    }

    return RefreshIndicator(
      onRefresh: () async {
        await app.refreshAll(parallel: true);
        await _loadSkills();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Resumen Ambiental',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Vincular nuevo dispositivo',
                  onPressed: () => AddDeviceSheet.show(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            EnvironmentSummaryCard(
              temperature: avgTemp ?? 24.0,
              humidity: avgHum ?? 50.0,
              roomName: climateSensorCount > 0
                  ? 'Promedio General ($climateSensorCount sensores)'
                  : 'Estado Ambiental Base',
              onTap: () {
                app.refreshAll(parallel: true);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sincronizando lecturas ambientales con sensores en red...')),
                );
              },
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Escenas y Rutinas Activas',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  tooltip: 'Refrescar escenas',
                  onPressed: _loadSkills,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_loadingScenes)
              const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
            else if (_scenes.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome_outlined, color: cs.primary),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'No hay escenas configuradas en el Hub central. Crea una rutina desde el módulo de automatizaciones.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _scenes.length,
                itemBuilder: (ctx, idx) {
                  final s = _scenes[idx];
                  final skillId = (s['id'] as num?)?.toInt() ?? -1;
                  final name = s['name']?.toString() ?? 'Escena';
                  final desc = s['description']?.toString() ?? 'Rutina automatizada';
                  final isActive = _activeSceneId == skillId;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SceneTriggerButton(
                      title: name,
                      subtitle: desc,
                      icon: Icons.auto_awesome,
                      isActive: isActive,
                      onTap: () async {
                        setState(() => _activeSceneId = skillId);
                        final ok = await app.executeSkill(skillId);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(ok
                                  ? 'Escena "$name" ejecutada exitosamente en el Hub.'
                                  : 'No se pudo ejecutar la escena "$name". Verifica la conexión del Hub.'),
                            ),
                          );
                        }
                      },
                    ),
                  );
                },
              ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Dispositivos y Luces del Hogar',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.sync),
                  tooltip: 'Actualizar estado de dispositivos',
                  onPressed: () => app.refreshAll(parallel: true),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (devices.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.devices_other, size: 48, color: cs.onSurfaceVariant),
                        const SizedBox(height: 12),
                        const Text(
                          'No hay dispositivos vinculados aún',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Añade interruptores, luces, enchufes o sensores en tu red Wi-Fi o Hub RF.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () => AddDeviceSheet.show(context),
                          icon: const Icon(Icons.add),
                          label: const Text('Vincular Dispositivo'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: devices.length,
                itemBuilder: (ctx, i) {
                  final d = devices[i];
                  final names = app.getSwitchNames(d.id, d.relays.length);
                  return _buildDeviceControlBlock(context, d, names, cs);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceControlBlock(
    BuildContext context,
    Device d,
    List<String> switchNames,
    ColorScheme cs,
  ) {
    final app = context.read<AppState>();
    final relays = d.relays;
    final isOnline = d.online;

    // Si es un dispositivo con múltiples interruptores/relés (o con al menos 1 relé)
    if (relays.isNotEmpty) {
      return Card(
        margin: const EdgeInsets.only(bottom: 14),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _openDeviceDetail(d.id),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            _getKindIcon(d.kind),
                            color: isOnline ? const Color(0xFF00E5A8) : cs.onSurfaceVariant,
                            size: 26,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  d.alias ?? d.id,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${d.kind ?? "Interruptor"} - ${d.room ?? "General"} (${d.isRf ? "Hub RF" : "Wi-Fi"})',
                                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isOnline ? const Color(0xFF00E5A8).withValues(alpha: 0.15) : cs.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isOnline ? 'En Línea' : 'Desconectado',
                        style: TextStyle(
                          color: isOnline ? const Color(0xFF00E5A8) : cs.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: relays.length == 1 ? 1 : 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: relays.length == 1 ? 4.5 : 2.6,
                  ),
                  itemCount: relays.length,
                  itemBuilder: (context, idx) {
                    final isOn = relays[idx];
                    final swName = idx < switchNames.length ? switchNames[idx] : 'Canal ${idx + 1}';
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isOn ? cs.primary.withValues(alpha: 0.15) : cs.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isOn ? cs.primary : cs.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  swName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: isOn ? cs.primary : cs.onSurface,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  isOn ? 'Encendido' : 'Apagado',
                                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: isOn,
                            onChanged: (val) async {
                              final ok = await app.setRelay(d, idx + 1, val);
                              if (!ok && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Error de comunicación con el hardware.')),
                                );
                              }
                            },
                            activeThumbColor: cs.primary,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Si no tiene relés (por ej. Sensor de temperatura pura o cámara)
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _openDeviceDetail(d.id),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(_getKindIcon(d.kind), color: cs.primary, size: 26),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.alias ?? d.id,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        '${d.kind ?? "Sensor"} - ${d.room ?? "General"}',
                        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getKindIcon(String? kind) {
    if (kind == null) return Icons.device_hub;
    if (kind.contains('Luz') || kind.contains('Dimmer')) return Icons.lightbulb_outline;
    if (kind.contains('Enchufe')) return Icons.power_outlined;
    if (kind.contains('Temperatura') || kind.contains('Clima')) return Icons.thermostat_outlined;
    if (kind.contains('Cámara')) return Icons.videocam_outlined;
    if (kind.contains('Ventilador')) return Icons.air;
    return Icons.toggle_on_outlined;
  }

  void _openDeviceDetail(String deviceId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DeviceDetailScreen(deviceId: deviceId),
      ),
    );
  }
}
