// =============================================================
// lib/ui/flows/devices/automation_scenes_view.dart
// Rutinas y Escenas Inteligentes M3 con ejecución real en el hogar
// =============================================================
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import 'package:bthapp/src/state/app_state.dart';
import 'skill_notification_builder_view.dart';

class AutomationScenesView extends StatefulWidget {
  const AutomationScenesView({super.key});

  @override
  State<AutomationScenesView> createState() => _AutomationScenesViewState();
}

class _AutomationScenesViewState extends State<AutomationScenesView> {
  String? runningScene;
  List<Map<String, dynamic>> hubSkills = [];
  bool isLoadingSkills = true;

  @override
  void initState() {
    super.initState();
    _loadHubSkills();
  }

  Future<void> _loadHubSkills() async {
    setState(() => isLoadingSkills = true);
    final app = context.read<AppState>();
    final list = await app.fetchSkills();
    if (mounted) {
      setState(() {
        hubSkills = list;
        isLoadingSkills = false;
      });
    }
  }

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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Escenas y Rutinas', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHubSkills,
            tooltip: 'Sincronizar Skills',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadHubSkills,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // TARJETA PRINCIPAL PARA CREAR SKILLS / NOTIFICACIONES
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF6A11CB), const Color(0xFF2575FC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF6A11CB).withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 8)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: Colors.white, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Rutinas y Alertas Inteligentes',
                          style: tt.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Crea reglas inteligentes y arrastra ítems de notificación para recibir alertas instantáneas cuando un sensor se active o un dispositivo cambie de estado.',
                    style: tt.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.85)),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF6A11CB),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                      ),
                      icon: const Icon(Icons.add_circle_outline, size: 22),
                      label: const Text('Crear Rutina y Alerta Automática', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        final res = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SkillNotificationBuilderView()),
                        );
                        if (res == true) _loadHubSkills();
                      },
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn().scale(duration: 300.ms, curve: Curves.easeOutBack),
            const SizedBox(height: 24),

            // SECCIÓN DE SKILLS GUARDADAS EN EL HUB
            if (hubSkills.isNotEmpty) ...[
              Text(
                'Rutinas Activas en tu Hogar',
                style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Estas rutinas se ejecutan de forma autónoma día y noche en tu Central Colmena.',
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < hubSkills.length; i++) ...[
                Card(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: cs.primary.withValues(alpha: 0.2),
                      child: Icon(Icons.hub, color: cs.primary),
                    ),
                    title: Text(hubSkills[i]['name']?.toString() ?? 'Skill Colmena', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    subtitle: Text('ID #${hubSkills[i]['id']} | Estado: ${hubSkills[i]['is_active'] == 1 ? 'Activa' : 'Pausada'}', style: tt.bodySmall),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.play_circle_fill, color: Color(0xFF00E5A8), size: 28),
                          tooltip: 'Ejecutar Ahora',
                          onPressed: () async {
                            final id = int.tryParse(hubSkills[i]['id']?.toString() ?? '0') ?? 0;
                            final ok = await context.read<AppState>().executeSkill(id);
                            if (ok && mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Skill "${hubSkills[i]['name']}" ejecutada.')),
                              );
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          tooltip: 'Eliminar Skill',
                          onPressed: () async {
                            final id = int.tryParse(hubSkills[i]['id']?.toString() ?? '0') ?? 0;
                            final ok = await context.read<AppState>().deleteSkill(id);
                            if (ok) _loadHubSkills();
                          },
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(delay: Duration(milliseconds: i * 60)).slideX(begin: 0.04, end: 0),
              ],
              const SizedBox(height: 24),
            ],

            Text(
              'Escenas Rápidas',
              style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Ejecuta comandos coordinados en todos tus dispositivos Wi-Fi y RF con un toque.',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
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
