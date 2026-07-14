import 'dart:math' as math;
import 'package:flutter/material.dart';

class ColorPickerWheel extends StatefulWidget {
  final Color initialColor;
  final ValueChanged<Color> onColorSelected;
  final double size;

  const ColorPickerWheel({
    super.key,
    required this.initialColor,
    required this.onColorSelected,
    this.size = 240,
  });

  @override
  State<ColorPickerWheel> createState() => _ColorPickerWheelState();
}

class _ColorPickerWheelState extends State<ColorPickerWheel> {
  late Color _currentColor;

  @override
  void initState() {
    super.initState();
    _currentColor = widget.initialColor;
  }

  void _handleTouch(Offset localPos, double radius) {
    final dx = localPos.dx - radius;
    final dy = localPos.dy - radius;
    final dist = math.sqrt(dx * dx + dy * dy);

    if (dist <= radius) {
      double angle = math.atan2(dy, dx);
      if (angle < 0) angle += 2 * math.pi;

      final hue = (angle / (2 * math.pi)) * 360.0;
      final saturation = (dist / radius).clamp(0.0, 1.0);

      final color = HSVColor.fromAHSV(1.0, hue, saturation, 1.0).toColor();
      setState(() => _currentColor = color);
      widget.onColorSelected(color);
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.size / 2;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onPanUpdate: (d) => _handleTouch(d.localPosition, radius),
          onTapDown: (d) => _handleTouch(d.localPosition, radius),
          child: CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _ColorWheelPainter(),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _currentColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'HEX: #${_currentColor.toARGB32().toRadixString(16).toUpperCase().padLeft(8, '0').substring(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ],
    );
  }
}

class _ColorWheelPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    for (double angle = 0; angle < 360; angle += 1.0) {
      final rad = angle * math.pi / 180;
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white,
            HSVColor.fromAHSV(1.0, angle, 1.0, 1.0).toColor(),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        rad,
        0.03,
        true,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
