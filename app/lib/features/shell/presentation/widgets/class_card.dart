import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/lattice.dart';
import '../../../../domain/entities/class_session.dart';

/// One class, rendered as a card.
///
/// [trailingLabel] carries whichever axis the current view is *not* keyed on:
/// the student view shows the teacher, the teacher view shows the batch.
class ClassCard extends StatelessWidget {
  const ClassCard({
    required this.session,
    this.trailingLabel,
    this.isLive = false,
    super.key,
  });

  final ClassSession session;
  final String? trailingLabel;
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final accent = session.isOptional
        ? scheme.optionalAccent
        : session.isLab
        ? scheme.labAccent
        : scheme.primary;

    return Semantics(
      label:
          '${session.baseCourseCode}, ${prettySlot(session.timeSlot)}, '
          'room ${session.room}'
          '${trailingLabel == null ? '' : ', $trailingLabel'}'
          '${isLive ? ', happening now' : ''}',
      child: Card(
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              session.courseTitle ?? session.baseCourseCode,
                              style: text.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isLive)
                            const _Pill(label: 'Now', tone: _Tone.live),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        session.courseCode,
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 14,
                        runSpacing: 6,
                        children: [
                          _Meta(
                            icon: Icons.schedule,
                            label: prettySlot(session.timeSlot),
                          ),
                          _Meta(
                            icon: Icons.place_outlined,
                            label: session.room,
                          ),
                          if (trailingLabel != null)
                            _Meta(
                              icon: Icons.person_outline,
                              label: trailingLabel!,
                            ),
                        ],
                      ),
                      if (session.isLab || session.isOptional) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          children: [
                            // Labelled, not colour-coded: the accent stripe is
                            // reinforcement, never the only signal.
                            if (session.isLab)
                              _Pill(
                                label: 'Lab ${session.subsection ?? ''}'.trim(),
                              ),
                            if (session.isOptional)
                              const _Pill(label: 'Optional'),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _Tone { neutral, live }

class _Pill extends StatelessWidget {
  const _Pill({required this.label, this.tone = _Tone.neutral});
  final String label;
  final _Tone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLive = tone == _Tone.live;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isLive ? scheme.primary : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: isLive ? scheme.onPrimary : scheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: scheme.onSurfaceVariant),
        const SizedBox(width: 5),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
