// lib/ui/flows/provision/provision_flow.dart
import 'dart:async';
import 'dart:io';
import 'package:animations/animations.dart';
import 'package:bthapp/src/services/api_client.dart';
import 'package:bthapp/src/services/mdns_resolver.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wifi_iot/wifi_iot.dart';
import 'package:wifi_scan/wifi_scan.dart';

import '../../components/index.dart';
import '../../../src/models/device.dart';
import '../../../src/state/app_state.dart';
import 'provision_actions.dart';
import 'provision_steps.dart';

enum _Step { connectToAp, chooseHome, provisioning, connectingHome, discovering, success, error }

class ProvisionFlow extends StatefulWidget {
  const ProvisionFlow({super.key});
  @override
  State<ProvisionFlow> createState() => _ProvisionFlowState();
}

class _ProvisionFlowState extends State<ProvisionFlow> {
  _Step step = _Step.connectToAp;

  // datos para chooseHome
  List<String> ssids = <String>[];
  String? selectedHomeSsid;
  final passCtrl = TextEditingController();
  String mdnsName = 'mi-esp';
  String progressMsg = '';

  @override
  void dispose() {
    passCtrl.dispose();
    super.dispose();
  }

  Future<void> _connectToEspAp(WiFiAccessPoint ap) async {
    if (!Platform.isAndroid) {
      _snack('Conéctate manualmente al AP y vuelve.');
      return;
    }
    setState(() {
      step = _Step.provisioning;
      progressMsg = 'Conectando al dispositivo…';
    });

    final ok = await ProvisionActions.connectToEspAp(ap.ssid);
    if (!ok) {
      _fail('No se pudo conectar al AP del dispositivo');
      return;
    }

    // Verificar /conection?ready=1 en el gateway
    setState(() {
      progressMsg = 'Verificando conexión con el dispositivo…';
    });
    final ready = await ProvisionActions.verifyEspApReady();
    if (!ready) {
      _fail('El dispositivo no confirmó la conexión. Reintenta o revisa el AP.');
      return;
    }

    // Ya conectados y verificados: pedir al ESP su lista de redes (/scan)
    await _checkApAndLoadScan(); // este método setea step = _Step.chooseHome
  }

