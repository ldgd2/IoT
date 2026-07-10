// =============================================================
// lib/ui/flows/devices/devices_widgets.dart
// Tarjetas Material 3 especializadas por tipo de dispositivo
// Muestra TODOS los relays/canales individualmente con switches
// =============================================================
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:bthapp/ui/components/index.dart';
import 'package:bthapp/src/models/device.dart';

// ──────────────────────────────────────────────────────────────
// SmartDeviceCard: tarjeta principal en la lista de dispositivos
// ──────────────────────────────────────────────────────────────
class SmartDeviceCard extends StatelessWidget {
  const SmartDeviceCard({
    super.key,
    required this.device,
    required this.switchNames,
    required this.onTap,
    required this.onToggleRelay,
  });

  final Device device;
  /// Nombres de cada canal: switchNames[0] = nombre canal 1, etc.
  final List<String> switchNames;
  final VoidCallback onTap;
  /// Llamado cuando el usuario toca el switch del canal (index1 = 1-based, val = nuevo estado)
  final Future<void> Function(int index1, bool val) onToggleRelay;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final kind = device.kind ?? 'Interruptor';
    final isRf = device.commMode == 'rf';
    final anyOn = device.relays.any((r) => r);
    final activeCount = device.relays.where((r) => r).length;

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Encabezado ──────────────────────────────────────
          Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: _kindColor(kind, anyOn, cs).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(_kindIcon(kind), color: _kindColor(kind, anyOn, cs), size: 24),
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
              const SizedBox(width: 12),
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
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        _Badge(
                          icon: isRf ? Icons.podcasts : Icons.wifi,
                          label: isRf ? 'RF Hub' : 'Wi-Fi',
                          color: isRf ? const Color(0xFF00E5A8) : cs.primary,
                        ),
                        const SizedBox(width: 5),
                        _Badge(
                          icon: Icons.room_outlined,
                          label: device.room ?? 'General',
                          color: cs.onSurfaceVariant,
                        ),
                        if (_supportsRelays(kind)) ...[
                          const SizedBox(width: 5),
                          _Badge(
                            icon: Icons.toggle_on_outlined,
                            label: '$activeCount/${device.relays.length} ON',
                            color: activeCount > 0 ? const Color(0xFF00E5A8) : cs.onSurfaceVariant,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Icono flecha "ver detalle"
              Icon(Icons.chevron_right, color: cs.onSurfaceVariant, size: 20),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // ── Contenido dinámico ───────────────────────────────
          _buildBody(context, kind, cs, tt),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms).scale(
          begin: const Offset(0.98, 0.98),
          end: const Offset(1, 1),
        );
  }

  // ── Cuerpo según tipo ────────────────────────────────────────
  Widget _buildBody(BuildContext context, String kind, ColorScheme cs, TextTheme tt) {
    switch (kind) {
      // ── Sensores: solo lectura ───────────────────────────────
      case 'Sensor Temperatura':
        final temp = (device.state['temperature'] as num?)?.toDouble() ?? 24.5;
        final hum  = (device.state['humidity']    as num?)?.toDouble() ?? 48.0;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _SensorStat(icon: Icons.thermostat,      label: 'Temperatura', value: '${temp.toStringAsFixed(1)} °C', color: Colors.orangeAccent),
            Container(width: 1, height: 28, color: cs.outlineVariant),
            _SensorStat(icon: Icons.water_drop_outlined, label: 'Humedad', value: '${hum.toStringAsFixed(0)} %',   color: Colors.lightBlueAccent),
          ],
        );

      case 'Sensor Movimiento':
        final motion = device.state['motion'] == true;
        return Row(
          children: [
            Icon(
              motion ? Icons.directions_run : Icons.verified_user_outlined,
              size: 18,
              color: motion ? Colors.redAccent : const Color(0xFF00E5A8),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                motion ? '¡Movimiento detectado!' : 'Zona despejada',
                style: tt.bodySmall?.copyWith(
                  color: motion ? Colors.redAccent : cs.onSurfaceVariant,
                  fontWeight: motion ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
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
              Expanded(child: Text('Transmisión RF/IP activa', style: tt.labelSmall)),
              Icon(Icons.fullscreen, size: 18, color: cs.onSurfaceVariant),
            ],
          ),
        );

      case 'Persiana':
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _MiniActionBtn(icon: Icons.keyboard_arrow_up,   label: 'Subir', onTap: () {}),
            _MiniActionBtn(icon: Icons.stop_circle_outlined, label: 'Parar', onTap: () {}),
            _MiniActionBtn(icon: Icons.keyboard_arrow_down, label: 'Bajar', onTap: () {}),
          ],
        );

      // ── Relays: Luz, Dimmer, Enchufe, Interruptor, Ventilador ─
      default:
        return _buildRelayToggles(context, kind, cs, tt);
    }
  }

  // ── Todos los relays con switch individual ───────────────────
  Widget _buildRelayToggles(BuildContext context, String kind, ColorScheme cs, TextTheme tt) {
    final relays = device.relays;
    if (relays.isEmpty) return const SizedBox.shrink();

    // Si solo hay 1 relay → fila compacta horizontal
    if (relays.length == 1) {
      return _SingleRelayRow(
        name: switchNames.isNotEmpty ? switchNames[0] : 'Canal 1',
        isOn: relays[0],
        online: device.online,
        kind: kind,
        cs: cs,
        tt: tt,
        onToggle: (v) => onToggleRelay(1, v),
      );
    }

    // Si hay varios relays → grid 2 columnas
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 2.6,
      ),
      itemCount: relays.length,
      itemBuilder: (context, i) {
        final name = i < switchNames.length ? switchNames[i] : 'Canal ${i + 1}';
        return _RelayChip(
          index1: i + 1,
          name: name,
          isOn: relays[i],
          online: device.online,
          kind: kind,
          cs: cs,
          tt: tt,
          onToggle: (v) => onToggleRelay(i + 1, v),
        );
      },
    );
  }

  bool _supportsRelays(String kind) =>
      kind == 'Luz' || kind == 'Dimmer' || kind == 'Enchufe' || kind == 'Interruptor' || kind == 'Ventilador';

  IconData _kindIcon(String kind) {
    switch (kind) {
      case 'Luz':
      case 'Dimmer':        return Icons.lightbulb_outline;
      case 'Enchufe':       return Icons.power_outlined;
      case 'Sensor Temperatura': return Icons.thermostat_outlined;
      case 'Sensor Movimiento':  return Icons.sensors_outlined;
      case 'Cámara':        return Icons.videocam_outlined;
      case 'Persiana':      return Icons.roller_shades;
      case 'Ventilador':    return Icons.mode_fan_off_outlined;
      default:              return Icons.toggle_on_outlined;
    }
  }

  Color _kindColor(String kind, bool isOn, ColorScheme cs) {
    if (!isOn && _supportsRelays(kind)) return cs.onSurfaceVariant;
    switch (kind) {
      case 'Luz':
      case 'Dimmer':        return Colors.amberAccent;
      case 'Sensor Temperatura': return Colors.orangeAccent;
      case 'Sensor Movimiento':  return Colors.redAccent;
      case 'Cámara':        return Colors.lightBlueAccent;
      case 'Persiana':      return Colors.purpleAccent;
      default:              return const Color(0xFF00E5A8);
    }
  }
}

