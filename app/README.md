# Open Routine — App

Flutter client. Android and iOS. Offline-first: every query runs against a local database.

> **Status: structure only.** No code yet. This README is the specification the implementation will follow.

## Stack

| Concern | Choice | Why |
|---|---|---|
| Framework | **Flutter 3.44+** | one codebase, real native performance |
| State | **Riverpod** | compile-safe, testable, no BuildContext gymnastics |
| Local DB | **Drift** (SQLite) | typed queries, real indexes, migrations |
| HTTP | **Dio** + generated client from the backend's OpenAPI | no hand-written DTOs to drift out of sync |
| Models | **freezed** + **json_serializable** | immutable, exhaustive |
| Routing | **go_router** | deep links |
| Notifications | **flutter_local_notifications** + **timezone** | class reminders |
| Testing | `flutter_test`, `mocktail` | |

## Layout

Clean-architecture-lite: three layers, feature-sliced UI.

```
app/lib/
├── main.dart
├── core/
│   ├── config/       environment, API base URL
│   ├── theme/        design tokens, light + dark
│   ├── utils/        lattice constants, formatters
│   └── error/        failure types
├── data/
│   ├── datasources/
│   │   ├── local/      Drift database, DAOs
│   │   └── remote/     generated API client
│   ├── models/         DTOs (freezed)
│   └── repositories/   implementations — network → local, offline-first
├── domain/
│   ├── entities/       ClassSession, Routine, Teacher
│   ├── repositories/   abstract interfaces
│   └── usecases/       GetStudentSchedule, GetFreeRooms, …
└── features/
    ├── student/        presentation/{pages,widgets} + providers
    ├── teacher/
    ├── empty_slots/
    ├── room_search/
    └── settings/
```

**Dependency rule:** `features` → `domain` ← `data`. The domain layer imports nothing from Flutter or Drift, so use cases are pure-Dart testable.

## Local schema

Mirrors the backend, indexed for the four queries:

```dart
class ClassSessions extends Table {
  IntColumn  get id          => integer().autoIncrement()();
  IntColumn  get routineId   => integer()();

  TextColumn get day         => text()();            // "Sunday"
  TextColumn get timeSlot    => text()();            // "08:30-10:00" — VERBATIM
  TextColumn get room        => text()();
  TextColumn get roomType    => text()();

  TextColumn get courseCode  => text()();            // "CSE414(62_E1)" — FUSED
  TextColumn get courseTitle => text().nullable()();
  TextColumn get teacher     => text()();
  TextColumn get batch       => text()();
  TextColumn get section     => text()();
  BoolColumn get isLab       => boolean()();
  BoolColumn get isOptional  => boolean()();

  IntColumn  get startMin    => integer()();         // display/sorting ONLY
  IntColumn  get endMin      => integer()();
}

// indexes: (routineId, batch) · (routineId, teacher) · (routineId, room, day, timeSlot)
```

⚠️ `timeSlot` is the occupancy key, compared with `=`. `startMin`/`endMin` are for "happening now" and sorting only.

## Sync strategy

```
launch
  → GET /routines/current
  → local routine version matches?
        yes → done, everything answers locally
        no  → GET /routines/{id}/snapshot
              → write into a NEW routineId in one transaction
              → flip the active pointer
              → delete the old routine's rows
```

The swap is transactional, so the app is never showing a half-updated routine. Re-checked on launch and at most once every 24 hours.

## The four queries

All local, all sub-millisecond:

```dart
// student — index (routineId, batch)
select(classSessions)..where((t) => t.routineId.equals(rid) & t.batch.equals('60_C'));

// teacher — index (routineId, teacher)
select(classSessions)..where((t) => t.routineId.equals(rid) & t.teacher.equals('SRH'));

// room search — index (routineId, room, day, timeSlot). O(1) here; O(n) in the original.
select(classSessions)..where((t) =>
    t.routineId.equals(rid) & t.room.equals(room) &
    t.day.equals(day) & t.timeSlot.equals(slot));

// free rooms — set difference in SQL
customSelect('''
  SELECT DISTINCT room FROM class_sessions WHERE routine_id = ?1
  EXCEPT
  SELECT room FROM class_sessions
   WHERE routine_id = ?1 AND day = ?2 AND time_slot = ?3
''');
```

## Platform notes

- **Android 12+** needs `SCHEDULE_EXACT_ALARM` for precise class reminders. Degrade gracefully to inexact alarms if the user denies it — don't block the app.
- **iOS caps pending notifications at 64.** A full 6 × 6 semester of reminders exceeds that. Schedule a **rolling window** (the next 7 days) and top it up on launch, rather than scheduling everything.
- **Reminders are built from local data**, so they keep working with no network.

## Accessibility

Non-negotiable, not a later pass: semantic labels on schedule cards, dynamic type support, 4.5:1 contrast minimum in both themes, and no information conveyed by colour alone (lab vs theory vs optional need shape or text too).
