import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/gamepad_input.dart';
import '../../core/profile_pin.dart';
import '../../core/session.dart';
import '../../core/settings.dart';
import '../../l10n/strings.dart';
import '../../theme.dart';
import '../../widgets/pin_dialog.dart';

/// Sperrt ein Profil mit PIN nach einer Weile ohne Eingabe (Einstellung, Standard: aus).
/// Weiter geht es nur mit der PIN – oder zurück zur Profilauswahl. Während ein Video
/// läuft, wird nicht gesperrt. Downloads laufen im Hintergrund weiter.
class IdleLock extends ConsumerStatefulWidget {
  const IdleLock({super.key, required this.router, required this.child});

  final GoRouter router;
  final Widget child;

  /// Nur für Tests: Wartezeit statt der Minuten aus den Einstellungen.
  @visibleForTesting
  static Duration? debugDelay;

  @override
  ConsumerState<IdleLock> createState() => _IdleLockState();
}

class _IdleLockState extends ConsumerState<IdleLock> {
  Timer? _idle;
  bool _locked = false;

  /// Solange gesperrt, liegt der Tastatur-Fokus hier – Tasten erreichen die App darunter nicht.
  final _focus = FocusScopeNode(debugLabel: 'IdleLock');

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onAnyKey);
    GamepadInput.activity.addListener(_onActivity);
    _restartTimer();
  }

  @override
  void dispose() {
    _idle?.cancel();
    HardwareKeyboard.instance.removeHandler(_onAnyKey);
    GamepadInput.activity.removeListener(_onActivity);
    _focus.dispose();
    super.dispose();
  }

  void _restartTimer() {
    _idle?.cancel();
    final minutes = ref.read(settingsProvider).pinLockMinutes;
    final session = ref.read(sessionProvider).value;
    if (minutes <= 0 || session == null || !session.hasPin || _locked) return;
    _idle = Timer(IdleLock.debugDelay ?? Duration(minutes: minutes), _lockIfAllowed);
  }

  void _lockIfAllowed() {
    final config = widget.router.routerDelegate.currentConfiguration;
    final path = config.isEmpty ? '' : widget.router.state.uri.path;
    // Beim Filmschauen gibt es keine Eingaben – das ist keine Abwesenheit.
    if (path.startsWith('/play')) {
      _restartTimer();
      return;
    }
    if (!mounted || ref.read(sessionProvider).value?.hasPin != true) return;
    setState(() => _locked = true);
    _focus.requestFocus();
  }

  void _unlock() {
    if (!mounted) return;
    setState(() => _locked = false);
    _focus.unfocus();
    _restartTimer();
  }

  bool _onAnyKey(KeyEvent event) {
    if (!_locked) _restartTimer();
    return false;
  }

  void _onActivity() {
    if (!_locked) _restartTimer();
  }

  void _onPointer(PointerEvent event) {
    if (!_locked) _restartTimer();
  }

  @override
  Widget build(BuildContext context) {
    // Profil gewechselt/abgemeldet oder Einstellung geändert → neu beginnen.
    ref.listen(sessionProvider, (_, next) {
      if (_locked && next.value?.hasPin != true) _unlock();
      _restartTimer();
    });
    ref.listen(settingsProvider.select((s) => s.pinLockMinutes), (_, _) => _restartTimer());
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointer,
      onPointerHover: _onPointer,
      onPointerSignal: _onPointer,
      child: Stack(
        children: [
          widget.child,
          // Fester Platz im Stack (sonst verliert die App darunter beim Sperren ihren Fokus).
          Positioned.fill(
            child: Offstage(
              offstage: !_locked,
              child: FocusScope(
                node: _focus,
                child: _locked
                    ? Navigator(
                        onGenerateRoute: (_) =>
                            PageRouteBuilder<void>(pageBuilder: (_, _, _) => _LockPage(onUnlocked: _unlock)),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LockPage extends ConsumerWidget {
  const _LockPage({required this.onUnlocked});

  final VoidCallback onUnlocked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider).value;
    final name = session?.userName ?? '';

    Future<void> unlock() async {
      final hash = session?.pinHash;
      if (session == null || hash == null) return onUnlocked();
      final pin = await showPinDialog(
        context,
        title: tr.pinFor(name),
        accountKey: session.accountKey,
        check: (pin) => ProfilePin.verify(pin, hash),
      );
      if (pin != null) onUnlocked();
    }

    return Material(
      color: AppColors.background,
      child: Stack(
        children: [
          // Fenster bleibt verschiebbar, minimierbar und schließbar.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: kTitleBarHeight,
            child: Row(
              children: [
                const Expanded(child: DragToMoveArea(child: SizedBox.expand())),
                IconButton(
                  tooltip: tr.minimize,
                  icon: const Icon(Icons.remove_rounded, size: 18),
                  onPressed: () => windowManager.minimize(),
                ),
                IconButton(
                  tooltip: tr.close,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () => windowManager.close(),
                ),
                const SizedBox(width: 6),
              ],
            ),
          ),
          _lockContent(name, unlock, ref),
        ],
      ),
    );
  }

  Widget _lockContent(String name, Future<void> Function() unlock, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: AppColors.accentGradient),
            child: Text(
              name.isEmpty ? '?' : name[0].toUpperCase(),
              style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 18),
          Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_rounded, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Text(tr.profileLocked, style: TextStyle(color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.icon(
                autofocus: true,
                onPressed: unlock,
                icon: const Icon(Icons.lock_open_rounded),
                label: Text(tr.unlock),
              ),
              const SizedBox(width: 12),
              TextButton.icon(
                onPressed: () => ref.read(sessionProvider.notifier).switchUser(),
                icon: const Icon(Icons.people_alt_rounded),
                label: Text(tr.switchProfile),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
