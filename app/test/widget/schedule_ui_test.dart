import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_routine/core/utils/lattice.dart';
import 'package:open_routine/features/student/presentation/widgets/free_gap.dart';
import 'package:open_routine/features/student/presentation/widgets/recent_searches.dart';
import 'package:open_routine/features/student/presentation/widgets/up_next.dart';
import 'package:open_routine/features/student/presentation/widgets/view_toggle.dart';
import 'package:open_routine/features/student/presentation/widgets/week_grid.dart';

import '../fixtures.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  await tester.pumpAndSettle();
}

/// For widgets carrying a looping animation: pumpAndSettle would wait forever.
Future<void> _pumpLooping(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  group('RecentSearches', () {
    testWidgets('lists batches and reports taps', (tester) async {
      String? tapped;
      await _pump(
        tester,
        RecentSearches(
          batches: const ['66_B', '60_C'],
          current: '66_B',
          onSelect: (b) => tapped = b,
          onRemove: (_) {},
        ),
      );

      expect(find.text('66_B'), findsOneWidget);
      expect(find.text('60_C'), findsOneWidget);

      await tester.tap(find.text('60_C'));
      expect(tapped, '60_C');
    });

    testWidgets('long press forgets one', (tester) async {
      String? removed;
      await _pump(
        tester,
        RecentSearches(
          batches: const ['66_B'],
          onSelect: (_) {},
          onRemove: (b) => removed = b,
        ),
      );

      await tester.longPress(find.text('66_B'));
      expect(removed, '66_B');
    });

    testWidgets('renders nothing when there is no history', (tester) async {
      await _pump(
        tester,
        RecentSearches(batches: const [], onSelect: (_) {}, onRemove: (_) {}),
      );
      expect(find.text('RECENT'), findsNothing);
    });
  });

  group('ViewToggle', () {
    testWidgets('reports the other mode when tapped', (tester) async {
      bool? got;
      await _pump(
        tester,
        SizedBox(
          width: 300,
          child: ViewToggle(weekView: false, onChanged: (v) => got = v),
        ),
      );

      await tester.tap(find.text('Week'));
      expect(got, isTrue);
    });
  });

  group('WeekGrid', () {
    testWidgets('shows every day and slot of the lattice', (tester) async {
      await _pump(
        tester,
        WeekGrid(sessions: testSessions, today: 'Saturday', onTapDay: (_) {}),
      );

      for (final day in kDays) {
        expect(find.text(dayAbbreviation(day)), findsOneWidget);
      }
      // Row labels are the slot start times.
      expect(find.text('08:30'), findsOneWidget);
      expect(find.text('04:00'), findsOneWidget);
    });

    testWidgets('tapping a day reports it', (tester) async {
      String? tapped;
      await _pump(
        tester,
        WeekGrid(sessions: testSessions, onTapDay: (d) => tapped = d),
      );

      await tester.tap(find.text('Mon'));
      expect(tapped, 'Monday');
    });

    testWidgets('collapses simultaneous lab groups into one cell', (
      tester,
    ) async {
      // 62_E1 and 62_E2 run at the same time in different rooms; the cell says
      // how many rather than pretending there is one.
      final clash = [
        testSessions.firstWhere((s) => s.section == '62_E1'),
        testSessions
            .firstWhere((s) => s.section == '62_E1')
            .copyWith(room: 'G1-099', section: '62_E2'),
      ];
      await _pump(tester, WeekGrid(sessions: clash, onTapDay: (_) {}));
      expect(find.text('2 groups'), findsOneWidget);
    });
  });

  group('FreeGap', () {
    test('only worth drawing for a real break', () {
      expect(FreeGap.worthShowing(0), isFalse);
      expect(FreeGap.worthShowing(29), isFalse);
      expect(FreeGap.worthShowing(90), isTrue);
    });

    test('consecutive slots leave no gap', () {
      expect(gapBetween('08:30-10:00', '10:00-11:30'), 0);
    });

    test('measures a real break', () {
      // 10:00 ends, 13:00 starts -> three hours.
      expect(gapBetween('08:30-10:00', '01:00-02:30'), 180);
    });

    testWidgets('renders the length', (tester) async {
      await _pump(tester, const FreeGap(minutes: 90));
      expect(find.text('1h 30m free'), findsOneWidget);
    });
  });

  group('UpNext', () {
    testWidgets('stays out of the way on Friday', (tester) async {
      await _pumpLooping(
        tester,
        UpNext(sessions: testSessions, now: DateTime(2026, 8, 28, 10)),
      );
      expect(find.textContaining('class'), findsNothing);
    });

    testWidgets('says so during a class', (tester) async {
      // Saturday 09:00 falls inside the 08:30-10:00 slot.
      await _pumpLooping(
        tester,
        UpNext(sessions: testSessions, now: DateTime(2026, 8, 29, 9)),
      );
      expect(find.text('In class now'), findsOneWidget);
    });

    testWidgets('counts down to the next one', (tester) async {
      // Saturday 08:15, fifteen minutes before the first class.
      await _pumpLooping(
        tester,
        UpNext(sessions: testSessions, now: DateTime(2026, 8, 29, 8, 15)),
      );
      expect(find.text('Next in 15 min'), findsOneWidget);
    });

    testWidgets('says nothing once the day is over', (tester) async {
      await _pumpLooping(
        tester,
        UpNext(sessions: testSessions, now: DateTime(2026, 8, 29, 23)),
      );
      expect(find.textContaining('In class'), findsNothing);
      expect(find.textContaining('Next in'), findsNothing);
    });
  });
}
