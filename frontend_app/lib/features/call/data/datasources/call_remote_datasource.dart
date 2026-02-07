import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/errors/call_exceptions.dart';
import '../../../../core/network/dio_client.dart';
import '../../domain/entities/agora_client_role.dart';
import '../models/call_token_model.dart';

/// Fetches Agora tokens and config from the backend. Uses [DioClient];
/// 2xx is success; only error mapping is done here.
class CallRemoteDataSource {
  CallRemoteDataSource({DioClient? dioClient})
    : _client = dioClient ?? DioClient();

  final DioClient _client;

  Future<CallTokenModel> fetchToken({
    required String idToken,
    required String channelName,
    int? uid,
    AgoraClientRole role = AgoraClientRole.publisher,
  }) async {
    if (idToken.isEmpty) throw CallUnauthorizedException();
    try {
      final body = <String, dynamic>{
        'channelName': channelName,
        if (uid != null) 'uid': uid,
        'role': role == AgoraClientRole.publisher ? 'publisher' : 'subscriber',
      };
      final response = await _client.post<Map<String, dynamic>>(
        AppConfig.callsTokenEndpoint,
        data: body,
        headers: {'Authorization': 'Bearer $idToken'},
      );
      final data = response.data;
      if (data == null) throw CallServerException('Empty token response');
      return CallTokenModel.fromJson(data);
    } on DioException catch (e) {
      if (DioClient.getStatusCode(e) == 401) throw CallUnauthorizedException();
      final message = DioClient.getErrorMessage(e, 'Failed to get call token');
      if ((e.response?.statusCode ?? 0) >= 500) {
        throw CallServerException(message);
      }
      throw CallException(message, statusCode: e.response?.statusCode);
    } catch (e) {
      if (e is CallException) rethrow;
      debugPrint('Call fetchToken error: $e');
      final baseUrl = AppConfig.baseUrl;
      final cause = e.toString().replaceFirst(RegExp(r'^Exception: '), '');
      throw CallNetworkException('Cannot reach $baseUrl. $cause');
    }
  }

  Future<Map<String, dynamic>?> getOffer({
    required String idToken,
    required String callId,
  }) async {
    if (idToken.isEmpty) return null;
    try {
      final response = await _client.get<Map<String, dynamic>>(
        AppConfig.callsOfferGetEndpoint(callId),
        headers: {'Authorization': 'Bearer $idToken'},
      );
      return response.data;
    } on DioException catch (e) {
      if (DioClient.getStatusCode(e) == 404) return null;
      return null;
    }
  }

  Future<Map<String, dynamic>> createOffer({
    required String idToken,
    required String calleeUserId,
  }) async {
    if (idToken.isEmpty) throw CallUnauthorizedException();
    try {
      final response = await _client.post<Map<String, dynamic>>(
        AppConfig.callsOfferEndpoint,
        data: {'calleeUserId': calleeUserId},
        headers: {'Authorization': 'Bearer $idToken'},
      );
      final data = response.data;
      if (data == null) throw CallException('Empty create offer response');
      return data;
    } on DioException catch (e) {
      if (DioClient.getStatusCode(e) == 401) throw CallUnauthorizedException();
      if (DioClient.getStatusCode(e) == 404) {
        throw CallException('User not found');
      }
      throw CallException(
        DioClient.getErrorMessage(e, 'Failed to create call'),
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<CallTokenModel> acceptOffer({
    required String idToken,
    required String callId,
  }) async {
    if (idToken.isEmpty) throw CallUnauthorizedException();
    try {
      final response = await _client.post<Map<String, dynamic>>(
        AppConfig.callsOfferAcceptEndpoint(callId),
        headers: {'Authorization': 'Bearer $idToken'},
      );
      final data = response.data;
      if (data == null) throw CallServerException('Empty accept response');
      return CallTokenModel.fromJson(data);
    } on DioException catch (e) {
      if (DioClient.getStatusCode(e) == 401) throw CallUnauthorizedException();
      if (DioClient.getStatusCode(e) == 404) {
        throw CallException('Call not found');
      }
      final message = DioClient.getErrorMessage(e, 'Failed to accept call');
      if ((e.response?.statusCode ?? 0) >= 500) {
        throw CallServerException(message);
      }
      throw CallException(message, statusCode: e.response?.statusCode);
    } catch (e) {
      if (e is CallException) rethrow;
      debugPrint('Call acceptOffer error: $e');
      final baseUrl = AppConfig.baseUrl;
      final cause = e.toString().replaceFirst(RegExp(r'^Exception: '), '');
      throw CallNetworkException('Cannot reach $baseUrl. $cause');
    }
  }

  Future<void> declineOffer({
    required String idToken,
    required String callId,
  }) async {
    if (idToken.isEmpty) throw CallUnauthorizedException();
    try {
      await _client.post(
        AppConfig.callsOfferDeclineEndpoint(callId),
        headers: {'Authorization': 'Bearer $idToken'},
      );
    } on DioException catch (e) {
      if (DioClient.getStatusCode(e) == 401) throw CallUnauthorizedException();
      if (DioClient.getStatusCode(e) == 404) {
        throw CallException('Call not found');
      }
    }
  }

  Future<void> cancelOffer({
    required String idToken,
    required String callId,
  }) async {
    if (idToken.isEmpty) throw CallUnauthorizedException();
    try {
      await _client.post(
        AppConfig.callsOfferCancelEndpoint(callId),
        headers: {'Authorization': 'Bearer $idToken'},
      );
    } on DioException catch (e) {
      if (DioClient.getStatusCode(e) == 401) throw CallUnauthorizedException();
      if (DioClient.getStatusCode(e) == 404) {
        throw CallException('Call not found');
      }
    }
  }

  Future<String> fetchAppId(String? idToken) async {
    if (idToken == null || idToken.isEmpty) throw CallUnauthorizedException();
    try {
      final response = await _client.get<Map<String, dynamic>>(
        AppConfig.callsConfigEndpoint,
        headers: {'Authorization': 'Bearer $idToken'},
      );
      final data = response.data;
      final appId = data?['appId'] as String?;
      if (appId == null || appId.isEmpty) {
        throw CallServerException('Invalid config response');
      }
      return appId;
    } on DioException catch (e) {
      if (DioClient.getStatusCode(e) == 401) throw CallUnauthorizedException();
      final message = DioClient.getErrorMessage(e, 'Failed to get app config');
      if ((e.response?.statusCode ?? 0) >= 500) {
        throw CallServerException(message);
      }
      throw CallException(message, statusCode: e.response?.statusCode);
    } catch (e) {
      if (e is CallException) rethrow;
      debugPrint('Call fetchAppId error: $e');
      final baseUrl = AppConfig.baseUrl;
      final cause = e.toString().replaceFirst(RegExp(r'^Exception: '), '');
      throw CallNetworkException('Cannot reach $baseUrl. $cause');
    }
  }
}
