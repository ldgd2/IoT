// =============================================================
// lib/src/models/device.dart
// Modelo de dispositivo IoT (Wi-Fi ESP / Gateway Hub RF)
// =============================================================

class Device {
  /// Identificador único en la app (ej: "mi-esp.local" o "dev_001")
  final String id;

  /// Modo de comunicación: 'wifi' (mDNS/HTTP directo) o 'rf' (Gateway Hub)
  final String commMode;

  /// Identificador de nodo RF en el Gateway Hub (ej: "dev_001" o "101")
  final String? rfNodeId;

  /// IP o host:puerto del Gateway Hub RF (ej: "192.168.1.100:5000")
  final String? hubIp;

  /// Nombre mDNS (con o sin .local). Ej: "esp-sala.local"
  final String mdns;

  /// IP actual descubierta o configurada. Ej: "192.168.1.50"
  final String ip;

  /// Puerto HTTP (normalmente 80 para Wi-Fi)
  final int port;

  /// ¿Está en línea?
  final bool online;

  /// Estado de relés/switches (true=ON). Por defecto 4 relés.
  final List<bool> relays;

  /// Alias opcional definido por el usuario (para UI)
  final String? alias;

  /// Tipo de dispositivo: 'Luz', 'Enchufe', 'Interruptor', 'Dimmer',
  /// 'Sensor Temperatura', 'Sensor Movimiento', 'Cámara', 'Persiana', 'Ventilador'
  final String? kind;

  /// Habitación o categoría: 'Sala', 'Dormitorio', 'Cocina', 'Exterior', 'General'
  final String? room;

  /// Nivel de señal RSSI en dBm (ej: -65)
  final int? rssi;

  /// Estado dinámico extendido (temperatura, humedad, brillo, movimiento, potencia)
  final Map<String, dynamic> state;

  /// Última vez que respondió
  final DateTime? lastSeen;

  const Device({
    required this.id,
    this.commMode = 'wifi',
    this.rfNodeId,
    this.hubIp,
    required this.mdns,
    required this.ip,
    this.port = 80,
    this.online = false,
    this.relays = const [false, false, false, false],
    this.alias,
    this.kind,
    this.room,
    this.rssi,
    this.state = const {},
    this.lastSeen,
  });

  /// Creador rápido para dispositivo Wi-Fi / mDNS.
  factory Device.fromHost({
    required String hostMdns,
    required String ip,
    int port = 80,
    int relayCount = 4,
    String? alias,
    String? kind,
    String? room,
  }) {
    return Device(
      id: hostMdns,
      commMode: 'wifi',
      mdns: hostMdns,
      ip: ip,
      port: port,
      relays: List<bool>.filled(relayCount, false, growable: false),
      alias: alias,
      kind: kind,
      room: room ?? 'General',
    );
  }

  /// Creador rápido para dispositivo de Radiofrecuencia (Gateway Hub RF).
  factory Device.fromRf({
    required String rfId,
    required String name,
    required String hubHost,
    String? typeName,
    String? room,
    int? rssi,
    Map<String, dynamic> state = const {},
    bool online = true,
  }) {
    // Relés por defecto a partir del estado if present
    bool isOn = state['on'] == true || state['state'] == 'ON';
    return Device(
      id: rfId,
      commMode: 'rf',
      rfNodeId: rfId,
      hubIp: hubHost,
      mdns: rfId,
      ip: hubHost.split(':').first,
      port: hubHost.contains(':') ? int.tryParse(hubHost.split(':').last) ?? 5000 : 5000,
      online: online,
      alias: name,
      kind: _normalizeKind(typeName ?? 'Sensor'),
      room: room ?? 'General',
      rssi: rssi ?? -70,
      relays: [isOn, false, false, false],
      state: Map<String, dynamic>.from(state),
      lastSeen: DateTime.now(),
    );
  }

