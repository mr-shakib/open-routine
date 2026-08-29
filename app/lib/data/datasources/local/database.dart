import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../../core/utils/lattice.dart';
import '../../../domain/entities/class_session.dart';
import '../../../domain/entities/routine_info.dart';
import '../../../domain/entities/teacher.dart' as domain;

part 'database.g.dart';

/// Every class of the active routine, stored once and indexed for the four
/// queries the app makes.
///
/// The app we studied stored every record *twice* -- once under a batch key and
/// once under a teacher key -- because IndexedDB cannot index arbitrary fields.
/// SQLite can, so one copy plus indexes does the same job in half the space,
/// and turns room search from a linear scan into an index seek.
@DataClassName('ClassSessionRow')
@TableIndex(name: 'idx_session_batch', columns: {#routineId, #batch})
@TableIndex(name: 'idx_session_teacher', columns: {#routineId, #teacher})
@TableIndex(
  name: 'idx_session_room_day_slot',
  columns: {#routineId, #room, #day, #timeSlot},
)
@TableIndex(
  name: 'idx_session_day_slot',
  columns: {#routineId, #day, #timeSlot},
)
class ClassSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get routineId => integer()();

  /// Weekday name. Grid row axis.
  TextColumn get day => text().withLength(max: 16)();

  /// Slot label, verbatim. The occupancy key, compared with `=`.
  TextColumn get timeSlot => text().withLength(max: 32)();

  TextColumn get room => text().withLength(max: 64)();
  TextColumn get roomType =>
      text().withLength(max: 32).withDefault(const Constant('Theory'))();

  /// Fused source token: `CSE414(62_E1)`.
  TextColumn get courseCode => text().withLength(max: 64)();
  TextColumn get courseTitle => text().nullable()();
  TextColumn get teacher => text().withLength(max: 16)();
  TextColumn get batch => text().withLength(max: 32)();
  TextColumn get section => text().withLength(max: 32)();
  BoolColumn get isLab => boolean().withDefault(const Constant(false))();
  BoolColumn get isOptional => boolean().withDefault(const Constant(false))();

  /// Display and sorting only -- never the occupancy test.
  IntColumn get startMin => integer()();
  IntColumn get endMin => integer()();
}

/// The routine revision currently stored on this device.
@DataClassName('RoutineRow')
class Routines extends Table {
  IntColumn get id => integer()();
  TextColumn get department => text().withLength(max: 16)();
  TextColumn get version => text().withLength(max: 32)();
  TextColumn get semester => text().nullable()();
  IntColumn get sessionCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get publishedAt => dateTime().nullable()();
  DateTimeColumn get syncedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Faculty directory, joined to the routine on the initial.
@DataClassName('TeacherRow')
class Teachers extends Table {
  TextColumn get initial => text().withLength(max: 16)();
  TextColumn get name => text()();
  TextColumn get designation => text().nullable()();
  TextColumn get department => text().nullable()();
  TextColumn get officeRoom => text().nullable()();
  TextColumn get imageUrl => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {initial};
}

@DriftDatabase(tables: [ClassSessions, Routines, Teachers])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'open_routine'));

  @override
  int get schemaVersion => 1;

  // ---------------------------------------------------------------- sync ----

  /// Replace the stored routine with [snapshot], atomically.
  ///
  /// Everything happens in one transaction, so the app is never left showing a
  /// half-updated routine: readers see either the old routine or the new one.
  Future<void> replaceRoutine({
    required RoutineInfo routine,
    required List<ClassSession> sessions,
  }) async {
    await transaction(() async {
      await delete(classSessions).go();
      await delete(routines).go();

      await into(routines).insert(
        RoutinesCompanion.insert(
          id: Value(routine.id),
          department: routine.department,
          version: routine.version,
          semester: Value(routine.semester),
          sessionCount: Value(routine.sessionCount),
          publishedAt: Value(routine.publishedAt),
          syncedAt: DateTime.now(),
        ),
      );

      await batch((b) {
        b.insertAll(classSessions, [
          for (final s in sessions)
            ClassSessionsCompanion.insert(
              routineId: routine.id,
              day: s.day,
              timeSlot: s.timeSlot,
              room: s.room,
              roomType: Value(s.roomType),
              courseCode: s.courseCode,
              courseTitle: Value(s.courseTitle),
              teacher: s.teacher,
              batch: s.batch,
              section: s.section,
              isLab: Value(s.isLab),
              isOptional: Value(s.isOptional),
              startMin: s.startMin,
              endMin: s.endMin,
            ),
        ]);
      });
    });
  }

  Future<void> replaceTeachers(List<domain.Teacher> people) async {
    await transaction(() async {
      await delete(teachers).go();
      await batch((b) {
        b.insertAll(teachers, [
          for (final t in people)
            TeachersCompanion.insert(
              initial: t.initial,
              name: t.name,
              designation: Value(t.designation),
              department: Value(t.department),
              officeRoom: Value(t.officeRoom),
              imageUrl: Value(t.imageUrl),
            ),
        ]);
      });
    });
  }

  /// The routine revision held locally, or `null` if nothing is stored.
  Future<RoutineInfo?> storedRoutine() async {
    final row = await (select(routines)..limit(1)).getSingleOrNull();
    if (row == null) return null;
    return RoutineInfo(
      id: row.id,
      department: row.department,
      version: row.version,
      semester: row.semester,
      publishedAt: row.publishedAt,
      sessionCount: row.sessionCount,
    );
  }

  Future<DateTime?> lastSyncedAt() async =>
      (await (select(routines)..limit(1)).getSingleOrNull())?.syncedAt;

  // --------------------------------------------------------------- query ----

  /// Every class for one batch. Index: `(routineId, batch)`.
  ///
  /// The `60_C` case: an index seek, then sorted into academic-week order.
  Future<List<ClassSession>> studentSchedule(
    String batch, {
    bool includeOptional = true,
  }) {
    final query = select(classSessions)
      ..where((t) => t.batch.upper().equals(batch.trim().toUpperCase()));
    if (!includeOptional) query.where((t) => t.isOptional.equals(false));
    return _mapped(query);
  }

  /// Every class taught by one initial. Index: `(routineId, teacher)`.
  Future<List<ClassSession>> teacherSchedule(
    String initial, {
    bool includeOptional = true,
  }) {
    final query = select(classSessions)
      ..where((t) => t.teacher.upper().equals(initial.trim().toUpperCase()));
    if (!includeOptional) query.where((t) => t.isOptional.equals(false));
    return _mapped(query);
  }

  /// What occupies [room] in one lattice cell. Index: `(routineId, room, day, timeSlot)`.
  ///
  /// More than one result means the published routine double-books the room;
  /// they are surfaced rather than hidden.
  Future<List<ClassSession>> classesInRoom({
    required String room,
    required String day,
    required String slot,
  }) => _mapped(
    select(classSessions)..where(
      (t) =>
          t.room.upper().equals(room.trim().toUpperCase()) &
          t.day.equals(day) &
          t.timeSlot.equals(slot.trim()),
    ),
  );

  /// Every room appearing anywhere in the routine.
  ///
  /// The universe is derived from the routine itself: a room that hosts no
  /// class cannot be reported free, because nothing tells us it exists.
  Future<List<String>> allRooms() async {
    final rows =
        await (selectOnly(classSessions, distinct: true)
              ..addColumns([classSessions.room])
              ..orderBy([OrderingTerm.asc(classSessions.room)]))
            .get();
    return rows.map((r) => r.read(classSessions.room)!).toList();
  }

  /// Free rooms per working day at [slot], in one pass.
  ///
  /// `free = all rooms - occupied rooms`, where occupancy is equality on the
  /// slot label. No interval arithmetic: the lattice makes overlaps impossible.
  Future<Map<String, List<String>>> freeRoomsBySlot(String slot) async {
    final universe = (await allRooms()).toSet();

    final rows =
        await (selectOnly(classSessions, distinct: true)
              ..addColumns([classSessions.day, classSessions.room])
              ..where(classSessions.timeSlot.equals(slot.trim())))
            .get();

    final occupied = <String, Set<String>>{
      for (final d in kDays) d: <String>{},
    };
    for (final row in rows) {
      final day = row.read(classSessions.day)!;
      (occupied[day] ??= <String>{}).add(row.read(classSessions.room)!);
    }

    return {
      for (final day in kDays)
        day: (universe.difference(occupied[day] ?? const <String>{}).toList()
          ..sort()),
    };
  }

  /// Batches present in the routine, for typeahead.
  Future<List<String>> batchSuggestions(String query) async {
    final rows =
        await (selectOnly(classSessions, distinct: true)
              ..addColumns([classSessions.batch])
              ..where(
                classSessions.batch.upper().like(
                  '%${query.trim().toUpperCase()}%',
                ),
              )
              ..orderBy([OrderingTerm.asc(classSessions.batch)])
              ..limit(10))
            .get();
    return rows.map((r) => r.read(classSessions.batch)!).toList();
  }

  /// Teaching initials present in the routine, excluding the `TBA` sentinel.
  Future<List<String>> teacherSuggestions(String query) async {
    final rows =
        await (selectOnly(classSessions, distinct: true)
              ..addColumns([classSessions.teacher])
              ..where(
                classSessions.teacher.upper().like(
                      '%${query.trim().toUpperCase()}%',
                    ) &
                    classSessions.teacher.equals('TBA').not(),
              )
              ..orderBy([OrderingTerm.asc(classSessions.teacher)])
              ..limit(10))
            .get();
    return rows.map((r) => r.read(classSessions.teacher)!).toList();
  }

  Future<List<String>> roomSuggestions(String query) async {
    final rows =
        await (selectOnly(classSessions, distinct: true)
              ..addColumns([classSessions.room])
              ..where(
                classSessions.room.upper().like(
                  '%${query.trim().toUpperCase()}%',
                ),
              )
              ..orderBy([OrderingTerm.asc(classSessions.room)])
              ..limit(10))
            .get();
    return rows.map((r) => r.read(classSessions.room)!).toList();
  }

  Future<domain.Teacher?> teacherByInitial(String initial) async {
    final row =
        await (select(teachers)..where(
              (t) => t.initial.upper().equals(initial.trim().toUpperCase()),
            ))
            .getSingleOrNull();
    if (row == null) return null;
    return domain.Teacher(
      initial: row.initial,
      name: row.name,
      designation: row.designation,
      department: row.department,
      officeRoom: row.officeRoom,
      imageUrl: row.imageUrl,
    );
  }

  // ----------------------------------------------------------------- util ----

  Future<List<ClassSession>> _mapped(
    SimpleSelectStatement<$ClassSessionsTable, ClassSessionRow> q,
  ) async {
    final rows = await q.get();
    final sessions = rows.map(_toEntity).toList();
    sortByDayThenTime(sessions);
    return sessions;
  }

  static ClassSession _toEntity(ClassSessionRow r) => ClassSession(
    day: r.day,
    timeSlot: r.timeSlot,
    room: r.room,
    roomType: r.roomType,
    courseCode: r.courseCode,
    courseTitle: r.courseTitle,
    teacher: r.teacher,
    batch: r.batch,
    section: r.section,
    isLab: r.isLab,
    isOptional: r.isOptional,
    startMin: r.startMin,
    endMin: r.endMin,
  );
}

/// Sort into academic-week order: day first, then start time within the day.
///
/// Day order is explicit, never lexical -- the week starts on Saturday.
void sortByDayThenTime(List<ClassSession> sessions) {
  sessions.sort((a, b) {
    final byDay = dayIndex(a.day).compareTo(dayIndex(b.day));
    return byDay != 0 ? byDay : a.startMin.compareTo(b.startMin);
  });
}

/// Bucket a schedule into the six working days, empty days included.
Map<String, List<ClassSession>> groupByDay(List<ClassSession> sessions) {
  final grouped = <String, List<ClassSession>>{
    for (final d in kDays) d: <ClassSession>[],
  };
  final sorted = [...sessions];
  sortByDayThenTime(sorted);
  for (final s in sorted) {
    (grouped[s.day] ??= <ClassSession>[]).add(s);
  }
  return grouped;
}
