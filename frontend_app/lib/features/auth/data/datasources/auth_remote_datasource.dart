import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../../core/config/app_config.dart';
import '../../../../core/errors/auth_exceptions.dart';
import '../models/user_model.dart';

/**
 * Auth Remote Data Source
 * Handles API calls to backend for authentication
 */
class AuthRemoteDataSource {
  final http.Client client;

  AuthRemoteDataSource({http.Client? client}) : client = client ?? http.Client();

  /// Sign in with Firebase ID token
  /// Returns UserModel if user exists, or null if user not found
  Future<UserModel?> signIn(String idToken) async {
    try {
      final response = await client.post(
        Uri.parse('${AppConfig.baseUrl}${AppConfig.signInEndpoint}'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'idToken': idToken}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        
        // Check if user exists
        if (data['exists'] == true && data['user'] != null) {
          return UserModel.fromJson(data['user']);
        } else if (data['exists'] == false) {
          // User not found - return null to trigger sign-up flow
          return null;
        }
      } else if (response.statusCode == 401) {
        throw SignInException('Invalid credentials');
      } else {
        // Log the response for debugging
        debugPrint('Sign in failed with status ${response.statusCode}: ${response.body}');
        throw SignInException('Sign in failed: ${response.statusCode}');
      }
    } catch (e) {
      if (e is SignInException) rethrow;
      throw SignInException('Network error: ${e.toString()}');
    }
    return null;
  }

  /// Sign up with Firebase ID token and consent
  Future<UserModel> signUp(String idToken, bool consent) async {
    try {
      final response = await client.post(
        Uri.parse('${AppConfig.baseUrl}${AppConfig.signUpEndpoint}'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'idToken': idToken,
          'consent': consent,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['user'] != null) {
          return UserModel.fromJson(data['user']);
        }
      } else if (response.statusCode == 400) {
        final error = jsonDecode(response.body);
        throw SignUpException(error['message'] ?? 'Sign up failed');
      } else {
        throw SignUpException('Sign up failed: ${response.statusCode}');
      }
    } catch (e) {
      if (e is SignUpException) rethrow;
      throw SignUpException('Network error: ${e.toString()}');
    }
    throw SignUpException('Unexpected error during sign up');
  }

  /// Verify Firebase token
  Future<Map<String, dynamic>> verifyToken(String idToken) async {
    try {
      final response = await client.post(
        Uri.parse('${AppConfig.baseUrl}${AppConfig.verifyTokenEndpoint}'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'idToken': idToken}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw TokenException('Token verification failed');
      }
    } catch (e) {
      if (e is TokenException) rethrow;
      throw TokenException('Network error: ${e.toString()}');
    }
  }
}
