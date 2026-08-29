import 'package:freezed_annotation/freezed_annotation.dart';

part 'teacher.freezed.dart';
part 'teacher.g.dart';

/// A faculty directory entry, joined to the routine on [initial].
///
/// The routine identifies teachers by initial alone, so a collision in the
/// published directory is ambiguous at the source. The backend warns about it;
/// the app simply shows whichever record it was given.
@freezed
abstract class Teacher with _$Teacher {
  const factory Teacher({
    required String initial,
    required String name,
    String? designation,
    String? department,
    @JsonKey(name: 'office_room') String? officeRoom,
    @JsonKey(name: 'image_url') String? imageUrl,
  }) = _Teacher;

  factory Teacher.fromJson(Map<String, dynamic> json) =>
      _$TeacherFromJson(json);
}
