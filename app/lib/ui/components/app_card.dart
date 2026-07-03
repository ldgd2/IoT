// ==============================================
// lib/ui/components/app_card.dart
// — Tarjeta con elevación animada
// ==============================================
import 'package:flutter/material.dart';
import 'app_theme.dart';

class AppCard extends StatefulWidget {
  final Widget child; final EdgeInsets padding; final VoidCallback? onTap;
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap});
  @override State<AppCard> createState() => _AppCardState(); }

class _AppCardState extends State<AppCard> { bool _down=false; @override Widget build(BuildContext c){
  return AnimatedContainer(
    duration: Dur.normal, curve: Curv.ease,
    decoration: BoxDecoration(
      color: const Color(0xFF12161D), borderRadius: BorderRadius.circular(16),
      boxShadow: _down?[]:[BoxShadow(color: Colors.black.withOpacity(.35), blurRadius: 18, offset: const Offset(0,10))],
    ),
    child: Material(color: Colors.transparent, child: InkWell(
      borderRadius: BorderRadius.circular(16), onHighlightChanged:(v)=>setState(()=>_down=v), onTap: widget.onTap,
      child: Padding(padding: widget.padding, child: widget.child))),
  ); }
}