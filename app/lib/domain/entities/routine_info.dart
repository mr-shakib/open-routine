import 'package:freezed_annotation/freezed_annotation.dart';

part 'routine_info.freezed.dart';
part 'routine_info.g.dart';

/// One published revision of a department's routine.
///
/// DIU republishes mid-semester and numbers each revision. The client compares
/// [version] against what it has stored to decide whether to re-download.
@freezed
abstract class RoutineInfo with _$RoutineInfo {
  const factory RoutineInfo({
    required int id,
    required String department,
    required String version,
    String? semester,
    @JsonKey(name: 'is_active') @Default(true) bool isActive,
    @JsonKey(name: 'published_at') DateTime? publishedAt,
    @JsonKey(name: 'session_count') @Default(0) int sessionCount,
  }) = _RoutineInfo;

  factory RoutineInfo.fromJson(Map<String, dynamic> json) =>
      _$RoutineInfoFromJson(json);
}
