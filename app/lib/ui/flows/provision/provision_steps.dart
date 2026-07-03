// lib/ui/flows/provision/provision_steps.dart
import 'package:flutter/material.dart';
import '../../components/index.dart';
import 'provision_widgets.dart';

class ConnectToApStep extends StatelessWidget {
  const ConnectToApStep({
    super.key,
    required this.onCheck,
    required this.onOpenWifiSettings,
  });

  final Future<void> Function() onCheck;
  final Future<void> Function() onOpenWifiSettings;

  @override
  Widget build(BuildContext c) {
    final t = Theme.of(c).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const AppLabel('Conéctate al AP del dispositivo'),
        Gap.s,
        Text(
          'Abre los ajustes Wi-Fi del teléfono y conéctate a la red del dispositivo '
          '(por ejemplo: ESP-Setup-XXXX). Luego vuelve aquí y toca “Comprobar”.',
          style: t.bodyMedium,
        ),
        Gap.m,
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Abrir ajustes Wi-Fi',
                variant: BtnVariant.outline,
                icon: Icons.wifi,
                onPressed: onOpenWifiSettings,
              ),
            ),
            Gap.m,
            Expanded(
              child: AppButton(
                label: 'Comprobar',
                icon: Icons.check_circle,
                onPressed: onCheck,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class ChooseHomeStepSimple extends StatelessWidget {
  const ChooseHomeStepSimple({
    super.key,
    required this.ssids,
    required this.selected,
    required this.passCtrl,
    required this.mdns,
    required this.onPick,
    required this.onMdns,
    required this.onRefresh,
    required this.onSubmit,
  });

  final List<String> ssids;
  final String? selected;
  final TextEditingController passCtrl;
  final String mdns;
  final ValueChanged<String> onPick;
  final ValueChanged<String> onMdns;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext c) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const AppLabel('Selecciona tu Wi-Fi'),
        Gap.m,
        DropdownButtonFormField<String>(
          value: selected,
          items: [for (final s in ssids) DropdownMenuItem(value: s, child: Text(s))],
          onChanged: (v) { if (v != null) onPick(v); },
          decoration: const InputDecoration(labelText: 'SSID'),
        ),
        Gap.s,
        AppTextField(controller: passCtrl, label: 'Contraseña', obscure: true),
        Gap.s,
        TextFormField(
          initialValue: mdns,
          onChanged: onMdns,
          decoration: const InputDecoration(labelText: 'Nombre mDNS', hintText: 'sin ".local"'),
        ),
        Gap.m,
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Volver a consultar',
                variant: BtnVariant.outline,
                icon: Icons.refresh,
                onPressed: onRefresh,
              ),
            ),
            Gap.m,
            Expanded(
              child: AppButton(
                label: 'Listo',
                icon: Icons.send,
                onPressed: onSubmit,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class ProgressStep extends StatelessWidget {
  const ProgressStep({super.key, required this.message});
  final String message;
  @override
  Widget build(BuildContext c) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Spinner(size: 38), Gap.m, Text(message),
    ]));
  }
}

class ResultStep extends StatelessWidget {
  const ResultStep({super.key, required this.success, required this.message});
  final bool success; final String message;
  @override
  Widget build(BuildContext c) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      ResultBadge(success: success), Gap.m, Text(message, textAlign: TextAlign.center), Gap.l,
      AppButton(label: 'Cerrar', variant: BtnVariant.text, icon: Icons.check, onPressed: () => Navigator.pop(c)),
    ]));
  }
}
