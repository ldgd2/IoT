import 'package:flutter/material.dart';

class ProvisioningBottomSheet extends StatefulWidget {
  final ValueChanged<Map<String, String>> onStartProvisioning;

  const ProvisioningBottomSheet({
    super.key,
    required this.onStartProvisioning,
  });

  static Future<void> show(BuildContext context, {required ValueChanged<Map<String, String>> onStart}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => ProvisioningBottomSheet(onStartProvisioning: onStart),
    );
  }

  @override
  State<ProvisioningBottomSheet> createState() => _ProvisioningBottomSheetState();
}

class _ProvisioningBottomSheetState extends State<ProvisioningBottomSheet> {
  final _nameCtrl = TextEditingController();
  final _ssidCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String _selectedType = 'RF Relay';

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: bottomInset + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Vincular Nuevo Dispositivo', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedType,
            decoration: const InputDecoration(labelText: 'Tipo de Dispositivo', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'RF Relay', child: Text('Relé RF 433MHz')),
              DropdownMenuItem(value: 'WiFi Switch', child: Text('Interruptor WiFi ESP32')),
              DropdownMenuItem(value: 'Sensor TH', child: Text('Sensor Temperatura/Humedad')),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _selectedType = val);
            },
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Nombre o Alias', border: OutlineInputBorder()),
          ),
          if (_selectedType == 'WiFi Switch') ...[
            const SizedBox(height: 14),
            TextField(
              controller: _ssidCtrl,
              decoration: const InputDecoration(labelText: 'Red WiFi (SSID)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _passCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Contraseña WiFi', border: OutlineInputBorder()),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.settings_input_antenna_rounded),
              label: const Text('Iniciar Vinculación'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                if (_nameCtrl.text.trim().isEmpty) return;
                widget.onStartProvisioning({
                  'type': _selectedType,
                  'name': _nameCtrl.text.trim(),
                  'ssid': _ssidCtrl.text.trim(),
                  'pass': _passCtrl.text.trim(),
                });
                Navigator.pop(context);
              },
            ),
          ),
        ],
      ),
    );
  }
}
