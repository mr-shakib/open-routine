/// Build-time configuration.
///
/// Override at build time:
/// `flutter run --dart-define=OPEN_ROUTINE_API=https://api.example.com`
class AppConfig {
  const AppConfig._();

  /// Base URL of the Open Routine backend.
  ///
  /// The default targets a desktop/web dev server. Android emulators reach the
  /// host at 10.0.2.2, so that case is handled in [resolvedBaseUrl].
  static const String baseUrl = String.fromEnvironment(
    'OPEN_ROUTINE_API',
    defaultValue: 'http://localhost:8000',
  );

  static const String apiPrefix = '/api/v1';

  /// Department whose routine this build shows.
  static const String department = String.fromEnvironment(
    'OPEN_ROUTINE_DEPARTMENT',
    defaultValue: 'cse',
  );

  /// How long before a stale local routine triggers a version re-check.
  static const Duration syncInterval = Duration(hours: 12);

  /// Minutes before a class starts to fire its reminder.
  static const int reminderLeadMinutes = 20;
}