  Future<void> _checkApAndLoadScan() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      _fail('Sólo soportado en móvil.');
      return;
    }

    final onEsp = await ProvisionActions.isConnectedToEspAp();
    if (!onEsp) {
      _snack('Conéctate al AP del dispositivo (ESP-Setup-XXXX) y reintenta.');
      return;
    }

    // Pedimos al ESP su /scan
    setState(() => progressMsg = 'Consultando redes en el dispositivo…');
    try {
      final nets = await ProvisionActions.getScanFromDevice();
      if (nets.isEmpty) {
        _snack('No se recibieron redes desde el ESP. Reintenta.');
        return;
      }
      setState(() {
        ssids = nets;
        selectedHomeSsid = nets.first;
        step = _Step.chooseHome;
      });
    } catch (_) {
      _snack('No se pudo consultar /scan en el ESP.');
    }
  }

 Future<void> _submitProvision() async {
  // NO TRIM al SSID/Pass (tu SSID tiene espacio final)
  final ssid = selectedHomeSsid ?? '';
  final pass = passCtrl.text; // sin trim
  final mdns = mdnsName.trim();

  if (ssid.isEmpty || pass.isEmpty) {
    _snack('Selecciona SSID e ingresa la contraseña.');
    return;
  }

  setState(() {
    step = _Step.provisioning;
    progressMsg = 'Enviando credenciales al dispositivo…';
  });

  Map<String, dynamic>? resp = await ProvisionActions.submitProvisionAtGateway(
    ssid: ssid,
    pass: pass,
    mdns: mdns,
  );

  // --- Fallback: si no pudimos “provisionar”, pero el dispositivo YA ESTÁ en la red,
  // seguimos con el flujo usando mDNS -> /ping (esto cubre tu caso actual).
  if (resp == null) {
    final mdnsHost = mdns.endsWith('.local') ? mdns : '$mdns.local';
    final pingOk = await ApiClient(mdnsHost).ping();
    if (!pingOk) {
      _fail('No se pudo enviar /provision al ESP.');
      return;
    }
    // Simulamos una respuesta OK de /provision
    resp = {'ok': true};
  }

  final staIpHint = (resp['sta_ip'] as String?)?.trim();

  // Android: sugerimos cambio, pero NO bloqueamos por SSID exacto
  if (Platform.isAndroid) {
    setState(() {
      step = _Step.connectingHome;
      progressMsg = 'Conectando el teléfono a $ssid…';
    });

    // Best-effort; si falla, el usuario lo hace manual
    await ProvisionActions.connectPhoneToHome(ssid: ssid, pass: pass);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Conéctate a tu Wi-Fi'),
        content: Text(
          'Android puede pedirte confirmar la conexión a "$ssid". '
          'Si no aparece, toca "Abrir ajustes" y elige la red manualmente.\n\n'
          'Cuando ya estés conectado, toca "Ya me conecté".',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await WiFiForIoTPlugin.setEnabled(true, shouldOpenSettings: true);
            },
            child: const Text('Abrir ajustes'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Ya me conecté'),
          ),
        ],
      ),
    );
    // No esperamos SSID exacto → vamos directo a descubrir por /ping
  } else {
    _snack('Cámbiate manualmente a la red $ssid y vuelve a la app.');
  }

  // Descubrimiento real por /ping (mDNS y/o pista de IP del propio firmware)
  setState(() {
    step = _Step.discovering;
    progressMsg = 'Buscando el dispositivo en la red…';
  });

  final ip = await ProvisionActions.discoverAfterProvision(
    mdns: mdns,
    staIpHint: staIpHint,
    timeout: const Duration(seconds: 45),
  );

  if (ip == null) {
    await _showPrivateDnsHint(context);
    _fail('No se pudo resolver ${mdns}.local ni hacer ping. Intenta desactivar DNS privada o reintentar.');
    return;
  }

  // GUARDAR DISPOSITIVO EN EL ESTADO (usa mDNS como id lógico)
  try {
    final app = context.read<AppState>();
    final mdnsHost = mdns.endsWith('.local') ? mdns : '$mdns.local';

    final dev = Device.fromHost(
      hostMdns: mdnsHost,
      ip: ip,       // fallback
      port: 80,
      relayCount: 4,
    );

    await app.addOrUpdateDevice(dev);
    await app.refreshDevice(dev);
  } catch (_) {}

  setState(() {
    step = _Step.success;
    progressMsg = '¡Listo! Dispositivo configurado';
  });
}



  

  Future<void> _showPrivateDnsHint(BuildContext context) async {
  await showDialog(
    context: context,
    builder: (_) => const AlertDialog(
      title: Text('No se pudo encontrar el dispositivo'),
      content: Text(
        'A veces “DNS privada” o la red del router bloquean mDNS (.local).\n\n'
        'Prueba temporalmente:\n'
        '• Desactivar DNS privada (Ajustes → Red e Internet → DNS Privado → Desactivado)\n'
        '• Conectarte a la banda 2.4 GHz\n'
        '• Reintentar o ingresar IP manual',
      ),
    ),
  );
}



  void _fail(String m) => setState(() {
        step = _Step.error;
        progressMsg = m;
      });

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));




  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurar dispositivo')),
      body: PageTransitionSwitcher(
        duration: Dur.normal,
        transitionBuilder: (child, a, b) => SharedAxisTransition(
          animation: a,
          secondaryAnimation: b,
          transitionType: SharedAxisTransitionType.scaled,
          child: child,
        ),
        child: switch (step) {
          _Step.connectToAp => ConnectToApStep(
              onCheck: _checkApAndLoadScan,
              onOpenWifiSettings: () async {
                // Abre ajustes Wi-Fi (fallback)
                await WiFiForIoTPlugin.setEnabled(true, shouldOpenSettings: true);
              },
            ),
          _Step.chooseHome => ChooseHomeStepSimple(
              ssids: ssids,
              selected: selectedHomeSsid,
              passCtrl: passCtrl,
              mdns: mdnsName,
              onPick: (s) => setState(() => selectedHomeSsid = s),
              onMdns: (v) => setState(() => mdnsName = v),
              onRefresh: _checkApAndLoadScan,
              onSubmit: _submitProvision,
            ),
          _Step.provisioning => ProgressStep(message: progressMsg),
          _Step.connectingHome => ProgressStep(message: progressMsg),
          _Step.discovering => ProgressStep(message: progressMsg),
          _Step.success => const ResultStep(success: true, message: '¡Listo! Dispositivo configurado'),
          _Step.error => ResultStep(success: false, message: progressMsg),
        },
      ),
    );
  }
}
