import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../domain/entities/class_session.dart';

/// The batch currently being viewed, e.g. `60_C`.
///
/// Seeded from the remembered batch so the app opens on the user's own week.
class StudentQuery extends Notifier<String> {
  @override
  String build() =>
      ref.watch(settingsProvider.select((s) => s.savedBatch)) ?? '';

  void set(String batch) => state = batch.trim().toUpperCase();
}

final studentQueryProvider = NotifierProvider<StudentQuery, String>(
  StudentQuery.new,
);

/// The `60_C` lookup: an index seek against the local database.
///
/// No network, so this resolves in about a millisecond.
final studentScheduleProvider = FutureProvider<List<ClassSession>>((ref) async {
  final batch = ref.watch(studentQueryProvider).trim();
  if (batch.isEmpty) return const [];
  final hideOptional = ref.watch(
    settingsProvider.select((s) => s.hideOptionalCourses),
  );
  return ref
      .watch(routineRepositoryProvider)
      .studentSchedule(batch, includeOptional: !hideOptional);
});

/// Day list or week grid. Persisted, because it is a preference rather than a
/// transient mode -- people tend to favour one and stay there.
class ScheduleViewMode extends Notifier<bool> {
  @override
  bool build() => ref.watch(settingsProvider.select((s) => s.weekView));

  Future<void> set({required bool weekView}) async {
    state = weekView;
    await ref.read(settingsProvider.notifier).setWeekView(value: weekView);
  }
}

final weekViewProvider = NotifierProvider<ScheduleViewMode, bool>(ScheduleViewMode.new);

final batchSuggestionsProvider = FutureProvider.family<List<String>, String>((
  ref,
  query,
) {
  if (query.trim().isEmpty) return Future.value(const []);
  return ref.watch(routineRepositoryProvider).batchSuggestions(query);
});
