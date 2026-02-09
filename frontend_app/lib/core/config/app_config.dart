import 'package:flutter/foundation.dart';

/**
 * App Configuration
 * Centralized configuration constants
 */
class AppConfig {
  /// Your computer's IP on the same WiFi so phones can reach the backend.
  /// Change to your machine's local IP if different (e.g. from `ifconfig` / ipconfig).
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

  /// Socket.IO server URL for signaling. Use HTTP(S) base URL; socket_io_client handles protocol.
  static String get signalingUrl => baseUrl;

  // API endpoints
  static const String signInEndpoint = '/auth/sign-in';
  static const String signUpEndpoint = '/auth/sign-up';
  static const String verifyTokenEndpoint = '/auth/verify-token';
  static const String meEndpoint = '/auth/me';
  static const String profileUpdateEndpoint = '/auth/profile';
  static const String fcmTokenEndpoint = '/auth/fcm-token';
  static const String usersListEndpoint = '/auth/users';
  static const String reelsEndpoint = '/reels';

  // --- Reels feed (audio reels) — separate server ---
  /// Base URL for the reels/feeds API (different from main backend). Set manually.
  static const String reelsFeedBaseUrl = 'http://35.200.252.238:8080/api/v1/';

  /// Bearer token for reels feed API. Set manually.
  static const String reelsFeedBearerToken =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhY2Nlc3NfdXVpZCI6ImI5NmFiOTZkLWNkOTItNDk2MS1hYmQ1LTI4ZWRmYTdjZjE0MCIsImF1dGhvcml6ZWQiOnRydWUsImV4cCI6MTc3MzE2ODIzNSwidXNlcl9pZCI6ImQ2YjZlZGM0LTM0N2YtNDNjMy1iZDkwLWYxZDgyZmY1ZWQ3YSJ9.QEWaS1ZdZ9eZ2ByQtLCP4WW43rkf3SCLyKmuJ18Izes';

  /// Path for the feeds endpoint on the reels server (e.g. /feeds). Set manually.
  static const String reelsFeedEndpoint = 'user/user-feed';

  /// Number of audio reels to fetch per page (query param [limit]).
  static const int reelsFeedLimit = 10;

  /// Agora RTC token and config (calls & live audio streaming).
  static const String callsTokenEndpoint = '/calls/token';
  static const String callsConfigEndpoint = '/calls/config';
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
  static const String liveHostTokenEndpoint = '/live/host-token';
}
