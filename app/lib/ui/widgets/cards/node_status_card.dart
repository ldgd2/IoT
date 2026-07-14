import 'package:flutter/material.dart';

class NodeStatusCard extends StatelessWidget {
  final String nodeName;
  final String ipAddress;
  final String macAddress;
  final int pingMs;
  final bool isOnline;
  final VoidCallback? onRefreshPing;

  const NodeStatusCard({
    super.key,
    required this.nodeName,
    required this.ipAddress,
    required this.macAddress,
    required this.pingMs,
    required this.isOnline,
    this.onRefreshPing,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final statusColor = isOnline ? const Color(0xFF00E5A8) : cs.error;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withValues(alpha: 0.4),
                        blurRadius: 6,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    nodeName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isOnline ? '$pingMs ms' : 'OFFLINE',
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('IP: $ipAddress', style: TextStyle(fontSize: 13, color: cs.onSurface)),
                    const SizedBox(height: 2),
                    Text('MAC: $macAddress', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  ],
                ),
                if (onRefreshPing != null)
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    onPressed: onRefreshPing,
                    tooltip: 'Hacer ping',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
