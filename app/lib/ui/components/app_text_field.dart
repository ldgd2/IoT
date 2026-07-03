import 'package:flutter/material.dart';
import 'app_theme.dart';

class AppTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;

  const AppTextField({super.key, required this.controller, required this.label, this.hint, this.obscure = false, this.keyboardType});

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  final _node = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _node.addListener(() => setState(() => _focused = _node.hasFocus));
  }

  @override
  void dispose() { _node.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: Dur.normal, curve: Curv.ease,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF141920),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _focused ? cs.primary : cs.outlineVariant, width: _focused ? 1.4 : 1),
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _node,
        keyboardType: widget.keyboardType,
        obscureText: widget.obscure,
        decoration: InputDecoration(border: InputBorder.none, labelText: widget.label, hintText: widget.hint),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}