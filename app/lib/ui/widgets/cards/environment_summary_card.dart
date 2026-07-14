import 'package:flutter/material.dart';

class EnvironmentSummaryCard extends StatelessWidget {
  final double temperature;
  final double humidity;
  final String roomName;
  final VoidCallback? onTap;

  const EnvironmentSummaryCard({
    super.key,
    required this.temperature,
    required this.humidity,
    required this.roomName,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    roomName.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  Icon(Icons.thermostat_outlined, color: cs.secondary, size: 20),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildMetric(
                      context,
                      'Temperatura',
                      '${temperature.toStringAsFixed(1)} °C',
                      Icons.device_thermostat,
                      cs.secondary,
                    ),
                  ),
                  Container(width: 1, height: 40, color: cs.outlineVariant.withValues(alpha: 0.3)),
                  Expanded(
                    child: _buildMetric(
                      context,
                      'Humedad',
                      '${humidity.toStringAsFixed(0)} %',
                      Icons.water_drop_outlined,
                      const Color(0xFF3DA9FC),
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

  Widget _buildMetric(BuildContext context, String label, String value, IconData icon, Color color) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}
