// =============================================================
// lib/ui/flows/devices/network_health_view.dart
// Diagnóstico y monitor de salud de la red Colmena IoT
// =============================================================
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import 'package:bthapp/src/models/device.dart';

import 'package:bthapp/src/state/app_state.dart';

class NetworkHealthView extends StatefulWidget {
  const NetworkHealthView({super.key});

  @override
  State<NetworkHealthView> createState() => _NetworkHealthViewState();
}

class _NetworkHealthViewState extends State<NetworkHealthView> {
  bool testingHub = false;
  bool hubOnline = false;

  @override
  void initState() {
    super.initState();
    _testHub();
  }

  Future<void> _testHub() async {
    setState(() => testingHub = true);
    final app = context.read<AppState>();
    final ok = await app.checkHubOnline();
    if (mounted) {
      setState(() {
        hubOnline = ok;
        testingHub = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final devices = app.devices;

    final rfDevices = devices.where((d) => d.commMode == 'rf').toList();
    final wifiDevices = devices.where((d) => d.commMode == 'wifi').toList();
    final onlineCount = devices.where((d) => d.online).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnóstico de Red', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: 'Probar conectividad',
            icon: const Icon(Icons.refresh),
            onPressed: _testHub,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Tarjeta de estado del Gateway RF
          _HealthMetricCard(
            title: 'Central Colmena (Servidor Hogar)',
            subtitle: app.hubHost,
            statusText: testingHub ? 'Probando...' : (hubOnline ? 'ONLINE • Excelente' : 'DESCONECTADO'),
            statusColor: testingHub ? Colors.amberAccent : (hubOnline ? const Color(0xFF00E5A8) : Colors.redAccent),
            icon: Icons.hub_outlined,
            onAction: _testHub,
          ).animate().fadeIn().slideY(begin: 0.05, end: 0),
          const SizedBox(height: 16),

          // Resumen de nodos
          Row(
            children: [
              Expanded(
                child: _StatBox(
                  icon: Icons.podcasts,
                  label: 'Nodos RF (Colmena)',
                  value: '${rfDevices.length}',
                  color: const Color(0xFF00E5A8),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatBox(
                  icon: Icons.wifi,
                  label: 'Nodos Wi-Fi Directo',
                  value: '${wifiDevices.length}',
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ).animate().fadeIn(delay: 100.ms),
          const SizedBox(height: 12),
          _StatBox(
            icon: Icons.check_circle_outline,
            label: 'Dispositivos en Línea',
            value: '$onlineCount / ${devices.length}',
            color: const Color(0xFF00E5A8),
          ),
          const SizedBox(height: 16),

          // Distribución RSSI
          Text(
            'Fuerza de Señal por Dispositivo (RSSI)',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (devices.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text('No hay dispositivos registrados en la red.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ),
            )
          else
            for (final d in devices) ...[
              _SignalRow(device: d),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _HealthMetricCard extends StatelessWidget {
  const _HealthMetricCard({
    required this.title,
    required this.subtitle,
    required this.statusText,
    required this.statusColor,
    required this.icon,
    required this.onAction,
  });

  final String title;
  final String subtitle;
  final String statusText;
  final Color statusColor;
  final IconData icon;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: statusColor.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: statusColor, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                Text(subtitle, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.icon, required this.label, required this.value, required this.color});
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 10),
          Text(value, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _SignalRow extends StatelessWidget {
  const _SignalRow({required this.device});
  final Device device;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final rssi = device.rssi ?? (device.commMode == 'rf' ? -68 : -55);
    final isGood = rssi > -70;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(device.commMode == 'rf' ? Icons.podcasts : Icons.wifi, color: isGood ? const Color(0xFF00E5A8) : Colors.amberAccent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(device.alias ?? device.id, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('${device.kind ?? "Módulo"} • ${device.room ?? "General"}', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$rssi dBm', style: TextStyle(fontWeight: FontWeight.bold, color: isGood ? const Color(0xFF00E5A8) : Colors.orangeAccent)),
              Text(isGood ? 'Óptima' : 'Regular', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }
}
