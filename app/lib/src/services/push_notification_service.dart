import 'dart:convert';
import 'dart:developer';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/api_constants.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  log("Recibido mensaje en segundo plano: ${message.messageId}");
}

class PushNotificationService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  
  // Clave global para navegar al tocar la notificación
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static Future<void> initializeApp() async {
    try {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 1. Solicitar Permisos
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        log('Usuario concedió permisos de notificación.');
      } else {
        log('Permisos de notificación denegados o provisionales.');
      }

      // 2. Configurar Notificaciones Locales
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      
      const DarwinInitializationSettings initializationSettingsDarwin =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin,
      );

      await _localNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          _handleNotificationClick(response.payload);
        },
      );

      // Crear canal de alta prioridad en Android
      if (defaultTargetPlatform == TargetPlatform.android) {
        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          'colmena_high_importance_channel',
          'Notificaciones Colmena IoT',
          description: 'Este canal se usa para alertas urgentes de dispositivos y skills de la Colmena.',
          importance: Importance.max,
          playSound: true,
        );

        await _localNotificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(channel);
      }

      // 3. Obtener y Registrar Token FCM
      String? token = await getTokenSafe();
      if (token != null) {
        log("FCM Token obtenido: $token");
        await registerTokenWithBackend(token);
      }

      _firebaseMessaging.onTokenRefresh.listen((newToken) async {
        log("FCM Token refrescado: $newToken");
        _cachedFcmToken = newToken;
        final sp = await SharedPreferences.getInstance();
        await sp.setString('fcm_token_v1', newToken);
        registerTokenWithBackend(newToken);
      });

      // 4. Escuchar mensajes en primer plano (Foreground)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        log("Mensaje en Foreground: ${message.notification?.title} - ${message.notification?.body}");
        _showLocalNotification(message);
      });

      // 5. Escuchar clics cuando la app se abre desde una notificación en segundo plano
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        log("App abierta por notificación en Background: ${message.data}");
        _handleNotificationClick(jsonEncode(message.data));
      });
    } catch (e) {
      log("Error inicializando PushNotificationService: $e");
    }
  }

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    RemoteNotification? notification = message.notification;
    Map<String, dynamic> data = message.data;

    String title = notification?.title ?? data['title'] ?? 'Colmena IoT';
    String body = notification?.body ?? data['body'] ?? '¡Nueva actividad en tu hogar inteligente!';

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'colmena_high_importance_channel',
      'Notificaciones Colmena IoT',
      channelDescription: 'Canal principal para alertas de la Colmena.',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
    );

    await _localNotificationsPlugin.show(
      DateTime.now().millisecond,
      title,
      body,
      platformChannelSpecifics,
      payload: jsonEncode(data),
    );
  }

  static void _handleNotificationClick(String? payload) {
    if (payload != null && navigatorKey.currentState != null) {
      log("Navegando a vista de notificaciones por clic: $payload");
      navigatorKey.currentState!.pushNamed('/notificaciones');
    }
  }

  static String? _cachedFcmToken;

  static Future<String?> getTokenSafe() async {
    if (_cachedFcmToken != null && _cachedFcmToken!.isNotEmpty) {
      return _cachedFcmToken;
    }
    try {
      final sp = await SharedPreferences.getInstance();
      _cachedFcmToken = sp.getString('fcm_token_v1');
      if (_cachedFcmToken != null && _cachedFcmToken!.isNotEmpty) {
        // Tentar obtener token de FCM en background
        _firebaseMessaging.getToken().then((tok) {
          if (tok != null && tok.isNotEmpty) {
            _cachedFcmToken = tok;
            sp.setString('fcm_token_v1', tok);
          }
        }).catchError((_) {});
        return _cachedFcmToken;
      }
      final token = await _firebaseMessaging.getToken().timeout(const Duration(seconds: 4));
      if (token != null && token.isNotEmpty) {
        _cachedFcmToken = token;
        await sp.setString('fcm_token_v1', token);
      }
    } catch (e) {
      log("No se pudo obtener el token FCM en línea: $e");
    }
    return _cachedFcmToken;
  }

  /// Registra (o actualiza) el FCM token en el servidor Nube y en el Hub local para recibir notificaciones push M:N.
  /// Se autentica con el JWT guardado o explícito.
  static Future<void> registerTokenWithBackend(String token, {String? explicitJwt}) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final jwtToken = explicitJwt ?? sp.getString('auth_token_v1') ?? '';
      final userRaw = sp.getString('auth_user_v1');
      String userId = '';
      if (userRaw != null && userRaw.isNotEmpty) {
        try {
          final userMap = jsonDecode(userRaw) as Map<String, dynamic>;
          userId = userMap['id']?.toString() ?? userMap['user_id']?.toString() ?? '';
        } catch (_) {}
      }

      // 1) Registro en Nube VPS (relación M:N usuario <-> tokens)
      if (jwtToken.isNotEmpty) {
        final Uri uri = Uri.parse('${ApiConstants.serverBaseUrl}/auth/fcm-token');
        log("Sincronizando token FCM M:N con Nube VPS: $uri");
        try {
          final res = await http.post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $jwtToken',
            },
            body: jsonEncode({'fcm_token': token, 'platform': 'android', 'device_name': 'Android Mobile'}),
          ).timeout(const Duration(seconds: 6));
          log("[OK] Token FCM registrado M:N en la nube VPS. Status: ${res.statusCode}");
        } catch (e) {
          log("[WARN] Excepción HTTP registrando FCM en nube: $e");
        }
      } else {
        log("[WARN] No hay JWT disponible en registerTokenWithBackend para registrar en nube.");
      }

      // 2) Registro local en el Hub Colmena (para funcionar sin internet o modo local)
      try {
        final Uri localUri = Uri.parse('${ApiConstants.localBaseUrl}/device-token');
        await http.post(
          localUri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'token': token,
            'user_id': userId,
            'platform': 'android',
            'device_name': 'Android Mobile'
          }),
        ).timeout(const Duration(seconds: 3));
        log("[OK] Token FCM registrado en el Hub Local.");
      } catch (errLocal) {
        log("[INFO] Hub Local no alcanzable para registro de token fcm: $errLocal");
      }
    } catch (e) {
      log("[WARN] Excepción al registrar el FCM token: $e");
    }
  }

  /// Sincroniza el FCM token en cuanto el usuario inicia sesión.
  static Future<void> syncTokenWithBackend({String? explicitJwt}) async {
    try {
      final token = await getTokenSafe();
      if (token != null && token.isNotEmpty) {
        await registerTokenWithBackend(token, explicitJwt: explicitJwt);
      } else {
        log("[WARN] No se obtuvo ningún token FCM para sincronizar al backend.");
      }
    } catch (e) {
      log("Error en syncTokenWithBackend: $e");
    }
  }

  /// Elimina el FCM token del servidor (Nube VPS y Hub local) al cerrar sesión.
  static Future<void> unregisterTokenFromBackend() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;

      final sp = await SharedPreferences.getInstance();
      final jwtToken = sp.getString('auth_token_v1') ?? '';

      // 1) Eliminar en Nube VPS
      if (jwtToken.isNotEmpty) {
        final Uri uri = Uri.parse('${ApiConstants.serverBaseUrl}/auth/fcm-token');
        await http.delete(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $jwtToken',
          },
          body: jsonEncode({'fcm_token': token}),
        ).timeout(const Duration(seconds: 4));
        log("[OK] Token FCM eliminado de la Nube VPS al cerrar sesión.");
      }

      // 2) Eliminar en Hub Local si está accesible
      try {
        final Uri localUri = Uri.parse('${ApiConstants.localBaseUrl}/device-token');
        await http.delete(
          localUri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'token': token}),
        ).timeout(const Duration(seconds: 3));
        log("[OK] Token FCM eliminado del Hub Local al cerrar sesión.");
      } catch (errLocal) {
        log("[INFO] Hub Local no alcanzable durante eliminación de token fcm: $errLocal");
      }
    } catch (e) {
      log("[WARN] Excepción al eliminar el FCM token al cerrar sesión: $e");
    }
  }
}
