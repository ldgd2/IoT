// lib/src/services/mdns_bridge.dart
import 'dart:io';
import 'package:flutter/services.dart';

class MdnsBridge {
  static const _ch = MethodChannel('mdns.channel');

  static Future<bool> acquire() async {
    if (!Platform.isAndroid) return true;
    final ok = await _ch.invokeMethod<bool>('acquire');
    return ok == true;
  }

  static Future<void> release() async {
    if (!Platform.isAndroid) return;
    await _ch.invokeMethod('release');
  }
}
