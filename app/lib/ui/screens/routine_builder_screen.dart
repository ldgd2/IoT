import 'package:flutter/material.dart';
import '../widgets/buttons/scene_trigger_button.dart';
import '../widgets/buttons/primary_action_button.dart';

class RoutineBuilderScreen extends StatefulWidget {
  const RoutineBuilderScreen({super.key});

  @override
  State<RoutineBuilderScreen> createState() => _RoutineBuilderScreenState();
}

class _RoutineBuilderScreenState extends State<RoutineBuilderScreen> {
  final List<Map<String, dynamic>> _scenes = [
    {
      'title': 'Despertar Matutino',
      'subtitle': 'Abre persianas al 80% y sube termostato a 22°C',
      'icon': Icons.wb_sunny_outlined,
      'active': false,
    },
    {
      'title': 'Modo Cine en Casa',
      'subtitle': 'Atenúa iluminación de sala y enciende TV inteligente',
      'icon': Icons.movie_creation_outlined,
      'active': true,
    },
    {
      'title': 'Alerta de Intrusión Perimetral',
      'subtitle': 'Dispara sirenas RF y enciende focos exteriores a 100%',
      'icon': Icons.shield_outlined,
      'active': false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Escenas y Rutinas IoT', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Nueva Rutina'),
                onPressed: _showNewRoutineDialog,
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _scenes.length,
            itemBuilder: (ctx, idx) {
              final s = _scenes[idx];
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: SceneTriggerButton(
                  title: s['title'],
                  subtitle: s['subtitle'],
                  icon: s['icon'],
                  isActive: s['active'],
                  onTap: () {
                    setState(() {
                      for (var item in _scenes) {
                        item['active'] = false;
                      }
                      s['active'] = true;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Ejecutando escena en lote: ${s['title']}')),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showNewRoutineDialog() {
    final titleCtrl = TextEditingController();
    final subCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Creador de Automatización'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Nombre de la escena', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: subCtrl,
              decoration: const InputDecoration(labelText: 'Acciones de la rutina', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          PrimaryActionButton(
            label: 'Crear Rutina',
            onPressed: () {
              if (titleCtrl.text.trim().isNotEmpty) {
                setState(() {
                  _scenes.add({
                    'title': titleCtrl.text.trim(),
                    'subtitle': subCtrl.text.trim(),
                    'icon': Icons.auto_awesome,
                    'active': false,
                  });
                });
                Navigator.pop(ctx);
              }
            },
          ),
        ],
      ),
    );
  }
}
