// =============================================================
// lib/ui/flows/devices/devices_view.dart
// Dashboard M3 con filtro de habitaciones/categorías y controles en tiempo real
// =============================================================
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import 'package:bthapp/ui/components/index.dart';
import 'package:bthapp/src/state/app_state.dart';
import 'package:bthapp/ui/flows/devices/devices_widgets.dart' as dvw;
import 'device_detail_view.dart';
import 'package:bthapp/ui/flows/provision/add_device_sheet.dart';

class DevicesView extends StatefulWidget {
  const DevicesView({super.key});

  @override
  State<DevicesView> createState() => _DevicesViewState();
}

class _DevicesViewState extends State<DevicesView> {
  String selectedFilter = 'Todos';
  final List<String> filters = ['Todos', 'Sala', 'Dormitorio', 'Cocina', 'Exterior', 'Luces', 'Clima', 'Cámaras'];

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final devices = app.devices;

    // Filtrado por habitación o categoría
    final filteredDevices = devices.where((d) {
      if (selectedFilter == 'Todos') return true;
      if (selectedFilter == 'Luces') return d.kind == 'Luz' || d.kind == 'Dimmer';
      if (selectedFilter == 'Clima') return d.kind == 'Sensor Temperatura' || d.kind == 'Ventilador';
      if (selectedFilter == 'Cámaras') return d.kind == 'Cámara';
      return d.room == selectedFilter;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.home_max_rounded, color: Color(0xFF00E5A8)),
            const SizedBox(width: 10),
            const Text('Mi Hogar Colmena', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Añadir Dispositivo',
            icon: const Icon(Icons.add_circle_outline, size: 26),
            onPressed: () => AddDeviceSheet.show(context),
          ),
          IconButton(
            tooltip: 'Sincronizar Red',
            icon: app.loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.sync),
            onPressed: () => context.read<AppState>().refreshAll(parallel: true),
          ),
        ],
      ),
      floatingActionButton: devices.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => AddDeviceSheet.show(context),
              icon: const Icon(Icons.add),
              label: const Text('Vincular'),
            ),
      body: devices.isEmpty
          ? _EmptyState(onAddTap: () => AddDeviceSheet.show(context))
          : Column(
              children: [
                // Barra de Filtros
                SizedBox(
                  height: 52,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    scrollDirection: Axis.horizontal,
                    itemCount: filters.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final f = filters[i];
                      final isSelected = selectedFilter == f;
                      return FilterChip(
                        label: Text(f),
                        selected: isSelected,
                        onSelected: (val) {
                          if (val) setState(() => selectedFilter = f);
                        },
                      );
                    },
                  ),
                ),
                const Divider(height: 1),

                // Lista de dispositivos
                Expanded(
                  child: filteredDevices.isEmpty
                      ? Center(
                          child: Text(
                            'No hay dispositivos en la categoría "$selectedFilter"',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () => context.read<AppState>().refreshAll(parallel: true),
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: filteredDevices.length,
                            itemBuilder: (context, i) {
                              final d = filteredDevices[i];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: dvw.SmartDeviceCard(
                                  device: d,
                                  onTap: () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => DeviceDetailView(deviceId: d.id),
                                      ),
                                    );
                                    if (!context.mounted) return;
                                    context.read<AppState>().refreshDevice(d);
                                  },
                                  onToggleQuick: (val) async {
                                    await context.read<AppState>().setRelay(d, 1, val);
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAddTap});
  final VoidCallback onAddTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.hub_outlined, size: 56, color: cs.primary),
            ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
            Gap.l,
            Text('Bienvenido a Mi Hogar Colmena', style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            Gap.s,
            Text(
              'No tienes dispositivos configurados aún. Añade luces, cámaras, enchufes o sensores por Wi-Fi directo o a través del Gateway Hub RF.',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            Gap.xl,
            AppButton(
              label: 'Añadir Primer Dispositivo',
              icon: Icons.add,
              onPressed: onAddTap,
            ).animate().fadeIn(delay: 200.ms),
          ],
        ),
      ),
    );
  }
}
