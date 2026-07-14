import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bthapp/src/state/app_state.dart';
import 'package:bthapp/src/models/device.dart';
import '../widgets/cards/cctv_feed_card.dart';
import '../widgets/buttons/ptz_joystick_button.dart';
import '../layouts/cctv_fullscreen_layout.dart';
import '../widgets/dialogs/critical_alarm_modal.dart';
import 'package:bthapp/ui/flows/provision/add_device_sheet.dart';

class CctvLiveScreen extends StatefulWidget {
  const CctvLiveScreen({super.key});

  @override
  State<CctvLiveScreen> createState() => _CctvLiveScreenState();
}

class _CctvLiveScreenState extends State<CctvLiveScreen> {
  Device? _selectedCameraForPtz;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final allDevices = app.devices;
    final cameras = allDevices.where((d) => d.kind == 'Cámara' || (d.kind?.toLowerCase().contains('cam') ?? false)).toList();
    final cs = Theme.of(context).colorScheme;

    if (_selectedCameraForPtz == null && cameras.isNotEmpty) {
      _selectedCameraForPtz = cameras.first;
    } else if (cameras.isNotEmpty && !cameras.any((c) => c.id == _selectedCameraForPtz?.id)) {
      _selectedCameraForPtz = cameras.first;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Matriz de Seguridad CCTV (${cameras.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Sincronizar streams',
                    onPressed: () => app.refreshAll(parallel: true),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    tooltip: 'Añadir cámara IP/RTSP',
                    onPressed: () => AddDeviceSheet.show(context),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (cameras.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.videocam_off_outlined, size: 56, color: cs.onSurfaceVariant),
                      const SizedBox(height: 14),
                      const Text('No hay cámaras registradas en el hogar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 6),
                      Text('Vincular una cámara IP con protocolo RTSP o módulo ESP32-CAM te permitirá ver transmisión en vivo y controlar movimiento PTZ.', textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: () => AddDeviceSheet.show(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Vincular Cámara'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else ...[
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1.15,
              ),
              itemCount: cameras.length,
              itemBuilder: (ctx, idx) {
                final cam = cameras[idx];
                final isSelected = _selectedCameraForPtz?.id == cam.id;
                final isRecording = cam.state['recording'] == true || cam.state['rec'] == true || cam.online;
                final statusText = cam.online ? 'RTSP en línea (${cam.ip})' : 'Sin conexión con el stream';

                return InkWell(
                  onTap: () => setState(() => _selectedCameraForPtz = cam),
                  child: Container(
                    decoration: BoxDecoration(
                      border: isSelected ? Border.all(color: cs.primary, width: 2.5) : null,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: CctvFeedCard(
                      cameraName: cam.alias ?? cam.id,
                      statusText: statusText,
                      isRecording: isRecording,
                      videoStreamChild: Container(
                        color: cam.online ? const Color(0xFF141A24) : const Color(0xFF1E1E1E),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(cam.online ? Icons.videocam : Icons.videocam_off, size: 40, color: cam.online ? cs.primary : cs.error),
                            const SizedBox(height: 6),
                            Text(cam.online ? 'Stream Activo' : 'Cámara Desconectada', style: const TextStyle(fontSize: 11, color: Colors.white70)),
                          ],
                        ),
                      ),
                      onFullscreen: () => _openFullscreen(cam),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Control PTZ para: ${_selectedCameraForPtz?.alias ?? _selectedCameraForPtz?.id ?? "Seleccionar cámara"}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (_selectedCameraForPtz != null)
                  TextButton.icon(
                    icon: const Icon(Icons.shield, color: Colors.redAccent, size: 18),
                    label: const Text('Disparar Bloqueo', style: TextStyle(color: Colors.redAccent)),
                    onPressed: () => _triggerCriticalAlarmDemo(_selectedCameraForPtz!),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: PtzJoystickButton(
                onDirectionPressed: (dir) {
                  if (_selectedCameraForPtz == null) return;
                  context.read<AppState>().setDeviceAttribute(_selectedCameraForPtz!, {'ptz': dir.name.toUpperCase()});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Comando PTZ ${dir.name.toUpperCase()} enviado a ${_selectedCameraForPtz!.alias ?? _selectedCameraForPtz!.id}')),
                  );
                },
                onZoomIn: () {
                  if (_selectedCameraForPtz == null) return;
                  context.read<AppState>().setDeviceAttribute(_selectedCameraForPtz!, {'ptz_zoom': 'IN'});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Comando Zoom In enviado a ${_selectedCameraForPtz!.alias ?? _selectedCameraForPtz!.id}')),
                  );
                },
                onZoomOut: () {
                  if (_selectedCameraForPtz == null) return;
                  context.read<AppState>().setDeviceAttribute(_selectedCameraForPtz!, {'ptz_zoom': 'OUT'});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Comando Zoom Out enviado a ${_selectedCameraForPtz!.alias ?? _selectedCameraForPtz!.id}')),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openFullscreen(Device cam) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CctvFullscreenLayout(
          videoStreamWidget: Container(
            color: const Color(0xFF141A24),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(cam.online ? Icons.videocam : Icons.videocam_off, size: 80, color: cam.online ? Colors.white70 : Colors.redAccent),
                const SizedBox(height: 12),
                Text('Transmisión IP RTSP: ${cam.ip}', style: const TextStyle(color: Colors.white, fontSize: 16)),
              ],
            ),
          ),
          overlayControls: Positioned(
            bottom: 24,
            left: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
              child: Text(cam.alias ?? cam.id, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ),
      ),
    );
  }

  void _triggerCriticalAlarmDemo(Device cam) {
    CriticalAlarmModal.show(
      context,
      title: 'Alerta de Intrusión: ${cam.alias ?? cam.id}',
      details: 'El sistema ha detectado movimiento inusual o desconexión abrupta en la cámara del sector "${cam.room ?? "General"}".',
      location: cam.room ?? 'Perímetro Principal',
      onDismiss: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alarma silenciada por el operador en el panel central.')),
        );
      },
      onProtocol: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Protocolo de bloqueo de emergencia activado.')),
        );
      },
    );
  }
}
