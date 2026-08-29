import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/lattice.dart';
import '../../../../domain/entities/class_session.dart';

/// One class, anchored to its time.
///
/// A timetable's primary axis is time, so the start time sits in a fixed left
/// rail and the cards line up down the page: a day can be read by scanning that
/// column alone. Course code, then room, then who — in the order people ask.
///
/// The card deliberately does not repeat the fused source token. `course_title`
/// is not published with the routine, so an earlier version printed `CSE322`
/// and `CSE322(66_B1)` on the two most valuable lines — the same thing twice.
/// The section now appears as a chip, which is shorter and says more.
class ClassCard extends StatelessWidget {
  const ClassCard({
    required this.session,
    this.trailingLabel,
    this.isLive = false,
    super.key,
  });

  final ClassSession session;

  /// Whichever axis the current view is *not* keyed on: the student view shows
  /// the teacher, the teacher view shows the section.
  final String? trailingLabel;

  final bool isLive;

  static const _railWidth = 62.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final accent = session.isOptional
        ? scheme.optionalAccent
        : session.isLab
        ? scheme.labAccent
        : scheme.primary;

    final parts = prettySlot(session.timeSlot).split(' – ');
    final start = parts.first.replaceAll(' AM', '').replaceAll(' PM', '');
    final meridiem = parts.first.contains('PM') ? 'PM' : 'AM';

    return Semantics(
      label: [
        session.baseCourseCode,
        prettySlot(session.timeSlot),
        'room ${session.room}',
        ?trailingLabel,
        if (isLive) 'happening now',
      ].join(', '),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ---- the time rail: the spine of the day --------------------
            SizedBox(
              width: _railWidth,
              child: Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      start,
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isLive ? accent : scheme.onSurface,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        height: 1.1,
                      ),
                    ),
                    Text(
                      meridiem,
                      style: text.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      parts.length > 1
                          ? parts[1].replaceAll(' AM', '').replaceAll(' PM', '')
                          : '',
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),

            // ---- the class ----------------------------------------------
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isLive
                      ? accent.withValues(alpha: 0.12)
                      : scheme.surfaceContainerHighest.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isLive
                        ? accent.withValues(alpha: 0.55)
                        : scheme.outlineVariant.withValues(alpha: 0.7),
                  ),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: 3.5,
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(14),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      session.courseTitle ??
                                          session.baseCourseCode,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: text.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ),
                                  if (isLive) _NowPill(accent: accent),
                                ],
                              ),
                              const SizedBox(height: 9),
                              Row(
                                children: [
                                  Icon(
                                    Icons.place_outlined,
                                    size: 15,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      session.room,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: text.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  if (trailingLabel != null) ...[
                                    Text(
                                      '  ·  ',
                                      style: text.bodyMedium?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                    Flexible(
                                      child: Text(
                                        trailingLabel!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: text.bodyMedium?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 9),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  // The section is what the routine actually
                                  // keys on, so it earns a place of its own
                                  // rather than being buried in the code.
                                  _Tag(label: session.section, accent: accent),
                                  if (session.isLab)
                                    _Tag(
                                      label: session.subsection == null
                                          ? 'Lab'
                                          : 'Lab group ${session.subsection}',
                                    ),
                                  if (session.isOptional)
                                    const _Tag(label: 'Optional'),
                                  if (session.roomType != 'Theory')
                                    _Tag(label: session.roomType),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NowPill extends StatelessWidget {
  const _NowPill({required this.accent});
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        'NOW',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.surface,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, this.accent});
  final String label;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colour = accent ?? scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colour,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
