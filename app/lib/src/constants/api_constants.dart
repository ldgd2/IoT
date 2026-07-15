// =============================================================
// lib/src/constants/api_constants.dart
// Constantes y endpoints para comunicación con Hub y Servidor
// =============================================================

class ApiConstants {
  // ── SERVIDOR REMOTO (Nube / Fuera de casa) ────────────────────────
  // Maneja: Auth, Usuarios, Salas, Notificaciones, Skills
  static const String remoteHostFromEnv =
      String.fromEnvironment('HUB_HOST', defaultValue: '157.173.102.129:8000');

  /// URL base del Servidor — siempre apunta a la nube
  static String get serverBaseUrl => 'http://$remoteHostFromEnv/api';

  // ── HUB LOCAL (LAN / En casa) ─────────────────────────────────────
  // Maneja: Control de dispositivos RF/relés/sensores ÚNICAMENTE
  static String localHost = '192.168.1.100:5000';

  // Host activo actual (puede ser local o remoto según conectividad)
  static String activeHost = remoteHostFromEnv;

  /// URL base del Hub activo — puede ser local o remoto (proxy)
  static String get mainBaseUrl => 'http://$activeHost/api';
  static String get localBaseUrl => 'http://$localHost/api';
  static bool isConnectedLocally = false;

  static void updateHost(String host, {bool isLocal = false}) {
    final cleanHost =
        host.trim().replaceFirst(RegExp(r'^https?://'), '').split('/').first;
    activeHost = cleanHost;
    if (isLocal) {
      localHost = cleanHost;
    }
    isConnectedLocally = isLocal;
  }
}

