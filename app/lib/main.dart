// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'package:bthapp/firebase_options.dart';
import 'package:bthapp/src/services/push_notification_service.dart';
import 'package:bthapp/src/state/app_state.dart';
import 'package:bthapp/src/state/auth_state.dart';
import 'package:bthapp/ui/components/app_theme.dart';
import 'package:bthapp/ui/flows/auth/login_view.dart';
import 'package:bthapp/ui/flows/devices/home_shell.dart';
import 'package:bthapp/ui/flows/devices/notifications_view.dart';
import 'package:bthapp/ui/flows/devices/skill_notification_builder_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await PushNotificationService.initializeApp();
  } catch (e) {
    debugPrint('Firebase/FCM Init notice: $e');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthState()..initialize()),
        ChangeNotifierProvider(create: (_) => AppState()..load()),
      ],
      child: MaterialApp(
        title: 'Mi Hogar Colmena',
        theme: AppTheme.dark(),
        navigatorKey: PushNotificationService.navigatorKey,
        home: const _AuthGate(),
        routes: {
          '/notificaciones': (_) => const NotificationsView(),
          '/skills_builder': (_) => const SkillNotificationBuilderView(),
        },
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

/// Decide qué pantalla mostrar según el estado de autenticación.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();

    switch (auth.status) {
      case AuthStatus.loading:
        // Splash / cargando sesión guardada
        return const Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.home_outlined, size: 64),
                SizedBox(height: 20),
                CircularProgressIndicator(),
              ],
            ),
          ),
        );
      case AuthStatus.authenticated:
        return const HomeShell();
      case AuthStatus.unauthenticated:
        return const LoginView();
    }
  }
}

