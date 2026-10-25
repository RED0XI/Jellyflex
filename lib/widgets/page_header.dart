import 'package:flutter/material.dart';

import '../theme.dart';

/// Kopf einer Seite: großer Titel, darunter eine Zeile Erklärung, rechts die Aktionen
/// der Seite. Überall gleich, damit Listen, Downloads, Kalender, Bibliothek & Co.
/// dieselben Abstände haben.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.actions = const [],
    this.padding = defaultPadding,
  });

  /// Abstand zum Fensterrand und zum Inhalt darunter.
  static const defaultPadding = EdgeInsets.fromLTRB(kPageGutter, kTitleBarHeight + 28, kPageGutter, 24);

  final String title;
  final String? subtitle;

  /// Kleines Symbol in Akzentfarbe vor dem Titel (z. B. Würfel bei "Überrasch mich").
  final IconData? icon;
  final List<Widget> actions;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (icon != null) ...[Icon(icon, size: 34, color: AppColors.accent), const SizedBox(width: 12)],
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w800, letterSpacing: -0.8),
                      ),
                    ),
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
                ],
              ],
            ),
          ),
          for (final (i, action) in actions.indexed) ...[SizedBox(width: i == 0 ? 24 : 10), action],
        ],
      ),
    );
  }
}
