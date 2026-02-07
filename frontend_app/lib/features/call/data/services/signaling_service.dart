import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../../../../core/config/app_config.dart';
import '../../../auth/domain/repositories/auth_repository.dart';

/// Payload for incoming_call (to callee).
class IncomingCallPayload {
  const IncomingCallPayload({
    required this.callId,
    required this.channelName,
    required this.callerId,
    required this.callerName,
  });
  final String callId;
  final String channelName;
  final String callerId;
  final String callerName;

  static IncomingCallPayload fromMap(Map<String, dynamic> map) {
    return IncomingCallPayload(
      callId: (map['callId'] as String?) ?? '',
      channelName: (map['channelName'] as String?) ?? '',
      callerId: (map['callerId'] as String?) ?? '',
      callerName: (map['callerName'] as String?) ?? 'Unknown',
    );
  }
}

/// Payload for call_accepted (to caller).
class CallAcceptedPayload {
  const CallAcceptedPayload({required this.callId, required this.channelName});
  final String callId;
  final String channelName;

  static CallAcceptedPayload fromMap(Map<String, dynamic> map) {
    return CallAcceptedPayload(
      callId: (map['callId'] as String?) ?? '',
      channelName: (map['channelName'] as String?) ?? '',
    );
  }
}

/// Payload for call_declined / call_cancelled.
class CallEndedPayload {
  const CallEndedPayload({required this.callId});
  final String callId;

  static CallEndedPayload fromMap(Map<String, dynamic> map) {
    return CallEndedPayload(callId: (map['callId'] as String?) ?? '');
  }
}

/// Payload for live_started (broadcast to all).
class LiveStartedPayload {
  const LiveStartedPayload({
    required this.sessionId,
    required this.channelName,
    required this.hostUserId,
    required this.hostDisplayName,
    required this.startedAt,
  });
  final String sessionId;
  final String channelName;
  final String hostUserId;
  final String hostDisplayName;
  final String startedAt;

  static LiveStartedPayload fromMap(Map<String, dynamic> map) {
    return LiveStartedPayload(
      sessionId: (map['sessionId'] as String?) ?? '',
      channelName: (map['channelName'] as String?) ?? '',
      hostUserId: (map['hostUserId'] as String?) ?? '',
      hostDisplayName: (map['hostDisplayName'] as String?) ?? 'Unknown',
      startedAt: (map['startedAt'] as String?) ?? '',
    );
  }
}

/// Payload for live_ended (broadcast to all).
class LiveEndedPayload {
  const LiveEndedPayload({required this.sessionId, this.channelName});
  final String sessionId;
  final String? channelName;

  static LiveEndedPayload fromMap(Map<String, dynamic> map) {
    return LiveEndedPayload(
      sessionId: (map['sessionId'] as String?) ?? '',
      channelName: map['channelName'] as String?,
    );
  }
}

/// WebSocket signaling client: connect after login, register with idToken,
/// subscribe to incoming_call, call_accepted, call_declined, call_cancelled.
class SignalingService {
  SignalingService({required AuthRepository authRepository})
    : _authRepository = authRepository;

  final AuthRepository _authRepository;
  IO.Socket? _socket;
  Timer? _reconnectTimer;
  bool _reconnectEnabled = true;
  static const Duration _reconnectDelay = Duration(seconds: 3);
  static const int _reconnectMaxAttempts = 5;
  int _reconnectAttempts = 0;

  final StreamController<IncomingCallPayload> _incomingCallController =
      StreamController<IncomingCallPayload>.broadcast();
  final StreamController<CallAcceptedPayload> _callAcceptedController =
      StreamController<CallAcceptedPayload>.broadcast();
  final StreamController<CallEndedPayload> _callDeclinedController =
      StreamController<CallEndedPayload>.broadcast();
  final StreamController<CallEndedPayload> _callCancelledController =
      StreamController<CallEndedPayload>.broadcast();
  final StreamController<LiveStartedPayload> _liveStartedController =
      StreamController<LiveStartedPayload>.broadcast();
  final StreamController<LiveEndedPayload> _liveEndedController =
      StreamController<LiveEndedPayload>.broadcast();

