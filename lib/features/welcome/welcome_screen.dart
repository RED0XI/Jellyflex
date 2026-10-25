import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings.dart';
import '../../l10n/strings.dart';
import '../../theme.dart';
import '../../widgets/ambient_background.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/buttons.dart';
import '../../widgets/focusable.dart';
import '../../widgets/layout_picker.dart';
import '../../widgets/theme_picker.dart';

/// Einrichtungs-Assistent beim allerersten Start: Sprache, Aussehen, ein paar Fragen –
/// danach geht es zur Anmeldung. Alles wirkt sofort und lässt sich später ändern.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  static const _steps = 3;
  int _step = 0;

  void _finish() => ref.read(settingsProvider.notifier).update((s) => s.copyWith(setupDone: true));

  void _next() => _step == _steps - 1 ? _finish() : setState(() => _step++);

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    final ctrl = ref.read(settingsProvider.notifier);
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: AmbientBackground()),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BrandLogo(size: 42),
                  const SizedBox(height: 20),
                  _StepDots(step: _step, count: _steps),
                  const SizedBox(height: 24),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    width: _step == 1 ? 920 : 560,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
                      boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 60, offset: Offset(0, 20))],
                    ),
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: KeyedSubtree(
                          key: ValueKey(_step),
                          child: switch (_step) {
                            0 => _languageStep(s, ctrl),
                            1 => _lookStep(),
                            _ => _optionsStep(s, ctrl),
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Überschrift, Erklärung, Inhalt und unten Zurück/Weiter.
  Widget _page({required String title, required String hint, required Widget child}) {
    final last = _step == _steps - 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(hint, style: TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 26),
        child,
        const SizedBox(height: 30),
        Row(
          children: [
            if (_step > 0)
              TextButton.icon(
                onPressed: () => setState(() => _step--),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: Text(tr.back),
              )
            else
              TextButton(onPressed: _finish, child: Text(tr.setupLater)),
            const Spacer(),
            SizedBox(
              width: 200,
              child: PrimaryButton(
                label: last ? tr.setupFinish : tr.next,
                icon: last ? Icons.check_rounded : Icons.arrow_forward_rounded,
                onPressed: _next,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _languageStep(AppSettings s, SettingsController ctrl) => _page(
    title: tr.welcomeTitle,
    hint: tr.welcomeHint,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr.appLanguage, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final l in AppLanguage.values)
              _Chip(
                label: l.nativeName,
                selected: s.language == l,
                autofocus: s.language == l,
                onTap: () => ctrl.update((s) => s.copyWith(language: l)),
              ),
          ],
        ),
      ],
    ),
  );

  Widget _lookStep() => _page(
    title: tr.setupLookTitle,
    hint: tr.setupLookHint,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr.theme, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        const ThemePicker(),
        const SizedBox(height: 26),
        Text(tr.layout, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        const LayoutPicker(),
      ],
    ),
  );

  Widget _optionsStep(AppSettings s, SettingsController ctrl) => _page(
    title: tr.setupOptionsTitle,
    hint: tr.setupOptionsHint,
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          _Option(
            title: tr.themeMusic,
            hint: tr.themeMusicHint,
            value: s.themeMusic,
            onChanged: (v) => ctrl.update((s) => s.copyWith(themeMusic: v)),
          ),
          _Option(
            title: tr.bannerTrailers,
            hint: tr.bannerTrailersHint,
            value: s.bannerTrailers,
            onChanged: (v) => ctrl.update((s) => s.copyWith(bannerTrailers: v)),
          ),
          _Option(
            title: tr.sounds,
            hint: tr.soundsHint,
            value: s.soundEffects,
            onChanged: (v) => ctrl.update((s) => s.copyWith(soundEffects: v)),
          ),
          _Option(
            title: tr.updateCheck,
            hint: tr.updateCheckHint,
            value: s.updateCheck,
            onChanged: (v) => ctrl.update((s) => s.copyWith(updateCheck: v)),
          ),
        ],
      ),
    ),
  );
}

/// Punkte oben: welcher Schritt gerade dran ist.
class _StepDots extends StatelessWidget {
  const _StepDots({required this.step, required this.count});

  final int step;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: tr.stepOf(step + 1, count),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: i == step ? 26 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i <= step ? AppColors.accent : Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      ),
    );
  }
}

/// Auswahl-Kachel für die Sprache.
class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap, this.autofocus = false});

  final String label;
  final bool selected;
  final bool autofocus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Focusable(
      onTap: onTap,
      autofocus: autofocus,
      semanticLabel: label,
      builder: (context, hovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : Colors.white.withValues(alpha: hovered ? 0.14 : 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: hovered ? Colors.white : Colors.transparent, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[const Icon(Icons.check_rounded, size: 18), const SizedBox(width: 6)],
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

/// Eine Frage mit Schalter.
class _Option extends StatelessWidget {
  const _Option({required this.title, required this.hint, required this.value, required this.onChanged});

  final String title;
  final String hint;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(hint, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
