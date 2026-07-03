// =============================================================
// lib/ui/flows/devices/devices_widgets.dart
// Tarjetas Material 3 especializadas por tipo de dispositivo
// =============================================================
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:bthapp/ui/components/index.dart';
import 'package:bthapp/src/models/device.dart';

class SmartDeviceCard extends StatelessWidget {
  const SmartDeviceCard({
    super.key,
    required this.device,
    required this.onTap,
    required this.onToggleQuick,
  });

  final Device device;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggleQuick;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final kind = device.kind ?? 'Interruptor';
    final isRf = device.commMode == 'rf';
    final isOn = device.relays.isNotEmpty ? device.relays.first : false;

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado
          Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _getKindColor(kind, isOn, cs).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(_getKindIcon(kind), color: _getKindColor(kind, isOn, cs), size: 24),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: device.online ? const Color(0xFF00E5A8) : Colors.grey,
                        shape: BoxShape.circle,
                        border: Border.all(color: cs.surface, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.alias ?? device.id,
                      style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _Badge(
                          icon: isRf ? Icons.podcasts : Icons.wifi,
                          label: isRf ? 'RF Hub' : 'Wi-Fi',
                          color: isRf ? const Color(0xFF00E5A8) : cs.primary,
                        ),
                        const SizedBox(width: 6),
                        _Badge(
                          icon: Icons.room_outlined,
                          label: device.room ?? 'General',
                          color: cs.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_supportsToggle(kind))
                Switch(
                  value: isOn,
                  onChanged: device.online ? onToggleQuick : null,
                ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Contenido dinámico específico por categoría
          _buildSpecializedWidget(context, kind, cs, tt),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms).scale(begin: const Offset(0.98, 0.98), end: const Offset(1, 1));
  }

  Widget _buildSpecializedWidget(BuildContext context, String kind, ColorScheme cs, TextTheme tt) {
    switch (kind) {
      case 'Luz':
      case 'Dimmer':
        final brightness = (device.state['brightness'] as num?)?.toInt() ?? (device.relays.first ? 100 : 0);
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.brightness_medium, size: 16, color: cs.onSurfaceVariant),
                const SizedBox(width: 6),
                Text('Brillo actual: $brightness%', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
            Text(device.relays.first ? 'Encendido' : 'Apagado', style: tt.labelMedium?.copyWith(color: device.relays.first ? const Color(0xFF00E5A8) : cs.onSurfaceVariant)),
          ],
        );

