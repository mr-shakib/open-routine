import 'dart:developer' as developer;

import '../../core/config/app_config.dart';
import '../../core/error/failures.dart';
import '../../domain/entities/class_session.dart';
import '../../domain/entities/routine_info.dart';
import '../../domain/entities/teacher.dart';
import '../../domain/repositories/routine_repository.dart';
import '../datasources/local/database.dart';
import '../datasources/remote/routine_api.dart';

/// Offline-first implementation.
///
/// Reads never touch the network. [sync] compares the server's routine version
/// against what is stored and downloads a fresh snapshot only when they differ,
/// which is the whole point of the backend publishing a version at all.
class RoutineRepositoryImpl implements RoutineRepository {
  RoutineRepositoryImpl({
    required AppDatabase database,
    required RoutineApi api,
  }) : _db = database,
       _remote = api;

  final AppDatabase _db;
  final RoutineApi _remote;

  @override
  Future<RoutineInfo?> localRoutine() => _db.storedRoutine();

  @override
  Future<SyncResult> sync({bool force = false}) async {
    final stored = await _db.storedRoutine();

    try {
      final remote = await _remote.currentRoutine();

      // The version is the university's revision number, not the app's. If it
      // has not moved, the stored routine is authoritative and there is nothing
      // to download.
      if (!force && stored != null && stored.version == remote.version) {
        return SyncResult(SyncOutcome.upToDate, routine: stored);
      }

      final snapshot = await _remote.snapshot(remote.id);
      await _db.replaceRoutine(
        routine: snapshot.routine,
        sessions: snapshot.sessions,
      );

      // The directory is a nicety; a failure here must not fail the sync.
      try {
        await _db.replaceTeachers(await _remote.teachers());
      } on Object catch (e) {
        developer.log('Teacher directory sync skipped: $e', name: 'sync');
      }

      return SyncResult(
        SyncOutcome.updated,
        routine: snapshot.routine,
        message: 'Routine updated to version ${snapshot.routine.version}.',
      );
    } on Failure catch (failure) {
      // Offline with a stored routine is a normal state, not an error.
      if (stored != null) {
        return SyncResult(
          SyncOutcome.offline,
          routine: stored,
          message: failure.message,
        );
      }
      return SyncResult(SyncOutcome.failed, message: failure.message);
    }
  }

  /// Whether enough time has passed to be worth re-checking the version.
  Future<bool> isStale() async {
    final syncedAt = await _db.lastSyncedAt();
    if (syncedAt == null) return true;
    return DateTime.now().difference(syncedAt) > AppConfig.syncInterval;
  }

  @override
  Future<List<ClassSession>> studentSchedule(
    String batch, {
    bool includeOptional = true,
  }) => _db.studentSchedule(batch, includeOptional: includeOptional);

  @override
  Future<List<ClassSession>> teacherSchedule(
    String initial, {
    bool includeOptional = true,
  }) => _db.teacherSchedule(initial, includeOptional: includeOptional);

  @override
  Future<List<ClassSession>> classesInRoom({
    required String room,
    required String day,
    required String slot,
  }) => _db.classesInRoom(room: room, day: day, slot: slot);

  @override
  Future<Map<String, List<String>>> freeRooms(String slot) =>
      _db.freeRoomsBySlot(slot);

  @override
  Future<List<String>> allRooms() => _db.allRooms();

  @override
  Future<List<String>> batchSuggestions(String query) =>
      _db.batchSuggestions(query);

  @override
  Future<List<String>> teacherSuggestions(String query) =>
      _db.teacherSuggestions(query);

  @override
  Future<List<String>> roomSuggestions(String query) =>
      _db.roomSuggestions(query);

  @override
  Future<Teacher?> teacherDetails(String initial) =>
      _db.teacherByInitial(initial);
}
