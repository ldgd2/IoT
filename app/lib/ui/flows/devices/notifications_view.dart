// =============================================================
// lib/ui/flows/devices/notifications_view.dart
// Vista de Centro de Notificaciones y Alertas de la Colmena
// =============================================================
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import 'package:bthapp/src/models/notification_item.dart';
import 'package:bthapp/src/state/app_state.dart';

class NotificationsView extends StatefulWidget {
  const NotificationsView({super.key});

  @override
  State<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<NotificationsView> {
  List<NotificationItem> logs = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => isLoading = true);
    final app = context.read<AppState>();
    final fetched = await app.fetchNotificationLogs();
    if (mounted) {
      setState(() {
        logs = fetched;
        isLoading = false;
      });
    }
  }

  Future<void> _clearLogs() async {
    final app = context.read<AppState>();
    final ok = await app.clearNotificationLogs();
    if (ok && mounted) {
      setState(() => logs.clear());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Historial de notificaciones limpiado.')),
      );
    }
  }

  Future<void> _sendTestPush() async {
    final app = context.read<AppState>();
    await app.sendTestNotification(
      'Alerta de Prueba',
      '¡Tu teléfono está conectado y sincronizado con tu Hogar Colmena!',
    );
    await Future.delayed(const Duration(milliseconds: 600));
    _loadLogs();
  }

  Color _getEventColor(String type, ColorScheme cs) {
    switch (type.toLowerCase()) {
      case 'connected':
        return const Color(0xFF00E5A8);
      case 'disconnected':
        return const Color(0xFFFF3B30);
      case 'skill':
        return const Color(0xFF9D4EDD);
      default:
        return cs.primary;
    }
  }

  IconData _getEventIcon(String type) {
    switch (type.toLowerCase()) {
      case 'connected':
        return Icons.link_rounded;
      case 'disconnected':
        return Icons.link_off_rounded;
      case 'skill':
        return Icons.auto_awesome;
      default:
        return Icons.notifications_active_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Centro de Alertas y Avisos', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.send_rounded),
            tooltip: 'Enviar Alerta de Prueba',
            onPressed: _sendTestPush,
          ),
          if (logs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Limpiar Historial',
              onPressed: _clearLogs,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadLogs,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : logs.isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(32),
                    children: [
                      const SizedBox(height: 60),
                      Icon(Icons.notifications_none_rounded, size: 80, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
                      const SizedBox(height: 20),
                      Text(
                        'No hay notificaciones recientes',
                        textAlign: TextAlign.center,
                        style: tt.titleMedium?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Aquí aparecerán las alertas cuando un dispositivo se vincule, se desconecte, o cuando una rutina inteligente active un aviso.',
                        textAlign: TextAlign.center,
                        style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
                      ),
                      const SizedBox(height: 30),
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: _sendTestPush,
                          icon: const Icon(Icons.send_rounded),
                          label: const Text('Enviar Alerta de Prueba'),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: logs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final item = logs[i];
                      final color = _getEventColor(item.eventType, cs);
                      final icon = _getEventIcon(item.eventType);

                      return Container(
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: color.withValues(alpha: 0.3)),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(icon, color: color, size: 24),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  item.eventType.toUpperCase(),
                                  style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.body, style: tt.bodyMedium),
                                const SizedBox(height: 4),
                                Text(
                                  item.ts.replaceFirst('T', ' ').split('.').first,
                                  style: tt.bodySmall?.copyWith(fontSize: 11, color: cs.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ).animate().fadeIn(delay: Duration(milliseconds: i * 50)).slideX(begin: 0.04, end: 0);
                    },
                  ),
      ),
    );
  }
}
