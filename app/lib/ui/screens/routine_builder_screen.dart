import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bthapp/src/state/app_state.dart';
import 'package:bthapp/src/models/device.dart';
import '../widgets/buttons/scene_trigger_button.dart';
import '../widgets/buttons/primary_action_button.dart';

class RoutineBuilderScreen extends StatefulWidget {
  const RoutineBuilderScreen({super.key});

  @override
  State<RoutineBuilderScreen> createState() => _RoutineBuilderScreenState();
}

class _RoutineBuilderScreenState extends State<RoutineBuilderScreen> {
  List<Map<String, dynamic>> _skills = [];
  bool _loading = true;
  int? _activeId;

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
        _skills = list;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Escenas y Automatizaciones Reales', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Sincronizar con Hub',
                    onPressed: _loadSkills,
                  ),
                  FilledButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Nueva Rutina'),
                    onPressed: () => _showNewRoutineDialog(context, app.devices),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
          else if (_skills.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome_motion, size: 48, color: cs.onSurfaceVariant),
                      const SizedBox(height: 12),
                      const Text('No hay automatizaciones registradas en el Hub', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 6),
                      Text('Crea tu primera escena para controlar múltiples relés, luces o enchufes con un solo toque.', textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => _showNewRoutineDialog(context, app.devices),
                        icon: const Icon(Icons.add),
                        label: const Text('Crear Escena Real'),
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
              itemCount: _skills.length,
              itemBuilder: (ctx, idx) {
                final s = _skills[idx];
                final skillId = (s['id'] as num?)?.toInt() ?? -1;
                final name = s['name']?.toString() ?? 'Escena Sin Nombre';
                final desc = s['description']?.toString() ?? 'Rutina configurada en servidor central';
                final isActive = _activeId == skillId;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          Expanded(
                            child: SceneTriggerButton(
                              title: name,
                              subtitle: desc,
                              icon: Icons.auto_awesome,
                              isActive: isActive,
                              onTap: () async {
                                setState(() => _activeId = skillId);
                                final ok = await app.executeSkill(skillId);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(ok
                                          ? 'Escena "$name" ejecutada en los dispositivos.'
                                          : 'No se pudo comunicar con el Hub para ejecutar la escena.'),
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline, color: cs.error),
                            tooltip: 'Eliminar rutina',
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (c) => AlertDialog(
                                  title: const Text('Confirmar Eliminación'),
                                  content: Text('¿Deseas eliminar la escena "$name" del servidor Hub?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
                                    FilledButton(
                                      style: FilledButton.styleFrom(backgroundColor: cs.error),
                                      onPressed: () => Navigator.pop(c, true),
                                      child: const Text('Eliminar'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true && context.mounted) {
                                await app.deleteSkill(skillId);
                                _loadSkills();
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  void _showNewRoutineDialog(BuildContext context, List<Device> devices) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    Device? selectedDevice = devices.isNotEmpty ? devices.first : null;
    int selectedRelay = 1;
    bool targetState = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Creador de Rutina Real'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre de la escena', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Descripción corta', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                const Text('Dispositivo objetivo principal:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                if (devices.isEmpty)
                  const Text('No hay dispositivos disponibles para vincular.')
                else
                  DropdownButtonFormField<Device>(
                    initialValue: selectedDevice,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    items: devices.map((d) => DropdownMenuItem(value: d, child: Text(d.alias ?? d.id))).toList(),
                    onChanged: (v) => setDialogState(() => selectedDevice = v),
                  ),
                const SizedBox(height: 12),
                if (selectedDevice != null && selectedDevice!.relays.isNotEmpty) ...[
                  DropdownButtonFormField<int>(
                    initialValue: selectedRelay,
                    decoration: const InputDecoration(labelText: 'Canal o relé de conmutación', border: OutlineInputBorder()),
                    items: List.generate(
                      selectedDevice!.relays.length,
                      (i) => DropdownMenuItem(value: i + 1, child: Text('Canal ${i + 1}')),
                    ),
                    onChanged: (v) {
                      if (v != null) setDialogState(() => selectedRelay = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<bool>(
                    initialValue: targetState,
                    decoration: const InputDecoration(labelText: 'Acción al ejecutar', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: true, child: Text('Encender (ON)')),
                      DropdownMenuItem(value: false, child: Text('Apagar (OFF)')),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => targetState = v);
                    },
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            PrimaryActionButton(
              label: 'Guardar Rutina',
              onPressed: () async {
                final title = titleCtrl.text.trim();
                if (title.isNotEmpty) {
                  final app = context.read<AppState>();
                  final skillData = {
                    'name': title,
                    'description': descCtrl.text.trim().isEmpty ? 'Escena creada desde la app' : descCtrl.text.trim(),
                    'is_active': true,
                    'actions': selectedDevice != null
                        ? [
                            {
                              'device_id': selectedDevice!.id,
                              'relay': selectedRelay,
                              'state': targetState ? 'ON' : 'OFF',
                            }
                          ]
                        : [],
                  };
                  final ok = await app.saveSkill(skillData);
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    if (ok) {
                      _loadSkills();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No se pudo guardar la rutina en el servidor Hub.')),
                      );
                    }
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
