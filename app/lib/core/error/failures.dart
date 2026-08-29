/// Errors the UI is expected to render, rather than crash on.
sealed class Failure implements Exception {
  const Failure(this.message);
  final String message;

  @override
  String toString() => message;
}

/// The device could not reach the backend.
class NetworkFailure extends Failure {
  const NetworkFailure([
    super.message = 'No connection. Showing saved routine.',
  ]);
}

/// The backend answered, but with an error.
class ServerFailure extends Failure {
  const ServerFailure(super.message, {this.statusCode});
  final int? statusCode;
}

/// Nothing has been downloaded yet, so there is nothing to show offline.
class NoLocalRoutineFailure extends Failure {
  const NoLocalRoutineFailure([
    super.message = 'No routine downloaded yet. Connect once to get started.',
  ]);
}
