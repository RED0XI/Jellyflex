import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/images.dart';
import '../../core/models.dart';
import '../../core/session.dart';
import '../../core/settings.dart';
import '../../theme.dart';
import '../../widgets/buttons.dart';
import '../../widgets/focusable.dart';
import '../../widgets/jf_image.dart';
import '../../l10n/strings.dart';

/// Eine Quizrunde: richtiger Titel, vier Antworten (in zufälliger Reihenfolge),
/// Bildausschnitt, an dem gezoomt wird.
class _Round {
  _Round(this.answer, this.choices, this.focus);

  final BaseItem answer;
  final List<BaseItem> choices;
  final Alignment focus;
}

/// Film-Quiz: Ein Hintergrundbild aus der eigenen Bibliothek ist anfangs stark
/// vergrößert und unscharf und wird mit der Zeit deutlicher. Wer schneller den
/// richtigen Titel wählt, bekommt mehr Punkte.
class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({super.key});

  static const rounds = 8;
  static const roundTime = Duration(seconds: 15);

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> with TickerProviderStateMixin {
  final _random = math.Random();
  late final _reveal = AnimationController(vsync: this, duration: QuizScreen.roundTime);
  final _focus = FocusNode(debugLabel: 'Quiz');

  List<_Round> _rounds = const [];
  int _index = 0;
  int _score = 0;
  int _correct = 0;

  /// Gewählte Antwort der aktuellen Runde (`null` = noch offen).
  BaseItem? _picked;
  int _lastPoints = 0;
  bool _loading = true;
  bool _finished = false;
  bool _newRecord = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reveal.addStatusListener((status) {
      // Zeit abgelaufen → wie eine falsche Antwort.
      if (status == AnimationStatus.completed && _picked == null && mounted) _choose(null);
    });
    _newGame();
  }

  @override
  void dispose() {
    _reveal.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _newGame() async {
    setState(() {
      _loading = true;
      _error = null;
      _finished = false;
      _newRecord = false;
      _index = 0;
      _score = 0;
      _correct = 0;
      _picked = null;
    });
    try {
      final pool = (await ref.read(apiProvider).getFeatured(limit: 60))
          .where((i) => Images.backdrop(i) != null)
          .toList();
      if (pool.length < 4) {
        setState(() {
          _loading = false;
          _error = tr.quizNeedsTitles;
        });
        return;
      }
      final answers = [...pool]..shuffle(_random);
      final rounds = [
        for (final answer in answers.take(QuizScreen.rounds))
          _Round(
            answer,
            ([answer, ...(pool.where((i) => i.id != answer.id).toList()..shuffle(_random)).take(3)]..shuffle(_random)),
            Alignment(_random.nextDouble() * 1.4 - 0.7, _random.nextDouble() * 1.2 - 0.6),
          ),
      ];
      if (!mounted) return;
      setState(() {
        _rounds = rounds;
        _loading = false;
      });
      _precache(0);
      _reveal.forward(from: 0);
      _focus.requestFocus();
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = tr.serverUnreachable;
        });
      }
    }
  }

  void _precache(int index) {
    for (final i in [index, index + 1]) {
      if (i >= _rounds.length) continue;
      final url = ref.read(apiProvider).imageUrlOrNull(Images.backdrop(_rounds[i].answer), maxWidth: 1280);
      if (url != null) precacheImage(NetworkImage(url), context).ignore();
    }
  }

  void _choose(BaseItem? item) {
    if (_picked != null || _finished || _rounds.isEmpty) return;
    final round = _rounds[_index];
    final right = item?.id == round.answer.id;
    // 100 Punkte fürs Richtige, bis zu 900 dazu für Schnelligkeit.
    final points = right ? 100 + (900 * (1 - _reveal.value)).round() : 0;
    _reveal.stop();
    setState(() {
      _picked = item ?? round.answer;
      _lastPoints = points;
      if (right) _correct++;
      _score += points;
    });
    // Bild ganz zeigen.
    _reveal.animateTo(1, duration: const Duration(milliseconds: 600), curve: Curves.easeOut);
  }

  void _next() {
    if (_index + 1 >= _rounds.length) {
      final best = ref.read(settingsProvider).quizHighscore;
      if (_score > best) {
        ref.read(settingsProvider.notifier).update((s) => s.copyWith(quizHighscore: _score));
      }
      setState(() {
        _finished = true;
        _newRecord = _score > best;
      });
      return;
    }
    setState(() {
      _index++;
      _picked = null;
    });
    _precache(_index);
    _reveal.forward(from: 0);
    _focus.requestFocus();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || _rounds.isEmpty || _finished) return KeyEventResult.ignored;
    const digits = [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
    ];
    final n = digits.indexOf(event.logicalKey);
    if (n >= 0 && _picked == null) {
      _choose(_rounds[_index].choices[n]);
      return KeyEventResult.handled;
    }
    if (_picked != null &&
        (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.space)) {
      _next();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(kPageGutter, kTitleBarHeight + 20, kPageGutter, 28),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                  child: Text(_error!, style: const TextStyle(color: AppColors.textSecondary)),
                )
              : _finished
              ? _Result(
                  score: _score,
                  correct: _correct,
                  rounds: _rounds.length,
                  highscore: ref.watch(settingsProvider).quizHighscore,
                  newRecord: _newRecord,
                  onAgain: _newGame,
                )
              : _buildRound(),
        ),
      ),
    );
  }

  Widget _buildRound() {
    final round = _rounds[_index];
    final api = ref.watch(apiProvider);
    final backdrop = Images.backdrop(round.answer);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.quiz_rounded, color: AppColors.accent, size: 28),
            const SizedBox(width: 10),
            Text(tr.movieQuiz, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
            const SizedBox(width: 20),
            Text(
              tr.roundOf(_index + 1, _rounds.length),
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
            ),
            const Spacer(),
            Text(tr.points(_score), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 14),
        // Zeitleiste.
        AnimatedBuilder(
          animation: _reveal,
          builder: (context, _) => ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: _picked == null ? 1 - _reveal.value : 0,
              minHeight: 5,
              backgroundColor: Colors.white12,
              color: Color.lerp(AppColors.accent, const Color(0xFFFF6B6B), _reveal.value),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Bild: erst stark vergrößert und unscharf, dann immer deutlicher.
                AnimatedBuilder(
                  animation: _reveal,
                  builder: (context, child) {
                    final t = Curves.easeIn.transform(_reveal.value);
                    final blur = 24 * (1 - t);
                    return ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur, tileMode: TileMode.clamp),
                      child: Transform.scale(scale: 1 + 2.4 * (1 - t), alignment: round.focus, child: child),
                    );
                  },
                  child: JfImage(
                    key: ValueKey(round.answer.id),
                    url: api.imageUrlOrNull(backdrop, maxWidth: 1280),
                    blurHash: null,
                  ),
                ),
                if (_picked != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(24, 40, 24, 20),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Color(0xE6000000), Color(0x00000000)],
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _lastPoints > 0 ? Icons.check_circle_rounded : Icons.cancel_rounded,
                            color: _lastPoints > 0 ? const Color(0xFF4ADE80) : const Color(0xFFFF6B6B),
                            size: 34,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _lastPoints > 0 ? tr.correctPlus(_lastPoints) : tr.notQuite,
                                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                                ),
                                Text(
                                  '${round.answer.name}${round.answer.productionYear != null ? ' (${round.answer.productionYear})' : ''}',
                                  style: const TextStyle(color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          PrimaryButton(
                            label: _index + 1 >= _rounds.length ? tr.result : tr.next,
                            icon: Icons.arrow_forward_rounded,
                            onPressed: _next,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            for (var i = 0; i < round.choices.length; i++) ...[
              if (i > 0) const SizedBox(width: 14),
              Expanded(
                child: _Choice(
                  number: i + 1,
                  item: round.choices[i],
                  state: _picked == null
                      ? _ChoiceState.open
                      : round.choices[i].id == round.answer.id
                      ? _ChoiceState.right
                      : round.choices[i].id == _picked!.id
                      ? _ChoiceState.wrong
                      : _ChoiceState.other,
                  onTap: () => _choose(round.choices[i]),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

enum _ChoiceState { open, right, wrong, other }

class _Choice extends StatelessWidget {
  const _Choice({required this.number, required this.item, required this.state, required this.onTap});

  final int number;
  final BaseItem item;
  final _ChoiceState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (color, border) = switch (state) {
      _ChoiceState.right => (const Color(0x334ADE80), const Color(0xFF4ADE80)),
      _ChoiceState.wrong => (const Color(0x33FF6B6B), const Color(0xFFFF6B6B)),
      _ChoiceState.other => (Colors.white.withValues(alpha: 0.03), Colors.transparent),
      _ChoiceState.open => (Colors.white.withValues(alpha: 0.08), Colors.transparent),
    };
    return Focusable(
      onTap: state == _ChoiceState.open ? onTap : null,
      builder: (context, hovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: hovered ? Colors.white.withValues(alpha: 0.16) : color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: hovered ? Colors.white70 : border, width: 2),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(8)),
              child: Text('$number', style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: state == _ChoiceState.other ? AppColors.textMuted : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({
    required this.score,
    required this.correct,
    required this.rounds,
    required this.highscore,
    required this.newRecord,
    required this.onAgain,
  });

  final int score;
  final int correct;
  final int rounds;
  final int highscore;
  final bool newRecord;
  final VoidCallback onAgain;

  @override
  Widget build(BuildContext context) {
    final verdict = switch (correct / rounds) {
      >= 0.875 => tr.verdictPro,
      >= 0.6 => tr.verdictStrong,
      >= 0.3 => tr.verdictNotBad,
      _ => tr.verdictMore,
    };
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (newRecord)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(gradient: AppColors.accentGradient, borderRadius: BorderRadius.circular(20)),
              child: Text(tr.newRecord, style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          Text(verdict, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text(tr.points(score), style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w300, height: 1.1)),
          const SizedBox(height: 6),
          Text(
            tr.correctOf(correct, rounds, math.max(highscore, score)),
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 16),
          ),
          const SizedBox(height: 28),
          PrimaryButton(label: tr.playAgain, icon: Icons.replay_rounded, onPressed: onAgain),
        ],
      ),
    );
  }
}
