import 'package:flutter/material.dart';
import '../widgets/cards/node_status_card.dart';
import '../widgets/inputs/credential_text_field.dart';

class NetworkTopologyScreen extends StatefulWidget {
  const NetworkTopologyScreen({super.key});

  @override
  State<NetworkTopologyScreen> createState() => _NetworkTopologyScreenState();
}

class _NetworkTopologyScreenState extends State<NetworkTopologyScreen> {
  final _wifiCtrl = TextEditingController(text: 'Colmena_IoT_Mesh_5G');
  final _passCtrl = TextEditingController(text: 'secret_mesh_key_2026');

  final List<Map<String, dynamic>> _nodes = [
    {
      'name': 'Gateway RF 433MHz Principal',
      'ip': '192.168.1.10',
      'mac': 'AA:BB:CC:DD:EE:01',
      'ping': 4,
      'online': true,
    },
    {
      'name': 'Nodo Mesh Dormitorio',
      'ip': '192.168.1.15',
      'mac': 'AA:BB:CC:DD:EE:02',
      'ping': 12,
      'online': true,
    },
    {
      'name': 'Sensor Exterior Jardín',
      'ip': '192.168.1.22',
      'mac': 'AA:BB:CC:DD:EE:03',
      'ping': 0,
      'online': false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Credenciales de Red Mesh IoT', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          CredentialTextField(
            labelText: 'SSID de Red Mesh',
            controller: _wifiCtrl,
            prefixIcon: Icons.wifi,
          ),
          const SizedBox(height: 12),
          CredentialTextField(
            labelText: 'Clave de Acceso de Red',
            controller: _passCtrl,
            isPassword: true,
            prefixIcon: Icons.lock_outline,
          ),
          const SizedBox(height: 28),
          const Text('Topología de Nodos Activos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _nodes.length,
            itemBuilder: (ctx, idx) {
              final n = _nodes[idx];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: NodeStatusCard(
                  nodeName: n['name'],
                  ipAddress: n['ip'],
                  macAddress: n['mac'],
                  pingMs: n['ping'],
                  isOnline: n['online'],
                  onRefreshPing: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Haciendo ping a ${n['ip']}... OK (${n['ping']} ms)')),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
