import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/utils/lattice.dart';

part 'class_session.freezed.dart';
part 'class_session.g.dart';

/// A single class: one cell of the routine grid.
///
/// This is both the domain entity and the API wire model -- the backend's
/// `ClassSessionOut` has exactly this shape, so a separate DTO would be two
/// identical classes and a mapper that can drift out of sync.
@freezed
abstract class ClassSession with _$ClassSession {
  const factory ClassSession({
    /// Weekday name, e.g. `Sunday`. From the grid's row axis.
    required String day,

    /// Slot label exactly as published, e.g. `08:30-10:00`.
    ///
    /// This is a lattice coordinate, not a time. It is the occupancy key and is
    /// compared with `==`. Never parse it into times to decide occupancy.
    @JsonKey(name: 'time_slot') required String timeSlot,

    required String room,
    @JsonKey(name: 'room_type') required String roomType,

    /// The source token, kept fused: `CSE414(62_E1)`.
    @JsonKey(name: 'course_code') required String courseCode,
    @JsonKey(name: 'course_title') String? courseTitle,

    /// Teacher initial, or `TBA` when unassigned.
    required String teacher,

    /// Derived from [courseCode]: `62_E`.
    required String batch,

    /// Full section including any lab subsection: `62_E1`.
    required String section,

    /// The section carries a subsection suffix, i.e. a split lab group.
    @JsonKey(name: 'is_lab') required bool isLab,

    /// Elective course (code prefixed `TCSE`).
    @JsonKey(name: 'is_optional') required bool isOptional,

    /// Minutes past midnight. Display and sorting only.
    @JsonKey(name: 'start_min') required int startMin,
    @JsonKey(name: 'end_min') required int endMin,
  }) = _ClassSession;

  const ClassSession._();

  factory ClassSession.fromJson(Map<String, dynamic> json) =>
      _$ClassSessionFromJson(json);

  /// Course code without the section, e.g. `CSE414` from `CSE414(62_E1)`.
  String get baseCourseCode {
    final index = courseCode.indexOf('(');
    return index == -1 ? courseCode : courseCode.substring(0, index);
  }

  /// Lab subsection digit, e.g. `1` from `62_E1`; `null` for theory classes.
  String? get subsection {
    final match = RegExp(r'^\d+_[A-Z](\d+)$').firstMatch(section);
    return match?.group(1);
  }

  bool get hasTeacher => teacher.isNotEmpty && teacher != 'TBA';

  /// Whether this class is running at [now], for the "happening now" badge.
  ///
  /// Uses the derived minute values, which is exactly what they are for. This
  /// is presentation, not occupancy.
  bool isLiveAt(DateTime now) =>
      weekdayName(now) == day &&
      now.hour * 60 + now.minute >= startMin &&
      now.hour * 60 + now.minute < endMin;
}
