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

  /// WebSocket URL for signaling (same host as API, ws scheme).
  static String get signalingUrl {
    final base = baseUrl;
    if (base.startsWith('https://')) {
      return 'wss://${base.substring(8)}';
    }
    return 'ws://${base.substring(7)}';
  }

  // API endpoints
  static const String signInEndpoint = '/auth/sign-in';
  static const String signUpEndpoint = '/auth/sign-up';
  static const String verifyTokenEndpoint = '/auth/verify-token';
  static const String meEndpoint = '/auth/me';
  static const String profileUpdateEndpoint = '/auth/profile';
  static const String fcmTokenEndpoint = '/auth/fcm-token';
  static const String usersListEndpoint = '/auth/users';
  static const String reelsEndpoint = '/reels';

  /// Agora RTC token and config (calls & live audio streaming).
  static const String callsTokenEndpoint = '/calls/token';
  static const String callsConfigEndpoint = '/calls/config';
  static const String callsAgoraStatusEndpoint = '/calls/agora-status';
  static const String callsOfferEndpoint = '/calls/offer';
  static String callsOfferGetEndpoint(String callId) => '/calls/offer/$callId';
  static String callsOfferAcceptEndpoint(String callId) =>
      '/calls/offer/$callId/accept';
  static String callsOfferDeclineEndpoint(String callId) =>
      '/calls/offer/$callId/decline';
  static String callsOfferCancelEndpoint(String callId) =>
      '/calls/offer/$callId/cancel';

  /// Live audio streaming.
  static const String liveStartEndpoint = '/live/start';
  static const String liveEndEndpoint = '/live/end';
  static const String liveSessionsEndpoint = '/live/sessions';
}
