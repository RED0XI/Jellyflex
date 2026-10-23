import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/layouts.dart';
import '../core/settings.dart';
import '../core/themes.dart';
import '../l10n/strings.dart';
import '../theme.dart';
import 'focusable.dart';

/// Auswahl des Layouts: eine kleine Skizze je Layout in den aktuellen Farben.
/// Ein Klick stellt sofort um – die ganze App ist dann die Live-Vorschau.
class LayoutPicker extends ConsumerWidget {
  const LayoutPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(settingsProvider.select((s) => s.layoutId));
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        for (final l in appLayouts)
          _LayoutTile(
            layout: l,
            palette: appPalette,
            selected: l.id == current,
            onTap: () => ref.read(settingsProvider.notifier).update((s) => s.copyWith(layoutId: l.id)),
          ),
      ],
    );
  }
}

class _LayoutTile extends StatelessWidget {
  const _LayoutTile({required this.layout, required this.palette, required this.selected, required this.onTap});

  final AppLayout layout;
  final AppPalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final german = appLanguage == AppLanguage.de;
    return Focusable(
      onTap: onTap,
      semanticLabel: german ? layout.nameDe : layout.name,
      builder: (context, hovered) => SizedBox(
        width: 212,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedScale(
              scale: hovered ? 1.04 : 1,
              duration: const Duration(milliseconds: 180),
              child: Container(
                width: 212,
                height: 132,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: p.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? p.accent : (hovered ? Colors.white70 : Colors.white12),
                    width: selected || hovered ? 2.5 : 1,
                  ),
                  boxShadow: [if (selected) BoxShadow(color: p.accent.withValues(alpha: 0.35), blurRadius: 18)],
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(painter: _Sketch(layout, p)),
                    if (selected)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(color: p.accent, shape: BoxShape.circle),
                          child: Icon(Icons.check_rounded, size: 14, color: p.background),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              german ? layout.nameDe : layout.name,
              style: TextStyle(
                fontFamily: layout.headingFont ?? layout.bodyFont,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              german ? layout.descriptionDe : layout.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, height: 1.3, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skizze eines Layouts: Navigation, Kopfbereich und eine Reihe Karten.
class _Sketch extends CustomPainter {
  _Sketch(this.layout, this.p);

  final AppLayout layout;
  final AppPalette p;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final r = Radius.circular(layout.radius / 4);
    final surface = Paint()..color = p.surfaceHigh;
    final text = Paint()..color = p.textPrimary;
    final muted = Paint()..color = p.textSecondary.withValues(alpha: 0.7);
    final accent = Paint()..color = p.accent;
    void bar(double x, double y, double width, double height, Paint paint) =>
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, width, height), const Radius.circular(2)), paint);
    void hero(Rect rect) {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            colors: [p.accent.withValues(alpha: 0.55), p.accentAlt.withValues(alpha: 0.25), p.background],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ).createShader(rect),
      );
    }

    void cards(double x, double y, double cardW, double cardH, int count, double gap) {
      for (var i = 0; i < count; i++) {
        final rect = Rect.fromLTWH(x + i * (cardW + gap), y, cardW, cardH);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, r), surface);
        if (i == 0) {
          // Gewählte Karte im Stil des Layouts.
          final focus = Paint()
            ..color = layout.focus == FocusStyle.zoom ? Colors.white : p.accent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5;
          canvas.drawRRect(RRect.fromRectAndRadius(rect.inflate(1), r), focus);
        }
      }
    }

    switch (layout.id) {
      case 'couch':
        hero(Rect.fromLTWH(0, 0, w, h * 0.5));
        for (var i = 0; i < 4; i++) {
          bar(w / 2 - 58 + i * 30, 8, 26, 9, i == 0 ? text : (Paint()..color = Colors.white24));
        }
        bar(10, 40, 60, 7, text);
        cards(10, h * 0.6, 58, 33, 4, 8);
      case 'library':
        canvas.drawRect(Rect.fromLTWH(0, 0, w * 0.24, h), Paint()..color = p.surface);
        bar(8, 10, 24, 5, accent);
        for (var i = 0; i < 6; i++) {
          bar(8, 24 + i * 11.0, i == 1 ? 34 : 28, 4, i == 1 ? text : muted);
        }
        final x = w * 0.24 + 10;
        bar(x, 12, 60, 7, text);
        cards(x, 30, 20, 30, 6, 6);
        cards(x, 76, 20, 30, 6, 6);
      case 'magazine':
        bar(10, 8, 28, 4, text);
        bar(46, 8, 14, 3, muted);
        bar(64, 8, 14, 3, muted);
        bar(10, 30, 22, 3, accent);
        bar(10, 38, 66, 9, text);
        bar(10, 50, 52, 9, text);
        bar(10, 64, 70, 3, muted);
        bar(10, 70, 60, 3, muted);
        hero(Rect.fromLTWH(w * 0.45, 26, w * 0.5, 54));
        cards(10, 92, 26, 36, 6, 8);
      case 'minimal':
        bar(10, 9, 16, 4, muted);
        bar(w - 22, 8, 12, 6, muted);
        bar(10, 34, 92, 9, Paint()..color = p.textPrimary.withValues(alpha: 0.85));
        bar(10, 62, 30, 3, muted);
        cards(10, 72, 28, 42, 6, 8);
      case 'retro':
        hero(Rect.fromLTWH(0, 0, w, h * 0.55));
        bar(10, 8, 30, 4, text);
        bar(10, 44, 70, 6, text);
        cards(10, h * 0.62, 26, 38, 6, 8);
        final line = Paint()..color = const Color(0x30000000);
        for (var y = 0.0; y < h; y += 3) {
          canvas.drawRect(Rect.fromLTWH(0, y, w, 1), line);
        }
      default: // Kino
        hero(Rect.fromLTWH(0, 0, w, h * 0.66));
        bar(10, 8, 22, 5, accent);
        bar(40, 9, 14, 3, text);
        bar(58, 9, 14, 3, muted);
        bar(76, 9, 14, 3, muted);
        bar(10, 40, 66, 9, text);
        bar(10, 54, 46, 4, muted);
        bar(10, 63, 22, 8, Paint()..color = p.button);
        cards(10, h * 0.7, 26, 38, 6, 8);
    }
  }

  @override
  bool shouldRepaint(_Sketch old) => old.layout != layout || old.p != p;
}
