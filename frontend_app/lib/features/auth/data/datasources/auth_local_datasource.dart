import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/user_model.dart';

/**
 * Auth Local Data Source
 * Handles local storage for authentication tokens and user data
 */
class AuthLocalDataSource {
  static const String _userKey = 'user_data';
  static const String _tokenKey = 'auth_token';

  final SharedPreferences prefs;

  AuthLocalDataSource(this.prefs);

  /// Save user data locally
  Future<void> saveUser(UserModel user) async {
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  /// Get saved user data
  Future<UserModel?> getUser() async {
    final userJson = prefs.getString(_userKey);
    if (userJson != null) {
      return UserModel.fromJson(jsonDecode(userJson));
    }
    return null;
  }

  /// Save auth token
  Future<void> saveToken(String token) async {
    await prefs.setString(_tokenKey, token);
  }

  /// Get saved auth token
  Future<String?> getToken() async {
    return prefs.getString(_tokenKey);
  }

  /// Clear all auth data
  Future<void> clearAuthData() async {
    await prefs.remove(_userKey);
    await prefs.remove(_tokenKey);
  }
}
