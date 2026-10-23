import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/images.dart';
import '../core/models.dart';
import '../core/session.dart';
import '../theme.dart';
import 'focusable.dart';
import 'jf_image.dart';
import 'media_row.dart';

/// Reihe runder Personenbilder (Besetzung, Suchergebnisse) – Klick öffnet die Personenseite.
class PeopleRow extends ConsumerWidget {
  const PeopleRow({super.key, required this.title, required this.people});

  final String title;
  final List<Person> people;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider);
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 20),
      child: MediaRow(
        title: title,
        itemCount: people.length,
        height: 190,
        spacing: 22,
        itemBuilder: (context, i) {
          final p = people[i];
          return SizedBox(
            width: 120,
            child: Focusable(
              semanticLabel: p.role == null ? p.name : '${p.name}, ${p.role}',
              onTap: () => context.push('/person/${p.id}'),
              builder: (context, hovered) => Column(
                children: [
                  AnimatedScale(
                    scale: hovered ? 1.06 : 1,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    child: Container(
                      foregroundDecoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: hovered ? Colors.white.withValues(alpha: 0.9) : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: ClipOval(
                        child: SizedBox(
                          width: 120,
                          height: 120,
                          child: JfImage(
                            url: api.imageUrlOrNull(Images.person(p), fillWidth: 240, fillHeight: 360),
                            blurHash: p.blurHash,
                            alignment: Alignment.topCenter,
                            fallback: Icon(Icons.person_rounded, size: 48, color: AppColors.textMuted),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                  ),
                  if (p.role != null)
                    Text(
                      p.role!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
