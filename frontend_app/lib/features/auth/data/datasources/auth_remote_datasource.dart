import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/errors/auth_exceptions.dart';
import '../../../../core/network/dio_client.dart';
import '../models/list_user_item.dart';
import '../models/user_model.dart';

/**
 * Auth Remote Data Source
 * Handles API calls to backend for authentication. Uses [DioClient] for HTTP;
 * success (2xx) is handled in one place; only error mapping is done here.
 */
class AuthRemoteDataSource {
  AuthRemoteDataSource({DioClient? dioClient})
    : _client = dioClient ?? DioClient();

  final DioClient _client;

  /// Sign in with Firebase ID token.
  /// Returns UserModel if user exists, or null if user not found.
  Future<UserModel?> signIn(String idToken) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        AppConfig.signInEndpoint,
        data: {'idToken': idToken},
      );
      final data = response.data;
      if (data == null) return null;
      if (data['exists'] == true && data['user'] != null) {
        return UserModel.fromJson(data['user'] as Map<String, dynamic>);
      }
      if (data['exists'] == false) return null;
      return null;
    } on DioException catch (e) {
      if (DioClient.getStatusCode(e) == 401) {
        throw SignInException('Invalid credentials');
      }
      debugPrint(
        'Sign in failed: ${e.response?.statusCode} ${e.response?.data}',
      );
      throw SignInException(DioClient.getErrorMessage(e, 'Sign in failed'));
    } catch (e) {
      if (e is SignInException) rethrow;
      throw SignInException('Network error: ${e.toString()}');
    }
  }

  /// Sign up with Firebase ID token and consent.
  Future<UserModel> signUp(String idToken, bool consent) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        AppConfig.signUpEndpoint,
        data: {'idToken': idToken, 'consent': consent},
      );
      final data = response.data;
      if (data != null && data['user'] != null) {
        return UserModel.fromJson(data['user'] as Map<String, dynamic>);
      }
      throw SignUpException('Unexpected response from server');
    } on DioException catch (e) {
      if (DioClient.getStatusCode(e) == 400) {
        final msg = e.response?.data;
        final message = msg is Map && msg['message'] != null
            ? msg['message'].toString()
            : 'Sign up failed';
        throw SignUpException(message);
      }
      throw SignUpException(DioClient.getErrorMessage(e, 'Sign up failed'));
    } catch (e) {
      if (e is SignUpException) rethrow;
      throw SignUpException('Network error: ${e.toString()}');
    }
  }

  /// Update profile (displayName and optional photo). Requires valid token.
  Future<UserModel> updateProfile(
    String idToken,
    String displayName, {
    File? photoFile,
  }) async {
    try {
      final map = <String, dynamic>{'displayName': displayName.trim()};
      if (photoFile != null &&
          photoFile.path.isNotEmpty &&
          await photoFile.exists()) {
        final filename = photoFile.path
            .replaceAll(RegExp(r'[/\\]'), '/')
            .split('/')
            .last;
        map['photo'] = await MultipartFile.fromFile(
          photoFile.path,
          filename: filename.contains('.') ? filename : 'image.jpg',
        );
      }
      final formData = FormData.fromMap(map);
      final response = await _client.dio.patch<Map<String, dynamic>>(
        AppConfig.profileUpdateEndpoint,
        data: formData,
        options: Options(
          headers: {'Authorization': 'Bearer $idToken'},
          contentType: 'multipart/form-data',
        ),
      );
      final data = response.data;
      if (data != null) return UserModel.fromJson(data);
      throw ProfileUpdateException('Profile update failed');
    } on DioException catch (e) {
      if (DioClient.getStatusCode(e) == 400) {
        final body = e.response?.data;
        final message = body is Map && body['message'] != null
            ? (body['message'] is List
                  ? (body['message'] as List).join(' ')
                  : body['message'].toString())
            : 'Invalid profile data';
        throw ProfileUpdateException(message);
      }
      if (DioClient.getStatusCode(e) == 401) {
        throw ProfileUpdateException('Please sign in again');
      }
      debugPrint(
        'Profile update failed: ${e.response?.statusCode} ${e.response?.data}',
      );
      throw ProfileUpdateException(
        DioClient.getErrorMessage(e, 'Profile update failed'),
      );
    } catch (e) {
      if (e is ProfileUpdateException) rethrow;
      throw ProfileUpdateException('Network error: ${e.toString()}');
    }
  }

  /// List users (Find people). Requires valid token. Excludes current user.
  Future<List<ListUserItem>> getUsers(String idToken) async {
    try {
      final response = await _client.get<List<dynamic>>(
        AppConfig.usersListEndpoint,
        headers: {'Authorization': 'Bearer $idToken'},
      );
      final list = response.data;
      if (list is List) {
        return list
            .map((e) => ListUserItem.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      if (DioClient.getStatusCode(e) == 401) {
        throw SignInException('Please sign in again');
      }
      return [];
    } catch (e) {
      if (e is SignInException) rethrow;
      rethrow;
    }
  }

  /// Update FCM device token for push notifications (incoming call, etc.)
  Future<void> updateFcmToken(String idToken, String? fcmToken) async {
    try {
      await _client.post(
        AppConfig.fcmTokenEndpoint,
        data: {'fcmToken': fcmToken},
        headers: {'Authorization': 'Bearer $idToken'},
      );
    } on DioException catch (e) {
      debugPrint('FCM token update failed: ${e.response?.statusCode}');
    }
  }

  /// Verify Firebase token.
  Future<Map<String, dynamic>> verifyToken(String idToken) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        AppConfig.verifyTokenEndpoint,
        data: {'idToken': idToken},
      );
      final data = response.data;
      if (data != null) return data;
      throw TokenException('Token verification failed');
    } on DioException catch (e) {
      throw TokenException(
        DioClient.getErrorMessage(e, 'Token verification failed'),
      );
    } catch (e) {
      if (e is TokenException) rethrow;
      throw TokenException('Network error: ${e.toString()}');
    }
  }
}
