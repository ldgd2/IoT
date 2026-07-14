import 'package:flutter/material.dart';

class CriticalAlarmModal extends StatelessWidget {
  final String alarmTitle;
  final String alarmDetails;
  final String sourceLocation;
  final VoidCallback onDismissOrSilence;
  final VoidCallback? onTriggerProtocol;

  const CriticalAlarmModal({
    super.key,
    required this.alarmTitle,
    required this.alarmDetails,
    required this.sourceLocation,
    required this.onDismissOrSilence,
    this.onTriggerProtocol,
  });

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String details,
    required String location,
    required VoidCallback onDismiss,
    VoidCallback? onProtocol,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => CriticalAlarmModal(
        alarmTitle: title,
        alarmDetails: details,
        sourceLocation: location,
        onDismissOrSilence: onDismiss,
        onTriggerProtocol: onProtocol,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: const Color(0xFF6B0008),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_rounded,
                  color: Colors.white,
                  size: 96,
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'ALERTA CRÍTICA DE SEGURIDAD',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  letterSpacing: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                alarmTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 28,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Origen: $sourceLocation',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                alarmDetails,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              if (onTriggerProtocol != null) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.shield_outlined, color: Colors.red),
                    label: const Text(
                      'Activar Protocolo de Emergencia',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      onTriggerProtocol!();
                    },
                  ),
                ),
                const SizedBox(height: 14),
              ],
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white, width: 2),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    onDismissOrSilence();
                  },
                  child: const Text(
                    'Silenciar y Descartar Alarma',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
