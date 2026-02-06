import 'package:flutter/foundation.dart';

/**
 * App Configuration
 * Centralized configuration constants
 */
class AppConfig {
  /// Set to your computer's IP (e.g. 'http://192.168.1.100:3000') when running
  /// on a physical device; leave null to use platform defaults.
  static const String? baseUrlOverride = null;

  /// Backend API base URL. Uses [baseUrlOverride] if set, otherwise picks the
  /// right host for the current platform (emulator/simulator).
  static String get baseUrl {
    if (baseUrlOverride != null && baseUrlOverride!.isNotEmpty) {
      return baseUrlOverride!;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000'; // Android emulator
    }
    return 'http://localhost:3000'; // iOS simulator, macOS, etc.
  }

  // API endpoints
  static const String signInEndpoint = '/auth/sign-in';
  static const String signUpEndpoint = '/auth/sign-up';
  static const String verifyTokenEndpoint = '/auth/verify-token';
  static const String meEndpoint = '/auth/me';
  static const String reelsEndpoint = '/reels';

  /// Agora RTC token and config (calls & live audio streaming).
  static const String callsTokenEndpoint = '/calls/token';
  static const String callsConfigEndpoint = '/calls/config';
}
