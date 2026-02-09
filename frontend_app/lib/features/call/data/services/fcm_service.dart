import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../../../auth/domain/repositories/auth_repository.dart';

/// Handles FCM: permission, token, upload to backend, and foreground message stream.
/// Initialize in main() after Firebase. Call [uploadTokenToBackend] when user is authenticated.
class FcmService {
  FcmService({required AuthRepository authRepository})
      : _authRepository = authRepository;

  final AuthRepository _authRepository;
  final StreamController<RemoteMessage> _foregroundMessageController =
      StreamController<RemoteMessage>.broadcast();

  String? _currentToken;
  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<String>? _onTokenRefreshSub;

  /// Stream of FCM messages received while app is in foreground.
  /// Use for showing in-app incoming call UI (e.g. type == 'incoming_call').
  Stream<RemoteMessage> get foregroundMessages => _foregroundMessageController.stream;

  /// Initialize: request permission, get token, set up listeners.
  /// Call once after Firebase init. Does not require user to be logged in.
  Future<void> initialize() async {
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('FCM permission denied');
      return;
    }
    _currentToken = await messaging.getToken();
    if (_currentToken != null) {
      try {
        await _uploadTokenToBackend();
      } catch (e) {
        debugPrint('FCM initial uploadTokenToBackend: $e');
      }
    }

    _onMessageSub = FirebaseMessaging.onMessage.listen((message) {
      _foregroundMessageController.add(message);
    });

    _onTokenRefreshSub = messaging.onTokenRefresh.listen((token) {
      _currentToken = token;
      _uploadTokenToBackend().catchError((e) {
        debugPrint('FCM token refresh upload failed: $e');
      });
    });
  }

  /// Upload current FCM token to backend. Safe to call when not authenticated (no-op).
  /// Call after login and when token is refreshed (handled in [initialize]).
  /// On first install, FCM may not have a token yet; we fetch it if needed and never send null
  /// (sending null would clear the server token and break incoming calls).
  Future<void> uploadTokenToBackend() => _uploadTokenToBackend();

  /// Subscribe to topic "live_sessions" to receive "someone went live" notifications.
  /// Call when user is authenticated.
  Future<void> subscribeToLiveTopic() async {
    try {
      await FirebaseMessaging.instance.subscribeToTopic('live_sessions');
    } catch (e) {
      debugPrint('FCM subscribeToLiveTopic: $e');
    }
  }

  /// Uploads current FCM token to backend. Throws on failure so callers can retry.
  /// Never sends null to the server when we intend to register (only clearTokenOnBackend clears).
  /// On first install FCM token may not be ready yet; we try to fetch it once if missing.
  Future<void> _uploadTokenToBackend() async {
    String? token = _currentToken;
    if (token == null || token.isEmpty) {
      token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) _currentToken = token;
    }
    if (token == null || token.isEmpty) {
      debugPrint(
        'FCM: no token available yet (e.g. first install); skipping upload to avoid clearing server token',
      );
      return;
    }
    await _authRepository.updateFcmToken(token);
  }

  /// Call on sign-out to clear token on server (optional).
  Future<void> clearTokenOnBackend() async {
    try {
      await _authRepository.updateFcmToken(null);
    } catch (e) {
      debugPrint('FCM clearTokenOnBackend: $e');
    }
  }

  void dispose() {
    _onMessageSub?.cancel();
    _onTokenRefreshSub?.cancel();
    _foregroundMessageController.close();
  }
}
