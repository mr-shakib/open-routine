import 'package:flutter_test/flutter_test.dart';
import 'package:open_routine/core/utils/lattice.dart';
import 'package:open_routine/data/datasources/local/database.dart';

import '../fixtures.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = testDatabase();
    await db.replaceRoutine(routine: testRoutine, sessions: testSessions);
  });

  tearDown(() => db.close());

  group('sync', () {
    test('stores the routine revision', () async {
      final stored = await db.storedRoutine();
      expect(stored?.version, '5.1');
      expect(stored?.department, 'cse');
    });

    test('replacing a routine does not accumulate rows', () async {
      await db.replaceRoutine(routine: testRoutine, sessions: testSessions);
      await db.replaceRoutine(routine: testRoutine, sessions: testSessions);
      // 60_C has seven classes in the fixture; a leak would multiply them.
      expect(await db.studentSchedule('60_C'), hasLength(7));
    });
  });

  group('student search', () {
    test('returns only that batch', () async {
      final rows = await db.studentSchedule('60_C');
      expect(rows, hasLength(7));
      expect(rows.map((r) => r.batch).toSet(), {'60_C'});
    });

    test('is case insensitive', () async {
      expect(
        (await db.studentSchedule('60_c')).length,
        (await db.studentSchedule('60_C')).length,
      );
    });

    test('can exclude optional courses', () async {
      expect(await db.studentSchedule('61_A'), hasLength(1));
      expect(await db.studentSchedule('61_A', includeOptional: false), isEmpty);
    });

    test('is sorted by academic week then time', () async {
      final rows = await db.studentSchedule('60_C');
      final keys = rows.map((r) => (dayIndex(r.day), r.startMin)).toList();
      final sorted = [...keys]
        ..sort((a, b) {
          final byDay = a.$1.compareTo(b.$1);
          return byDay != 0 ? byDay : a.$2.compareTo(b.$2);
        });
      expect(keys, sorted);
    });

    test('unknown batch returns nothing rather than throwing', () async {
      expect(await db.studentSchedule('99_Z'), isEmpty);
    });
  });

  group('teacher search', () {
    test('uses the normalised initial', () async {
      final rows = await db.teacherSchedule('SRH');
      expect(rows, hasLength(4));
      expect(rows.map((r) => r.teacher).toSet(), {'SRH'});
    });

    test('finds both lab subsections of the same section', () async {
      final rows = await db.teacherSchedule('SRH');
      expect(rows.map((r) => r.section).toSet(), {'62_E1', '62_E2'});
    });
  });

  group('room occupancy', () {
    test('room universe comes from the routine itself', () async {
      expect(await db.allRooms(), ['G1-007', 'KT-503', 'KT-515', 'KT-801(A)']);
    });

    test('free rooms is universe minus occupied', () async {
      final byDay = await db.freeRoomsBySlot('08:30-10:00');
      // Saturday 08:30 has KT-503 and KT-515 in use.
      expect(byDay['Saturday'], ['G1-007', 'KT-801(A)']);
    });

    test('covers every working day, including empty ones', () async {
      final byDay = await db.freeRoomsBySlot('08:30-10:00');
      expect(byDay.keys, kDays);
      // Nothing is scheduled Thursday at this slot, so all four are free.
      expect(byDay['Thursday'], hasLength(4));
    });

    test('room search finds the occupying class', () async {
      final rows = await db.classesInRoom(
        room: 'KT-503',
        day: 'Saturday',
        slot: '08:30-10:00',
      );
      expect(rows, hasLength(1));
      expect(rows.single.courseCode, 'CSE414(62_E1)');
      expect(rows.single.batch, '62_E');
    });

    test('room search is case insensitive', () async {
      final rows = await db.classesInRoom(
        room: 'kt-503',
        day: 'Saturday',
        slot: '08:30-10:00',
      );
      expect(rows, hasLength(1));
    });

    test('empty result means the room is free', () async {
      expect(
        await db.classesInRoom(
          room: 'KT-515',
          day: 'Thursday',
          slot: '08:30-10:00',
        ),
        isEmpty,
      );
    });

    test('occupancy is exact slot equality, never interval overlap', () async {
      // KT-515 is busy Saturday 08:30-10:00 and free at 10:00-11:30. If anyone
      // ever swaps the label comparison for interval arithmetic, this fails.
      final first = await db.classesInRoom(
        room: 'KT-515',
        day: 'Saturday',
        slot: '08:30-10:00',
      );
      final second = await db.classesInRoom(
        room: 'KT-515',
        day: 'Saturday',
        slot: '10:00-11:30',
      );
      expect(first, hasLength(1));
      expect(second, isEmpty);
    });
  });

  group('suggestions', () {
    test('only suggest values present in the routine', () async {
      expect(await db.batchSuggestions('60'), contains('60_C'));
      expect(await db.batchSuggestions('zzz'), isEmpty);
    });

    test('teacher suggestions exclude the TBA sentinel', () async {
      expect(await db.teacherSuggestions('T'), isNot(contains('TBA')));
    });

    test('room suggestions match partially', () async {
      expect(await db.roomSuggestions('KT'), hasLength(3));
    });
  });

  group('grouping', () {
    test('groupByDay includes empty days', () async {
      final grouped = groupByDay(await db.studentSchedule('62_E'));
      expect(grouped.keys, kDays);
      expect(grouped['Tuesday'], isEmpty);
    });
  });
}
