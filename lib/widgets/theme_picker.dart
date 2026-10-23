import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/settings.dart';
import '../core/themes.dart';
import '../l10n/strings.dart';
import '../theme.dart';
import 'focusable.dart';

/// Auswahl des Farbschemas: kleine Vorschau je Theme (Hintergrund, Poster,
/// Titel, Fortschrittsbalken, Knopf). Klick wechselt sofort.
class ThemePicker extends ConsumerWidget {
  const ThemePicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(settingsProvider.select((s) => s.themeId));
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: [
        for (final p in appPalettes)
          _ThemeTile(
            palette: p,
            selected: p.id == current,
            onTap: () => ref.read(settingsProvider.notifier).update((s) => s.copyWith(themeId: p.id)),
          ),
      ],
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({required this.palette, required this.selected, required this.onTap});

  final AppPalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Focusable(
      onTap: onTap,
      builder: (context, hovered) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedScale(
            scale: hovered ? 1.04 : 1,
            duration: const Duration(milliseconds: 180),
            child: Container(
              width: 176,
              height: 112,
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
                children: [
                  // Leuchten oben links wie ein Banner-Bild.
                  Positioned(
                    left: -30,
                    top: -40,
                    child: Container(
                      width: 140,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [p.accent.withValues(alpha: 0.35), p.accent.withValues(alpha: 0)],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Titelzeile.
                        Container(
                          width: 70,
                          height: 7,
                          decoration: BoxDecoration(color: p.textPrimary, borderRadius: BorderRadius.circular(3)),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 46,
                          height: 5,
                          decoration: BoxDecoration(color: p.textSecondary, borderRadius: BorderRadius.circular(3)),
                        ),
                        const Spacer(),
                        // Drei "Poster", das erste mit Fortschritt.
                        Row(
                          children: [
                            for (var i = 0; i < 3; i++) ...[
                              if (i > 0) const SizedBox(width: 6),
                              Container(
                                width: 30,
                                height: 40,
                                alignment: Alignment.bottomCenter,
                                padding: const EdgeInsets.fromLTRB(3, 0, 3, 3),
                                decoration: BoxDecoration(
                                  color: i == 1 ? p.surfaceHigh : p.surface,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: p.border),
                                ),
                                child: i == 0
                                    ? Container(
                                        height: 2.5,
                                        decoration: BoxDecoration(
                                          gradient: AppColors.gradientOf(p),
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      )
                                    : null,
                              ),
                            ],
                            const Spacer(),
                            // Hauptknopf in der Knopffarbe des Themes.
                            Container(
                              width: 38,
                              height: 16,
                              decoration: BoxDecoration(color: p.button, borderRadius: BorderRadius.circular(8)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
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
            tr.themeName(p.id),
            style: TextStyle(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
