// =============================================================
// lib/ui/flows/provision/provision_guide_view.dart
// Guía animada paso a paso para vinculación de hardware
// =============================================================
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:bthapp/ui/components/index.dart';
import 'provision_flow.dart';
import 'rf_provision_flow.dart';

class InteractiveProvisionGuideView extends StatefulWidget {
  const InteractiveProvisionGuideView({super.key});

  @override
  State<InteractiveProvisionGuideView> createState() => _InteractiveProvisionGuideViewState();
}

class _InteractiveProvisionGuideViewState extends State<InteractiveProvisionGuideView> {
  final PageController pageCtrl = PageController();
  int currentPage = 0;

  @override
  void dispose() {
    pageCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (currentPage < 2) {
      pageCtrl.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeInOutCubic);
    }
  }

  void _prev() {
    if (currentPage > 0) {
      pageCtrl.previousPage(duration: const Duration(milliseconds: 350), curve: Curves.easeInOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Asistente Animado de Emparejamiento'),
      ),
      body: Column(
        children: [
          // Indicador de Progreso
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 6,
                      decoration: BoxDecoration(
                        color: i <= currentPage ? cs.primary : cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  if (i < 2) const SizedBox(width: 8),
                ],
              ],
            ),
          ),

          // Contenido Animado de Páginas
          Expanded(
            child: PageView(
              controller: pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (idx) => setState(() => currentPage = idx),
              children: [
                _buildStep1Hardware(context, cs, tt),
                _buildStep2SelectChannel(context, cs, tt),
                _buildStep3Ready(context, cs, tt),
              ],
            ),
          ),

          // Controles Inferiores
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (currentPage > 0)
                  AppButton(
                    label: 'Atrás',
                    variant: BtnVariant.outline,
                    icon: Icons.arrow_back,
                    onPressed: _prev,
                  )
                else
                  const SizedBox(),
                if (currentPage < 2)
                  AppButton(
                    label: 'Siguiente',
                    icon: Icons.arrow_forward,
                    onPressed: _next,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1Hardware(BuildContext context, ColorScheme cs, TextTheme tt) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.memory_rounded, size: 72, color: cs.primary),
                Positioned(
                  top: 26,
                  right: 32,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: Color(0xFF00E5A8),
                      shape: BoxShape.circle,
                    ),
                  ).animate(onPlay: (c) => c.repeat(reverse: true))
                   .fadeIn(duration: 400.ms)
                   .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.4, 1.4)),
                ),
              ],
            ),
          ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 32),
          Text(
            '1. Pon tu dispositivo en Modo Emparejamiento',
            style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          Text(
            'Conecta la alimentación eléctrica al módulo. Luego mantén presionado el botón BOOT / PROG durante 5 segundos hasta que el indicador LED parpadee rápidamente en verde.',
            style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant, height: 1.4),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStep2SelectChannel(BuildContext context, ColorScheme cs, TextTheme tt) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.alt_route_rounded, size: 64, color: cs.primary).animate().fadeIn().slideY(begin: -0.1, end: 0),
          const SizedBox(height: 24),
          Text(
            '2. Elige el Canal de Conexión',
            style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Selecciona si tu módulo se empareja mediante red Wi-Fi directa (ESP) o a través del Gateway Hub por Radiofrecuencia.',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          _ChannelSelectOption(
            icon: Icons.podcasts_rounded,
            title: 'Radiofrecuencia (Gateway Hub RF)',
            desc: 'Para sensores de clima, movimiento, luces RF 433MHz / nRF24.',
            color: const Color(0xFF00E5A8),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const RfProvisionFlow()));
            },
          ),
          const SizedBox(height: 14),
          _ChannelSelectOption(
            icon: Icons.wifi_tethering,
            title: 'Punto de Acceso Wi-Fi (ESP)',
            desc: 'Para módulos con chip ESP8266 / ESP32 en red local.',
            color: cs.primary,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ProvisionFlow()));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStep3Ready(BuildContext context, ColorScheme cs, TextTheme tt) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFF00E5A8).withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.verified_rounded, size: 64, color: Color(0xFF00E5A8)),
          ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 28),
          Text(
            '3. ¡Todo listo para vincular!',
            style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          Text(
            'Una vez vinculado, podrás asignar tu dispositivo a una habitación, controlar su consumo y participar en escenas inteligentes.',
            style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          AppButton(
            label: 'Comenzar Emparejamiento RF',
            icon: Icons.podcasts,
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const RfProvisionFlow()));
            },
          ),
        ],
      ),
    );
  }
}

class _ChannelSelectOption extends StatelessWidget {
  const _ChannelSelectOption({
    required this.icon,
    required this.title,
    required this.desc,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String desc;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(16)),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text(desc, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, size: 16, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
