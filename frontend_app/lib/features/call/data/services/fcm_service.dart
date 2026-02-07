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
      await _uploadTokenToBackend();
    }

    _onMessageSub = FirebaseMessaging.onMessage.listen((message) {
      _foregroundMessageController.add(message);
    });

    _onTokenRefreshSub = messaging.onTokenRefresh.listen((token) {
      _currentToken = token;
      _uploadTokenToBackend();
    });
  }

  /// Upload current FCM token to backend. Safe to call when not authenticated (no-op).
  /// Call after login and when token is refreshed (handled in [initialize]).
  Future<void> uploadTokenToBackend() => _uploadTokenToBackend();

  Future<void> _uploadTokenToBackend() async {
    try {
      await _authRepository.updateFcmToken(_currentToken);
    } catch (e) {
      debugPrint('FCM uploadTokenToBackend: $e');
    }
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
