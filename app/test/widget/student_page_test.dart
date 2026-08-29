import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:open_routine/core/providers/app_providers.dart';
import 'package:open_routine/core/providers/settings_provider.dart';
import 'package:open_routine/data/datasources/local/database.dart';
import 'package:open_routine/data/datasources/remote/routine_api.dart';
import 'package:open_routine/data/repositories/routine_repository_impl.dart';
import 'package:open_routine/features/shell/presentation/widgets/class_card.dart';
import 'package:open_routine/features/student/presentation/pages/student_page.dart';
import 'package:open_routine/features/student/providers/student_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fixtures.dart';

class MockApi extends Mock implements RoutineApi {}

Future<Widget> harness(AppDatabase db, {String? batch}) async {
  SharedPreferences.setMockInitialValues(
    batch == null ? {} : {'saved_batch': batch},
  );
  final prefs = await SharedPreferences.getInstance();
  final api = MockApi();

  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      databaseProvider.overrideWithValue(db),
      routineApiProvider.overrideWithValue(api),
      routineRepositoryProvider.overrideWithValue(
        RoutineRepositoryImpl(database: db, api: api),
      ),
    ],
    child: const MaterialApp(home: Scaffold(body: StudentPage())),
  );
}

void main() {
  late AppDatabase db;

  setUp(() async {
    db = testDatabase();
    await db.replaceRoutine(routine: testRoutine, sessions: testSessions);
  });

  tearDown(() => db.close());

  testWidgets('prompts for a batch when none is saved', (tester) async {
    await tester.pumpWidget(await harness(db));
    await tester.pumpAndSettle();

    expect(find.text('Find your schedule'), findsOneWidget);
    expect(find.byType(ClassCard), findsNothing);
  });

  testWidgets('renders the saved batch on first frame', (tester) async {
    await tester.pumpWidget(await harness(db, batch: '60_C'));
    await tester.pumpAndSettle();

    // The page opens on today, so select a day explicitly rather than assuming
    // one -- otherwise this passes only on Saturdays.
    await tester.tap(find.text('Sat'));
    await tester.pumpAndSettle();

    // Saturday holds two 60_C classes in the fixture.
    expect(find.byType(ClassCard), findsNWidgets(2));
    expect(find.text('CSE332(60_C)'), findsOneWidget);
  });

  testWidgets('switching day re-renders that day only', (tester) async {
    await tester.pumpWidget(await harness(db, batch: '60_C'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mon'));
    await tester.pumpAndSettle();

    // Monday has exactly one 60_C class.
    expect(find.byType(ClassCard), findsOneWidget);
    expect(find.text('CSE311(60_C)'), findsOneWidget);
  });

  testWidgets(
    'a day with no classes shows an empty state, not a blank screen',
    (tester) async {
      await tester.pumpWidget(await harness(db, batch: '60_C'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Wed'));
      await tester.pumpAndSettle();

      expect(find.text('No classes'), findsOneWidget);
    },
  );

  testWidgets('typing a batch and submitting updates the schedule', (
    tester,
  ) async {
    await tester.pumpWidget(await harness(db));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '62_E');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sat'));
    await tester.pumpAndSettle();

    // 62_E splits into two lab subsections that run simultaneously in
    // different rooms, so both belong on the same day. Collapsing them would
    // hide half the section's classes.
    expect(find.byType(ClassCard), findsNWidgets(2));
    expect(find.text('CSE414(62_E1)'), findsOneWidget);
    expect(find.text('CSE414(62_E2)'), findsOneWidget);
  });

  testWidgets('unknown batch reports it rather than showing an empty list', (
    tester,
  ) async {
    await tester.pumpWidget(await harness(db));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '99_Z');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('No classes for 99_Z'), findsOneWidget);
  });

  testWidgets('hiding optional courses removes electives', (tester) async {
    SharedPreferences.setMockInitialValues({'saved_batch': '61_A'});
    final prefs = await SharedPreferences.getInstance();
    final api = MockApi();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        routineApiProvider.overrideWithValue(api),
        routineRepositoryProvider.overrideWithValue(
          RoutineRepositoryImpl(database: db, api: api),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(await container.read(studentScheduleProvider.future), hasLength(1));

    await container
        .read(settingsProvider.notifier)
        .setHideOptional(value: true);
    expect(await container.read(studentScheduleProvider.future), isEmpty);
  });
}