// ──────────────────────────────────────────────────────────────
// Relay chip (para grids con 2+ relays)
// ──────────────────────────────────────────────────────────────
class _RelayChip extends StatefulWidget {
  const _RelayChip({
    required this.index1,
    required this.name,
    required this.isOn,
    required this.online,
    required this.kind,
    required this.cs,
    required this.tt,
    required this.onToggle,
  });
  final int index1;
  final String name;
  final bool isOn;
  final bool online;
  final String kind;
  final ColorScheme cs;
  final TextTheme tt;
  final Future<void> Function(bool) onToggle;

  @override
  State<_RelayChip> createState() => _RelayChipState();
}

class _RelayChipState extends State<_RelayChip> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final onColor = const Color(0xFF00E5A8);
    final bgColor = widget.isOn
        ? onColor.withValues(alpha: 0.15)
        : widget.cs.surfaceContainerHighest.withValues(alpha: 0.6);
    final borderColor = widget.isOn ? onColor : widget.cs.outlineVariant;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: widget.online && !_loading
              ? () async {
                  setState(() => _loading = true);
                  await widget.onToggle(!widget.isOn);
                  if (mounted) setState(() => _loading = false);
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                if (_loading)
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: onColor))
                else
                  Icon(
                    widget.isOn ? Icons.toggle_on : Icons.toggle_off,
                    size: 20,
                    color: widget.isOn ? onColor : widget.cs.onSurfaceVariant,
                  ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: widget.tt.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: widget.isOn ? onColor : widget.cs.onSurface,
                        ),
                      ),
                      Text(
                        widget.isOn ? 'Encendido' : 'Apagado',
                        style: widget.tt.bodySmall?.copyWith(
                          fontSize: 10,
                          color: widget.isOn ? onColor.withValues(alpha: 0.8) : widget.cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Fila de relay único compacta
// ──────────────────────────────────────────────────────────────
class _SingleRelayRow extends StatefulWidget {
  const _SingleRelayRow({
    required this.name,
    required this.isOn,
    required this.online,
    required this.kind,
    required this.cs,
    required this.tt,
    required this.onToggle,
  });
  final String name;
  final bool isOn;
  final bool online;
  final String kind;
  final ColorScheme cs;
  final TextTheme tt;
  final Future<void> Function(bool) onToggle;

  @override
  State<_SingleRelayRow> createState() => _SingleRelayRowState();
}

class _SingleRelayRowState extends State<_SingleRelayRow> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final onColor = const Color(0xFF00E5A8);
    return Row(
      children: [
        Icon(
          widget.isOn ? Icons.power : Icons.power_off_outlined,
          color: widget.isOn ? onColor : widget.cs.onSurfaceVariant,
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            widget.name,
            style: widget.tt.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: widget.isOn ? onColor : widget.cs.onSurface,
            ),
          ),
        ),
        Text(
          widget.isOn ? 'Encendido' : 'Apagado',
          style: widget.tt.bodySmall?.copyWith(
            color: widget.isOn ? onColor : widget.cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
        _loading
            ? SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 2, color: onColor))
            : Switch(
                value: widget.isOn,
                onChanged: widget.online
                    ? (v) async {
                        setState(() => _loading = true);
                        await widget.onToggle(v);
                        if (mounted) setState(() => _loading = false);
                      }
                    : null,
              ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Widgets de apoyo
// ──────────────────────────────────────────────────────────────
class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

// ──────────────────────────────────────────────────────────────
// DeviceHeader (usado en DeviceDetailView)
// ──────────────────────────────────────────────────────────────
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

// ──────────────────────────────────────────────────────────────
// SwitchCard (usado en DeviceDetailView para la lista de relays)
// ──────────────────────────────────────────────────────────────
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
    final onColor = const Color(0xFF00E5A8);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: value ? onColor.withValues(alpha: 0.08) : cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: value ? onColor.withValues(alpha: 0.4) : cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            Icon(
              value ? Icons.toggle_on : Icons.toggle_off,
              color: value ? onColor : cs.outline,
              size: 26,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: value ? onColor : cs.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Renombrar',
              icon: const Icon(Icons.edit, size: 18),
              onPressed: onEdit,
            ),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}
