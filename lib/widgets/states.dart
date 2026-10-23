import 'package:flutter/material.dart';

import '../theme.dart';
import 'buttons.dart';
import '../l10n/strings.dart';

/// Pulsierender Platzhalter, solange Inhalte laden.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, required this.width, required this.height, this.radius = 12});

  final double width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.45, end: 1.0).animate(CurvedAnimation(parent: _anim, curve: Curves.easeInOut)),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(widget.radius)),
      ),
    );
  }
}

/// Mehrere Skeleton-Reihen als Ladeansicht.
class RowsSkeleton extends StatelessWidget {
  const RowsSkeleton({super.key, this.rows = 2});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kPageGutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var r = 0; r < rows; r++) ...[
            const Skeleton(width: 220, height: 22, radius: 6),
            const SizedBox(height: 18),
            ClipRect(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                child: Row(
                  children: [
                    for (var i = 0; i < 8; i++) ...[const Skeleton(width: 320, height: 180), const SizedBox(width: 18)],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ],
      ),
    );
  }
}

/// Fehleransicht mit "Erneut versuchen".
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, required this.onRetry, this.secondaryLabel, this.onSecondary});

  final String message;
  final VoidCallback onRetry;

  /// Optionaler zweiter Knopf (z. B. Downloads ansehen ohne Verbindung).
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              children: [
                GlassButton(label: tr.retry, icon: Icons.refresh_rounded, onPressed: onRetry),
                if (secondaryLabel != null && onSecondary != null)
                  GlassButton(label: secondaryLabel!, icon: Icons.download_done_rounded, onPressed: onSecondary),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