  Stream<IncomingCallPayload> get incomingCall =>
      _incomingCallController.stream;
  Stream<CallAcceptedPayload> get callAccepted =>
      _callAcceptedController.stream;
  Stream<CallEndedPayload> get callDeclined => _callDeclinedController.stream;
  Stream<CallEndedPayload> get callCancelled => _callCancelledController.stream;
  Stream<LiveStartedPayload> get liveStarted => _liveStartedController.stream;
  Stream<LiveEndedPayload> get liveEnded => _liveEndedController.stream;

  bool get isConnected => _socket?.connected ?? false;

  static void _safeAdd<T>(StreamController<T> c, T value) {
    try {
      if (!c.isClosed) c.add(value);
    } catch (_) {
      // Controller may be closed (e.g. hot restart / dispose)
    }
  }

  static void _safeParseAndAdd<T>(
    StreamController<T> c,
    dynamic data,
    T Function(Map<String, dynamic>) fromMap,
  ) {
    if (data is! Map<String, dynamic>) {
      debugPrint('Signaling: expected Map for event, got ${data.runtimeType}');
      return;
    }
    try {
      final value = fromMap(data);
      _safeAdd(c, value);
    } catch (e, st) {
      debugPrint('Signaling: payload parse error: $e');
      if (kDebugMode) debugPrint('$st');
    }
  }

  void _scheduleReconnect() {
    if (!_reconnectEnabled || _reconnectTimer != null) return;
    if (_reconnectAttempts >= _reconnectMaxAttempts) {
      debugPrint('Signaling: max reconnect attempts reached');
      return;
    }
    _reconnectAttempts++;
    debugPrint('Signaling: reconnecting in ${_reconnectDelay.inSeconds}s (attempt $_reconnectAttempts/$_reconnectMaxAttempts)');
    _reconnectTimer = Timer(_reconnectDelay, () {
      _reconnectTimer = null;
      connect();
    });
  }

  void _cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;
  }

  /// Connect and register with current Firebase ID token.
  /// Call when user is authenticated. Safe to call again if already connected.
  Future<void> connect() async {
    if (_socket?.connected == true) {
      _cancelReconnect();
      return;
    }
    final idToken = await _authRepository.getCurrentIdToken();
    if (idToken == null || idToken.isEmpty) return;

    _reconnectEnabled = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _socket?.dispose();
    _socket = IO.io(
      AppConfig.signalingUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) {
      debugPrint('Signaling: connected');
      _reconnectAttempts = 0;
      _socket!.emit('register', {'idToken': idToken});
    });

    _socket!.on('registered', (data) {
      final ok = data is Map && data['ok'] == true;
      if (!ok) {
        final err = data is Map ? (data['error'] ?? 'unknown') : 'invalid response';
        debugPrint('Signaling: register failed: $err');
      }
    });

    _socket!.on('incoming_call', (data) {
      _safeParseAndAdd(_incomingCallController, data, IncomingCallPayload.fromMap);
    });
    _socket!.on('call_accepted', (data) {
      _safeParseAndAdd(_callAcceptedController, data, CallAcceptedPayload.fromMap);
    });
    _socket!.on('call_declined', (data) {
      _safeParseAndAdd(_callDeclinedController, data, CallEndedPayload.fromMap);
    });
    _socket!.on('call_cancelled', (data) {
      _safeParseAndAdd(_callCancelledController, data, CallEndedPayload.fromMap);
    });
    _socket!.on('live_started', (data) {
      _safeParseAndAdd(_liveStartedController, data, LiveStartedPayload.fromMap);
    });
    _socket!.on('live_ended', (data) {
      _safeParseAndAdd(_liveEndedController, data, LiveEndedPayload.fromMap);
    });

    _socket!.onDisconnect((_) {
      debugPrint('Signaling: disconnected');
      _scheduleReconnect();
    });
    _socket!.onConnectError((e) => debugPrint('Signaling: connect error $e'));
    _socket!.onError((e) => debugPrint('Signaling: error $e'));

    _socket!.connect();
  }

  void disconnect() {
    _reconnectEnabled = false;
    _cancelReconnect();
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  void dispose() {
    disconnect();
    _incomingCallController.close();
    _callAcceptedController.close();
    _callDeclinedController.close();
    _callCancelledController.close();
    _liveStartedController.close();
    _liveEndedController.close();
  }
}
