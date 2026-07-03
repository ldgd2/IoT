// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:bthapp/src/state/app_state.dart';
import 'package:bthapp/ui/components/app_theme.dart';
import 'package:bthapp/ui/flows/devices/home_shell.dart';

void main() {
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
        home: const HomeShell(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
