import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/models.dart';
import '../core/session.dart';
import '../theme.dart';
import 'details/details_screen.dart';

enum _ItemAction { play, playFromStart, details, series, markPlayed, markUnplayed, favorite, unfavorite, forget }

/// Kontextmenü (Rechtsklick) für Karten: Abspielen, als gesehen markieren,
/// aus "Weiterschauen" entfernen, Favoriten …
Future<void> showItemContextMenu(BuildContext context, BaseItem item, Offset globalPosition) async {
  final container = ProviderScope.containerOf(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final router = GoRouter.of(context);
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  final data = item.userData;
  final canPlay = !item.isSeries && !item.isSeason;

  PopupMenuItem<_ItemAction> entry(_ItemAction value, IconData icon, String label) => PopupMenuItem(
    value: value,
    height: 42,
    child: Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: 14),
        Text(label),
      ],
    ),
  );

  final action = await showMenu<_ItemAction>(
    context: context,
    position: RelativeRect.fromRect(globalPosition & const Size(1, 1), Offset.zero & overlay.size),
    constraints: const BoxConstraints(minWidth: 240),
    items: [
      PopupMenuItem(
        enabled: false,
        height: 34,
        child: Text(
          item.isEpisode ? '${item.seriesName ?? ''} · ${item.episodeLabel ?? ''}' : item.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
      if (canPlay)
        entry(_ItemAction.play, Icons.play_arrow_rounded, data.hasResumePosition ? 'Fortsetzen' : 'Abspielen'),
      if (canPlay && data.hasResumePosition)
        entry(_ItemAction.playFromStart, Icons.replay_rounded, 'Von vorne abspielen'),
      entry(_ItemAction.details, Icons.info_outline_rounded, 'Details'),
      if (item.isEpisode && item.seriesId != null) entry(_ItemAction.series, Icons.tv_rounded, 'Zur Serie'),
      const PopupMenuDivider(),
      if (data.played)
        entry(_ItemAction.markUnplayed, Icons.remove_done_rounded, 'Als ungesehen markieren')
      else
        entry(_ItemAction.markPlayed, Icons.check_rounded, 'Bereits angeschaut'),
      if (data.isFavorite)
        entry(_ItemAction.unfavorite, Icons.heart_broken_rounded, 'Aus Favoriten entfernen')
      else
        entry(_ItemAction.favorite, Icons.favorite_border_rounded, 'Zu Favoriten hinzufügen'),
      if (data.hasResumePosition) entry(_ItemAction.forget, Icons.history_toggle_off_rounded, 'Vergessen'),
    ],
  );
  if (action == null) return;

  final api = container.read(apiProvider);
  final ticks = data.playbackPositionTicks;

  Future<void> run(Future<void> Function() call, String done) async {
    try {
      await call();
      refreshItemDataIn(container, item);
      messenger?.showSnackBar(_snack(done));
    } catch (_) {
      messenger?.showSnackBar(_snack('Das hat leider nicht geklappt.'));
    }
  }

  switch (action) {
    case _ItemAction.play:
      router.push('/play/${item.id}${ticks > 0 ? '?start=$ticks' : ''}');
    case _ItemAction.playFromStart:
      router.push('/play/${item.id}');
    case _ItemAction.details:
      router.push('/item/${item.id}');
    case _ItemAction.series:
      router.push('/item/${item.seriesId}');
    case _ItemAction.markPlayed:
      await run(() => api.setPlayed(item.id, true), '„${item.name}“ als angeschaut markiert');
    case _ItemAction.markUnplayed:
      await run(() => api.setPlayed(item.id, false), '„${item.name}“ als ungesehen markiert');
    case _ItemAction.favorite:
      await run(() => api.setFavorite(item.id, true), 'Zu Favoriten hinzugefügt');
    case _ItemAction.unfavorite:
      await run(() => api.setFavorite(item.id, false), 'Aus Favoriten entfernt');
    case _ItemAction.forget:
      await run(() => api.clearResumePosition(item.id), 'Aus „Weiterschauen“ entfernt');
  }
}

SnackBar _snack(String text) => SnackBar(
  content: Text(text),
  behavior: SnackBarBehavior.floating,
  width: 420,
  backgroundColor: AppColors.surfaceHigh,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  duration: const Duration(seconds: 3),
);
