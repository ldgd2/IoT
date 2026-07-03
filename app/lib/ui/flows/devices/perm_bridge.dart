// lib/src/services/perm_bridge.dart
import 'dart:io';
import 'package:flutter/services.dart';

class PermBridge {
  static const _ch = MethodChannel('perm.channel');

  /// ¿Ya tenemos el permiso necesario?  (NEARBY_WIFI_DEVICES o FINE_LOCATION)
  static Future<bool> hasWifiPermission() async {
    if (!Platform.isAndroid) return true;
    final ok = await _ch.invokeMethod<bool>('hasWifiPermission');
    return ok == true;
  }

  /// Dispara directamente el prompt nativo de Android para el permiso
  static Future<bool> requestWifiPermission() async {
    if (!Platform.isAndroid) return true;
    final ok = await _ch.invokeMethod<bool>('requestWifiPermission');
    return ok == true;
  }

  /// Muestra un diálogo propio y luego dispara el prompt nativo
  static Future<bool> requestWifiPermissionWithPrompt({
    String? title,
    String? message,
  }) async {
    if (!Platform.isAndroid) return true;
    final ok = await _ch.invokeMethod<bool>(
      'requestWifiPermissionWithPrompt',
      {'title': title, 'message': message},
    );
    return ok == true;
  }

  /// ¿El servicio de ubicación del sistema está activo?
  static Future<bool> isLocationServiceEnabled() async {
    if (!Platform.isAndroid) return true;
    final ok = await _ch.invokeMethod<bool>('isLocationServiceEnabled');
    return ok == true;
  }
}
