import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../error/app_failure.dart';

/// Thin wrapper over Dio that turns every failure into an [AppFailure].
class ApiClient {
  ApiClient(this._dio);

  factory ApiClient.create({String? baseUrl}) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 8),
        headers: {'Accept': 'application/json'},
        responseType: ResponseType.json,
      ),
    );
    if (kDebugMode) {
      dio.interceptors.add(
        LogInterceptor(requestBody: false, responseBody: false, logPrint: (o) => debugPrint('[api] $o')),
      );
    }
    return ApiClient(dio);
  }

  final Dio _dio;

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get<Map<String, dynamic>>(path, queryParameters: query));

  Future<Map<String, dynamic>> post(String path, Object body) =>
      _send(() => _dio.post<Map<String, dynamic>>(path, data: body));

  Future<Map<String, dynamic>> _send(Future<Response<Map<String, dynamic>>> Function() request) async {
    try {
      final res = await request();
      return res.data ?? const {};
    } on DioException catch (e) {
      throw mapDioException(e);
    } on FormatException {
      throw const UnexpectedFailure('The server sent a response we could not read.');
    }
  }
}

@visibleForTesting
AppFailure mapDioException(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return const TimeoutFailure();
    case DioExceptionType.connectionError:
      return const NetworkFailure();
    case DioExceptionType.badResponse:
      final data = e.response?.data;
      final error = data is Map ? data['error'] : null;
      if (error is Map) {
        final details = error['details'];
        return ServerFailure(
          (error['message'] as String?) ?? 'The server returned an error.',
          code: error['code'] as String?,
          statusCode: e.response?.statusCode,
          reason: details is Map ? details['reason'] as String? : null,
        );
      }
      return ServerFailure(
        'The server returned an error (${e.response?.statusCode}).',
        statusCode: e.response?.statusCode,
      );
    case DioExceptionType.cancel:
      return const UnexpectedFailure('The request was cancelled.');
    case DioExceptionType.badCertificate:
      return const NetworkFailure('The secure connection to the server could not be verified.');
    case DioExceptionType.unknown:
      return const NetworkFailure();
  }
}

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient.create());
