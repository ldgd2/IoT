// lib/ui/flows/provision/provision_actions.dart
import 'dart:async';
import 'package:network_info_plus/network_info_plus.dart' show NetworkInfo;
import 'package:wifi_iot/wifi_iot.dart';

import '../../../src/services/api_client.dart';
import '../../../src/services/mdns_resolver.dart';

class ProvisionActions {
  static String _normSsid(String? s) =>
      (s ?? '').replaceAll('"', '').trim();

  // ---------- UTILIDADES DE RED ----------
  static Future<String?> currentSsid() async {
    try {
      final s = await WiFiForIoTPlugin.getSSID();
      if (s == null) return null;
      return s.replaceAll('"', '');
    } catch (_) {
      return null;
    }
  }

  /// Gateway REAL si se puede leer; si no, null (NO devolver por defecto aquí)
  static Future<String?> _currentGatewayIp() async {
    try {
      final info = NetworkInfo();
      final gw = await info.getWifiGatewayIP();
      if (gw != null && gw.isNotEmpty) return gw;
    } catch (_) {}
    return null;
  }

  /// Gateway con fallback para usos puntuales.
  static Future<String> gatewayIpOrDefault() async {
    final gw = await _currentGatewayIp();
    return gw ?? '192.168.4.1';
  }

  /// Verifica conexión al AP del ESP sin depender del SSID.
  /// 1) Si SSID está disponible y parece “ESP…”, listo.
  /// 2) Si no, intenta /connection?ready=1 o /ping en el gateway REAL.
  /// 3) Si no hay gateway, prueba 192.168.4.1 pero exige HTTP OK.
  static Future<bool> isConnectedToEspAp() async {
    // 1) por SSID (si se puede)
    try {
      final ssid = await currentSsid();
      if (ssid != null) {
        final low = ssid.toLowerCase();
        if (low.startsWith('esp-setup') || low.contains('esp')) return true;
      }
    } catch (_) {}

    // 2) por gateway REAL
    final gw = await _currentGatewayIp();
    if (gw != null) {
      final okConn = await ApiClient.checkConnection(host: gw);
      if (okConn) return true;
      final okPing = await ApiClient(gw).ping();
      if (okPing) return true;
      return false;
    }

    // 3) último intento: 192.168.4.1 (solo si responde)
    if (await ApiClient.checkConnection(host: '192.168.4.1')) return true;
    if (await ApiClient('192.168.4.1').ping()) return true;

    return false;
  }

  // ---------- FLUJO VÍA GATEWAY ----------
  static Future<List<String>> getScanFromDevice() async {
  final gw = await gatewayIpOrDefault();
  final nets = await ApiClient.scanSsids(host: gw) ?? <String>[];
  final cleaned = nets.where((e) => e.isNotEmpty).toList()..sort(); // sin trim
  return cleaned;
}



 static Future<Map<String, dynamic>?> submitProvisionAtGateway({
  required String ssid,
  required String pass,
  required String mdns,
}) async {
  final List<String> candidates = <String>[];

  // 1) SIEMPRE intentar el AP del ESP primero
  candidates.add('192.168.4.1');

  // 2) Luego, el gateway real (por si el ESP expone /provision también en STA)
  final gw = await _currentGatewayIp();
  if (gw != null && gw.isNotEmpty && !candidates.contains(gw)) {
    candidates.add(gw);
  }

  for (final host in candidates) {
    final resp = await ApiClient.provision(
      ssid: ssid,
      pass: pass,
      mdns: mdns,
      host: host,
    );
    if (resp != null) return resp;
  }
  return null;
}




  static Future<bool> connectPhoneToHome({
    required String ssid,
    required String pass,
  }) async {
    try {
      final ok = await WiFiForIoTPlugin.connect(
        ssid,
        password: pass,
        security: NetworkSecurity.WPA,
        isHidden: false,
        joinOnce: true,
        withInternet: true,
      );
      return ok == true;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> discoverDeviceIp(String mdnsHost) async {
    final ip = await MdnsResolver
        .resolveHost(mdnsHost)
        .timeout(const Duration(seconds: 5), onTimeout: () => null);
    if (ip == null) return null;
    final ok = await ApiClient(ip).ping();
    return ok ? ip : null;
  }

  static Future<bool> verifyEspApReady() async {
    final gw = await gatewayIpOrDefault();
    return await ApiClient.checkConnection(host: gw);
  }

  static Future<bool> connectToEspAp(String ssid, {String password = 'config123'}) async {
    try {
      final ok = await WiFiForIoTPlugin.connect(
        ssid,
        password: password,
        security: NetworkSecurity.WPA, // ajusta si usas otra seguridad en tu AP
        isHidden: false,
        joinOnce: true,
        withInternet: false,
      );
      return ok == true;
    } catch (_) {
      return false;
    }
  }

  // Espera a que el teléfono realmente esté en `ssid`
static Future<bool> waitForSsid({
    required String ssid,
    Duration timeout = const Duration(seconds: 75),
    Duration interval = const Duration(milliseconds: 800),
  }) async {
    final target = _normSsid(ssid);
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      final cur = _normSsid(await currentSsid());
      if (cur == target) return true;
      await Future<void>.delayed(interval);
    }
    return false;
  }

// Descubre por mDNS con reintentos
static Future<String?> discoverDeviceIpWithRetries(
  String mdnsHost, {
  int tries = 8,
  Duration delay = const Duration(seconds: 2),
}) async {
  for (var i = 0; i < tries; i++) {
    final ip = await discoverDeviceIp(mdnsHost);
    if (ip != null) return ip;
    await Future<void>.delayed(delay);
  }
  return null;
}

 static Future<String?> discoverAfterProvision({
  required String mdns,
  String? staIpHint,
  Duration timeout = const Duration(seconds: 45),
}) async {
  final deadline = DateTime.now().add(timeout);
  final host = mdns.endsWith('.local') ? mdns : '$mdns.local';

  Future<String?> _tryMdnsThenStatus() async {
    // 1) Ping por hostname
    final ok = await ApiClient(host).ping();
    if (!ok) return null;

    // 2) Si responde, pedimos /status para obtener IP real del firmware
    final st = await ApiClient(host).status();
    final ip = (st != null ? (st['ip'] as String?) : null)?.trim();
    if (ip != null && ip.isNotEmpty) return ip;

    // 3) Si /status no dio IP, resolvemos mDNS
    final resolved = await MdnsResolver.resolveHost(host);
    return resolved; // puede ser null
  }

  while (DateTime.now().isBefore(deadline)) {
    // mDNS → /status
    final ip1 = await _tryMdnsThenStatus();
    if (ip1 != null) return ip1;

    // pista ‘staIpHint’ si vino en la respuesta de /provision
    if (staIpHint != null && staIpHint.isNotEmpty) {
      if (await ApiClient(staIpHint).ping()) return staIpHint;
    }

    await Future<void>.delayed(const Duration(seconds: 2));
  }
  return null;
}


}
