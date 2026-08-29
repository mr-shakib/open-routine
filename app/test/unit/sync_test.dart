import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:open_routine/core/error/failures.dart';
import 'package:open_routine/data/datasources/local/database.dart';
import 'package:open_routine/data/datasources/remote/routine_api.dart';
import 'package:open_routine/data/repositories/routine_repository_impl.dart';
import 'package:open_routine/domain/entities/routine_info.dart';
import 'package:open_routine/domain/entities/snapshot.dart';
import 'package:open_routine/domain/repositories/routine_repository.dart';

import '../fixtures.dart';

class MockApi extends Mock implements RoutineApi {}

void main() {
  late AppDatabase db;
  late MockApi api;
  late RoutineRepositoryImpl repo;

  RoutineSnapshot snapshotOf(RoutineInfo routine) => RoutineSnapshot(
    routine: routine,
    slots: const [],
    days: const [],
    rooms: const [],
    sessions: testSessions,
  );

  setUp(() {
    db = testDatabase();
    api = MockApi();
    repo = RoutineRepositoryImpl(database: db, api: api);
    when(() => api.teachers()).thenAnswer((_) async => []);
  });

  tearDown(() => db.close());

  test('first run downloads the snapshot', () async {
    when(() => api.currentRoutine()).thenAnswer((_) async => testRoutine);
    when(
      () => api.snapshot(1),
    ).thenAnswer((_) async => snapshotOf(testRoutine));

    final result = await repo.sync();

    expect(result.outcome, SyncOutcome.updated);
    expect(await db.studentSchedule('60_C'), hasLength(7));
  });

  test('an unchanged version skips the download entirely', () async {
    when(() => api.currentRoutine()).thenAnswer((_) async => testRoutine);
    when(
      () => api.snapshot(any()),
    ).thenAnswer((_) async => snapshotOf(testRoutine));
    await repo.sync();

    final second = await repo.sync();

    expect(second.outcome, SyncOutcome.upToDate);
    // The version is the university's revision number: if it has not moved,
    // there is nothing to fetch.
    verify(() => api.snapshot(any())).called(1);
  });

  test('a new version replaces the stored routine', () async {
    when(() => api.currentRoutine()).thenAnswer((_) async => testRoutine);
    when(
      () => api.snapshot(1),
    ).thenAnswer((_) async => snapshotOf(testRoutine));
    await repo.sync();

    const next = RoutineInfo(
      id: 2,
      department: 'cse',
      version: '5.2',
      sessionCount: 1,
    );
    when(() => api.currentRoutine()).thenAnswer((_) async => next);
    when(() => api.snapshot(2)).thenAnswer(
      (_) async => RoutineSnapshot(
        routine: next,
        slots: const [],
        days: const [],
        rooms: const [],
        sessions: [testSessions.first],
      ),
    );

    final result = await repo.sync();

    expect(result.outcome, SyncOutcome.updated);
    expect((await db.storedRoutine())?.version, '5.2');
    // Old rows are gone, not merged.
    expect(await db.studentSchedule('60_C'), isEmpty);
  });

  test(
    'offline with a stored routine is a normal state, not an error',
    () async {
      when(() => api.currentRoutine()).thenAnswer((_) async => testRoutine);
      when(
        () => api.snapshot(1),
      ).thenAnswer((_) async => snapshotOf(testRoutine));
      await repo.sync();

      when(() => api.currentRoutine()).thenThrow(const NetworkFailure());

      final result = await repo.sync();

      expect(result.outcome, SyncOutcome.offline);
      expect(result.hasData, isTrue);
      // The saved routine still answers queries.
      expect(await db.studentSchedule('60_C'), hasLength(7));
    },
  );

  test('offline on a first run reports failure', () async {
    when(() => api.currentRoutine()).thenThrow(const NetworkFailure());

    final result = await repo.sync();

    expect(result.outcome, SyncOutcome.failed);
    expect(result.hasData, isFalse);
  });

  test('a failing teacher directory does not fail the sync', () async {
    when(() => api.currentRoutine()).thenAnswer((_) async => testRoutine);
    when(
      () => api.snapshot(1),
    ).thenAnswer((_) async => snapshotOf(testRoutine));
    when(() => api.teachers()).thenThrow(const ServerFailure('directory down'));

    final result = await repo.sync();

    expect(result.outcome, SyncOutcome.updated);
    expect(await db.studentSchedule('60_C'), hasLength(7));
  });

  test('force re-downloads even when the version matches', () async {
    when(() => api.currentRoutine()).thenAnswer((_) async => testRoutine);
    when(
      () => api.snapshot(any()),
    ).thenAnswer((_) async => snapshotOf(testRoutine));
    await repo.sync();

    await repo.sync(force: true);

    verify(() => api.snapshot(any())).called(2);
  });
}