      case 'Sensor Temperatura':
        final temp = (device.state['temperature'] as num?)?.toDouble() ?? 24.5;
        final hum = (device.state['humidity'] as num?)?.toDouble() ?? 48.0;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _SensorStat(icon: Icons.thermostat, label: 'Temperatura', value: '${temp.toStringAsFixed(1)} °C', color: Colors.orangeAccent),
            Container(width: 1, height: 24, color: cs.outlineVariant),
            _SensorStat(icon: Icons.water_drop_outlined, label: 'Humedad', value: '${hum.toStringAsFixed(0)}% RH', color: Colors.lightBlueAccent),
          ],
        );

      case 'Sensor Movimiento':
        final motion = device.state['motion'] == true;
        return Row(
          children: [
            Icon(motion ? Icons.directions_run : Icons.verified_user_outlined, size: 18, color: motion ? Colors.redAccent : const Color(0xFF00E5A8)),
            const SizedBox(width: 8),
            Text(motion ? '¡Movimiento detectado en la zona!' : 'Zona despejada sin movimiento', style: tt.bodySmall?.copyWith(color: motion ? Colors.redAccent : cs.onSurfaceVariant, fontWeight: motion ? FontWeight.bold : FontWeight.normal)),
          ],
        );

      case 'Cámara':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text('Transmisión RF/IP en vivo conectada', style: tt.labelSmall),
              const Spacer(),
              Icon(Icons.fullscreen, size: 18, color: cs.onSurfaceVariant),
            ],
          ),
        );

      case 'Persiana':
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _MiniActionBtn(icon: Icons.keyboard_arrow_up, label: 'Subir', onTap: () {}),
            _MiniActionBtn(icon: Icons.stop_circle_outlined, label: 'Parar', onTap: () {}),
            _MiniActionBtn(icon: Icons.keyboard_arrow_down, label: 'Bajar', onTap: () {}),
          ],
        );

      case 'Enchufe':
      default:
        final power = (device.state['power'] as num?)?.toDouble() ?? (device.relays.first ? 115.0 : 0.0);
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.bolt, size: 16, color: Colors.amberAccent),
                const SizedBox(width: 4),
                Text('Consumo actual: ${power.toStringAsFixed(1)} W', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
            Text('${device.relays.where((e) => e).length}/${device.relays.length} activos', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          ],
        );
    }
  }

  bool _supportsToggle(String kind) {
    return kind == 'Luz' || kind == 'Dimmer' || kind == 'Enchufe' || kind == 'Interruptor' || kind == 'Ventilador';
  }

  IconData _getKindIcon(String kind) {
    switch (kind) {
      case 'Luz':
      case 'Dimmer':
        return Icons.lightbulb_outline;
      case 'Enchufe':
        return Icons.power_outlined;
      case 'Sensor Temperatura':
        return Icons.thermostat_outlined;
      case 'Sensor Movimiento':
        return Icons.sensors_outlined;
      case 'Cámara':
        return Icons.videocam_outlined;
      case 'Persiana':
        return Icons.roller_shades;
      case 'Ventilador':
        return Icons.mode_fan_off_outlined;
      default:
        return Icons.toggle_on_outlined;
    }
  }

  Color _getKindColor(String kind, bool isOn, ColorScheme cs) {
    if (!isOn && _supportsToggle(kind)) return cs.onSurfaceVariant;
    switch (kind) {
      case 'Luz':
      case 'Dimmer':
        return Colors.amberAccent;
      case 'Sensor Temperatura':
        return Colors.orangeAccent;
      case 'Sensor Movimiento':
        return Colors.redAccent;
      case 'Cámara':
        return Colors.lightBlueAccent;
      case 'Persiana':
        return Colors.purpleAccent;
      default:
        return const Color(0xFF00E5A8);
    }
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _SensorStat extends StatelessWidget {
  const _SensorStat({required this.icon, required this.label, required this.value, required this.color});
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            Text(label, style: tt.bodySmall?.copyWith(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      ],
    );
  }
}

class _MiniActionBtn extends StatelessWidget {
  const _MiniActionBtn({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 16, color: cs.primary),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 12, color: cs.primary)),
          ],
        ),
      ),
    );
  }
}

class DeviceHeader extends StatelessWidget {
  const DeviceHeader({
    super.key,
    required this.kind,
    required this.online,
    required this.ip,
    required this.onKindTap,
  });

  final String kind;
  final bool online;
  final String ip;
  final VoidCallback onKindTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppCard(
      child: Row(
        children: [
          Stack(children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: cs.primary.withValues(alpha: 0.15),
              child: Icon(Icons.memory_outlined, color: cs.primary),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: online ? const Color(0xFF00E5A8) : Colors.grey,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 1),
                ),
              ),
            ),
          ]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tipo: $kind', style: Theme.of(context).textTheme.titleMedium),
                Text(ip, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onKindTap,
            icon: const Icon(Icons.tune),
            label: const Text('Cambiar'),
          ),
        ],
      ),
    );
  }
}

class SwitchCard extends StatelessWidget {
  const SwitchCard({
    super.key,
    required this.title,
    required this.value,
    this.onChanged,
    this.onEdit,
  });

  final String title;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppCard(
      child: Row(
        children: [
          Icon(value ? Icons.toggle_on : Icons.toggle_off, color: value ? cs.primary : cs.outline),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
          IconButton(
            tooltip: 'Renombrar',
            icon: const Icon(Icons.edit),
            onPressed: onEdit,
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
