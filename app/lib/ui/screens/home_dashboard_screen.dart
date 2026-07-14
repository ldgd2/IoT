import 'package:flutter/material.dart';
import '../widgets/cards/device_quick_control_card.dart';
import '../widgets/cards/environment_summary_card.dart';
import '../widgets/buttons/scene_trigger_button.dart';
import '../widgets/dialogs/provisioning_bottom_sheet.dart';
import 'device_detail_screen.dart';

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  bool _livingLight = true;
  bool _kitchenSwitch = false;
  bool _garageRelay = true;
  String _activeScene = 'Modo Noche';

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Resumen Ambiental',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                tooltip: 'Vincular hardware',
                onPressed: () {
                  ProvisioningBottomSheet.show(context, onStart: (data) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Vinculando: ${data['name']} (${data['type']})...')),
                    );
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: EnvironmentSummaryCard(
                  temperature: 23.4,
                  humidity: 48.0,
                  roomName: 'Sala de Estar',
                  onTap: () {},
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Escenas Rápidas',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          SceneTriggerButton(
            title: 'Modo Noche',
            subtitle: 'Apaga luces y activa alarma perimetral',
            icon: Icons.nightlight_round,
            isActive: _activeScene == 'Modo Noche',
            onTap: () => setState(() => _activeScene = 'Modo Noche'),
          ),
          const SizedBox(height: 12),
          SceneTriggerButton(
            title: 'Modo Salida',
            subtitle: 'Apaga todo y bloquea cerraduras',
            icon: Icons.lock_outline,
            isActive: _activeScene == 'Modo Salida',
            onTap: () => setState(() => _activeScene = 'Modo Salida'),
          ),
          const SizedBox(height: 24),
          const Text(
            'Control Rápido de Hardware',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 1.15,
            children: [
              DeviceQuickControlCard(
                deviceName: 'Luz Principal Sala',
                deviceType: 'Interruptor WiFi',
                isOn: _livingLight,
                icon: Icons.lightbulb_outline,
                onToggle: (v) => setState(() => _livingLight = v),
                onTap: () => _openDeviceDetail('Luz Principal Sala', 'Interruptor WiFi'),
              ),
              DeviceQuickControlCard(
                deviceName: 'Extractor Cocina',
                deviceType: 'Interruptor WiFi',
                isOn: _kitchenSwitch,
                icon: Icons.air_rounded,
                onToggle: (v) => setState(() => _kitchenSwitch = v),
                onTap: () => _openDeviceDetail('Extractor Cocina', 'Interruptor WiFi'),
              ),
              DeviceQuickControlCard(
                deviceName: 'Portón Garaje',
                deviceType: 'Relé RF 433MHz',
                isOn: _garageRelay,
                icon: Icons.garage_outlined,
                onToggle: (v) => setState(() => _garageRelay = v),
                onTap: () => _openDeviceDetail('Portón Garaje', 'Relé RF 433MHz'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openDeviceDetail(String name, String type) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DeviceDetailScreen(deviceName: name, deviceType: type),
      ),
    );
  }
}
