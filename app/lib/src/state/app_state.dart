// =============================================================
// lib/src/state/app_state.dart
// Estado global con Provider (ChangeNotifier)
// - Persistencia local con SharedPreferences
// - Gestión dual de dispositivos (Wi-Fi ESP directo + Gateway Hub RF)
// - Comunicación real con endpoints REST
// =============================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/device.dart';
import '../models/notification_item.dart';
import '../constants/api_constants.dart';
import '../services/api_client.dart';
import '../services/mdns_resolver.dart';

class AppState extends ChangeNotifier {
  static const _storeKey = 'devices_v2';
  static const _namesKey = 'switch_names_v1';
  static const _kindKey  = 'device_kind_v1';
  static const _hubHostKey = 'rf_hub_host_v1';

  final List<Device> _devices = <Device>[];
  bool _loading = false;
  String? _lastError;
  String _hubHost = '192.168.1.100:5000';

  final Map<String, List<String>> _switchNames = <String, List<String>>{};
  final Map<String, String> _deviceKinds = <String, String>{};

  List<Device> get devices => List.unmodifiable(_devices);
  bool get loading => _loading;
  String? get lastError => _lastError;
  String get hubHost => _hubHost;

  // -----------------------------------------------------------
  // CARGA / GUARDA
  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();

    _hubHost = sp.getString(_hubHostKey) ?? ApiConstants.defaultHostFromEnv;
    ApiConstants.updateHost(_hubHost);

