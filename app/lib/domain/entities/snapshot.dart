import 'package:freezed_annotation/freezed_annotation.dart';

import 'class_session.dart';
import 'routine_info.dart';

part 'snapshot.freezed.dart';
part 'snapshot.g.dart';

/// An entire routine in one payload.
///
/// This is what makes the app offline-first: it is downloaded once, written to
/// the local database in a single transaction, and then answers every query
/// with no network until the routine version changes.
@freezed
abstract class RoutineSnapshot with _$RoutineSnapshot {
  const factory RoutineSnapshot({
    required RoutineInfo routine,
    required List<String> slots,
    required List<String> days,
    required List<String> rooms,
    required List<ClassSession> sessions,
  }) = _RoutineSnapshot;

  factory RoutineSnapshot.fromJson(Map<String, dynamic> json) =>
      _$RoutineSnapshotFromJson(json);
}
