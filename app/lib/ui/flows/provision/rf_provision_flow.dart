// =============================================================
// lib/ui/flows/provision/rf_provision_flow.dart
// Flujo de vinculación por Radiofrecuencia (RF Hub Colmena Gateway)
// Comunicación 100% real con endpoints REST del servidor Python
// =============================================================
import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../components/index.dart';
import '../../../src/models/device.dart';
import '../../../src/state/app_state.dart';

enum _RfStep { connectHub, chooseKind, scanOrInput, customize, success, error }

class RfProvisionFlow extends StatefulWidget {
  const RfProvisionFlow({super.key});

  @override
  State<RfProvisionFlow> createState() => _RfProvisionFlowState();
}

class _RfProvisionFlowState extends State<RfProvisionFlow> {
  _RfStep step = _RfStep.connectHub;
  final hostCtrl = TextEditingController();
  final nodeIdCtrl = TextEditingController();
  final nameCtrl = TextEditingController();

  String selectedKind = 'Luz';
  String selectedRoom = 'Sala';
  String progressMsg = '';
  List<Device> discoveredFromHub = [];
  Device? selectedHubDevice;

  final List<Map<String, dynamic>> categories = [
    {'name': 'Luz', 'icon': Icons.lightbulb_outline, 'desc': 'Bombillas, luces LED'},
    {'name': 'Enchufe', 'icon': Icons.power_outlined, 'desc': 'Tomas e interruptores de potencia'},
    {'name': 'Interruptor', 'icon': Icons.toggle_on_outlined, 'desc': 'Módulos de pared 1-4 relés'},
    {'name': 'Sensor Temperatura', 'icon': Icons.thermostat_outlined, 'desc': 'Clima, humedad y temperatura'},
    {'name': 'Sensor Movimiento', 'icon': Icons.sensors_outlined, 'desc': 'PIR y presencia'},
    {'name': 'Cámara', 'icon': Icons.videocam_outlined, 'desc': 'Cámaras de vigilancia RF/IP'},
    {'name': 'Persiana', 'icon': Icons.roller_shades, 'desc': 'Cortinas y motores'},
    {'name': 'Ventilador', 'icon': Icons.mode_fan_off_outlined, 'desc': 'Ventilación y HVAC'},
  ];

