// ==============================================
// lib/ui/components/app_switch_tile.dart
// — Switch tipo “tile” con animación de color/escala
// ==============================================
import 'package:flutter/material.dart';
import 'app_theme.dart';

class AppSwitchTile extends StatelessWidget {
  final String title; final String? subtitle; final bool value; final ValueChanged<bool> onChanged; final IconData iconOn; final IconData iconOff;
  const AppSwitchTile({super.key, required this.title, required this.value, required this.onChanged, this.subtitle, this.iconOn=Icons.power, this.iconOff=Icons.power_off});
  @override Widget build(BuildContext c){
    final isOn=value; final cs=Theme.of(c).colorScheme;
    return AnimatedContainer(
      duration: Dur.normal, curve: Curv.ease,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: isOn? cs.primaryContainer.withOpacity(.35): const Color(0xFF12161D),
        border: Border.all(color: isOn? cs.primary: cs.outlineVariant), borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children:[
        AnimatedScale(scale:isOn?1:0.96,duration:Dur.fast,curve:Curv.ease,child:Icon(isOn?iconOn:iconOff,color:isOn?cs.primary:cs.outline)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
          Text(title, style: Theme.of(c).textTheme.titleMedium),
          if(subtitle!=null) Text(subtitle!, style: Theme.of(c).textTheme.bodySmall?.copyWith(color: cs.outline))
        ])),
        Switch(value: value, onChanged: onChanged)
      ]),
    );
  }
}
