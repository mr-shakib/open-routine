import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/lattice.dart';
import '../../../../domain/entities/class_session.dart';

/// The whole week as the lattice it actually is: six slots down, six days
/// across.
///
/// The day list answers "what do I have on Tuesday". This answers the questions
/// the day list cannot -- where the free afternoons are, which day is heaviest,
/// whether Thursday is worth coming in for. Rows are time slots and columns are
/// days, so a free run reads as a vertical gap.
class WeekGrid extends StatelessWidget {
  const WeekGrid({
    required this.sessions,
    required this.onTapDay,
    this.today,
    super.key,
  });

  final List<ClassSession> sessions;
  final ValueChanged<String> onTapDay;

  /// Highlighted so the current day is findable without reading labels.
  final String? today;

  // Sized so roughly four days sit on a phone screen at once: enough for the
  // view to read as a week rather than a wide day, while leaving the room code
  // legible. The partially visible fifth column is the scroll affordance.
  static const _slotColumnWidth = 46.0;
  static const _dayColumnWidth = 84.0;
  static const _rowHeight = 58.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // One cell can hold more than one class: split lab groups run at the same
    // time in different rooms, and both are real.
    final cells = <String, List<ClassSession>>{};
    for (final s in sessions) {
      cells.putIfAbsent('${s.day}|${s.timeSlot}', () => []).add(s);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(width: _slotColumnWidth),
              for (final day in kDays)
                _DayHeader(
                  day: day,
                  count: sessions.where((s) => s.day == day).length,
                  isToday: day == today,
                  onTap: () => onTapDay(day),
                ),
            ],
          ),
          const SizedBox(height: 6),
          for (final slot in kSlots)
            Row(
              children: [
                SizedBox(
                  width: _slotColumnWidth,
                  height: _rowHeight,
                  child: Center(
                    child: Text(
                      slot.split('-').first,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
                for (final day in kDays)
                  _Cell(
                    sessions: cells['$day|$slot'] ?? const [],
                    isToday: day == today,
                    onTap: () => onTapDay(day),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.day,
    required this.count,
    required this.isToday,
    required this.onTap,
  });

  final String day;
  final int count;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: WeekGrid._dayColumnWidth,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              Text(
                dayAbbreviation(day),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: isToday ? scheme.primary : scheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                count == 0 ? '–' : '$count',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isToday ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.sessions, required this.isToday, required this.onTap});

  final List<ClassSession> sessions;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final busy = sessions.isNotEmpty;
    final first = busy ? sessions.first : null;

    final accent = first == null
        ? null
        : first.isOptional
        ? scheme.optionalAccent
        : first.isLab
        ? scheme.labAccent
        : scheme.primary;

    return Padding(
      padding: const EdgeInsets.all(2),
      child: SizedBox(
        width: WeekGrid._dayColumnWidth - 4,
        height: WeekGrid._rowHeight - 4,
        child: Material(
          color: busy
              ? accent!.withValues(alpha: 0.14)
              : isToday
              ? scheme.surfaceContainerHighest.withValues(alpha: 0.35)
              : scheme.surfaceContainerHighest.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: !busy
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          first!.baseCourseCode,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          sessions.length > 1
                              ? '${sessions.length} groups'
                              : first.room,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
