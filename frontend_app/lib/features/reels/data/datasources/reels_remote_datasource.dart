import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../../core/config/app_config.dart';
import '../../../../core/errors/reels_exceptions.dart';
import '../models/reel_model.dart';

/// Fetches reels from the backend. Requires a valid auth token.
class ReelsRemoteDataSource {
  ReelsRemoteDataSource({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  /// Fetches list of reels. [idToken] must be non-null and valid.
  Future<List<ReelModel>> fetchReels(String? idToken) async {
    if (idToken == null || idToken.isEmpty) {
      throw ReelsUnauthorizedException();
    }

    final uri = Uri.parse('${AppConfig.baseUrl}${AppConfig.reelsEndpoint}');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $idToken',
    };

    try {
      final response = await _client.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is! List) {
          throw ReelsServerException('Invalid response format');
        }
        return decoded
            .map((e) => ReelModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      if (response.statusCode == 401) {
        throw ReelsUnauthorizedException();
      }

      if (response.statusCode >= 500) {
        throw ReelsServerException('Server error. Try again later.');
      }

      String message = 'Failed to load reels';
      try {
        final err = jsonDecode(response.body) as Map<String, dynamic>;
        if (err['message'] != null) message = err['message'] as String;
      } catch (_) {}
      throw ReelsException(message, statusCode: response.statusCode);
    } catch (e) {
      if (e is ReelsException) rethrow;
      debugPrint('Reels fetch error: $e');
      final baseUrl = AppConfig.baseUrl;
      final cause = e.toString().replaceFirst(RegExp(r'^Exception: '), '');
      throw ReelsNetworkException('Cannot reach $baseUrl. $cause');
    }
  }
}
