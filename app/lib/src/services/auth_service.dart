// =============================================================
// lib/src/services/auth_service.dart
// Comunicación con endpoints /api/auth/* del Hub
// =============================================================
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';
import '../models/user.dart';

class AuthResult {
  final bool success;
  final String? token;
  final ColmenaUser? user;
  final String? error;

  const AuthResult({required this.success, this.token, this.user, this.error});
}

class AuthService {
  static const _tokenKey = 'auth_token_v1';
  static const _userKey = 'auth_user_v1';

  // ── Token persistido ─────────────────────────────────────────
  static Future<String?> getSavedToken() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_tokenKey);
  }

  static Future<void> saveToken(String token, ColmenaUser user) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_tokenKey, token);
    await sp.setString(_userKey, jsonEncode(user.toJson()));
  }

  static Future<ColmenaUser?> getSavedUser() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_userKey);
    if (raw == null) return null;
    try {
      return ColmenaUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearSession() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_tokenKey);
    await sp.remove(_userKey);
  }

  // ── Headers con token ────────────────────────────────────────
  static Future<Map<String, String>> _authHeaders() async {
    final token = await getSavedToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── Registro ─────────────────────────────────────────────────
  static Future<AuthResult> signup({
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      final uri = Uri.parse('${ApiConstants.serverBaseUrl}/auth/signup');
      final r = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'username': username, 'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 8));

      final body = jsonDecode(r.body) as Map<String, dynamic>;
      if (r.statusCode == 201) {
        final user = ColmenaUser.fromJson(body['user'] as Map<String, dynamic>);
        final token = body['token'] as String;
        await saveToken(token, user);
        return AuthResult(success: true, token: token, user: user);
      }
      return AuthResult(success: false, error: body['error'] as String? ?? 'Error desconocido');
    } catch (e) {
      return AuthResult(success: false, error: 'No se pudo conectar al servidor. Verifica tu conexión a internet.');
    }
  }

  // ── Login ────────────────────────────────────────────────────
  static Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final uri = Uri.parse('${ApiConstants.serverBaseUrl}/auth/login');
      final r = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 8));

      final body = jsonDecode(r.body) as Map<String, dynamic>;
      if (r.statusCode == 200) {
        final user = ColmenaUser.fromJson(body['user'] as Map<String, dynamic>);
        final token = body['token'] as String;
        await saveToken(token, user);
        return AuthResult(success: true, token: token, user: user);
      }
      return AuthResult(success: false, error: body['error'] as String? ?? 'Error desconocido');
    } catch (e) {
      return AuthResult(success: false, error: 'No se pudo conectar al servidor. Verifica tu conexión a internet.');
    }
  }

  // ── Verificar sesión activa ───────────────────────────────────
  static Future<bool> validateSession() async {
    try {
      final headers = await _authHeaders();
      if (!headers.containsKey('Authorization')) return false;
      final uri = Uri.parse('${ApiConstants.serverBaseUrl}/auth/me');
      final r = await http.get(uri, headers: headers).timeout(const Duration(seconds: 5));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Ping simple para verificar conexión al Hub ────────────────
  static Future<bool> pingHub(String hostWithPort) async {
    try {
      final clean = hostWithPort.trim()
          .replaceFirst(RegExp(r'^https?://'), '')
          .split('/').first;
      final uri = Uri.parse('http://$clean/api/ping');
      final r = await http.get(uri).timeout(const Duration(seconds: 5));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Obtener lista de Hubs del usuario (Nube VPS) ──────────────
  static Future<List<Map<String, dynamic>>> getUserHubs() async {
    try {
      final headers = await _authHeaders();
      if (!headers.containsKey('Authorization')) return [];
      final uri = Uri.parse('${ApiConstants.serverBaseUrl}/hubs');
      final r = await http.get(uri, headers: headers).timeout(const Duration(seconds: 5));
      if (r.statusCode == 200) {
        final list = jsonDecode(r.body) as List;
        return list.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}
