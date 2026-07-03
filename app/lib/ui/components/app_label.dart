// ==============================================
// lib/ui/components/app_label.dart
// — Etiqueta/Texto con fade/slide de entrada
// ==============================================
import 'package:flutter/material.dart';
import 'app_theme.dart';

class AppLabel extends StatelessWidget {
  final String text; final TextStyle? style; final TextAlign? align;
  const AppLabel(this.text, {super.key, this.style, this.align});
  @override Widget build(BuildContext c){
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1), duration: Dur.slow, curve: Curv.ease,
      builder: (_, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0,(1-v)*8), child: child)),
      child: Text(text, textAlign: align, style: style ?? Theme.of(c).textTheme.titleMedium),
    );
  }
}