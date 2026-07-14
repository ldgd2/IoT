import 'package:flutter/material.dart';
import '../widgets/inputs/color_picker_wheel.dart';
import '../widgets/inputs/dial_knob_input.dart';
import '../widgets/inputs/vertical_slider_input.dart';
import '../widgets/buttons/primary_action_button.dart';
import '../widgets/dialogs/ota_update_dialog.dart';

class DeviceDetailScreen extends StatefulWidget {
  final String deviceName;
  final String deviceType;

  const DeviceDetailScreen({
    super.key,
    required this.deviceName,
    required this.deviceType,
  });

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  Color _lightColor = const Color(0xFF00E5A8);
  double _targetTemp = 22.5;
  double _brightness = 0.8;
  bool _power = true;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.deviceName, style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.system_update_alt),
            tooltip: 'Actualizar Firmware OTA',
            onPressed: _startOtaDemo,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Estado de Alimentación', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(widget.deviceType, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                      ],
                    ),
                    Switch(
                      value: _power,
                      onChanged: (v) => setState(() => _power = v),
                      activeThumbColor: cs.primary,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            if (widget.deviceType.contains('WiFi') || widget.deviceType.contains('Interruptor')) ...[
              const Text('Control de Brillo y Color RGB', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ColorPickerWheel(
                    initialColor: _lightColor,
                    onColorSelected: (c) => setState(() => _lightColor = c),
                  ),
                  VerticalSliderInput(
                    value: _brightness,
                    onChanged: (b) => setState(() => _brightness = b),
                  ),
                ],
              ),
            ] else ...[
              const Text('Control de Termostato Digital', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 24),
              DialKnobInput(
                value: _targetTemp,
                onChanged: (t) => setState(() => _targetTemp = t),
              ),
            ],
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              child: PrimaryActionButton(
                label: 'Guardar Configuración en Hardware',
                icon: Icons.save_outlined,
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ajustes sincronizados con el dispositivo exitosamente.')),
                  );
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startOtaDemo() {
    double progress = 0.1;
    OtaUpdateDialog.show(
      context,
      version: 'v2.4.1-release',
      progress: progress,
      status: 'Descargando paquete de firmware desde el Hub...',
    );
  }
}
