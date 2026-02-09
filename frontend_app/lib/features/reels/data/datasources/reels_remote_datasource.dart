import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/errors/reels_exceptions.dart';
import '../../../../core/network/reels_feed_dio_client.dart';
import '../models/reels_feed_response.dart';

/// Fetches audio reels from the reels feed API (separate server).
/// Uses [ReelsFeedDioClient]. Configure [AppConfig.reelsFeedBaseUrl],
/// [AppConfig.reelsFeedBearerToken], and [AppConfig.reelsFeedEndpoint].
class ReelsRemoteDataSource {
  ReelsRemoteDataSource({ReelsFeedDioClient? reelsFeedClient})
      : _client = reelsFeedClient ?? ReelsFeedDioClient();

  final ReelsFeedDioClient _client;

  /// Fetches a page of reels. [cursor] is UTC time for pagination (omit for first page).
  /// [limit] is the number of audios per page.
  Future<ReelsFeedPageResult> fetchReels({
    String? cursor,
    int? limit,
  }) async {
    final endpoint = AppConfig.reelsFeedEndpoint;
    if (endpoint.isEmpty) {
      throw ReelsServerException(
        'Reels feed endpoint not set. Set AppConfig.reelsFeedEndpoint in app_config.dart.',
      );
    }
    final baseUrl = AppConfig.reelsFeedBaseUrl;
    if (baseUrl.isEmpty) {
      throw ReelsServerException(
        'Reels feed base URL not set. Set AppConfig.reelsFeedBaseUrl in app_config.dart.',
      );
    }
    final effectiveLimit = limit ?? AppConfig.reelsFeedLimit;
    final queryParams = <String, dynamic>{'limit': effectiveLimit};
    if (cursor != null && cursor.isNotEmpty) {
      queryParams['cursor'] = cursor;
    }
    try {
      final response = await _client.get<Map<String, dynamic>>(
        endpoint,
        queryParameters: queryParams,
      );
      final data = response.data;
      if (data == null) {
        throw ReelsServerException('Invalid response format');
      }
      final feed = ReelsFeedResponse.fromJson(data);
      return ReelsFeedPageResult(
        reels: feed.toReelModels(),
        nextCursor: feed.nextCursor,
      );
    } on DioException catch (e) {
      if (ReelsFeedDioClient.getStatusCode(e) == 401) {
        throw ReelsUnauthorizedException();
      }
      if ((e.response?.statusCode ?? 0) >= 500) {
        throw ReelsServerException('Server error. Try again later.');
      }
      final message =
          ReelsFeedDioClient.getErrorMessage(e, 'Failed to load reels');
      throw ReelsException(message, statusCode: e.response?.statusCode);
    } catch (e) {
      if (e is ReelsException) rethrow;
      debugPrint('Reels fetch error: $e');
      final cause = e.toString().replaceFirst(RegExp(r'^Exception: '), '');
      throw ReelsNetworkException('Cannot reach reels feed. $cause');
    }
  }
}
