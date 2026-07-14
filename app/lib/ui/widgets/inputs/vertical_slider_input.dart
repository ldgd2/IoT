import 'package:flutter/material.dart';

class VerticalSliderInput extends StatefulWidget {
  final double value; // 0.0 to 1.0
  final ValueChanged<double> onChanged;
  final String label;

  const VerticalSliderInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'Brillo',
  });

  @override
  State<VerticalSliderInput> createState() => _VerticalSliderInputState();
}

class _VerticalSliderInputState extends State<VerticalSliderInput> {
  late double _val;

  @override
  void initState() {
    super.initState();
    _val = widget.value.clamp(0.0, 1.0);
  }

  void _update(double dy, double height) {
    final pct = (1.0 - (dy / height)).clamp(0.0, 1.0);
    setState(() => _val = pct);
    widget.onChanged(pct);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LayoutBuilder(
          builder: (ctx, constraints) {
            const height = 200.0;
            return GestureDetector(
              onPanUpdate: (d) => _update(d.localPosition.dy, height),
              onTapDown: (d) => _update(d.localPosition.dy, height),
              child: Container(
                width: 64,
                height: height,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
                ),
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    Container(
                      width: 64,
                      height: height * _val,
                      decoration: BoxDecoration(
                        color: cs.primary,
                        borderRadius: BorderRadius.circular(32),
                      ),
                    ),
                    Positioned(
                      bottom: 16,
                      child: Icon(
                        Icons.lightbulb_outline,
                        color: _val > 0.3 ? cs.onPrimary : cs.onSurfaceVariant,
                        size: 28,
                      ),
                    ),
                    Positioned(
                      top: 16,
                      child: Text(
                        '${(_val * 100).toInt()}%',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _val > 0.85 ? cs.onPrimary : cs.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        Text(
          widget.label,
          style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}
