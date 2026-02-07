import 'package:dio/dio.dart';

import '../config/app_config.dart';

/// Shared Dio-based HTTP client for backend API calls.
/// Uses [AppConfig.baseUrl]; all requests are relative to that base.
/// Datasources use [get], [post], [patch] and optionally [dio] for multipart.
class DioClient {
  DioClient({String? baseUrl})
    : _dio = _createDio(baseUrl ?? AppConfig.baseUrl);

  static Dio _createDio(String baseUrl) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
    return dio;
  }

  final Dio _dio;

  Dio get dio => _dio;

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    Options? options,
  }) async {
    return _dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: options ?? Options(headers: headers),
    );
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, String>? headers,
    Options? options,
  }) async {
    return _dio.post<T>(
      path,
      data: data,
      options: options ?? Options(headers: headers),
    );
  }

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, String>? headers,
    Options? options,
  }) async {
    return _dio.patch<T>(
      path,
      data: data,
      options: options ?? Options(headers: headers),
    );
  }

  /// Status code from [DioException] (response or 0).
  static int getStatusCode(DioException e) {
    return e.response?.statusCode ?? 0;
  }

  /// User-facing error message from [DioException], or [fallback].
  static String getErrorMessage(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      final msg = data['message'];
      if (msg is String) return msg;
      if (msg is List) return msg.join(' ');
      return msg.toString();
    }
    final code = e.response?.statusCode;
    if (code != null && code >= 400) return fallback;
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Network error. Check connection.';
    }
    return fallback;
  }
}
