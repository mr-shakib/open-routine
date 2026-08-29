import '../entities/class_session.dart';
import '../entities/routine_info.dart';
import '../entities/teacher.dart';

/// How the rest of the app reaches routine data.
///
/// Every read is answered from local storage, so all of these work offline. Only
/// [sync] touches the network.
abstract interface class RoutineRepository {
  /// The routine held on this device, or `null` if nothing is stored yet.
  Future<RoutineInfo?> localRoutine();

  /// Check the server's version and download a new snapshot if it differs.
  Future<SyncResult> sync({bool force = false});

  Future<List<ClassSession>> studentSchedule(
    String batch, {
    bool includeOptional,
  });
  Future<List<ClassSession>> teacherSchedule(
    String initial, {
    bool includeOptional,
  });
  Future<List<ClassSession>> classesInRoom({
    required String room,
    required String day,
    required String slot,
  });
  Future<Map<String, List<String>>> freeRooms(String slot);
  Future<List<String>> allRooms();

  Future<List<String>> batchSuggestions(String query);
  Future<List<String>> teacherSuggestions(String query);
  Future<List<String>> roomSuggestions(String query);
  Future<Teacher?> teacherDetails(String initial);
}

/// What a [RoutineRepository.sync] attempt did.
enum SyncOutcome {
  /// A new revision was downloaded and stored.
  updated,

  /// The stored revision already matched the server.
  upToDate,

  /// The server was unreachable; the stored routine is still usable.
  offline,

  /// The server was unreachable and nothing is stored yet.
  failed,
}

class SyncResult {
  const SyncResult(this.outcome, {this.routine, this.message});

  final SyncOutcome outcome;
  final RoutineInfo? routine;
  final String? message;

  bool get hasData => outcome != SyncOutcome.failed;
}
