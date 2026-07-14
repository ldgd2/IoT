import 'package:flutter/material.dart';
import '../widgets/cards/cctv_feed_card.dart';
import '../widgets/buttons/ptz_joystick_button.dart';
import '../layouts/cctv_fullscreen_layout.dart';
import '../widgets/dialogs/critical_alarm_modal.dart';

class CctvLiveScreen extends StatefulWidget {
  const CctvLiveScreen({super.key});

  @override
  State<CctvLiveScreen> createState() => _CctvLiveScreenState();
}

class _CctvLiveScreenState extends State<CctvLiveScreen> {
  final List<Map<String, dynamic>> _cameras = [
    {
      'name': 'Cámara 01 - Acceso Principal',
      'status': '1080p • 30 FPS • RTSP En Vivo',
      'recording': true,
      'color': 0xFF1B2A47,
    },
    {
      'name': 'Cámara 02 - Patio Trasero',
      'status': '720p • Detección Movimiento Activa',
      'recording': true,
      'color': 0xFF243422,
    },
    {
      'name': 'Cámara 03 - Garaje Interno',
      'status': '1080p • Modo Nocturno Infrarrojo',
      'recording': false,
      'color': 0xFF352238,
    },
    {
      'name': 'Cámara 04 - Perímetro Sur',
      'status': 'Conexión RTSP Estable',
      'recording': true,
      'color': 0xFF382622,
    },
  ];

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
              const Text('Matriz de Seguridad CCTV', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              OutlinedButton.icon(
                icon: const Icon(Icons.shield, color: Colors.redAccent),
                label: const Text('Simular Alarma', style: TextStyle(color: Colors.redAccent)),
                onPressed: _triggerCriticalAlarmDemo,
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 1.15,
            ),
            itemCount: _cameras.length,
            itemBuilder: (ctx, idx) {
              final cam = _cameras[idx];
              return CctvFeedCard(
                cameraName: cam['name'],
                statusText: cam['status'],
                isRecording: cam['recording'],
                videoStreamChild: Container(
                  color: Color(cam['color']),
                  alignment: Alignment.center,
                  child: const Icon(Icons.videocam, size: 48, color: Colors.white24),
                ),
                onFullscreen: () => _openFullscreen(cam),
              );
            },
          ),
          const SizedBox(height: 28),
          const Text('Control Virtual PTZ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Center(
            child: PtzJoystickButton(
              onDirectionPressed: (dir) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Comando PTZ enviado: ${dir.name.toUpperCase()}')),
                );
              },
              onZoomIn: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PTZ Zoom In')),
                );
              },
              onZoomOut: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PTZ Zoom Out')),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openFullscreen(Map<String, dynamic> cam) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CctvFullscreenLayout(
          videoStreamWidget: Container(
            color: Color(cam['color']),
            alignment: Alignment.center,
            child: const Icon(Icons.videocam, size: 96, color: Colors.white38),
          ),
          overlayControls: Positioned(
            bottom: 24,
            left: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
              child: Text(cam['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ),
      ),
    );
  }

  void _triggerCriticalAlarmDemo() {
    CriticalAlarmModal.show(
      context,
      title: 'Intrusión Detectada en Sector 4',
      details: 'El sensor infrarrojo perimetral y la Cámara 04 han registrado movimiento no autorizado en horario de bloqueo de alta seguridad.',
      location: 'Perímetro Sur - Jardín Exterior',
      onDismiss: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alarma silenciada por el operador.')),
        );
      },
      onProtocol: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Protocolo de bloqueo total activado.')),
        );
      },
    );
  }
}