    // Dispositivos
    final raw = sp.getString(_storeKey);
    _devices.clear();
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
        for (final m in list) {
          _devices.add(Device.fromJson(m));
        }
      } catch (_) {}
    }

    // Metadatos legacy
    _loadMeta(sp);

    for (final d in _devices) {
      _ensureNamesList(d.id, d.relays.length);
      _deviceKinds.putIfAbsent(d.id, () => d.kind ?? _defaultKind(d.relays.length));
    }

    notifyListeners();
  }

  Future<void> setHubHost(String host) async {
    _hubHost = host.trim();
    ApiConstants.updateHost(_hubHost);
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_hubHostKey, _hubHost);
    notifyListeners();
  }

  Future<void> _save() async {
    final sp = await SharedPreferences.getInstance();
    final data = jsonEncode(_devices.map((e) => e.toJson()).toList());
    await sp.setString(_storeKey, data);
  }

  void _loadMeta(SharedPreferences sp) {
    final nraw = sp.getString(_namesKey);
    _switchNames.clear();
    if (nraw != null && nraw.isNotEmpty) {
      try {
        final map = jsonDecode(nraw) as Map<String, dynamic>;
        map.forEach((k, v) {
          if (v is List) {
            _switchNames[k] = v.map((e) => e.toString()).toList();
          }
        });
      } catch (_) {}
    }

    final kraw = sp.getString(_kindKey);
    _deviceKinds.clear();
    if (kraw != null && kraw.isNotEmpty) {
      try {
        final map = jsonDecode(kraw) as Map<String, dynamic>;
        map.forEach((k, v) => _deviceKinds[k] = v.toString());
      } catch (_) {}
    }
  }

  Future<void> _saveMeta() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_namesKey, jsonEncode(_switchNames));
    await sp.setString(_kindKey, jsonEncode(_deviceKinds));
  }

  // -----------------------------------------------------------
  // CRUD
  Future<void> addDevice(Device d) async {
    final i = _devices.indexWhere((x) => x.id == d.id);
    if (i >= 0) {
      _devices[i] = _devices[i].copyWith(
        mdns: d.mdns,
        ip: d.ip,
        port: d.port,
        alias: d.alias ?? _devices[i].alias,
        kind: d.kind ?? _devices[i].kind,
        room: d.room ?? _devices[i].room,
        commMode: d.commMode,
        hubIp: d.hubIp ?? _devices[i].hubIp,
        rfNodeId: d.rfNodeId ?? _devices[i].rfNodeId,
      );
    } else {
      _devices.add(d);
    }
    _ensureNamesList(d.id, d.relays.length);
    _deviceKinds.putIfAbsent(d.id, () => d.kind ?? _defaultKind(d.relays.length));
    await _save();
    await _saveMeta();
    notifyListeners();
  }

  Future<void> upsertDevice(Device d) => addDevice(d);
  Future<void> addOrUpdateDevice(Device d) => addDevice(d);

  Future<void> removeDevice(String id) async {
    _devices.removeWhere((x) => x.id == id);
    _switchNames.remove(id);
    _deviceKinds.remove(id);
    await _save();
    await _saveMeta();
    notifyListeners();
  }

  Device? getById(String id) {
    try { return _devices.firstWhere((x) => x.id == id); }
    catch (_) { return null; }
  }

  // -----------------------------------------------------------
  // GATEWAY HUB RF REAL API
  Future<bool> checkHubOnline({String? hostOverride}) async {
    final target = hostOverride ?? _hubHost;
    try {
      final uri = Uri.parse('http://$target/api/stats');
      final r = await http.get(uri).timeout(const Duration(seconds: 4));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // -----------------------------------------------------------
  // REGISTRO EN EL HUB (POST /api/devices)
  /// Registra o actualiza un dispositivo en la base de datos SQLite del Hub.
  /// Debe llamarse siempre que el usuario vincule un dispositivo RF manualmente.
  Future<bool> registerDeviceOnHub(Device d) async {
    final target = d.hubIp ?? _hubHost;
    try {
      final uri = Uri.parse('http://$target/api/devices');
      final body = jsonEncode({
        'device_id': d.rfNodeId ?? d.id,
        'name': d.alias ?? d.id,
        'type_name': d.kind ?? 'generic',
        'category': d.room ?? 'General',
        'rssi': d.rssi ?? -65,
        'state': d.state,
      });
      final r = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 5));
      return r.statusCode >= 200 && r.statusCode < 300;
    } catch (e) {
      _lastError = 'registerDeviceOnHub: $e';
      return false;
    }
  }

  Future<List<Device>> syncRfDevicesFromHub({String? hostOverride}) async {
    final target = hostOverride ?? _hubHost;
    try {
      final uri = Uri.parse('http://$target/api/devices');
      final r = await http.get(uri).timeout(const Duration(seconds: 5));
      if (r.statusCode != 200) return [];

      final list = jsonDecode(r.body) as List;
      final synced = <Device>[];
      for (final item in list) {
        if (item is Map) {
          final id = item['device_id']?.toString() ?? '';
          if (id.isEmpty) continue;

          final stateMap = item['state'] is Map ? Map<String, dynamic>.from(item['state'] as Map) : <String, dynamic>{};
          final dev = Device.fromRf(
            rfId: id,
            name: item['name']?.toString() ?? 'RF Device $id',
            hubHost: target,
            typeName: item['type_name']?.toString() ?? 'Sensor',
            rssi: (item['rssi'] as num?)?.toInt(),
            state: stateMap,
            online: item['status']?.toString().toLowerCase() == 'online',
          );
          await upsertDevice(dev);
          synced.add(dev);
        }
      }
      return synced;
    } catch (e) {
      _lastError = '$e';
      return [];
    }
  }

  Future<bool> sendRfCommand(Device d, String cmd, Map<String, dynamic> params) async {
    final target = d.hubIp ?? _hubHost;
    final payload = {
      'id': d.rfNodeId ?? d.id,
      'cmd': cmd,
      'params': params,
    };
    try {
      final uri = Uri.parse('http://$target/api/command');
      final r = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 4));

      if (r.statusCode == 200) {
        final j = jsonDecode(r.body);
        if (j is Map && j['state'] is Map) {
          final updated = d.applyStatus(Map<String, dynamic>.from(j['state'] as Map));
          _replace(updated);
          await _save();
          notifyListeners();
        } else {
          final mergedState = Map<String, dynamic>.from(d.state)..addAll(params);
          final updated = d.copyWith(state: mergedState, online: true, lastSeen: DateTime.now());
          _replace(updated);
          await _save();
          notifyListeners();
        }
        return true;
      }
    } catch (e) {
      _lastError = '$e';
    }
    return false;
  }

  // -----------------------------------------------------------
  // REFRESH: ping + status
  Future<Device?> refreshDevice(Device d) async {
    try {
      if (d.commMode == 'rf') {
        final target = d.hubIp ?? _hubHost;
        final uri = Uri.parse('http://$target/api/device/${d.rfNodeId ?? d.id}');
        final r = await http.get(uri).timeout(const Duration(seconds: 4));
        if (r.statusCode == 200) {
          final item = jsonDecode(r.body) as Map<String, dynamic>;
          final stateMap = item['state'] is Map ? Map<String, dynamic>.from(item['state'] as Map) : <String, dynamic>{};
          final updated = d.copyWith(
            online: item['status']?.toString().toLowerCase() == 'online',
            rssi: (item['rssi'] as num?)?.toInt() ?? d.rssi,
            state: stateMap,
            lastSeen: DateTime.now(),
          );
          _replace(updated);
          await _save();
          notifyListeners();
          return updated;
        } else {
          final off = d.copyWith(online: false);
          _replace(off);
          notifyListeners();
          return off;
        }
      } else {
        // Modo Wi-Fi
        final host = d.mdns.endsWith('.local') ? d.mdns : '${d.mdns}.local';
        Map<String, dynamic>? status;

        var ok = await ApiClient(host).ping();
        if (ok) {
          status = await ApiClient(host).status();
        } else if (d.ip.isNotEmpty && d.ip != '0.0.0.0') {
          ok = await ApiClient(d.ip).ping();
          if (ok) status = await ApiClient(d.ip).status();
        }

        final updated = (status != null)
            ? d.applyStatus(status)
            : d.copyWith(online: ok, lastSeen: ok ? DateTime.now() : d.lastSeen);

        _replace(updated);
        await _save();
        notifyListeners();
        return updated;
      }
    } catch (e) {
      _lastError = '$e';
      final off = d.copyWith(online: false);
      _replace(off);
      notifyListeners();
      return off;
    }
  }

  Future<void> refreshAll({bool parallel = false}) async {
    _loading = true;
    notifyListeners();
    try {
      // Si tenemos dispositivos RF, intentamos sincronizar con el Hub primero
      final hasRf = _devices.any((d) => d.commMode == 'rf');
      if (hasRf) {
        await syncRfDevicesFromHub();
      }

      if (parallel) {
        await Future.wait(_devices.map((d) => refreshDevice(d)));
      } else {
        for (final d in List<Device>.from(_devices)) {
          await refreshDevice(d);
        }
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // -----------------------------------------------------------
  // ACTIONS: relés y atributos
  Future<bool> setRelay(Device d, int relayIndex1, bool on) async {
    try {
      if (d.commMode == 'rf') {
        final newRelays = List<bool>.from(d.relays);
        final idx0 = relayIndex1 - 1;
        if (idx0 >= 0 && idx0 < newRelays.length) newRelays[idx0] = on;

        final params = <String, dynamic>{'on': on};
        if (d.relays.length > 1) params['ch$relayIndex1'] = on;

        final ok = await sendRfCommand(d, 'set', params);
        if (ok) {
          _replace(d.copyWith(relays: newRelays));
          notifyListeners();
        }
        return ok;
      } else {
        // Modo Wi-Fi
        final host = d.mdns.endsWith('.local') ? d.mdns : '${d.mdns}.local';

        var ok = await ApiClient(host).setRelay(relayIndex1, on);
        if (!ok && d.ip.isNotEmpty && d.ip != '0.0.0.0') {
          ok = await ApiClient(d.ip).setRelay(relayIndex1, on);
        }

        if (ok) {
          final newRelays = List<bool>.from(d.relays);
          final idx0 = relayIndex1 - 1;
          if (idx0 >= 0 && idx0 < newRelays.length) newRelays[idx0] = on;
          final updated = d.copyWith(
              relays: newRelays, online: true, lastSeen: DateTime.now());
          _replace(updated);
          await _save();
          notifyListeners();
        }
        return ok;
      }
    } catch (e) {
      _lastError = '$e';
      return false;
    }
  }

  Future<bool> setDeviceAttribute(Device d, Map<String, dynamic> params) async {
    if (d.commMode == 'rf') {
      return await sendRfCommand(d, 'set', params);
    } else {
      // Para dispositivos Wi-Fi si tuvieran endpoint /set
      final host = d.mdns.endsWith('.local') ? d.mdns : '${d.mdns}.local';
      try {
        final uri = Uri.parse('http://$host/set');
        final r = await http.post(uri, headers: {'Content-Type': 'application/json'}, body: jsonEncode(params));
        if (r.statusCode == 200) {
          _replace(d.applyStatus(params));
          notifyListeners();
          return true;
        }
      } catch (_) {}
      return false;
    }
  }

  // -----------------------------------------------------------
  // Metadatos legacy: NOMBRES de switches y TIPO de dispositivo
  List<String> getSwitchNames(String deviceId, int relayCount) {
    _ensureNamesList(deviceId, relayCount);
    return List<String>.from(_switchNames[deviceId]!);
  }

  Future<void> setSwitchName(String deviceId, int index0, String name) async {
    final list = _switchNames[deviceId];
    if (list == null) return;
    if (index0 < 0 || index0 >= list.length) return;
    list[index0] = name;
    await _saveMeta();
    notifyListeners();
  }

  String getDeviceKind(String deviceId, int relayCount) {
    final d = getById(deviceId);
    if (d != null && d.kind != null) return d.kind!;
    return _deviceKinds[deviceId] ?? _defaultKind(relayCount);
  }

  Future<void> setDeviceKind(String deviceId, String kind) async {
    _deviceKinds[deviceId] = kind;
    final d = getById(deviceId);
    if (d != null) {
      _replace(d.copyWith(kind: kind));
      await _save();
    }
    await _saveMeta();
    notifyListeners();
  }

  void _ensureNamesList(String deviceId, int relayCount) {
    final existing = _switchNames[deviceId];
    if (existing == null) {
      _switchNames[deviceId] = List.generate(relayCount, (i) => 'Switch ${i + 1}');
    } else if (existing.length != relayCount) {
      final resized = List<String>.from(existing);
      if (relayCount > resized.length) {
        for (var i = resized.length; i < relayCount; i++) {
          resized.add('Switch ${i + 1}');
        }
      } else if (relayCount < resized.length) {
        resized.removeRange(relayCount, resized.length);
      }
      _switchNames[deviceId] = resized;
    }
  }

  String _defaultKind(int relayCount) => relayCount <= 1 ? 'Enchufe' : 'Interruptor';

  // -----------------------------------------------------------
  // mDNS helpers
  Future<void> discoverAndMerge({String service = '_http._tcp.local'}) async {
    try {
      final found = await MdnsResolver.browse(service: service);
      for (final s in found) {
        final host = s.host.endsWith('.local') ? s.host : '${s.host}.local';
        final id = host;
        final ip = s.ip ?? await MdnsResolver.resolveHost(host) ?? '0.0.0.0';
        final d = Device(id: id, mdns: host, ip: ip, port: s.port, online: false);
        await upsertDevice(d);
      }
    } catch (e) {
      _lastError = '$e';
    }
  }

  Future<void> updateIpFromMdns(Device d) async {
    final host = d.mdns.endsWith('.local') ? d.mdns : '${d.mdns}.local';
    final ip = await MdnsResolver.resolveHost(host);
    if (ip != null && ip != d.ip) {
      _replace(d.copyWith(ip: ip));
      await _save();
      notifyListeners();
    }
  }

  // -----------------------------------------------------------
  // VINCULACIÓN RF VÍA API (RF PAIRING MODE)
  Future<bool> startRfPairing() async {
    try {
      final uri = Uri.parse('http://$_hubHost/api/pairing');
      final r = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'action': 'start'}),
      ).timeout(const Duration(seconds: 4));
      return r.statusCode == 200;
    } catch (e) {
      _lastError = '$e';
      return false;
    }
  }

  Future<bool> stopRfPairing() async {
    try {
      final uri = Uri.parse('http://$_hubHost/api/pairing');
      final r = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'action': 'stop'}),
      ).timeout(const Duration(seconds: 4));
      return r.statusCode == 200;
    } catch (e) {
      _lastError = '$e';
      return false;
    }
  }

  Future<Map<String, dynamic>?> checkRfPairingStatus() async {
    try {
      final uri = Uri.parse('http://$_hubHost/api/pairing/status');
      final r = await http.get(uri).timeout(const Duration(seconds: 3));
      if (r.statusCode == 200) {
        return jsonDecode(r.body) as Map<String, dynamic>;
      }
    } catch (e) {
      _lastError = '$e';
    }
    return null;
  }

  // -----------------------------------------------------------
  // HISTORIAL Y CONTROL DE NOTIFICACIONES
  Future<List<NotificationItem>> fetchNotificationLogs() async {
    try {
      final uri = Uri.parse('http://$_hubHost/api/notifications');
      final r = await http.get(uri).timeout(const Duration(seconds: 4));
      if (r.statusCode == 200) {
        final list = (jsonDecode(r.body) as List).cast<Map<String, dynamic>>();
        return list.map((m) => NotificationItem.fromJson(m)).toList();
      }
    } catch (e) {
      _lastError = '$e';
    }
    return [];
  }

  Future<bool> clearNotificationLogs() async {
    try {
      final uri = Uri.parse('http://$_hubHost/api/notifications');
      final r = await http.delete(uri).timeout(const Duration(seconds: 4));
      return r.statusCode == 200;
    } catch (e) {
      _lastError = '$e';
      return false;
    }
  }

  Future<bool> sendTestNotification(String title, String body) async {
    try {
      final uri = Uri.parse('http://$_hubHost/api/notifications/test');
      final r = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'title': title, 'body': body}),
      ).timeout(const Duration(seconds: 4));
      return r.statusCode == 200;
    } catch (e) {
      _lastError = '$e';
      return false;
    }
  }

  // -----------------------------------------------------------
  // SKILLS / AUTOMATIZACIONES Y DISPARADORES DE NOTIFICACIÓN
  Future<List<Map<String, dynamic>>> fetchSkills() async {
    try {
      final uri = Uri.parse('http://$_hubHost/api/skills');
      final r = await http.get(uri).timeout(const Duration(seconds: 4));
      if (r.statusCode == 200) {
        return (jsonDecode(r.body) as List).cast<Map<String, dynamic>>();
      }
    } catch (e) {
      _lastError = '$e';
    }
    return [];
  }

  Future<bool> saveSkill(Map<String, dynamic> skillData) async {
    try {
      final uri = Uri.parse('http://$_hubHost/api/skills');
      final r = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(skillData),
      ).timeout(const Duration(seconds: 5));
      return r.statusCode == 200;
    } catch (e) {
      _lastError = '$e';
      return false;
    }
  }

  Future<bool> toggleSkill(int skillId, {bool? active}) async {
    try {
      final uri = Uri.parse('http://$_hubHost/api/skills/$skillId/toggle');
      final body = active != null ? jsonEncode({'is_active': active}) : null;
      final r = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 4));
      return r.statusCode == 200;
    } catch (e) {
      _lastError = '$e';
      return false;
    }
  }

  Future<bool> deleteSkill(int skillId) async {
    try {
      final uri = Uri.parse('http://$_hubHost/api/skills/$skillId');
      final r = await http.delete(uri).timeout(const Duration(seconds: 4));
      return r.statusCode == 200;
    } catch (e) {
      _lastError = '$e';
      return false;
    }
  }

  Future<bool> executeSkill(int skillId) async {
    try {
      final uri = Uri.parse('http://$_hubHost/api/skills/$skillId/execute');
      final r = await http.post(uri).timeout(const Duration(seconds: 5));
      return r.statusCode == 200;
    } catch (e) {
      _lastError = '$e';
      return false;
    }
  }

  void _replace(Device d) {
    final i = _devices.indexWhere((x) => x.id == d.id);
    if (i >= 0) {
      _devices[i] = d;
    } else {
      _devices.add(d);
    }
  }
}
