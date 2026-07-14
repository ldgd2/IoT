// =============================================================
// lib/src/state/auth_state.dart
// Estado global de autenticación — ChangeNotifier
// =============================================================
import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../models/room.dart';
import '../models/hub.dart';
import '../services/auth_service.dart';
import '../services/push_notification_service.dart';
import '../constants/api_constants.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

enum AuthStatus { loading, authenticated, unauthenticated }

class AuthState extends ChangeNotifier {
  AuthStatus _status = AuthStatus.loading;
  ColmenaUser? _user;
  String? _token;
  String? _error;
  
  List<Hub> _hubs = [];
  Hub? _activeHub;
  List<Room> _rooms = []; // Representan los "spaces" del hub activo

  AuthStatus get status => _status;
  ColmenaUser? get user => _user;
  String? get token => _token;
  String? get error => _error;
  
  List<Hub> get hubs => List.unmodifiable(_hubs);
  Hub? get activeHub => _activeHub;
  List<Room> get rooms => List.unmodifiable(_rooms);
  
  bool get isLoggedIn => _status == AuthStatus.authenticated;
  String get userId => _user?.userId ?? '';

  // ── Inicialización (lee sesión guardada) ──────────────────────
  Future<void> initialize() async {
    _status = AuthStatus.loading;
    notifyListeners();

    _token = await AuthService.getSavedToken();
    _user = await AuthService.getSavedUser();

    if (_token != null && _user != null) {
      // Validar que el token siga siendo válido en el servidor
      final valid = await AuthService.validateSession();
      if (valid) {
        _status = AuthStatus.authenticated;
        PushNotificationService.syncTokenWithBackend(explicitJwt: _token);
        await _loadHubs();
      } else {
        await AuthService.clearSession();
        _token = null;
        _user = null;
        _status = AuthStatus.unauthenticated;
      }
    } else {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  // ── Login ──────────────────────────────────────────────────────
  Future<bool> login(String email, String password) async {
    _error = null;
    notifyListeners();
    final result = await AuthService.login(email: email, password: password);
    if (result.success) {
      _token = result.token;
      _user = result.user;
      _status = AuthStatus.authenticated;
      PushNotificationService.syncTokenWithBackend(explicitJwt: _token);
      await _loadHubs();
      notifyListeners();
      return true;
    } else {
      _error = result.error;
      notifyListeners();
      return false;
    }
  }

  // ── Signup ────────────────────────────────────────────────────
  Future<bool> signup(String username, String email, String password) async {
    _error = null;
    notifyListeners();
    final result = await AuthService.signup(
      username: username, email: email, password: password,
    );
    if (result.success) {
      _token = result.token;
      _user = result.user;
      _status = AuthStatus.authenticated;
      PushNotificationService.syncTokenWithBackend(explicitJwt: _token);
      notifyListeners();
      return true;
    } else {
      _error = result.error;
      notifyListeners();
      return false;
    }
  }

  // ── Logout ────────────────────────────────────────────────────
  Future<void> logout() async {
    await AuthService.logoutRemote();
    await PushNotificationService.unregisterTokenFromBackend();
    await AuthService.clearSession();
    _token = null;
    _user = null;
    _hubs = [];
    _activeHub = null;
    _rooms = [];
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  // ── Hubs ──────────────────────────────────────────────────────
  Future<void> _loadHubs() async {
    if (_token == null) return;
    try {
      final uri = Uri.parse('${ApiConstants.serverBaseUrl}/hubs');
      final r = await http.get(uri, headers: authHeaders).timeout(const Duration(seconds: 5));
      if (r.statusCode == 200) {
        final list = (jsonDecode(r.body) as List).cast<Map<String, dynamic>>();
        _hubs = list.map((j) => Hub.fromJson(j)).toList();
        if (_hubs.isNotEmpty && _activeHub == null) {
          _activeHub = _hubs.first;
        } else if (_hubs.isEmpty) {
          _activeHub = null;
        }
        await _loadRooms();
        notifyListeners();
      }
    } catch (e) {
      print("Error cargando hubs: $e");
    }
  }

  void setActiveHub(Hub hub) {
    _activeHub = hub;
    _loadRooms();
    notifyListeners();
  }
  
  Future<void> refreshHubs() async {
    await _loadHubs();
  }

  // ── Salas (Spaces) ────────────────────────────────────────────
  Future<void> _loadRooms() async {
    if (_token == null || _activeHub == null) {
      _rooms = [];
      notifyListeners();
      return;
    }
    try {
      final uri = Uri.parse('${ApiConstants.serverBaseUrl}/hubs/${_activeHub!.id}/spaces');
      final r = await http.get(uri, headers: authHeaders).timeout(const Duration(seconds: 5));
      if (r.statusCode == 200) {
        final list = (jsonDecode(r.body) as List).cast<Map<String, dynamic>>();
        _rooms = list.map((j) {
           // Mapear de space_id a id temporalmente para compatibilidad con Room
           j['id'] = j['space_id'];
           return Room.fromJson(j);
        }).toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<bool> createRoom(String name, String icon) async {
    if (_token == null || _activeHub == null) return false;
    try {
      final uri = Uri.parse('${ApiConstants.serverBaseUrl}/hubs/${_activeHub!.id}/spaces');
      final r = await http.post(
        uri,
        headers: authHeaders,
        body: jsonEncode({'name': name, 'icon': icon}),
      ).timeout(const Duration(seconds: 5));
      if (r.statusCode == 201) {
        await _loadRooms();
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> deleteRoom(String roomId) async {
    if (_token == null || _activeHub == null) return false;
    try {
      final uri = Uri.parse('${ApiConstants.serverBaseUrl}/hubs/${_activeHub!.id}/spaces/$roomId');
      final r = await http.delete(uri, headers: authHeaders).timeout(const Duration(seconds: 5));
      if (r.statusCode == 200) {
        await _loadRooms();
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Headers HTTP con Bearer token para usar en otras partes de la app
  Map<String, String> get authHeaders => {
        'Authorization': 'Bearer ${_token ?? ""}',
        'Content-Type': 'application/json',
      };
}

