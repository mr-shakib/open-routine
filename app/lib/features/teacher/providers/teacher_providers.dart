import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../domain/entities/class_session.dart';
import '../../../domain/entities/teacher.dart';

/// The teacher initial currently being viewed, e.g. `SRH`.
class TeacherQuery extends Notifier<String> {
  @override
  String build() =>
      ref.watch(settingsProvider.select((s) => s.savedTeacher)) ?? '';

  void set(String initial) => state = initial.trim().toUpperCase();
}

final teacherQueryProvider = NotifierProvider<TeacherQuery, String>(
  TeacherQuery.new,
);

/// The initial is normalised at ingestion, so this needs no name resolution.
final teacherScheduleProvider = FutureProvider<List<ClassSession>>((ref) async {
  final initial = ref.watch(teacherQueryProvider).trim();
  if (initial.isEmpty) return const [];
  final hideOptional = ref.watch(
    settingsProvider.select((s) => s.hideOptionalCourses),
  );
  return ref
      .watch(routineRepositoryProvider)
      .teacherSchedule(initial, includeOptional: !hideOptional);
});

/// Directory details, for display only.
final teacherDetailsProvider = FutureProvider<Teacher?>((ref) {
  final initial = ref.watch(teacherQueryProvider).trim();
  if (initial.isEmpty) return Future.value();
  return ref.watch(routineRepositoryProvider).teacherDetails(initial);
});

final teacherSuggestionsProvider = FutureProvider.family<List<String>, String>((
  ref,
  query,
) {
  if (query.trim().isEmpty) return Future.value(const []);
  return ref.watch(routineRepositoryProvider).teacherSuggestions(query);
});
