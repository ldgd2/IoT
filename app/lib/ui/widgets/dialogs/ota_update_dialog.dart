import 'package:flutter/material.dart';

class OtaUpdateDialog extends StatelessWidget {
  final String firmwareVersion;
  final double progress; // 0.0 to 1.0
  final String statusMessage;
  final bool isCompleted;
  final bool hasError;
  final VoidCallback? onClose;

  const OtaUpdateDialog({
    super.key,
    required this.firmwareVersion,
    required this.progress,
    required this.statusMessage,
    this.isCompleted = false,
    this.hasError = false,
    this.onClose,
  });

  static void show(
    BuildContext context, {
    required String version,
    required double progress,
    required String status,
    bool completed = false,
    bool error = false,
    VoidCallback? onClose,
  }) {
    showDialog(
      context: context,
      barrierDismissible: completed || error,
      builder: (_) => OtaUpdateDialog(
        firmwareVersion: version,
        progress: progress,
        statusMessage: status,
        isCompleted: completed,
        hasError: error,
        onClose: onClose,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text('Actualización OTA ($firmwareVersion)', style: const TextStyle(fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          if (hasError)
            Icon(Icons.error_outline, color: cs.error, size: 64)
          else if (isCompleted)
            const Icon(Icons.check_circle_outline, color: Color(0xFF00E5A8), size: 64)
          else
            SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(
                value: progress > 0 ? progress : null,
                strokeWidth: 6,
                backgroundColor: cs.surfaceContainerHigh,
                color: cs.primary,
              ),
            ),
          const SizedBox(height: 20),
          Text(
            statusMessage,
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w600, color: hasError ? cs.error : cs.onSurface),
          ),
          const SizedBox(height: 12),
          if (!isCompleted && !hasError)
            Text(
              '${(progress * 100).toInt()}% completado\nNo desconectes ni apagues el dispositivo.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
        ],
      ),
      actions: [
        if (isCompleted || hasError)
          FilledButton(
            onPressed: onClose ?? () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
      ],
    );
  }
}
