import 'package:flutter_test/flutter_test.dart';
import 'package:open_routine/core/notifications/reminder_planner.dart';

import '../fixtures.dart';

void main() {
  // Saturday 2026-08-29, 06:00 -- before the teaching day starts.
  final saturdayMorning = DateTime(2026, 8, 29, 6);

  group('ReminderPlanner', () {
    test('plans a reminder ahead of each class', () {
      final plan = ReminderPlanner.plan(
        sessions: testSessions.where((s) => s.batch == '60_C').toList(),
        from: saturdayMorning,
        windowDays: 0, // Saturday only
      );

      // 60_C has two Saturday classes.
      expect(plan, hasLength(2));
      // 08:30 class, 20 minutes lead -> 08:10.
      expect(plan.first.when, DateTime(2026, 8, 29, 8, 10));
    });

    test('skips classes that have already started', () {
      final plan = ReminderPlanner.plan(
        sessions: testSessions.where((s) => s.batch == '60_C').toList(),
        from: DateTime(2026, 8, 29, 9), // 08:30 class already running
        windowDays: 0,
      );

      expect(plan, hasLength(1)); // only the 10:00 class remains
      expect(plan.single.when, DateTime(2026, 8, 29, 9, 40));
    });

    test('skips Friday entirely', () {
      final plan = ReminderPlanner.plan(
        sessions: testSessions,
        from: DateTime(2026, 9, 3, 6), // Thursday
        windowDays: 1, // Thursday + Friday
      );

      // Friday contributes nothing, so only Thursday's class is planned.
      expect(plan.every((r) => r.session.day == 'Thursday'), isTrue);
    });

    test('covers a full week across day boundaries', () {
      final plan = ReminderPlanner.plan(
        sessions: testSessions,
        from: saturdayMorning,
      );
      expect(plan.map((r) => r.session.day).toSet(), hasLength(greaterThan(1)));
    });

    test('is sorted by fire time', () {
      final plan = ReminderPlanner.plan(
        sessions: testSessions,
        from: saturdayMorning,
      );
      final times = plan.map((r) => r.when).toList();
      expect(times, orderedEquals([...times]..sort()));
    });

    test('caps the plan so iOS 64-notification limit is not exceeded', () {
      final plan = ReminderPlanner.plan(
        sessions: testSessions,
        from: saturdayMorning,
        windowDays: 60, // two months
      );
      expect(plan.length, lessThanOrEqualTo(60));
    });

    test('ids are stable, so re-planning replaces rather than duplicates', () {
      final first = ReminderPlanner.plan(
        sessions: testSessions,
        from: saturdayMorning,
      );
      final second = ReminderPlanner.plan(
        sessions: testSessions,
        from: saturdayMorning,
      );

      expect(first.map((r) => r.id), orderedEquals(second.map((r) => r.id)));
      // And unique within a plan, so no reminder silently overwrites another.
      expect(first.map((r) => r.id).toSet(), hasLength(first.length));
    });

    test('ids are positive, as Android notification ids must be', () {
      final plan = ReminderPlanner.plan(
        sessions: testSessions,
        from: saturdayMorning,
      );
      expect(plan.every((r) => r.id > 0), isTrue);
    });

    test('body carries the details a student needs at a glance', () {
      final plan = ReminderPlanner.plan(
        sessions: testSessions.where((s) => s.batch == '62_E').toList(),
        from: saturdayMorning,
        windowDays: 0,
      );
      expect(plan.first.title, contains('CSE414'));
      expect(plan.first.body, contains('KT-503'));
      expect(plan.first.body, contains('SRH'));
    });

    test('an empty schedule plans nothing', () {
      expect(
        ReminderPlanner.plan(sessions: const [], from: saturdayMorning),
        isEmpty,
      );
    });
  });
}
