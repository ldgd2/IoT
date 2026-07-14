// =============================================================
// lib/src/services/notification_storage_service.dart
// Almacenamiento local con caducidad diaria y enrutamiento inteligente
// =============================================================
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/notification_item.dart';
import '../../ui/flows/devices/home_shell.dart';
import '../../ui/flows/hubs/hub_management_view.dart';
import 'push_notification_service.dart';

class NotificationStorageService {
  static const _storageKey = 'local_notifications_history_v1';

  /// Guarda una nueva notificación localmente y elimina las mayores a 24 horas.
  static Future<void> saveNotification({
    required String title,
    required String body,
    required String eventType,
    String deviceId = '',
  }) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final items = await _loadAndPurge(sp);

      final newItem = NotificationItem(
        id: DateTime.now().millisecondsSinceEpoch,
        ts: DateTime.now().toIso8601String(),
        title: title.isNotEmpty ? title : 'Colmena IoT',
        body: body,
        eventType: eventType.isNotEmpty ? eventType : 'info',
        deviceId: deviceId,
        priority: 'high',
      );

      items.insert(0, newItem);

      // Limitar máximo a 100 por seguridad tras limpiar expiradas
      final toSave = items.take(100).map((e) => e.toJson()).toList();
      await sp.setString(_storageKey, jsonEncode(toSave));
    } catch (e) {
      debugPrint('[NotificationStorage] Error guardando notificación: $e');
    }
  }

  /// Obtiene la lista local de notificaciones purgadas (< 24 horas).
  static Future<List<NotificationItem>> getNotifications() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final items = await _loadAndPurge(sp);
      return items;
    } catch (_) {
      return [];
    }
  }

  /// Limpia todo el historial local.
  static Future<bool> clearNotifications() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.remove(_storageKey);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<List<NotificationItem>> _loadAndPurge(SharedPreferences sp) async {
    final raw = sp.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      final now = DateTime.now();
      final validItems = <NotificationItem>[];
      bool didPurge = false;

      for (final m in list) {
        final item = NotificationItem.fromJson(m);
        final date = DateTime.tryParse(item.ts) ?? now;
        if (now.difference(date).inHours >= 24) {
          didPurge = true;
        } else {
          validItems.add(item);
        }
      }

      if (didPurge) {
        final toSave = validItems.map((e) => e.toJson()).toList();
        await sp.setString(_storageKey, jsonEncode(toSave));
      }

      return validItems;
    } catch (_) {
      return [];
    }
  }

  /// Enruta al usuario según el tipo o contenido de la notificación.
  static void routeFromNotification({
    required String eventType,
    required String title,
    required String body,
    BuildContext? context,
  }) {
    final nav = context != null
        ? Navigator.of(context)
        : PushNotificationService.navigatorKey.currentState;
    if (nav == null) return;

    final type = eventType.toLowerCase();
    final t = title.toLowerCase();
    final b = body.toLowerCase();

    // 1. Hubs (registro, vinculación, estado)
    if (type.contains('hub') || t.contains('hub') || b.contains('hub')) {
      if (context != null) {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HubManagementView()));
      } else {
        nav.push(MaterialPageRoute(builder: (_) => const HubManagementView()));
      }
      return;
    }

    // 2. Skills / Escenas / Rutinas
    if (type.contains('skill') ||
        type.contains('automation') ||
        t.contains('rutina') ||
        t.contains('escena') ||
        t.contains('skill') ||
        b.contains('rutina')) {
      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeShell(initialTab: 2)),
        (route) => false,
      );
      return;
    }

    // 3. Salas / Habitaciones
    if (type.contains('room') ||
        type.contains('space') ||
        t.contains('sala') ||
        t.contains('habitación') ||
        b.contains('sala')) {
      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeShell(initialTab: 1)),
        (route) => false,
      );
      return;
    }

    // 4. Diagnóstico / Red
    if (type.contains('network') ||
        type.contains('health') ||
        t.contains('red') ||
        t.contains('wifi') ||
        t.contains('rssi')) {
      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeShell(initialTab: 3)),
        (route) => false,
      );
      return;
    }

    // 5. Dispositivos (vinculación, registro, conectado, desconectado, relé)
    if (type.contains('device') ||
        type.contains('connected') ||
        type.contains('disconnected') ||
        t.contains('dispositivo') ||
        b.contains('dispositivo') ||
        t.contains('vincul') ||
        b.contains('vincul')) {
      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeShell(initialTab: 0)),
        (route) => false,
      );
      return;
    }

    // 6. Por defecto, navegar al Centro de Notificaciones (sólo si no estamos ya allí)
    if (context == null || ModalRoute.of(context)?.settings.name != '/notificaciones') {
      nav.pushNamed('/notificaciones');
    }
  }
}
