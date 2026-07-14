import 'dart:math' as math;
import 'package:flutter/material.dart';

class DialKnobInput extends StatefulWidget {
  final double value;
  final double minValue;
  final double maxValue;
  final ValueChanged<double> onChanged;
  final String unit;

  const DialKnobInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.minValue = 16.0,
    this.maxValue = 32.0,
    this.unit = '°C',
  });

  @override
  State<DialKnobInput> createState() => _DialKnobInputState();
}

class _DialKnobInputState extends State<DialKnobInput> {
  late double _currentValue;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.value.clamp(widget.minValue, widget.maxValue);
  }

  void _updateFromOffset(Offset localPos, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final dx = localPos.dx - center.dx;
    final dy = localPos.dy - center.dy;

    double angle = math.atan2(dy, dx);
    if (angle < -math.pi / 2) {
      angle += 2 * math.pi;
    }

    // Map angle from [-pi/2, 3pi/2] to [0, 1]
    final fraction = ((angle + math.pi / 2) / (2 * math.pi)).clamp(0.0, 1.0);
    final val = widget.minValue + fraction * (widget.maxValue - widget.minValue);

    setState(() => _currentValue = val);
    widget.onChanged(val);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onPanUpdate: (d) => _updateFromOffset(d.localPosition, const Size(200, 200)),
      onTapDown: (d) => _updateFromOffset(d.localPosition, const Size(200, 200)),
      child: Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: cs.surfaceContainerHigh,
          boxShadow: [
            BoxShadow(
              color: cs.primary.withValues(alpha: 0.15),
              blurRadius: 16,
              spreadRadius: 4,
            ),
          ],
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4), width: 2),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_currentValue.toStringAsFixed(1)}${widget.unit}',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Termostato',
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
