import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/datasources/local/database.dart';
import '../../data/datasources/remote/routine_api.dart';
import '../../data/repositories/routine_repository_impl.dart';
import '../../domain/entities/routine_info.dart';
import '../../domain/repositories/routine_repository.dart';
import '../notifications/notification_service.dart';

/// Overridden in [main] and in tests with a real instance.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) =>
      throw UnimplementedError('sharedPreferencesProvider must be overridden'),
);

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final routineApiProvider = Provider<RoutineApi>((ref) => RoutineApi());

final routineRepositoryProvider = Provider<RoutineRepository>(
  (ref) => RoutineRepositoryImpl(
    database: ref.watch(databaseProvider),
    api: ref.watch(routineApiProvider),
  ),
);

/// The routine revision stored on this device.
///
/// Waits for the in-flight sync before reading. Without that it resolves once
/// at startup, before the first download has finished, and then reports "nothing
/// downloaded yet" for the rest of the session even though the schedule is
/// visibly working.
final localRoutineProvider = FutureProvider<RoutineInfo?>((ref) async {
  await ref.watch(syncControllerProvider.future);
  return ref.watch(routineRepositoryProvider).localRoutine();
});

/// Drives the "checking / updated / offline" banner and the first-run download.
class SyncController extends AsyncNotifier<SyncResult> {
  @override
  Future<SyncResult> build() => ref.read(routineRepositoryProvider).sync();

  /// Re-check the server, optionally forcing a download.
  Future<void> refresh({bool force = false}) async {
    state = const AsyncValue<SyncResult>.loading();
    state = await AsyncValue.guard(
      () => ref.read(routineRepositoryProvider).sync(force: force),
    );
    ref
      ..invalidate(localRoutineProvider)
      ..invalidate(allRoomsProvider);
  }
}

final syncControllerProvider =
    AsyncNotifierProvider<SyncController, SyncResult>(SyncController.new);

final allRoomsProvider = FutureProvider<List<String>>(
  (ref) => ref.watch(routineRepositoryProvider).allRooms(),
);

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);
