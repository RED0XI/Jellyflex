import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/profile_pin.dart';
import '../l10n/strings.dart';
import '../theme.dart';
import 'focusable.dart';

/// PIN abfragen. [check] prüft die Eingabe (z. B. gegen den gespeicherten Hash);
/// ohne [check] wird die eingegebene PIN zurückgegeben (zum Festlegen).
/// Ergebnis: die PIN oder `null` (abgebrochen).
Future<String?> showPinDialog(
  BuildContext context, {
  required String title,
  String? subtitle,
  Future<bool> Function(String pin)? check,
  String? accountKey,
}) => showDialog<String>(
  context: context,
  builder: (_) => _PinDialog(title: title, subtitle: subtitle, check: check, accountKey: accountKey),
);

/// Neue PIN festlegen: zweimal eingeben. Ergebnis: PIN oder `null`.
Future<String?> askNewPin(BuildContext context) async {
  final first = await showPinDialog(context, title: tr.pinChoose, subtitle: tr.pinChooseHint);
  if (first == null || !context.mounted) return null;
  final second = await showPinDialog(context, title: tr.pinRepeat, check: (pin) async => pin == first);
  return second;
}

class _PinDialog extends StatefulWidget {
  const _PinDialog({required this.title, this.subtitle, this.check, this.accountKey});

  final String title;
  final String? subtitle;
  final Future<bool> Function(String pin)? check;
  final String? accountKey;

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  final _focus = FocusNode();
  String _pin = '';
  String? _error;
  bool _checking = false;
  Timer? _lockTimer;

  Duration get _locked => widget.accountKey == null ? Duration.zero : ProfilePin.lockedFor(widget.accountKey!);

  @override
  void initState() {
    super.initState();
    if (_locked > Duration.zero) _startLockTimer();
  }

  @override
  void dispose() {
    _focus.dispose();
    _lockTimer?.cancel();
    super.dispose();
  }

  void _startLockTimer() {
    _lockTimer?.cancel();
    _lockTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() {});
      if (_locked == Duration.zero) t.cancel();
    });
  }

  void _type(String digit) {
    if (_checking || _locked > Duration.zero || _pin.length >= 6) return;
    setState(() {
      _pin += digit;
      _error = null;
    });
  }

  void _back() {
    if (_pin.isEmpty || _checking) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submit() async {
    if (_checking || _locked > Duration.zero) return;
    if (!ProfilePin.isValid(_pin)) {
      setState(() => _error = tr.pinFormat);
      return;
    }
    final check = widget.check;
    if (check == null) {
      Navigator.pop(context, _pin);
      return;
    }
    setState(() => _checking = true);
    final ok = await check(_pin);
    if (!mounted) return;
    final key = widget.accountKey;
    if (ok) {
      if (key != null) ProfilePin.recordSuccess(key);
      Navigator.pop(context, _pin);
      return;
    }
    if (key != null) ProfilePin.recordFailure(key);
    setState(() {
      _checking = false;
      _pin = '';
      _error = tr.pinWrong;
    });
    if (_locked > Duration.zero) _startLockTimer();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final char = event.character;
    if (char != null && RegExp(r'^\d$').hasMatch(char)) {
      _type(char);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      _back();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      _submit();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final locked = _locked;
    return Focus(
      autofocus: true,
      focusNode: _focus,
      onKeyEvent: _onKey,
      child: AlertDialog(
        title: Text(widget.title, textAlign: TextAlign.center),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Text(
                    widget.subtitle!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              // Punkte statt Ziffern.
              Semantics(
                label: tr.pinDigits(_pin.length),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < 6; i++)
                      Container(
                        width: 16,
                        height: 16,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < _pin.length ? AppColors.accent : Colors.transparent,
                          border: Border.all(color: i < 4 ? AppColors.textSecondary : AppColors.border, width: 2),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(
                height: 34,
                child: Center(
                  child: Text(
                    locked > Duration.zero ? tr.pinLocked(locked.inSeconds + 1) : (_error ?? ''),
                    style: const TextStyle(color: Color(0xFFFF6B6B), fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              // Ziffernblock (Maus, Controller).
              for (final row in const [
                ['1', '2', '3'],
                ['4', '5', '6'],
                ['7', '8', '9'],
                ['<', '0', 'ok'],
              ])
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final key in row)
                      _Key(
                        label: key,
                        onTap: switch (key) {
                          '<' => _back,
                          'ok' => _submit,
                          _ => () => _type(key),
                        },
                      ),
                  ],
                ),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(tr.cancel))],
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = switch (label) {
      '<' => Icons.backspace_outlined,
      'ok' => Icons.check_rounded,
      _ => null,
    };
    return Padding(
      padding: const EdgeInsets.all(5),
      child: Focusable(
        onTap: onTap,
        semanticLabel: switch (label) {
          '<' => tr.pinDelete,
          'ok' => tr.pinConfirm,
          _ => label,
        },
        builder: (context, hovered) => AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 64,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: label == 'ok' ? AppColors.accent : Colors.white.withValues(alpha: hovered ? 0.16 : 0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: hovered ? AppColors.accent : Colors.transparent, width: 2),
          ),
          child: icon != null
              ? Icon(icon, size: 22)
              : Text(label, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}
