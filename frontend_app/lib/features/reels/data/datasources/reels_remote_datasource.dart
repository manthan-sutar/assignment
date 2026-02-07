import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/errors/reels_exceptions.dart';
import '../../../../core/network/dio_client.dart';
import '../models/reel_model.dart';

/// Fetches reels from the backend. Uses [DioClient]; 2xx is success.
class ReelsRemoteDataSource {
  ReelsRemoteDataSource({DioClient? dioClient})
    : _client = dioClient ?? DioClient();

  final DioClient _client;

  Future<List<ReelModel>> fetchReels(String? idToken) async {
    if (idToken == null || idToken.isEmpty) {
      throw ReelsUnauthorizedException();
    }
    try {
      final response = await _client.get<List<dynamic>>(
        AppConfig.reelsEndpoint,
        headers: {'Authorization': 'Bearer $idToken'},
      );
      final decoded = response.data;
      if (decoded is! List) {
        throw ReelsServerException('Invalid response format');
      }
      return decoded
          .map((e) => ReelModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      if (DioClient.getStatusCode(e) == 401) {
        throw ReelsUnauthorizedException();
      }
      if ((e.response?.statusCode ?? 0) >= 500) {
        throw ReelsServerException('Server error. Try again later.');
      }
      final message = DioClient.getErrorMessage(e, 'Failed to load reels');
      throw ReelsException(message, statusCode: e.response?.statusCode);
    } catch (e) {
      if (e is ReelsException) rethrow;
      debugPrint('Reels fetch error: $e');
      final baseUrl = AppConfig.baseUrl;
      final cause = e.toString().replaceFirst(RegExp(r'^Exception: '), '');
      throw ReelsNetworkException('Cannot reach $baseUrl. $cause');
    }
  }
}
