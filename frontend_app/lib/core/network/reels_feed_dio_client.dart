import 'package:dio/dio.dart';

import '../config/app_config.dart';

/// Dio client used only for the reels/feeds API (audio reels on a separate server).
/// Configure [AppConfig.reelsFeedBaseUrl], [AppConfig.reelsFeedBearerToken],
/// and [AppConfig.reelsFeedEndpoint] in app_config.dart.
class ReelsFeedDioClient {
  ReelsFeedDioClient({
    String? baseUrl,
    String? bearerToken,
  }) : _dio = _createDio(
          baseUrl ?? AppConfig.reelsFeedBaseUrl,
          bearerToken ?? AppConfig.reelsFeedBearerToken,
        );

  static Dio _createDio(String baseUrl, String bearerToken) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (bearerToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $bearerToken';
    }
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
        headers: headers,
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

  /// Status code from [DioException].
  static int getStatusCode(DioException e) {
    return e.response?.statusCode ?? 0;
  }

  /// User-facing error message from [DioException].
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
