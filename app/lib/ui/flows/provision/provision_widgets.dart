// =============================================================
// lib/ui/flows/provision/provision_widgets.dart
// Widgets de apoyo (spinner, tile, badge)
// =============================================================
import 'package:flutter/material.dart';
import '../../components/index.dart';

class Spinner extends StatelessWidget {
  const Spinner({super.key, this.size=28, this.stroke=3});
  final double size; final double stroke;
  @override Widget build(BuildContext c){
    return SizedBox(width:size, height:size, child: CircularProgressIndicator(strokeWidth: stroke, color: Theme.of(c).colorScheme.primary));
  }
}

class WifiTile extends StatelessWidget {
  const WifiTile({super.key, required this.title, this.subtitle, required this.icon, this.onTap});
  final String title; final String? subtitle; final IconData icon; final VoidCallback? onTap;
  @override Widget build(BuildContext c){
    final cs = Theme.of(c).colorScheme;
    return AppCard(onTap:onTap, child: Row(children:[
      Icon(icon, color: cs.primary), const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
        Text(title, style: Theme.of(c).textTheme.titleMedium),
        if(subtitle!=null) Text(subtitle!, style: Theme.of(c).textTheme.bodySmall?.copyWith(color: cs.outline))
      ])),
      const Icon(Icons.chevron_right)
    ]));
  }
}

class ResultBadge extends StatelessWidget {
  const ResultBadge({super.key, required this.success});
  final bool success;
  @override Widget build(BuildContext c){
    final bg = success ? Theme.of(c).colorScheme.primary : Colors.redAccent;
    final icon = success ? Icons.check_rounded : Icons.close_rounded;
    return AnimatedContainer(
      duration: Dur.normal, curve: Curv.spring,
      width: 56, height: 56,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle, boxShadow:[BoxShadow(color: bg.withOpacity(0.4), blurRadius: 18, spreadRadius: 2)]),
      child: Icon(icon, color: Colors.white, size: 32),
    );
  }
}
