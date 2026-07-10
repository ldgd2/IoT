// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'package:bthapp/firebase_options.dart';
import 'package:bthapp/src/services/push_notification_service.dart';
import 'package:bthapp/src/state/app_state.dart';
import 'package:bthapp/ui/components/app_theme.dart';
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
    return ChangeNotifierProvider(
      create: (_) => AppState()..load(),
      child: MaterialApp(
        title: 'Mi Hogar Colmena',
        theme: AppTheme.dark(),
        navigatorKey: PushNotificationService.navigatorKey,
        home: const HomeShell(),
        routes: {
          '/notificaciones': (_) => const NotificationsView(),
          '/skills_builder': (_) => const SkillNotificationBuilderView(),
        },
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
