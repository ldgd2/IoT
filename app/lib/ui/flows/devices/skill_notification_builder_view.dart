// =============================================================
// lib/ui/flows/devices/skill_notification_builder_view.dart
// Constructor Drag & Drop de Skills y Notificaciones Push Personalizadas
// =============================================================
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import 'package:bthapp/src/state/app_state.dart';

class SkillNotificationBuilderView extends StatefulWidget {
  const SkillNotificationBuilderView({super.key});

  @override
  State<SkillNotificationBuilderView> createState() => _SkillNotificationBuilderViewState();
}

class _SkillNotificationBuilderViewState extends State<SkillNotificationBuilderView> {
  final nameCtrl = TextEditingController(text: 'Alerta Inteligente Colmena');
  
  // Lista de disparadores y acciones en el canvas (AST)
  List<Map<String, dynamic>> conditions = [
    {
      'type': 'dev_state',
      'device': 'dev_sensor_01',
      'operator': '==',
      'value': 'ON',
      'label': 'Cuando Sensor de Movimiento detecta presencia',
    }
  ];

  List<Map<String, dynamic>> actions = [];

  // Controladores de notificación personalizada cuando se arrastra/añade el ítem
  final notifTitleCtrl = TextEditingController(text: 'Alerta de Seguridad');
  final notifBodyCtrl = TextEditingController(text: '¡Se ha activado el sensor de movimiento en casa!');
  String notifPriority = 'high';

  @override
  void dispose() {
    nameCtrl.dispose();
    notifTitleCtrl.dispose();
    notifBodyCtrl.dispose();
    super.dispose();
  }

  void _addCondition() {
    setState(() {
      conditions.add({
        'type': 'dev_state',
        'device': 'dev_temp_01',
        'operator': '>',
        'value': '28',
        'label': 'Si Sensor de Temperatura supera los 28°C',
      });
    });
  }

  void _addDeviceAction() {
    setState(() {
      actions.add({
        'type': 'action_device',
        'device': 'dev_light_01',
        'cmd': 'ON',
        'label': 'Encender Luz Principal de Alarma',
      });
    });
  }

