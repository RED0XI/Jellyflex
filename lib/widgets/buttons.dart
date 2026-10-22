import 'package:flutter/material.dart';

import '../theme.dart';
import 'focusable.dart';

/// Großer, heller Haupt-Button (z. B. "Abspielen").
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
            color: enabled ? (hovered ? Colors.white : const Color(0xFFEDEEF3)) : AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              if (hovered && enabled)
                BoxShadow(color: Colors.white.withValues(alpha: 0.18), blurRadius: 24, spreadRadius: 1),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.loading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.background),
                )
              else if (widget.icon != null)
                Icon(widget.icon, color: AppColors.background, size: 26),
              if (widget.icon != null || widget.loading) const SizedBox(width: 10),
              Text(
                widget.label,
                style: TextStyle(
                  color: enabled ? AppColors.background : AppColors.textMuted,
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

/// Runder Icon-Button (Favorit, Gesehen, …).
class CircleIconButton extends StatefulWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.active = false,
    this.activeColor = AppColors.accent,
    this.size = 52,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final bool active;
  final Color activeColor;
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
              color: widget.active ? widget.activeColor : AppColors.textPrimary,
              size: widget.size * 0.46,
            ),
          ),
        ),
      ),
    );
  }
}
