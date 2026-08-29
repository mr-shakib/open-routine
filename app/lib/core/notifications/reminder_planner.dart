import '../../domain/entities/class_session.dart';
import '../config/app_config.dart';
import '../utils/lattice.dart';

/// One reminder to be scheduled with the OS.
class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.when,
    required this.title,
    required this.body,
    required this.session,
  });

  /// Stable across re-planning, so rescheduling replaces rather than duplicates.
  final int id;
  final DateTime when;
  final String title;
  final String body;
  final ClassSession session;
}

/// Works out *which* reminders to schedule, and when.
///
/// Deliberately pure: no platform calls, no clock of its own. That keeps the
/// interesting logic -- the rolling window, the lead time, weekday mapping --
/// unit-testable, which matters because the platform side cannot be tested off
/// a real device.
abstract final class ReminderPlanner {
  /// Reminders for [sessions] over the next [windowDays] days from [from].
  ///
  /// A rolling window rather than a whole semester: iOS caps an app at 64
  /// pending notifications, and a full 6x6 routine would blow past it. The app
  /// tops the window up on each launch.
  static List<PlannedReminder> plan({
    required List<ClassSession> sessions,
    required DateTime from,
    int windowDays = 7,
    int leadMinutes = AppConfig.reminderLeadMinutes,
    int maxReminders = 60,
  }) {
    final planned = <PlannedReminder>[];

    for (var offset = 0; offset <= windowDays; offset++) {
      final date = DateTime(
        from.year,
        from.month,
        from.day,
      ).add(Duration(days: offset));
      final dayName = weekdayName(date);
      if (dayName == null) continue; // Friday

      for (final session in sessions.where((s) => s.day == dayName)) {
        final fireAt = date.add(
          Duration(minutes: session.startMin - leadMinutes),
        );

        // Skip anything already past -- scheduling it would fire immediately.
        if (!fireAt.isAfter(from)) continue;

        planned.add(
          PlannedReminder(
            id: _stableId(session, date),
            when: fireAt,
            title: '${session.baseCourseCode} in $leadMinutes min',
            body: [
              prettySlot(session.timeSlot),
              session.room,
              if (session.hasTeacher) session.teacher,
            ].join(' · '),
            session: session,
          ),
        );
      }
    }

    planned.sort((a, b) => a.when.compareTo(b.when));
    return planned.length > maxReminders
        ? planned.sublist(0, maxReminders)
        : planned;
  }

  /// A deterministic id for a class on a given date.
  ///
  /// Same class, same day, same id -- so re-planning overwrites the previous
  /// reminder instead of stacking a duplicate on top of it.
  static int _stableId(ClassSession session, DateTime date) {
    final key =
        '${date.year}-${date.month}-${date.day}|'
        '${session.courseCode}|${session.timeSlot}|${session.room}';
    // Positive 31-bit value: Android notification ids must fit in an int.
    return key.hashCode & 0x7FFFFFFF;
  }
}
