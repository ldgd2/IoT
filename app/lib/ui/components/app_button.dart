import 'package:flutter/material.dart';
import 'app_theme.dart';

enum BtnVariant { primary, tonal, outline, text }

class AppButton extends StatefulWidget {
  final String label;
  final BtnVariant variant;
  final IconData? icon;
  final bool expanded;
  final VoidCallback? onPressed;

  const AppButton({super.key, required this.label, this.variant = BtnVariant.primary, this.icon, this.expanded = false, this.onPressed});

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDisabled = widget.onPressed == null;

    Color bg, fg, bd;
    switch (widget.variant) {
      case BtnVariant.primary:
        bg = isDisabled ? cs.primary.withOpacity(.3) : cs.primary; fg = cs.onPrimary; bd = Colors.transparent; break;
      case BtnVariant.tonal:
        bg = cs.secondaryContainer; fg = cs.onSecondaryContainer; bd = Colors.transparent; break;
      case BtnVariant.outline:
        bg = Colors.transparent; fg = cs.primary; bd = cs.outlineVariant; break;
      case BtnVariant.text:
        bg = Colors.transparent; fg = cs.primary; bd = Colors.transparent; break;
    }

    final content = Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
      if (widget.icon != null) ...[Icon(widget.icon, size: 18, color: fg), const SizedBox(width: 8)],
      Flexible(child: Text(widget.label, overflow: TextOverflow.ellipsis, style: TextStyle(color: fg, fontWeight: FontWeight.w700))),
    ]);

    final button = AnimatedContainer(
      duration: Dur.normal, curve: Curv.ease,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: bg, border: Border.all(color: bd), borderRadius: BorderRadius.circular(14), boxShadow: [
        if (!isDisabled && widget.variant != BtnVariant.text)
          BoxShadow(color: Colors.black.withOpacity(.25), blurRadius: _down ? 2 : 12, offset: const Offset(0, 6)),
      ]),
      child: content,
    );

    final scaled = AnimatedScale(duration: Dur.fast, curve: Curv.ease, scale: _down ? 0.98 : 1, child: button);

    final result = InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: widget.onPressed,
      onHighlightChanged: (v) => setState(() => _down = v),
      splashColor: Colors.white.withOpacity(.08),
      child: scaled,
    );

    return widget.expanded ? SizedBox(width: double.infinity, child: result) : result;
  }
}
