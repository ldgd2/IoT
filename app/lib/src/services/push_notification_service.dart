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
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        log("FCM Token obtenido: $token");
        await registerTokenWithBackend(token);
      }

      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        log("FCM Token refrescado: $newToken");
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

  /// Registra (o actualiza) el FCM token en el servidor para recibir notificaciones push.
  /// Se autentica con el JWT guardado en SharedPreferences (clave 'auth_token_v1').
  static Future<void> registerTokenWithBackend(String token) async {
    try {
      // Leer el JWT almacenado por auth_service.dart
      final sp = await SharedPreferences.getInstance();
      final jwtToken = sp.getString('auth_token_v1') ?? '';

      if (jwtToken.isEmpty) {
        log("[WARN] No hay JWT disponible para registrar FCM token. Se reintentará al iniciar sesión.");
        return;
      }

      final Uri uri = Uri.parse('${ApiConstants.mainBaseUrl}/api/auth/fcm-token');
      final res = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode({'fcm_token': token}),
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        log("[OK] Token FCM registrado en el servidor exitosamente.");
      } else {
        log("[WARN] Respuesta servidor al registrar token FCM: ${res.statusCode} ${res.body}");
      }
    } catch (e) {
      log("[WARN] No se pudo registrar el FCM token (puede que el servidor aún no responda): $e");
    }
  }
}
