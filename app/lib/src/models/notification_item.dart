// =============================================================
// lib/src/models/notification_item.dart
// Modelo para historial y arrastre de ítems de notificación
// =============================================================

class NotificationItem {
  final int id;
  final String ts;
  final String title;
  final String body;
  final String eventType; // 'connected', 'disconnected', 'skill', 'info'
  final String deviceId;
  final String priority;

  const NotificationItem({
    required this.id,
    required this.ts,
    required this.title,
    required this.body,
    this.eventType = 'info',
    this.deviceId = '',
    this.priority = 'high',
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      ts: json['ts']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Alerta Colmena',
      body: json['body']?.toString() ?? '',
      eventType: json['event_type']?.toString() ?? json['type']?.toString() ?? 'info',
      deviceId: json['device_id']?.toString() ?? '',
      priority: json['priority']?.toString() ?? 'high',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ts': ts,
      'title': title,
      'body': body,
      'event_type': eventType,
      'device_id': deviceId,
      'priority': priority,
    };
  }
}
