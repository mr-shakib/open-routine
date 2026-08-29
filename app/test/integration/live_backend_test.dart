import 'package:flutter_test/flutter_test.dart';
import 'package:open_routine/data/datasources/remote/routine_api.dart';
import 'package:open_routine/data/repositories/routine_repository_impl.dart';
import 'package:open_routine/domain/repositories/routine_repository.dart';

import '../fixtures.dart';

/// Exercises the real HTTP contract against a running backend.
///
/// Skipped by default because it needs a server. To run it:
///
///   uvicorn open_routine.main:app --port 8077
///   flutter test test/integration/live_backend_test.dart \
///     --dart-define=LIVE_BACKEND=true \
///     --dart-define=OPEN_ROUTINE_API=http://127.0.0.1:8077
const bool liveBackend = bool.fromEnvironment('LIVE_BACKEND');

void main() {
  test(
    'syncs a real routine from the backend',
    skip: liveBackend
        ? null
        : 'needs a running backend; pass --dart-define=LIVE_BACKEND=true',
    () async {
      final db = testDatabase();
      addTearDown(db.close);

      final repo = RoutineRepositoryImpl(database: db, api: RoutineApi());
      final result = await repo.sync();

      expect(result.outcome, SyncOutcome.updated);
      expect(result.routine, isNotNull);

      // The four queries must work against server-supplied data, not just
      // hand-written fixtures.
      final students = await repo.studentSchedule(
        '66_B',
        includeOptional: true,
      );
      expect(students, isNotEmpty);
      expect(students.first.courseCode, contains('('));
      // Room names must arrive clean: the PDF writes "KT-503\n(COM LAB)" in a
      // single cell, and the annotation belongs in roomType, not the name.
      expect(students.every((s) => !s.room.contains('\n')), isTrue);
      expect(students.any((s) => s.roomType != 'Theory'), isTrue);

      final teachers = await repo.teacherSchedule('AAM', includeOptional: true);
      expect(teachers, isNotEmpty);

      final free = await repo.freeRooms('08:30-10:00');
      expect(free.keys, hasLength(6));

      final rooms = await repo.allRooms();
      expect(rooms, isNotEmpty);
    },
  );
}
