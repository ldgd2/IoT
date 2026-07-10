// =============================================================
// lib/src/constants/api_constants.dart
// Constantes y endpoints para comunicación con el Hub/Backend
// =============================================================

class ApiConstants {
  static const String defaultHostFromEnv = String.fromEnvironment('HUB_HOST', defaultValue: '192.168.1.100:5000');
  static String mainBaseUrl = 'http://$defaultHostFromEnv/api';

  static void updateHost(String host) {
    final cleanHost = host.trim().replaceFirst(RegExp(r'^https?://'), '').split('/').first;
    mainBaseUrl = 'http://$cleanHost/api';
  }
}
