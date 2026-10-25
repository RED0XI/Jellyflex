import 'package:flutter/material.dart';

import '../theme.dart';
import 'focusable.dart';

/// Großer Haupt-Button (z. B. "Abspielen") in der Knopffarbe des Themes.
class PrimaryButton extends StatefulWidget {
  const PrimaryButton({super.key, required this.label, required this.onPressed, this.icon, this.loading = false});

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.loading;
    return Focusable(
      onTap: enabled ? widget.onPressed : null,
      builder: (context, hovered) => AnimatedScale(
        scale: hovered && enabled ? 1.04 : 1,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 28),
          decoration: BoxDecoration(
            color: enabled
                ? (hovered ? Color.lerp(AppColors.button, Colors.white, 0.15) : AppColors.button)
                : AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              if (hovered && enabled)
                BoxShadow(color: AppColors.button.withValues(alpha: 0.35), blurRadius: 24, spreadRadius: 1),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.loading)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.onButton),
                )
              else if (widget.icon != null)
                Icon(widget.icon, color: AppColors.onButton, size: 26),
              if (widget.icon != null || widget.loading) const SizedBox(width: 10),
              Text(
                widget.label,
                style: TextStyle(
                  color: enabled ? AppColors.onButton : AppColors.textMuted,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Halbtransparenter Button mit Glas-Look (z. B. "Mehr Infos").
class GlassButton extends StatefulWidget {
  const GlassButton({super.key, required this.label, required this.onPressed, this.icon});

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton> {
  @override
  Widget build(BuildContext context) {
    return Focusable(
      onTap: widget.onPressed,
      builder: (context, hovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: hovered ? 0.22 : 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, size: 22, color: AppColors.textPrimary),
              const SizedBox(width: 10),
            ],
            Text(widget.label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

/// Kleine Auswahl unter den Hauptknöpfen (Fassung, Ton, Untertitel): "Ton: **Deutsch** ⌄".
/// [text] ist der ganze Text (z. B. tr.audioLabel(value)); der Teil [value] am Ende wird betont.
class OptionChip extends StatelessWidget {
  const OptionChip({super.key, required this.text, required this.value, required this.onPressed, this.icon});

  final String text;
  final String value;
  final IconData? icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final prefix = text.endsWith(value) ? text.substring(0, text.length - value.length) : '';
    return Focusable(
      onTap: onPressed,
      semanticLabel: text,
      builder: (context, hovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 38,
        padding: const EdgeInsets.only(left: 14, right: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: hovered ? 0.16 : 0.07),
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: Colors.white.withValues(alpha: hovered ? 0.5 : 0.12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 18, color: AppColors.textSecondary), const SizedBox(width: 8)],
            Text.rich(
              TextSpan(
                children: [
                  if (prefix.isNotEmpty)
                    TextSpan(
                      text: prefix,
                      style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                    ),
                  TextSpan(
                    text: prefix.isEmpty ? text : value,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(width: 4),
            Icon(Icons.expand_more_rounded, size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

/// Runder Icon-Button (Favorit, Gesehen, …).
class CircleIconButton extends StatefulWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.active = false,
    this.activeColor,
    this.size = 52,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final bool active;

  /// Farbe im aktiven Zustand (Standard: Akzentfarbe des Themes).
  final Color? activeColor;
  final double size;

  @override
  State<CircleIconButton> createState() => _CircleIconButtonState();
}

class _CircleIconButtonState extends State<CircleIconButton> {
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: Focusable(
        onTap: widget.onPressed,
        builder: (context, hovered) => AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: hovered ? 0.22 : 0.12),
            border: Border.all(
              color: hovered ? Colors.white : Colors.white.withValues(alpha: 0.14),
              width: hovered ? 2 : 1,
            ),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
            child: Icon(
              widget.icon,
              key: ValueKey('${widget.icon.codePoint}-${widget.active}'),
              color: widget.active ? (widget.activeColor ?? AppColors.accent) : AppColors.textPrimary,
              size: widget.size * 0.46,
            ),
          ),
        ),
      ),
    );
  }
}
