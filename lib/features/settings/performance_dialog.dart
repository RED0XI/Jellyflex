import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../core/performance_check.dart';
import '../../core/platform/app_paths.dart';
import '../../core/session.dart';
import '../../core/settings.dart';
import '../../l10n/strings.dart';
import '../../theme.dart';

/// Leistungstest starten (Einstellungen → Über): erklärt, was passiert, zeigt
/// den Fortschritt und am Ende die wichtigsten Zahlen und den gespeicherten Bericht.
Future<void> showPerformanceDialog(BuildContext context) =>
    showDialog<void>(context: context, barrierDismissible: false, builder: (_) => const PerformanceDialog());

class PerformanceDialog extends ConsumerStatefulWidget {
  const PerformanceDialog({super.key});

  @override
  ConsumerState<PerformanceDialog> createState() => _PerformanceDialogState();
}

class _PerformanceDialogState extends ConsumerState<PerformanceDialog> {
  bool _playback = true;
  bool _running = false;
  double _progress = 0;
  Map<String, Object?>? _report;
  File? _file;
  bool _failed = false;

  Future<void> _start() async {
    final session = ref.read(sessionProvider).value;
    if (session == null) return;
    setState(() => _running = true);
    final check = PerformanceCheck(
      api: ref.read(apiProvider),
      session: session,
      settings: ref.read(settingsProvider),
      router: ref.read(routerProvider),
      playback: _playback,
      onProgress: (_, progress) {
        if (mounted) setState(() => _progress = progress);
      },
    );
    try {
      final report = await check.run();
      final file = await check.save(report);
      if (mounted) {
        setState(() {
          _report = report;
          _file = file;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
    if (mounted) setState(() => _running = false);
  }

  static Object? _at(Map<String, Object?>? report, List<String> path) {
    Object? value = report;
    for (final key in path) {
      value = value is Map ? value[key] : null;
    }
    return value;
  }

  List<(String, String)> _summary(Map<String, Object?> r) {
    String? number(List<String> path, String unit, {num factor = 1, int digits = 0}) {
      final value = _at(r, path);
      return value is num ? '${(value * factor).toStringAsFixed(digits)} $unit' : null;
    }

    return [
      (tr.perfServer, number(['server', 'pingMs', 'median'], 'ms')),
      (tr.perfNetwork, number(['throughput', 'mbit'], 'Mbit/s')),
      (tr.perfImages, number(['images', 'singleMs', 'median'], 'ms')),
      (tr.perfScrolling, number(['scrolling', 'smoothPercent'], '%')),
      (tr.perfPlayback, number(['playback', 'startMs'], 's', factor: 1 / 1000, digits: 1)),
    ].where((e) => e.$2 != null).map((e) => (e.$1, e.$2!)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    final step = (_progress * 9).floor() + 1;
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(tr.perfTest),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (report != null) ...[
              Text(tr.perfTestDone),
              const SizedBox(height: 14),
              for (final (label, value) in _summary(report))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(label, style: TextStyle(color: AppColors.textSecondary)),
                      ),
                      Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              SelectableText(_file?.path ?? '', style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
            ] else if (_failed)
              Text(tr.perfTestFailed, style: const TextStyle(color: Color(0xFFFF6B6B)))
            else if (_running) ...[
              Text(tr.perfTestStep(step.clamp(1, 9), 9)),
              const SizedBox(height: 16),
              LinearProgressIndicator(value: _progress),
            ] else ...[
              Text(tr.perfTestIntro, style: TextStyle(color: AppColors.textSecondary, height: 1.4)),
              const SizedBox(height: 12),
              CheckboxListTile(
                value: _playback,
                onChanged: (v) => setState(() => _playback = v ?? true),
                title: Text(tr.perfTestPlayback),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (!_running) TextButton(onPressed: () => Navigator.pop(context), child: Text(tr.close)),
        if (report != null && _file != null)
          FilledButton.icon(
            onPressed: () => AppPaths.reveal(_file!.path),
            icon: const Icon(Icons.folder_open_rounded, size: 18),
            label: Text(tr.showInFolder),
          )
        else if (!_running && !_failed)
          FilledButton.icon(
            onPressed: _start,
            icon: const Icon(Icons.speed_rounded, size: 18),
            label: Text(tr.perfTestStart),
          ),
      ],
    );
  }
}
