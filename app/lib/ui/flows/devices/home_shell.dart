// =============================================================
// lib/ui/flows/devices/home_shell.dart
// Contenedor principal con NavigationBar Material 3
// =============================================================
import 'package:flutter/material.dart';
import 'package:animations/animations.dart';

import 'devices_view.dart';
import 'room_dashboard_view.dart';
import 'automation_scenes_view.dart';
import 'network_health_view.dart';
import '../provision/provision_guide_view.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int currentIndex = 0;

  final List<Widget> pages = const [
    DevicesView(),
    RoomDashboardView(),
    AutomationScenesView(),
    NetworkHealthView(),
    InteractiveProvisionGuideView(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageTransitionSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, primaryAnimation, secondaryAnimation) =>
            FadeThroughTransition(
          animation: primaryAnimation,
          secondaryAnimation: secondaryAnimation,
          child: child,
        ),
        child: KeyedSubtree(
          key: ValueKey<int>(currentIndex),
          child: pages[currentIndex],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (idx) => setState(() => currentIndex = idx),
        animationDuration: const Duration(milliseconds: 400),
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.devices_outlined),
            selectedIcon: Icon(Icons.devices, color: Color(0xFF00E5A8)),
            label: 'Dispositivos',
          ),
          NavigationDestination(
            icon: Icon(Icons.room_preferences_outlined),
            selectedIcon: Icon(Icons.room_preferences, color: Color(0xFF00E5A8)),
            label: 'Espacios',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome, color: Color(0xFF00E5A8)),
            label: 'Escenas',
          ),
          NavigationDestination(
            icon: Icon(Icons.monitor_heart_outlined),
            selectedIcon: Icon(Icons.monitor_heart, color: Color(0xFF00E5A8)),
            label: 'Salud Red',
          ),
          NavigationDestination(
            icon: Icon(Icons.help_outline),
            selectedIcon: Icon(Icons.menu_book, color: Color(0xFF00E5A8)),
            label: 'Guía RF',
          ),
        ],
      ),
    );
  }
}
