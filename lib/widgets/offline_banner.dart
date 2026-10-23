import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/server_status.dart';
import '../l10n/strings.dart';
import '../theme.dart';
import 'window_frame.dart';

/// Hinweis unten in der Mitte, solange der Server nicht erreichbar ist –
/// mit "Erneut versuchen" und dem Weg zu den Downloads. Im Player bleibt er
/// ausgeblendet (offline läuft dort gerade ein Download).
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key, required this.router, required this.child});

  final GoRouter router;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(serverOnlineProvider);
    return Stack(
      children: [
        Positioned.fill(child: child),
        Positioned(
          bottom: 28,
          left: 0,
          right: 0,
          child: ListenableBuilder(
            listenable: Listenable.merge([windowChromeVisible, router.routeInformationProvider]),
            builder: (context, _) {
              final inPlayer = router.state.uri.path.startsWith('/play');
              final show = !online && windowChromeVisible.value && !inPlayer;
              return IgnorePointer(
                ignoring: !show,
                child: AnimatedSlide(
                  offset: show ? Offset.zero : const Offset(0, 1.6),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  child: AnimatedOpacity(
                    opacity: show ? 1 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: Center(child: _Pill(router: router)),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Pill extends ConsumerWidget {
  const _Pill({required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Semantics(
      liveRegion: true,
      child: Material(
        color: AppColors.surfaceHigh,
        elevation: 8,
        shadowColor: Colors.black54,
        shape: StadiumBorder(side: BorderSide(color: AppColors.border)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 6, 6, 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 20, color: Color(0xFFFFB74D)),
              const SizedBox(width: 10),
              Text(tr.serverOffline, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Text(tr.offlineHint, style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(width: 10),
              TextButton(onPressed: () => router.push('/downloads'), child: Text(tr.downloads)),
              TextButton(onPressed: () => ref.read(serverOnlineProvider.notifier).check(), child: Text(tr.retry)),
            ],
          ),
        ),
      ),
    );
  }
}
