import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/dio_client.dart';
import '../../domain/entities/live_session_entity.dart';
import '../../domain/entities/start_live_entity.dart';

/// Live API. Uses [DioClient]; 2xx (and 400 for endLive) handled in one place.
class LiveRemoteDataSource {
  LiveRemoteDataSource({DioClient? dioClient})
    : _client = dioClient ?? DioClient();

  final DioClient _client;

  Exception _unauthorized() => Exception('Unauthorized');

  Future<StartLiveEntity> startLive(String idToken) async {
    if (idToken.isEmpty) throw _unauthorized();
    try {
      final response = await _client.post<Map<String, dynamic>>(
        AppConfig.liveStartEndpoint,
        headers: {'Authorization': 'Bearer $idToken'},
      );
      final map = response.data;
      if (map == null) throw Exception('Empty start live response');
      return StartLiveEntity(
        sessionId: map['sessionId'] as String,
        channelName: map['channelName'] as String,
        token: map['token'] as String,
        appId: map['appId'] as String,
        uid: (map['uid'] as num).toInt(),
        expiresIn: (map['expiresIn'] as num).toInt(),
      );
    } on DioException catch (e) {
      if (DioClient.getStatusCode(e) == 401) throw _unauthorized();
      debugPrint(
        'Live startLive error: ${e.response?.statusCode} ${e.response?.data}',
      );
      throw Exception(DioClient.getErrorMessage(e, 'Failed to start live'));
    }
  }

  Future<void> endLive(String idToken) async {
    if (idToken.isEmpty) throw _unauthorized();
    try {
      await _client.post(
        AppConfig.liveEndEndpoint,
        headers: {'Authorization': 'Bearer $idToken'},
      );
    } on DioException catch (e) {
      if (DioClient.getStatusCode(e) == 401) throw _unauthorized();
      // 400 = already not live — treat as success
      if (DioClient.getStatusCode(e) == 400) return;
      debugPrint(
        'Live endLive error: ${e.response?.statusCode} ${e.response?.data}',
      );
      throw Exception(DioClient.getErrorMessage(e, 'Failed to end live'));
    }
  }

  Future<StartLiveEntity?> getHostToken(String idToken) async {
    if (idToken.isEmpty) return null;
    try {
      final response = await _client.get<Map<String, dynamic>>(
        AppConfig.liveHostTokenEndpoint,
        headers: {'Authorization': 'Bearer $idToken'},
      );
      final map = response.data;
      if (map == null) return null;
      return StartLiveEntity(
        sessionId: map['sessionId'] as String,
        channelName: map['channelName'] as String,
        token: map['token'] as String,
        appId: map['appId'] as String,
        uid: (map['uid'] as num).toInt(),
        expiresIn: (map['expiresIn'] as num).toInt(),
      );
    } on DioException catch (e) {
      if (DioClient.getStatusCode(e) == 404) return null;
      rethrow;
    }
  }

  Future<List<LiveSessionEntity>> getSessions(String idToken) async {
    if (idToken.isEmpty) throw _unauthorized();
    try {
      final response = await _client.get<List<dynamic>>(
        AppConfig.liveSessionsEndpoint,
        headers: {'Authorization': 'Bearer $idToken'},
      );
      final list = response.data;
      if (list == null) return [];
      return list
          .map((e) => _sessionFromMap(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      if (DioClient.getStatusCode(e) == 401) throw _unauthorized();
      debugPrint(
        'Live getSessions error: ${e.response?.statusCode} ${e.response?.data}',
      );
      throw Exception(
        DioClient.getErrorMessage(e, 'Failed to load live sessions'),
      );
    }
  }

  LiveSessionEntity _sessionFromMap(Map<String, dynamic> map) {
    return LiveSessionEntity(
      sessionId: (map['sessionId'] as String?) ?? '',
      channelName: (map['channelName'] as String?) ?? '',
      hostUserId: (map['hostUserId'] as String?) ?? '',
      hostDisplayName: (map['hostDisplayName'] as String?) ?? 'Unknown',
      startedAt: (map['startedAt'] as String?) ?? '',
    );
  }
}
