import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../l10n/strings.dart';
import '../theme.dart';

/// Tab-Leiste unten auf dem iPhone: die Hauptziele immer in Daumennähe.
/// Steht außerhalb des Seiten-Navigators (siehe LayoutShell) und wechselt per `go`,
/// ein Ziel ersetzt also den Seitenstapel wie bei iOS-Tabs.
class MobileTabBar extends StatelessWidget {
  const MobileTabBar({super.key, required this.router, required this.active});

  final GoRouter router;

  /// Hervorgehobener Tab (Index in [tabs]).
  final int active;

  /// Höhe ohne den Bereich der Home-Leiste.
  static const height = 54.0;

  static List<({IconData icon, IconData activeIcon, String label, String path})> get tabs => [
    (icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: tr.home, path: '/'),
    (icon: Icons.search_rounded, activeIcon: Icons.manage_search_rounded, label: tr.search, path: '/search'),
    (icon: Icons.bookmarks_outlined, activeIcon: Icons.bookmarks_rounded, label: tr.listsTab, path: '/lists'),
    (icon: Icons.download_outlined, activeIcon: Icons.download_rounded, label: tr.downloads, path: '/downloads'),
  ];

  /// Tab, zu dem [path] gehört (`null` = Unterseite, der zuletzt gewählte Tab bleibt).
  static int? indexFor(String path) {
    final i = tabs.indexWhere((t) => t.path == path);
    return i < 0 ? null : i;
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Material(
      color: AppColors.surface,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
        ),
        padding: EdgeInsets.only(bottom: bottom),
        height: height + bottom,
        child: Row(
          children: [
            for (final (i, tab) in tabs.indexed)
              Expanded(
                child: _Tab(
                  icon: i == active ? tab.activeIcon : tab.icon,
                  label: tab.label,
                  selected: i == active,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    // Nochmal auf den aktiven Tab: zurück an seinen Anfang.
                    final current = router.routerDelegate.currentConfiguration.isEmpty ? '' : router.state.uri.path;
                    if (current != tab.path || router.canPop()) router.go(tab.path);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accent : AppColors.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Icon(icon, key: ValueKey(icon), size: 25, color: color),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: color, letterSpacing: 0.1),
            ),
          ],
        ),
      ),
    );
  }
}
