// =============================================================
// lib/ui/flows/provision/add_device_sheet.dart
// Modal Material 3 para elegir modo de vinculación (Hotspot vs RF)
// =============================================================
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../components/index.dart';
import 'provision_flow.dart';
import 'rf_provision_flow.dart';

class AddDeviceSheet extends StatelessWidget {
  const AddDeviceSheet({super.key});

  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const AddDeviceSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Añadir Dispositivo',
              style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0),
            Gap.s,
            Text(
              'Selecciona el método de comunicación del dispositivo que deseas vincular a tu red.',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ).animate().fadeIn(delay: 100.ms, duration: 300.ms),
            Gap.l,

            // Opcion 1: Hotspot Wi-Fi
            _OptionCard(
              title: 'Conexión Wi-Fi Directa',
              subtitle: 'Conecta y configura nuevos dispositivos inteligentes a través de su red inalámbrica temporal.',
              icon: Icons.wifi_tethering,
              iconColor: cs.primary,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProvisionFlow()),
                );
              },
            ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.05, end: 0),
            Gap.m,

            // Opcion 2: Radiofrecuencia RF
            _OptionCard(
              title: 'Vinculación Inalámbrica (Central Colmena)',
              subtitle: 'Conecta sensores, luces, interruptores y módulos automáticos gestionados por tu Central de forma instantánea.',
              icon: Icons.podcasts_rounded,
              iconColor: const Color(0xFF00E5A8),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RfProvisionFlow()),
                );
              },
            ).animate().fadeIn(delay: 300.ms).slideX(begin: -0.05, end: 0),
            Gap.m,
          ],
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 16, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
