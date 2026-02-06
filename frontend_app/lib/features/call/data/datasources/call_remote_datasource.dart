import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../../core/config/app_config.dart';
import '../../../../core/errors/call_exceptions.dart';
import '../models/call_token_model.dart';
import '../../domain/entities/agora_client_role.dart';

/// Fetches Agora tokens and config from the backend. Requires auth token.
class CallRemoteDataSource {
  CallRemoteDataSource({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  /// Request an RTC token for [channelName]. [idToken] = Firebase ID token.
  Future<CallTokenModel> fetchToken({
    required String idToken,
    required String channelName,
    int? uid,
    AgoraClientRole role = AgoraClientRole.publisher,
  }) async {
    if (idToken.isEmpty) throw CallUnauthorizedException();

    final uri = Uri.parse('${AppConfig.baseUrl}${AppConfig.callsTokenEndpoint}');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $idToken',
    };
    final body = <String, dynamic>{
      'channelName': channelName,
      if (uid != null) 'uid': uid,
      'role': role == AgoraClientRole.publisher ? 'publisher' : 'subscriber',
    };

    try {
      final response = await _client.post(
        uri,
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final decoded =
            jsonDecode(response.body) as Map<String, dynamic>;
        return CallTokenModel.fromJson(decoded);
      }

      if (response.statusCode == 401) throw CallUnauthorizedException();
      if (response.statusCode >= 500) {
        throw CallServerException('Server error. Try again later.');
      }

      String message = 'Failed to get call token';
      try {
        final err = jsonDecode(response.body) as Map<String, dynamic>;
        if (err['message'] != null) message = err['message'] as String;
      } catch (_) {}
      throw CallException(message, statusCode: response.statusCode);
    } catch (e) {
      if (e is CallException) rethrow;
      debugPrint('Call fetchToken error: $e');
      final baseUrl = AppConfig.baseUrl;
      final cause = e.toString().replaceFirst(RegExp(r'^Exception: '), '');
      throw CallNetworkException('Cannot reach $baseUrl. $cause');
    }
  }

  /// Fetch Agora App ID from backend.
  Future<String> fetchAppId(String? idToken) async {
    if (idToken == null || idToken.isEmpty) throw CallUnauthorizedException();

    final uri = Uri.parse('${AppConfig.baseUrl}${AppConfig.callsConfigEndpoint}');
    final headers = {
      'Authorization': 'Bearer $idToken',
    };

    try {
      final response = await _client.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final decoded =
            jsonDecode(response.body) as Map<String, dynamic>;
        final appId = decoded['appId'] as String?;
        if (appId == null || appId.isEmpty) {
          throw CallServerException('Invalid config response');
        }
        return appId;
      }

      if (response.statusCode == 401) throw CallUnauthorizedException();
      if (response.statusCode >= 500) {
        throw CallServerException('Server error. Try again later.');
      }

      throw CallException('Failed to get app config', statusCode: response.statusCode);
    } catch (e) {
      if (e is CallException) rethrow;
      debugPrint('Call fetchAppId error: $e');
      final baseUrl = AppConfig.baseUrl;
      final cause = e.toString().replaceFirst(RegExp(r'^Exception: '), '');
      throw CallNetworkException('Cannot reach $baseUrl. $cause');
    }
  }
}
