// =============================================================
// lib/ui/flows/provision/rf_provision_flow.dart
// Flujo de vinculación por Radiofrecuencia (RF Hub Colmena Gateway)
// Comunicación 100% real con endpoints REST del servidor Python
// =============================================================
import 'dart:async';
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
  
  Timer? _pairingTimer;
  Map<String, dynamic>? pairingApiDevice;
  bool isPairingTimeout = false;
  double pairingElapsedSeconds = 0.0;

  final List<Map<String, dynamic>> categories = [
    {'name': 'Luz', 'icon': Icons.lightbulb_outline, 'desc': 'Bombillas, luces LED'},
    {'name': 'Enchufe', 'icon': Icons.power_outlined, 'desc': 'Tomas e interruptores de potencia'},
    {'name': 'Interruptor', 'icon': Icons.toggle_on_outlined, 'desc': 'Interruptores de pared 1-4 botones'},
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (app.hubHost.isNotEmpty) {
        _verifyHubConnection(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _pairingTimer?.cancel();
    final app = context.read<AppState>();
    app.stopRfPairing();
    hostCtrl.dispose();
    nodeIdCtrl.dispose();
    nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _verifyHubConnection({bool silent = false}) async {
    final host = hostCtrl.text.trim();
    if (host.isEmpty) {
      if (!silent) _snack('Ingresa la dirección web de tu Central Colmena');
      return;
    }

    if (!silent) {
      setState(() {
        progressMsg = 'Verificando conexión con tu Central Colmena ($host)...';
      });
    }

    final app = context.read<AppState>();
    await app.setHubHost(host);
    final ok = await app.checkHubOnline();

    if (!ok) {
      if (!silent) {
        _snack('No se pudo conectar con la Central en http://$host. Verifica que esté encendida.');
      }
      return;
    }

    if (mounted) {
      setState(() {
        step = _RfStep.chooseKind;
      });
    }
  }

  Future<void> _startScanOnHub() async {
    setState(() {
      step = _RfStep.scanOrInput;
      isPairingTimeout = false;
      pairingElapsedSeconds = 0.0;
      progressMsg = 'Buscando dispositivos y activando modo de vinculación automática...';
    });

    final app = context.read<AppState>();
    await app.startRfPairing();
    final list = await app.syncRfDevicesFromHub();
    if (mounted) {
      setState(() {
        discoveredFromHub = list;
      });
    }

    _pairingTimer?.cancel();
    _pairingTimer = Timer.periodic(const Duration(milliseconds: 1000), (timer) async {
      if (step != _RfStep.scanOrInput) {
        timer.cancel();
        return;
      }
      if (mounted) {
        setState(() {
          pairingElapsedSeconds += 1.0;
          if (pairingElapsedSeconds >= 50.0) {
            isPairingTimeout = true;
            pairingElapsedSeconds = 50.0;
          }
        });
      }
      if (isPairingTimeout) {
        timer.cancel();
        await app.stopRfPairing();
        return;
      }

      final status = await app.checkRfPairingStatus();
      if (status != null) {
        if (status['status'] == 'timeout' || (status['elapsed'] != null && (status['elapsed'] as num) >= 50)) {
          timer.cancel();
          if (mounted) {
            setState(() {
              isPairingTimeout = true;
              pairingElapsedSeconds = 50.0;
            });
          }
          await app.stopRfPairing();
          return;
        } else if (status['elapsed'] != null) {
          final sElapsed = (status['elapsed'] as num).toDouble();
          if (sElapsed > pairingElapsedSeconds && sElapsed <= 50.0) {
            if (mounted) {
              setState(() {
                pairingElapsedSeconds = sElapsed;
              });
            }
          }
        }

        if (status['status'] == 'success' && status['last_device'] != null) {
          timer.cancel();
          if (mounted) {
            setState(() {
              pairingApiDevice = Map<String, dynamic>.from(status['last_device'] as Map);
              progressMsg = '¡Nuevo dispositivo detectado automáticamente!';
            });
          }
        }
      }
    });
  }

  void _proceedToCustomize(Device? devOrNull) {
    _pairingTimer?.cancel();
    final app = context.read<AppState>();
    app.stopRfPairing();

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

    try {
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

      // 1) Registrar en la base de datos SQLite del Hub
      final savedOnHub = await app.registerDeviceOnHub(dev);

      // 2) Guardar localmente en SharedPreferences (siempre)
      await app.addOrUpdateDevice(dev);
      await app.refreshDevice(dev);

      setState(() {
        step = _RfStep.success;
        progressMsg = savedOnHub
            ? '¡Dispositivo RF vinculado y guardado en el Hub!'
            : '¡Vinculado localmente! (El Hub no estaba disponible — se sincronizará cuando conectes)';
      });
    } catch (e) {
      setState(() {
        step = _RfStep.error;
        progressMsg = 'Error al guardar el dispositivo: $e';
      });
    }
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
            const AppLabel('Paso 1: Conectar con tu Central Colmena'),
            Gap.s,
            Text(
              'Puedes ingresar la IP local de tu Hub (ej. 192.168.xxx.xxx:5000) o la dirección de tu Servidor en la Nube (ej. 157.173.102.129:8000). El sistema enrutará los comandos automáticamente.',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            Gap.l,
            AppTextField(
              controller: hostCtrl,
              label: 'Dirección de la Central o Hub RF',
            ),
            Gap.xl,
            AppButton(
              label: 'Conectar a la Central',
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
              'Tu Central Colmena está en modo de emparejamiento buscando nuevos sensores y módulos.',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            Gap.l,
            if (pairingApiDevice != null) ...[
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [cs.primary.withValues(alpha: 0.85), cs.secondary.withValues(alpha: 0.85)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: cs.primary.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 6)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.bolt, color: Colors.white, size: 28),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '¡Dispositivo Detectado en Vivo!',
                            style: tt.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'ID: ${pairingApiDevice!['id']} | Nombre: ${pairingApiDevice!['name']} (${pairingApiDevice!['type_name'] ?? selectedKind})',
                      style: tt.bodyMedium?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: cs.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Configurar y Guardar Este Dispositivo', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () {
                          final dev = Device.fromRf(
                            rfId: pairingApiDevice!['id']?.toString() ?? '',
                            name: pairingApiDevice!['name']?.toString() ?? 'RF Device',
                            hubHost: context.read<AppState>().hubHost,
                            typeName: pairingApiDevice!['type_name']?.toString() ?? selectedKind,
                            online: true,
                          );
                          _proceedToCustomize(dev);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Gap.l,
            ] else if (isPairingTimeout) ...[
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cs.errorContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.error.withValues(alpha: 0.8), width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.timer_off_rounded, color: cs.error, size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Tiempo de espera agotado (50s)',
                            style: tt.titleMedium?.copyWith(color: cs.onErrorContainer, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: 1.0,
                        minHeight: 8,
                        color: cs.error,
                        backgroundColor: cs.error.withValues(alpha: 0.2),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'No se detectaron dispositivos en modo emparejamiento. Verifica que el foco o sensor esté encendido y dentro del rango de cobertura del traductor.',
                      style: tt.bodyMedium?.copyWith(color: cs.onErrorContainer, fontWeight: FontWeight.w600, height: 1.4),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _startScanOnHub,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cs.error,
                          foregroundColor: cs.onError,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text(
                          'Volver a intentar vinculación',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Gap.l,
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.primary.withValues(alpha: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: (pairingElapsedSeconds / 50.0).clamp(0.0, 1.0),
                                strokeWidth: 3.5,
                                color: cs.primary,
                                backgroundColor: cs.primary.withValues(alpha: 0.2),
                              ),
                              Text(
                                '${(50.0 - pairingElapsedSeconds).clamp(0, 50).toInt()}',
                                style: tt.labelSmall?.copyWith(fontWeight: FontWeight.bold, color: cs.primary, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Modo de vinculación activo (${(50.0 - pairingElapsedSeconds).clamp(0, 50).toInt()}s restantes)',
                                style: tt.titleSmall?.copyWith(color: cs.onPrimaryContainer, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Buscando dispositivos en tu hogar (${context.read<AppState>().hubHost})...',
                                style: tt.bodySmall?.copyWith(color: cs.onPrimaryContainer.withValues(alpha: 0.8)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (pairingElapsedSeconds / 50.0).clamp(0.0, 1.0),
                        minHeight: 8,
                        color: cs.primary,
                        backgroundColor: cs.primary.withValues(alpha: 0.2),
                      ),
                    ),
                  ],
                ),
              ),
              Gap.l,
            ],
            if (discoveredFromHub.isNotEmpty) ...[
              Text('Dispositivos detectados en la red:', style: tt.titleSmall),
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

