import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/config/app_config.dart';
import '../../../core/error/failures.dart';
import '../../../domain/entities/routine_info.dart';
import '../../../domain/entities/snapshot.dart';
import '../../../domain/entities/teacher.dart';

/// Thin client over the Open Routine backend.
///
/// Only two calls matter: [currentRoutine] to learn the live version, and
/// [snapshot] to download it whole. Everything else the app needs is answered
/// from the local database, so this class stays deliberately small.
class RoutineApi {
  RoutineApi({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: resolvedBaseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 30),
              headers: const {'Accept': 'application/json'},
            ),
          );

  final Dio _dio;

  /// Base URL for this build.
  ///
  /// An explicitly supplied `--dart-define=OPEN_ROUTINE_API=...` is honoured
  /// verbatim, because only the caller knows how their device reaches the
  /// backend: a physical device over `adb reverse` wants `127.0.0.1`, one on
  /// the same Wi-Fi wants the host's LAN address.
  ///
  /// The convenience rewrite applies *only* to the compile-time default, where
  /// "localhost" would otherwise mean the emulator itself rather than the
  /// machine hosting it.
  static String get resolvedBaseUrl {
    var base = AppConfig.baseUrl;
    if (!AppConfig.apiUrlWasProvided && !kIsWeb && Platform.isAndroid) {
      base = base
          .replaceFirst('localhost', '10.0.2.2')
          .replaceFirst('127.0.0.1', '10.0.2.2');
    }
    return '$base${AppConfig.apiPrefix}';
  }

  /// The revision the server is currently serving.
  Future<RoutineInfo> currentRoutine({
    String department = AppConfig.department,
  }) async {
    final response = await _get(
      '/routines/current',
      query: {'department': department},
    );
    return RoutineInfo.fromJson(response as Map<String, dynamic>);
  }

  /// An entire routine in one payload.
  Future<RoutineSnapshot> snapshot(int routineId) async {
    final response = await _get('/routines/$routineId/snapshot');
    return RoutineSnapshot.fromJson(response as Map<String, dynamic>);
  }

  Future<List<Teacher>> teachers({String? department}) async {
    final response = await _get(
      '/meta/teachers',
      query: department == null ? null : {'department': department},
    );
    return (response as List<dynamic>)
        .map((e) => Teacher.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Object?> _get(String path, {Map<String, dynamic>? query}) async {
    try {
      final response = await _dio.get<Object?>(path, queryParameters: query);
      return response.data;
    } on DioException catch (e) {
      throw _translate(e);
    }
  }

  /// Turn transport errors into failures the UI can render.
  Failure _translate(DioException e) {
    if (e.type == DioExceptionType.badResponse) {
      return ServerFailure(
        _serverMessage(e) ?? 'The server returned ${e.response?.statusCode}.',
        statusCode: e.response?.statusCode,
      );
    }
    return const NetworkFailure();
  }

  /// The backend reports failures as `{"error": {"code": ..., "message": ...}}`.
  String? _serverMessage(DioException e) {
    final data = e.response?.data;
    if (data is! Map<String, dynamic>) return null;
    final error = data['error'];
    if (error is! Map<String, dynamic>) return null;
    final message = error['message'];
    return message is String ? message : null;
  }
}