  final List<String> rooms = ['Sala', 'Dormitorio', 'Cocina', 'Exterior', 'Baño', 'Garaje'];

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    hostCtrl.text = app.hubHost;
  }

  @override
  void dispose() {
    hostCtrl.dispose();
    nodeIdCtrl.dispose();
    nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _verifyHubConnection() async {
    final host = hostCtrl.text.trim();
    if (host.isEmpty) {
      _snack('Ingresa la IP y puerto del Gateway Hub RF');
      return;
    }

    setState(() {
      progressMsg = 'Verificando conexión con Gateway Hub RF ($host)...';
    });

    final app = context.read<AppState>();
    await app.setHubHost(host);
    final ok = await app.checkHubOnline();

    if (!ok) {
      _snack('No se pudo conectar al Gateway en http://$host/api/stats. Verifica que el servidor esté activo.');
      return;
    }

    setState(() {
      step = _RfStep.chooseKind;
    });
  }

  Future<void> _startScanOnHub() async {
    setState(() {
      step = _RfStep.scanOrInput;
      progressMsg = 'Consultando dispositivos activos en el Gateway Hub...';
    });

    final app = context.read<AppState>();
    final list = await app.syncRfDevicesFromHub();
    setState(() {
      discoveredFromHub = list;
    });
  }

  void _proceedToCustomize(Device? devOrNull) {
    if (devOrNull != null) {
      selectedHubDevice = devOrNull;
      nodeIdCtrl.text = devOrNull.rfNodeId ?? devOrNull.id;
      nameCtrl.text = devOrNull.alias ?? '$selectedKind $selectedRoom';
    } else {
      selectedHubDevice = null;
      if (nodeIdCtrl.text.trim().isEmpty) {
        nodeIdCtrl.text = 'dev_${DateTime.now().millisecondsSinceEpoch % 1000}';
      }
      if (nameCtrl.text.trim().isEmpty) {
        nameCtrl.text = '$selectedKind $selectedRoom';
      }
    }
    setState(() => step = _RfStep.customize);
  }

  Future<void> _finishProvision() async {
    final nodeId = nodeIdCtrl.text.trim();
    final name = nameCtrl.text.trim();

    if (nodeId.isEmpty || name.isEmpty) {
      _snack('Por favor completa el identificador de nodo y el nombre.');
      return;
    }

    final app = context.read<AppState>();

    final dev = Device.fromRf(
      rfId: nodeId,
      name: name,
      hubHost: app.hubHost,
      typeName: selectedKind,
      room: selectedRoom,
      rssi: selectedHubDevice?.rssi ?? -65,
      state: selectedHubDevice?.state ?? {},
      online: true,
    );

    await app.addOrUpdateDevice(dev);
    await app.refreshDevice(dev);

    setState(() {
      step = _RfStep.success;
      progressMsg = '¡Dispositivo RF vinculado exitosamente con el Gateway Hub!';
    });
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vinculación por Radiofrecuencia')),
      body: PageTransitionSwitcher(
        duration: Dur.normal,
        transitionBuilder: (child, a, b) => SharedAxisTransition(
          animation: a,
          secondaryAnimation: b,
          transitionType: SharedAxisTransitionType.scaled,
          child: child,
        ),
        child: _buildCurrentStep(context),
      ),
    );
  }

  Widget _buildCurrentStep(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    switch (step) {
      case _RfStep.connectHub:
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const AppLabel('Paso 1: Conectar con Gateway Hub Colmena'),
            Gap.s,
            Text(
              'Ingresa la dirección (IP:Puerto) del servidor backend IoT RF Gateway. La app se comunicará por REST para enviar comandos RF433/nRF24/LoRa.',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            Gap.l,
            AppTextField(
              controller: hostCtrl,
              label: 'Dirección del Hub RF (ej. 192.168.1.100:5000)',
            ),
            Gap.xl,
            AppButton(
              label: 'Conectar al Gateway',
              icon: Icons.hub_outlined,
              onPressed: _verifyHubConnection,
            ),
          ],
        );

      case _RfStep.chooseKind:
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const AppLabel('Paso 2: ¿Qué tipo de dispositivo RF vas a vincular?'),
            Gap.s,
            Text(
              'Selecciona la categoría del dispositivo inalámbrico.',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            Gap.l,
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.45,
              ),
              itemCount: categories.length,
              itemBuilder: (context, i) {
                final cat = categories[i];
                final isSelected = selectedKind == cat['name'];
                return Container(
                  decoration: BoxDecoration(
                    color: isSelected ? cs.primary.withValues(alpha: 0.2) : cs.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isSelected ? cs.primary : Colors.transparent, width: 2),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => setState(() => selectedKind = cat['name']),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(cat['icon'] as IconData, color: isSelected ? cs.primary : cs.onSurface),
                          const Spacer(),
                          Text(cat['name'] as String, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                          Text(cat['desc'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: tt.bodySmall?.copyWith(fontSize: 10, color: cs.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ),
                ),
                );
              },
            ),
            Gap.xl,
            AppButton(
              label: 'Continuar',
              icon: Icons.arrow_forward,
              onPressed: _startScanOnHub,
            ),
          ],
        );

      case _RfStep.scanOrInput:
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const AppLabel('Paso 3: Identificador o Escaneo RF'),
            Gap.s,
            Text(
              'El Gateway Hub escucha paquetes RF. Selecciona un nodo detectado o ingresa el ID manualmente.',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            Gap.l,
            if (discoveredFromHub.isNotEmpty) ...[
              Text('Dispositivos reportados por el Gateway Hub:', style: tt.titleSmall),
              Gap.s,
              for (final d in discoveredFromHub)
                Card(
                  color: cs.surfaceContainerHighest,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.radio),
                    title: Text('${d.alias} (${d.rfNodeId})'),
                    subtitle: Text('Tipo: ${d.kind} | RSSI: ${d.rssi ?? -70} dBm'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _proceedToCustomize(d),
                  ),
                ),
              Gap.m,
              const Divider(),
              Gap.m,
            ],
            Text('Vincular por ID Manual de Nodo RF:', style: tt.titleSmall),
            Gap.s,
            AppTextField(
              controller: nodeIdCtrl,
              label: 'Node ID (ej. dev_001 o 101)',
            ),
            Gap.xl,
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Actualizar lista',
                    variant: BtnVariant.outline,
                    icon: Icons.refresh,
                    onPressed: _startScanOnHub,
                  ),
                ),
                Gap.m,
                Expanded(
                  child: AppButton(
                    label: 'Configurar',
                    icon: Icons.tune,
                    onPressed: () => _proceedToCustomize(null),
                  ),
                ),
              ],
            ),
          ],
        );

      case _RfStep.customize:
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const AppLabel('Paso 4: Personalización'),
            Gap.s,
            Text('Asigna un nombre legible y elige en qué habitación estará tu dispositivo.', style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            Gap.l,
            AppTextField(controller: nameCtrl, label: 'Nombre del dispositivo'),
            Gap.m,
            Text('Habitación / Ubicación:', style: tt.titleSmall),
            Gap.s,
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final r in rooms)
                  ChoiceChip(
                    label: Text(r),
                    selected: selectedRoom == r,
                    onSelected: (sel) {
                      if (sel) setState(() => selectedRoom = r);
                    },
                  ),
              ],
            ),
            Gap.xl,
            AppButton(
              label: 'Confirmar y Vincular',
              icon: Icons.check_circle,
              onPressed: _finishProvision,
            ),
          ],
        );

      case _RfStep.success:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _ResultBadge(success: true),
                Gap.m,
                Text(progressMsg, textAlign: TextAlign.center, style: tt.titleMedium),
                Gap.l,
                AppButton(
                  label: 'Volver al Dashboard',
                  icon: Icons.home,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        );

      case _RfStep.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _ResultBadge(success: false),
                Gap.m,
                Text(progressMsg, textAlign: TextAlign.center, style: tt.titleMedium),
                Gap.l,
                AppButton(
                  label: 'Reintentar',
                  variant: BtnVariant.outline,
                  onPressed: () => setState(() => step = _RfStep.connectHub),
                ),
              ],
            ),
          ),
        );
    }
  }
}

class _ResultBadge extends StatelessWidget {
  const _ResultBadge({required this.success});
  final bool success;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: success ? const Color(0xFF00E5A8).withValues(alpha: 0.2) : Colors.redAccent.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: Icon(
        success ? Icons.check_circle : Icons.error,
        size: 40,
        color: success ? const Color(0xFF00E5A8) : Colors.redAccent,
      ),
    );
  }
}

