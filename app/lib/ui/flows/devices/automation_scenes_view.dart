// =============================================================
// lib/ui/flows/devices/automation_scenes_view.dart
// Rutinas y Escenas Inteligentes M3 con ejecución real en el hogar
// =============================================================
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import 'package:bthapp/src/state/app_state.dart';

class AutomationScenesView extends StatefulWidget {
  const AutomationScenesView({super.key});

  @override
  State<AutomationScenesView> createState() => _AutomationScenesViewState();
}

class _AutomationScenesViewState extends State<AutomationScenesView> {
  String? runningScene;

  final List<Map<String, dynamic>> scenes = [
    {
      'id': 'night',
      'title': 'Modo Noche',
      'subtitle': 'Apaga todas las luces, deja las cámaras activas y ahorra energía en enchufes.',
      'icon': Icons.nightlight_round,
      'gradient': [Color(0xFF1A2980), Color(0xFF26D0CE)],
    },
    {
      'id': 'morning',
      'title': 'Buenos Días',
      'subtitle': 'Enciende las luces principales suavemente y activa los enchufes de cocina.',
      'icon': Icons.wb_sunny_rounded,
      'gradient': [Color(0xFFF3904F), Color(0xFF3B4371)],
    },
    {
      'id': 'cinema',
      'title': 'Modo Cine',
      'subtitle': 'Atenúa las luces de la sala al 15% para disfrutar tus películas sin reflejos.',
      'icon': Icons.movie_creation_outlined,
      'gradient': [Color(0xFF8A2387), Color(0xFFE94057)],
    },
    {
      'id': 'leave',
      'title': 'Salir de Casa',
      'subtitle': 'Apagado general instantáneo de todas las luces y enchufes para máxima seguridad.',
      'icon': Icons.lock_outline,
      'gradient': [Color(0xFFD31027), Color(0xFFEA384D)],
    },
  ];

  Future<void> _runScene(String sceneId, String title) async {
    setState(() => runningScene = sceneId);
    final app = context.read<AppState>();
    final devices = app.devices;

    for (final d in devices) {
      if (sceneId == 'night' || sceneId == 'leave') {
        if (d.kind == 'Luz' || d.kind == 'Dimmer' || d.kind == 'Enchufe' || d.kind == 'Interruptor') {
          await app.setRelay(d, 1, false);
          if (d.kind == 'Dimmer') await app.setDeviceAttribute(d, {'brightness': 0, 'on': false});
        }
      } else if (sceneId == 'morning') {
        if (d.kind == 'Luz' || d.kind == 'Dimmer') {
          await app.setRelay(d, 1, true);
          if (d.kind == 'Dimmer') await app.setDeviceAttribute(d, {'brightness': 80, 'on': true});
        }
      } else if (sceneId == 'cinema') {
        if (d.room == 'Sala') {
          if (d.kind == 'Dimmer' || d.kind == 'Luz') {
            await app.setDeviceAttribute(d, {'brightness': 15, 'on': true});
          }
        } else if (d.kind == 'Luz') {
          await app.setRelay(d, 1, false);
        }
      }
    }

    if (mounted) {
      setState(() => runningScene = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Color(0xFF00E5A8)),
              const SizedBox(width: 10),
              Text('Escena "$title" ejecutada con éxito en los dispositivos reales.'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escenas y Rutinas', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Automatizaciones Rápidas',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Ejecuta comandos coordinados en todos tus dispositivos Wi-Fi y RF con un toque.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          for (var i = 0; i < scenes.length; i++) ...[
            _SceneCard(
              scene: scenes[i],
              isRunning: runningScene == scenes[i]['id'],
              onTap: () => _runScene(scenes[i]['id'] as String, scenes[i]['title'] as String),
            ).animate().fadeIn(delay: Duration(milliseconds: i * 80)).slideX(begin: 0.05, end: 0),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

class _SceneCard extends StatelessWidget {
  const _SceneCard({required this.scene, required this.isRunning, required this.onTap});

  final Map<String, dynamic> scene;
  final bool isRunning;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final grads = scene['gradient'] as List<Color>;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: grads, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: grads.first.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: isRunning ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(scene['icon'] as IconData, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        scene['title'] as String,
                        style: tt.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        scene['subtitle'] as String,
                        style: tt.bodySmall?.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (isRunning)
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                  )
                else
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.play_arrow_rounded, color: grads.first, size: 28),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
