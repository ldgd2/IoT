import 'package:flutter/material.dart';

class DeviceQuickControlCard extends StatelessWidget {
  final String deviceName;
  final String deviceType;
  final bool isOn;
  final ValueChanged<bool> onToggle;
  final VoidCallback? onTap;
  final IconData icon;

  const DeviceQuickControlCard({
    super.key,
    required this.deviceName,
    required this.deviceType,
    required this.isOn,
    required this.onToggle,
    this.onTap,
    this.icon = Icons.power_settings_new,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: isOn ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isOn ? cs.primary : cs.outlineVariant.withValues(alpha: 0.3),
          width: isOn ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap ?? () => onToggle(!isOn),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isOn
                          ? cs.primary.withValues(alpha: 0.15)
                          : cs.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      icon,
                      color: isOn ? cs.primary : cs.onSurfaceVariant,
                      size: 24,
                    ),
                  ),
                  Switch(
                    value: isOn,
                    onChanged: onToggle,
                    activeThumbColor: cs.primary,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    deviceName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isOn ? cs.primary : cs.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    deviceType,
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
