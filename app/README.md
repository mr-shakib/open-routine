# Open Routine — App

Flutter client. Android and iOS. Offline-first: every query runs against a local database.

> **Status: working on device.** Four views, offline-first sync, 56 tests. Verified on a physical Android device against the real published routine — including offline operation with the backend stopped.

## Stack

| Concern | Choice | Why |
|---|---|---|
| Framework | **Flutter 3.44+** | one codebase, real native performance |
| State | **Riverpod** | compile-safe, testable, no BuildContext gymnastics |
| Local DB | **Drift** (SQLite) | typed queries, real indexes, migrations |
| HTTP | **Dio** | thin hand-written client -- only two calls matter, so a code generator would add tooling for no gain |
| Models | **freezed** + **json_serializable** | immutable, exhaustive |
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

## Running it

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs

# point at a backend (defaults to http://localhost:8000)
flutter run --dart-define=OPEN_ROUTINE_API=http://127.0.0.1:8000
```

**Reaching the backend from a device.** An explicit `--dart-define=OPEN_ROUTINE_API`
is honoured verbatim; only the compile-time default gets the emulator rewrite
(`localhost` → `10.0.2.2`), because only you know how your device reaches the host.

*Physical device over USB* — bridge the port, no Wi-Fi needed:

```bash
adb reverse tcp:8000 tcp:8000
flutter run --dart-define=OPEN_ROUTINE_API=http://127.0.0.1:8000
```

*Physical device on the same Wi-Fi* — pass the host's LAN address instead.

Debug builds permit cleartext HTTP (`android/app/src/debug/AndroidManifest.xml`)
so a local backend works; release builds keep Android's strict default.

```bash
flutter test        # 56 tests
flutter analyze     # clean
```

The live-backend test is skipped unless asked for:

```bash
flutter test test/integration/live_backend_test.dart \
  --dart-define=LIVE_BACKEND=true \
  --dart-define=OPEN_ROUTINE_API=http://127.0.0.1:8077
```

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

## Class reminders

Split deliberately in two:

- **`ReminderPlanner`** decides *which* reminders to schedule and when. It is pure — no platform calls, no clock of its own — so the interesting logic is unit-tested: the rolling window, the lead time, weekday mapping, stable ids.
- **`NotificationService`** hands that plan to the OS. Thin, and untestable off a real device.

Two constraints shaped the design:

- **iOS caps pending notifications at 64.** A whole semester of a 6 × 6 routine blows past it, so the planner emits a **rolling 7-day window** capped at 60, topped up on launch.
- **Android 12+ gates exact alarms** behind a runtime permission. The service uses `inexactAllowWhileIdle` rather than requesting it: a reminder a few minutes early beats no reminder, and it never throws.

Reminders are planned from the local database, so they keep working offline.

> ⚠️ The planning logic is tested; **actual delivery on a device is not yet verified.**

## Platform notes

- `minSdk` is raised to 23 and core-library desugaring enabled, both required by `flutter_local_notifications`.
- The application id is `dev.openroutine.open_routine` — a placeholder. **Change it before publishing; it is permanent.**

## Accessibility

Non-negotiable, not a later pass: semantic labels on schedule cards, dynamic type support, 4.5:1 contrast minimum in both themes, and no information conveyed by colour alone (lab vs theory vs optional need shape or text too).
