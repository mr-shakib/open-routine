import 'package:flutter/material.dart';

import '../../../../core/utils/lattice.dart';
import '../../../../domain/entities/class_session.dart';

/// A single line answering the question people actually open the app for:
/// where do I need to be, and when.
///
/// Only shown when it can say something true about right now — during the
/// teaching week, with a class in progress or still to come today. On a quiet
/// evening it stays out of the way rather than displaying a stale "next class"
/// from three days ago.
class UpNext extends StatelessWidget {
  const UpNext({required this.sessions, required this.now, super.key});

  final List<ClassSession> sessions;
  final DateTime now;

  static ClassSession? _current(List<ClassSession> today, int minutes) {
    for (final s in today) {
      if (minutes >= s.startMin && minutes < s.endMin) return s;
    }
    return null;
  }

  static ClassSession? _next(List<ClassSession> today, int minutes) {
    ClassSession? best;
    for (final s in today) {
      if (s.startMin > minutes &&
          (best == null || s.startMin < best.startMin)) {
        best = s;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final day = weekdayName(now);
    if (day == null) return const SizedBox.shrink();

    final minutes = now.hour * 60 + now.minute;
    final today = sessions.where((s) => s.day == day).toList();
    if (today.isEmpty) return const SizedBox.shrink();

    final current = _current(today, minutes);
    final next = current == null ? _next(today, minutes) : null;
    final session = current ?? next;
    if (session == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final live = current != null;
    final minutesAway = session.startMin - minutes;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 8 * (1 - t)),
          child: child,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: live ? 0.16 : 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: scheme.primary.withValues(alpha: live ? 0.45 : 0.2),
          ),
        ),
        child: Row(
          children: [
            if (live)
              const _Pulse()
            else
              Icon(Icons.schedule, size: 16, color: scheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    live
                        ? 'In class now'
                        : minutesAway <= 60
                        ? 'Next in $minutesAway min'
                        : 'Up next today',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${session.baseCourseCode} · ${session.room}'
                    '${session.hasTeacher ? ' · ${session.teacher}' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              prettySlot(session.timeSlot).split(' – ').first,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// A slow breathing dot. Signals "this is live" without a spinner, which would
/// imply something is loading.
class _Pulse extends StatefulWidget {
  const _Pulse();

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 16,
      height: 16,
      child: Center(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: scheme.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.5 * _c.value),
                  blurRadius: 8 * _c.value,
                  spreadRadius: 3 * _c.value,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
