// =============================================================
// lib/src/services/api_client.dart
// Cliente HTTP sencillo para comunicar con el ESP8266/ESP32
// Endpoints esperados en el firmware:
//   GET  /ping                     -> 200 OK si está vivo
//   GET  /status                   -> JSON { relays: [bool,bool,bool,bool], ... }
//   GET  /relay/<id>/(on|off)      -> 200 OK al conmutar
//   GET  /provision?ssid=&pass=&mdns=   (en AP 192.168.4.1)
//   (fallback) POST /provision con form-url-encoded / JSON
// =============================================================

import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  final String base; // "mi-esp.local" o "192.168.1.50"
  final Duration defaultTimeout;

  ApiClient(String base, {this.defaultTimeout = const Duration(seconds: 4)})
      : base = _sanitize(base);

  // Limpia esquema y paths (solo host[:puerto])
  static String _sanitize(String x) {
    var s = x.trim();
    s = s.replaceFirst(RegExp(r'^https?://', caseSensitive: false), '');
    if (s.contains('/')) s = s.split('/').first;
    return s;
  }

  Uri _u(String path) => Uri.parse('http://$base$path');

  // -------------------------------------------------------------
  // Helpers
  Future<http.Response?> _tryGet(Uri u, {Duration? timeout}) async {
    try {
      final r = await http.get(u).timeout(timeout ?? defaultTimeout);
      return r;
    } catch (_) {
      return null;
    }
  }

  Future<http.Response?> _tryPost(Uri u, {Object? body, Map<String, String>? headers, Duration? timeout}) async {
    try {
      final r = await http
          .post(u, body: body, headers: headers)
          .timeout(timeout ?? defaultTimeout);
      return r;
    } catch (_) {
      return null;
    }
  }

  bool _ok(http.Response? r) => r != null && r.statusCode >= 200 && r.statusCode < 300;

  // -------------------------------------------------------------
  // Ping / Status / Relés
    Future<bool> ping({Duration? timeout}) async {
      final r = await _tryGet(_u('/ping'), timeout: timeout);
      if (r == null) return false;
      final body = r.body.trim().toLowerCase();
      return r.statusCode == 200 && body == 'ok';
    }


  Future<Map<String, dynamic>?> status({Duration? timeout}) async {
    final r = await _tryGet(_u('/status'), timeout: timeout);
    if (!_ok(r)) return null;
    try {
      return jsonDecode(r!.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

   Future<bool> setRelay(int ch, bool on, {Duration? timeout}) async {
  // Tu firmware expone POST /relay con form-url-encoded ch=..&on=0/1
  final r = await _tryPost(
    _u('/relay'),
    headers: {'Content-Type': 'application/x-www-form-urlencoded'},
    body: {'ch': '$ch', 'on': on ? '1' : '0'},
    timeout: timeout,
  );
  if (_ok(r)) return true;

  // Fallbacks por compatibilidad (por si cambias el firmware)
  final r2 = await _tryGet(_u('/relay?ch=$ch&on=${on ? 1 : 0}'), timeout: timeout);
  if (_ok(r2)) return true;

  final r3 = await _tryGet(_u('/relay/$ch/${on ? 'on' : 'off'}'), timeout: timeout);
  return _ok(r3);
}



  // -------------------------------------------------------------
  // Provisioning en modo AP (192.168.4.1)
  // Intenta GET con querystring (lo más común en firmwares ligeros)
  // y si falla, intenta POST tanto form-url-encoded como JSON.
static Future<Map<String, dynamic>?> provision({
  required String ssid,
  required String pass,
  required String mdns,
  String host = '192.168.4.1',
  Duration timeout = const Duration(seconds: 8),
}) async {
  final params = {'ssid': ssid, 'pass': pass, 'mdns': mdns};

  final String base = host.startsWith('http')
      ? host.replaceFirst(RegExp(r'^https?://', caseSensitive: false), '')
      : host;
  final Uri u = Uri.parse('http://$base/provision');

  Map<String, dynamic>? _parseOkJson(http.Response r) {
    try {
      final body = r.body.trim();
      if (body.isEmpty) return null;
      final m = jsonDecode(body);
      if (m is Map<String, dynamic> && m['ok'] == true) return m;
      return null;
    } catch (_) {
      return null;
    }
  }

  bool _isProvisionResponse(http.Response r) {
    final p = r.request?.url.path ?? '';
    return p.endsWith('/provision'); // acepta /provision con o sin query
  }

  // 1) POST JSON
  try {
    final r = await http
        .post(u, headers: {'Content-Type': 'application/json'}, body: jsonEncode(params))
        .timeout(timeout);
    if (r.statusCode >= 200 && r.statusCode < 300 && _isProvisionResponse(r)) {
      final ok = _parseOkJson(r);
      if (ok != null) return ok;
    }
  } catch (_) {}

  // 2) POST form-url-encoded
  try {
    final r = await http
        .post(u, headers: {'Content-Type': 'application/x-www-form-urlencoded'}, body: params)
        .timeout(timeout);
    if (r.statusCode >= 200 && r.statusCode < 300 && _isProvisionResponse(r)) {
      final ok = _parseOkJson(r);
      if (ok != null) return ok;
    }
  } catch (_) {}

  // 3) GET con querystring (muchos firmwares lo prefieren)
  try {
    final ug = u.replace(queryParameters: params);
    final r = await http.get(ug).timeout(timeout);
    if (r.statusCode >= 200 && r.statusCode < 300 && _isProvisionResponse(r)) {
      final ok = _parseOkJson(r);
      if (ok != null) return ok;
    }
  } catch (_) {}

  // 4) GET “pelado” (compat muy vieja)
  try {
    final r = await http.get(u).timeout(timeout);
    if (r.statusCode >= 200 && r.statusCode < 300 && _isProvisionResponse(r)) {
      final ok = _parseOkJson(r);
      if (ok != null) return ok;
    }
  } catch (_) {}

  return null;
}


  static Map<String, dynamic>? _parseJsonFlexible(String body) {
    try {
      final t = body.trim();
      if (t.isEmpty) return {};
      return jsonDecode(t) as Map<String, dynamic>;
    } catch (_) {
      // Algunos firmwares devuelven texto plano. Devuelve un mapa mínimo.
      return {'ok': true, 'raw': body};
    }
  }

  // -------------------------------------------------------------
  // (AÑADIDOS) Scan de SSIDs desde el firmware y verificación de conexión
  static Future<List<String>?> scanSsids({
    required String host,
    int port = 80,
  }) async {
    try {
      final uri = Uri.parse('http://$host:$port/scan');
      final r = await http.get(uri).timeout(const Duration(seconds: 5));
      if (r.statusCode != 200) return null;

      final json = jsonDecode(r.body);
      // Esperamos: { "nets": [ {"ssid":"X","rssi":-50}, ... ] }
      final List list = (json is Map && json['nets'] is List) ? json['nets'] as List : const [];
      final out = list
          .map((e) => (e is Map ? (e['ssid'] ?? '') : e).toString())
          .where((s) => s.isNotEmpty)
          .toSet() // sin duplicados
          .toList();
      out.sort();
      return out;
    } catch (_) {
      return null;
    }
  }

    static Future<bool> checkConnection({
      String host = '192.168.4.1',
      int port = 80,
      Duration timeout = const Duration(seconds: 3),
    }) async {
      // --- Ruta nueva: /conection?ready=1 (sí, con una sola 'n')
      try {
        final uri = Uri.parse('http://$host:$port/conection')
            .replace(queryParameters: const {'ready': '1'});
        final r = await http.get(uri).timeout(timeout);
        if (r.statusCode >= 200 && r.statusCode < 300) {
          final body = r.body.trim();
          final low = body.toLowerCase();
          if (low == 'ok') return true;
          try {
            final j = jsonDecode(body);
            if (j is Map && (j['ok'] == true || j['status'] == 'ok')) return true;
          } catch (_) {/* ignore json parse */}
        }
      } catch (_) {/* ignore */}

      // --- Fallback: ruta antigua /connection (POST)
      try {
        final uri2 = Uri.parse('http://$host:$port/connection');
        final r2 = await http
            .post(uri2, headers: {'Content-Type': 'application/json'}, body: '{}')
            .timeout(timeout);
        if (r2.statusCode >= 200 && r2.statusCode < 300) {
          final body = r2.body.trim();
          final low = body.toLowerCase();
          if (low == 'ok') return true;
          try {
            final j = jsonDecode(body);
            if (j is Map && (j['ok'] == true || j['status'] == 'ok')) return true;
          } catch (_) {/* ignore json parse */}
        }
      } catch (_) {/* ignore */}

      return false;
    }

       
}


