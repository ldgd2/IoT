import 'package:flutter/material.dart';

enum PtzDirection { up, down, left, right, center }

class PtzJoystickButton extends StatelessWidget {
  final ValueChanged<PtzDirection> onDirectionPressed;
  final VoidCallback? onZoomIn;
  final VoidCallback? onZoomOut;

  const PtzJoystickButton({
    super.key,
    required this.onDirectionPressed,
    this.onZoomIn,
    this.onZoomOut,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 48),
              _buildArrowBtn(context, Icons.keyboard_arrow_up_rounded, PtzDirection.up),
              const SizedBox(width: 48),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildArrowBtn(context, Icons.keyboard_arrow_left_rounded, PtzDirection.left),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => onDirectionPressed(PtzDirection.center),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: cs.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.my_location_rounded, color: cs.onPrimary, size: 24),
                ),
              ),
              const SizedBox(width: 12),
              _buildArrowBtn(context, Icons.keyboard_arrow_right_rounded, PtzDirection.right),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onZoomOut != null)
                IconButton(
                  icon: const Icon(Icons.zoom_out),
                  onPressed: onZoomOut,
                  color: cs.onSurfaceVariant,
                )
              else
                const SizedBox(width: 48),
              _buildArrowBtn(context, Icons.keyboard_arrow_down_rounded, PtzDirection.down),
              if (onZoomIn != null)
                IconButton(
                  icon: const Icon(Icons.zoom_in),
                  onPressed: onZoomIn,
                  color: cs.onSurfaceVariant,
                )
              else
                const SizedBox(width: 48),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildArrowBtn(BuildContext context, IconData icon, PtzDirection dir) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: () => onDirectionPressed(dir),
        customBorder: const CircleBorder(),
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          child: Icon(icon, color: cs.onSurface, size: 28),
        ),
      ),
    );
  }
}
