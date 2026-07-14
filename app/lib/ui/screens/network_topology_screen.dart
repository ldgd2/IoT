import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bthapp/src/state/app_state.dart';
import '../widgets/cards/node_status_card.dart';
import '../widgets/inputs/credential_text_field.dart';
import '../widgets/buttons/primary_action_button.dart';

class NetworkTopologyScreen extends StatefulWidget {
  const NetworkTopologyScreen({super.key});

  @override
  State<NetworkTopologyScreen> createState() => _NetworkTopologyScreenState();
}

class _NetworkTopologyScreenState extends State<NetworkTopologyScreen> {
  final _wifiCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final app = context.read<AppState>();
      _wifiCtrl.text = app.hubHost;
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final devices = app.devices;
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Parámetros y Gateway del Hub', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  CredentialTextField(
                    labelText: 'Dirección o Host del Hub RF/Wi-Fi',
                    controller: _wifiCtrl,
                    prefixIcon: Icons.router_outlined,
                  ),
                  const SizedBox(height: 12),
                  CredentialTextField(
                    labelText: 'Clave o Token de Seguridad de Red',
                    controller: _passCtrl,
                    isPassword: true,
                    prefixIcon: Icons.lock_outline,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: PrimaryActionButton(
                      label: 'Actualizar Conexión de Red',
                      icon: Icons.sync,
                      onPressed: () async {
                        final newHost = _wifiCtrl.text.trim();
                        if (newHost.isNotEmpty) {
                          await app.setHubHost(newHost);
                          if (!context.mounted) return;
                          await app.refreshAll(parallel: true);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Sincronizando con Hub central en $newHost...')),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Topología de Nodos Activos (${devices.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Sincronizar latencia',
                onPressed: () => app.refreshAll(parallel: true),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (devices.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.hub_outlined, size: 48, color: cs.onSurfaceVariant),
                      const SizedBox(height: 12),
                      const Text('No hay nodos descubiertos en la red', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 6),
                      Text('Conecta el Hub central o escanea dispositivos Wi-Fi con el protocolo mDNS.', textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: devices.length,
              itemBuilder: (ctx, idx) {
                final d = devices[idx];
                final pingVal = d.rssi != null ? (d.rssi!.abs() ~/ 2) : (d.online ? 15 : 0);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: NodeStatusCard(
                    nodeName: d.alias ?? d.id,
                    ipAddress: '${d.ip}:${d.port}',
                    macAddress: d.mdns,
                    pingMs: pingVal,
                    isOnline: d.online,
                    onRefreshPing: () async {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Haciendo ping al nodo ${d.ip}...')),
                      );
                      await app.refreshDevice(d);
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