  static String _normalizeKind(String raw) {
    final low = raw.toLowerCase();
    if (low.contains('luz') || low.contains('light') || low.contains('bombilla')) return 'Luz';
    if (low.contains('enchufe') || low.contains('plug') || low.contains('socket')) return 'Enchufe';
    if (low.contains('dimmer')) return 'Dimmer';
    if (low.contains('temp') || low.contains('clima') || low.contains('hum')) return 'Sensor Temperatura';
    if (low.contains('mov') || low.contains('pir') || low.contains('motion')) return 'Sensor Movimiento';
    if (low.contains('cam') || low.contains('cámara') || low.contains('video')) return 'Cámara';
    if (low.contains('persiana') || low.contains('shutter') || low.contains('cortina')) return 'Persiana';
    if (low.contains('vent') || low.contains('fan')) return 'Ventilador';
    return 'Interruptor';
  }

  /// Actualiza campos manteniendo inmutabilidad.
  Device copyWith({
    String? id,
    String? commMode,
    String? rfNodeId,
    String? hubIp,
    String? mdns,
    String? ip,
    int? port,
    bool? online,
    List<bool>? relays,
    String? alias,
    String? kind,
    String? room,
    int? rssi,
    Map<String, dynamic>? state,
    DateTime? lastSeen,
  }) {
    return Device(
      id: id ?? this.id,
      commMode: commMode ?? this.commMode,
      rfNodeId: rfNodeId ?? this.rfNodeId,
      hubIp: hubIp ?? this.hubIp,
      mdns: mdns ?? this.mdns,
      ip: ip ?? this.ip,
      port: port ?? this.port,
      online: online ?? this.online,
      relays: relays != null ? List<bool>.from(relays) : List<bool>.from(this.relays),
      alias: alias ?? this.alias,
      kind: kind ?? this.kind,
      room: room ?? this.room,
      rssi: rssi ?? this.rssi,
      state: state != null ? Map<String, dynamic>.from(state) : Map<String, dynamic>.from(this.state),
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  /// Aplica un /status del firmware o actualización del Hub RF
  Device applyStatus(Map<String, dynamic> statusData) {
    final updatedRelays = _extractRelays(statusData, fallback: relays);
    final mergedState = Map<String, dynamic>.from(state)..addAll(statusData);
    return copyWith(
      online: true,
      relays: updatedRelays,
      state: mergedState,
      lastSeen: DateTime.now(),
    );
  }

  // -----------------------------------------------------------
  // JSON
  Map<String, dynamic> toJson() => {
        'id': id,
        'commMode': commMode,
        'rfNodeId': rfNodeId,
        'hubIp': hubIp,
        'mdns': mdns,
        'ip': ip,
        'port': port,
        'online': online,
        'relays': relays,
        'alias': alias,
        'kind': kind,
        'room': room,
        'rssi': rssi,
        'state': state,
        'lastSeen': lastSeen?.toIso8601String(),
      };

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'] as String,
      commMode: json['commMode'] as String? ?? 'wifi',
      rfNodeId: json['rfNodeId'] as String?,
      hubIp: json['hubIp'] as String?,
      mdns: json['mdns'] as String? ?? json['id'] as String,
      ip: json['ip'] as String? ?? '0.0.0.0',
      port: (json['port'] as num?)?.toInt() ?? 80,
      online: json['online'] as bool? ?? false,
      relays: _parseRelaysFromJson(json['relays']) ?? const [false, false, false, false],
      alias: json['alias'] as String?,
      kind: json['kind'] as String?,
      room: json['room'] as String? ?? 'General',
      rssi: (json['rssi'] as num?)?.toInt(),
      state: json['state'] is Map ? Map<String, dynamic>.from(json['state'] as Map) : const {},
      lastSeen: json['lastSeen'] != null ? DateTime.tryParse(json['lastSeen'] as String) : null,
    );
  }

  static List<bool>? _parseRelaysFromJson(dynamic v) {
    if (v is List) {
      return v.map((e) => e == true || e == 1 || e == '1').cast<bool>().toList(growable: false);
    }
    return null;
  }

  static List<bool> _extractRelays(Map<String, dynamic> status, {required List<bool> fallback}) {
    final v = status['relays'];
    final parsed = _parseRelaysFromJson(v);
    if (parsed == null || parsed.isEmpty) return fallback;
    return parsed;
  }

  // -----------------------------------------------------------
  // Utilidades
  String get baseUrl => port == 80 ? 'http://$ip' : 'http://$ip:$port';

  @override
  String toString() => 'Device(id: $id, mode: $commMode, kind: $kind, alias: $alias, online: $online)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Device && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