  void _addNotificationBlock() {
    // Si no está ya añadido, lo añadimos como ítem personalizable
    if (actions.any((a) => a['type'] == 'action_notify')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ya tienes una alerta al teléfono activa en esta automatización.')),
      );
      return;
    }
    setState(() {
      actions.add({
        'type': 'action_notify',
        'title': notifTitleCtrl.text,
        'message': notifBodyCtrl.text,
        'priority': notifPriority,
        'label': 'Enviar alerta personalizada al teléfono',
      });
    });
  }

  Future<void> _saveAndDeploySkill() async {
    final name = nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, dale un nombre a tu nueva rutina automática.')),
      );
      return;
    }

    // Si hay bloques action_notify, actualizamos sus campos con lo que el usuario personalizó
    for (var a in actions) {
      if (a['type'] == 'action_notify') {
        a['title'] = notifTitleCtrl.text.trim();
        a['message'] = notifBodyCtrl.text.trim();
        a['priority'] = notifPriority;
      }
    }

    final ast = {
      'conditions': conditions,
      'actions': actions,
      'logic': 'and',
    };

    final app = context.read<AppState>();
    final ok = await app.saveSkill({
      'name': name,
      'ast': ast,
      'is_active': 1,
    });

    if (mounted) {
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF00E5A8)),
                const SizedBox(width: 10),
                Expanded(child: Text('Rutina automática guardada y activada con éxito en tu hogar.')),
              ],
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar la rutina: verifica tu conexión con el hogar.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final hasNotificationAction = actions.any((a) => a['type'] == 'action_notify');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear Rutina y Alerta Automática', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Nombre de tu Rutina o Automatización',
                  style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    hintText: 'ej. Alerta de Seguridad Nocturna',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    filled: true,
                    fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 24),

                // SECCIÓN 1: DISPARADORES
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('1. ¿Cuándo debe activarse?', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    TextButton.icon(
                      onPressed: _addCondition,
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: const Text('Añadir Disparador'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < conditions.length; i++)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.bolt, color: cs.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            conditions[i]['label'] ?? 'Condición o Disparador',
                            style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => setState(() => conditions.removeAt(i)),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),

                // SECCIÓN 2: ACCIONES EN EL CANVAS
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('2. ¿Qué acciones realizar?', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    TextButton.icon(
                      onPressed: _addDeviceAction,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Acción Dispositivo'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (actions.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4), style: BorderStyle.solid),
                    ),
                    child: Center(
                      child: Text(
                        'Arrastra o toca el botón inferior para añadir alertas personalizadas a tu teléfono o encender/apagar dispositivos de tu hogar.',
                        textAlign: TextAlign.center,
                        style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ),
                  ),

                for (var i = 0; i < actions.length; i++) ...[
                  if (actions[i]['type'] == 'action_notify') ...[
                    // ÍTEM DE NOTIFICACIÓN PERSONALIZABLE
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [const Color(0xFF6A11CB).withValues(alpha: 0.85), const Color(0xFF2575FC).withValues(alpha: 0.85)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF6A11CB).withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.notifications_active, color: Colors.white, size: 24),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Alerta Automática al Teléfono (Activa)',
                                  style: tt.titleSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.white),
                                onPressed: () => setState(() => actions.removeAt(i)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text('Título de la Alerta en tu Teléfono:', style: tt.labelSmall?.copyWith(color: Colors.white70)),
                          const SizedBox(height: 4),
                          TextField(
                            controller: notifTitleCtrl,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.black.withValues(alpha: 0.25),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text('Mensaje / Detalle de la Alerta:', style: tt.labelSmall?.copyWith(color: Colors.white70)),
                          const SizedBox(height: 4),
                          TextField(
                            controller: notifBodyCtrl,
                            style: const TextStyle(color: Colors.white),
                            maxLines: 2,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.black.withValues(alpha: 0.25),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Text('Prioridad de Alerta: ', style: tt.labelSmall?.copyWith(color: Colors.white70)),
                              const SizedBox(width: 8),
                              DropdownButton<String>(
                                value: notifPriority,
                                dropdownColor: const Color(0xFF1E1E2E),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                underline: const SizedBox(),
                                items: const [
                                  DropdownMenuItem(value: 'high', child: Text('Alta (Vibración y Sonido)')),
                                  DropdownMenuItem(value: 'normal', child: Text('Normal (Estándar)')),
                                  DropdownMenuItem(value: 'low', child: Text('Silenciosa')),
                                ],
                                onChanged: (val) {
                                  if (val != null) setState(() => notifPriority = val);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ).animate().scale(duration: 250.ms, curve: Curves.easeOutBack),
                  ] else ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.touch_app_outlined),
                          const SizedBox(width: 12),
                          Expanded(child: Text(actions[i]['label'] ?? 'Acción de Dispositivo en Hogar', style: tt.bodyMedium)),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () => setState(() => actions.removeAt(i)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),

          // PANEL INFERIOR: CAJÓN DE ARRASTRE DE ÍTEMS
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.7),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Arrastra o toca el botón para personalizar una alerta a tu teléfono:',
                  style: tt.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Draggable<String>(
                        data: 'action_notify',
                        onDragCompleted: _addNotificationBlock,
                        feedback: Material(
                          color: Colors.transparent,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6A11CB),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10)],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.notifications_active, color: Colors.white),
                                SizedBox(width: 8),
                                Text('Alerta al Teléfono', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _addNotificationBlock,
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: hasNotificationAction
                                      ? [Colors.grey.shade700, Colors.grey.shade800]
                                      : [const Color(0xFF6A11CB), const Color(0xFF2575FC)],
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(hasNotificationAction ? Icons.check_circle : Icons.pan_tool_alt_outlined, color: Colors.white),
                                  const SizedBox(width: 8),
                                  Text(
                                    hasNotificationAction ? 'Alerta al Teléfono Configurada' : 'Añadir Alerta al Teléfono',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 6,
                    ),
                    icon: const Icon(Icons.save_rounded, size: 24),
                    label: const Text('Guardar y Activar Rutina en tu Hogar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    onPressed: _saveAndDeploySkill,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
