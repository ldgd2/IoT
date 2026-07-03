// lib/src/services/permission_service.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

class PermissionService {
  /// Pide SOLO el/los permisos necesarios y devuelve true si quedaron concedidos.
  /// NO bloquea por el estado del "servicio de ubicación".
  static Future<bool> ensureWifiPermission(BuildContext context) async {
    if (!Platform.isAndroid) return true;

    final sdk = (await DeviceInfoPlugin().androidInfo).version.sdkInt;

    if (sdk >= 33) {
      // Android 13+: NEARBY_WIFI_DEVICES
      final p = Permission.nearbyWifiDevices;
      final st = await p.status;
      if (st.isGranted || st.isLimited) return true;

      // Dispara SIEMPRE el prompt nativo si no está concedido
      final res = await p.request();
      if (res.isGranted || res.isLimited) return true;

      // Si está en "no preguntar de nuevo", ya no habrá prompt
      if (await p.isPermanentlyDenied) {
        _snack(context, 'Permiso de Wi-Fi cercano denegado permanentemente.');
      }
      return false;
    }

    // Android 10–12: ubicación para escanear Wi-Fi (algunos OEMs marcan uno u otro)
    final pWhen = Permission.locationWhenInUse;
    final pAny  = Permission.location;

    // ¿ya concedido?
    final stWhen = await pWhen.status;
    final stAny  = await pAny.status;
    if (stWhen.isGranted || stWhen.isLimited || stAny.isGranted || stAny.isLimited) return true;

    // Pedir AMBOS para forzar prompt nativo
    final r1 = await pWhen.request();
    final r2 = await pAny.request();

    if (r1.isGranted || r1.isLimited || r2.isGranted || r2.isLimited) return true;

    // Aquí no bloqueamos al usuario: sólo informamos
    final permDenied = await pWhen.isPermanentlyDenied || await pAny.isPermanentlyDenied;
    if (permDenied) {
      _snack(context, 'Permiso de ubicación denegado permanentemente.');
    } else {
      _snack(context, 'Permiso de ubicación no concedido.');
    }
    return false;
  }

  /// (Opcional) Chequeo informativo del "servicio de ubicación" para Android 10–12.
  /// NO bloquea el flujo. Úsalo si tu escaneo devuelve vacío y quieres sugerirlo.
  static Future<void> maybeHintLocationService(BuildContext context) async {
    if (!Platform.isAndroid) return;
    final sdk = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
    if (sdk >= 33) return; // en 13+ no aplica

    final status = await Permission.location.serviceStatus;
    if (status == ServiceStatus.disabled) {
      // solo informativo; no abrimos ajustes ni forzamos nada
      _snack(context, 'Sugerencia: activa la Ubicación del sistema para mejorar el escaneo Wi-Fi.');
    }
  }

  static void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
