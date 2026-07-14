import 'package:flutter/material.dart';
import 'package:animations/animations.dart';
import 'package:provider/provider.dart';

import 'package:bthapp/src/state/auth_state.dart';
import 'devices_view.dart';
import 'room_dashboard_view.dart';
import 'automation_scenes_view.dart';
import 'network_health_view.dart';
import '../provision/provision_guide_view.dart';
import '../hubs/hub_link_view.dart';
import '../hubs/hub_management_view.dart';

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
    final auth = context.watch<AuthState>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: auth.hubs.isEmpty
            ? Text(
                'Sin Hubs',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: cs.onSurface),
              )
            : DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: auth.activeHub?.id,
                  icon: const Icon(Icons.arrow_drop_down),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: cs.onSurface),
                  onChanged: (String? newId) {
                    if (newId != null) {
                      final selected = auth.hubs.firstWhere((h) => h.id == newId);
                      context.read<AuthState>().setActiveHub(selected);
                    }
                  },
                  items: auth.hubs.map((hub) {
                    return DropdownMenuItem<String>(
                      value: hub.id,
                      child: Row(
                        children: [
                          Icon(hub.online ? Icons.cloud_done : Icons.cloud_off, 
                               size: 16, 
                               color: hub.online ? Colors.green : Colors.grey),
                          const SizedBox(width: 8),
                          Text(hub.name),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_remote_outlined),
            tooltip: 'Administrar Hubs',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HubManagementView()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_link),
            tooltip: 'Vincular nuevo Hub',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HubLinkView()),
              );
            },
          ),
          PopupMenuButton<String>(
            offset: const Offset(0, 48),
            tooltip: 'Perfil',
            icon: CircleAvatar(
              radius: 16,
              backgroundColor: cs.primary.withValues(alpha: 0.2),
              child: Text(
                (auth.user?.username.isNotEmpty == true)
                    ? auth.user!.username[0].toUpperCase()
                    : '?',
                style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold),
              ),
            ),
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      auth.user?.username ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      auth.user?.email ?? '',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'manage_hubs',
                child: Row(
                  children: [
                    Icon(Icons.hub_outlined),
                    SizedBox(width: 10),
                    Text('Administrar Hubs'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout),
                    SizedBox(width: 10),
                    Text('Cerrar sesión'),
                  ],
                ),
              ),
            ],
            onSelected: (val) async {
              if (val == 'manage_hubs') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HubManagementView()),
                );
              } else if (val == 'logout') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Cerrar sesión'),
                    content: const Text('¿Seguro que quieres salir de tu cuenta?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Salir')),
                    ],
                  ),
                );
                if (confirm == true && context.mounted) {
                  await context.read<AuthState>().logout();
                }
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
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
