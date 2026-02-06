import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';

import '../../domain/entities/agora_client_role.dart';

/// Connection state for the Agora RTC session.
enum AgoraConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  failed,
}

/// Base type for events emitted by [AgoraRtcService].
sealed class AgoraRtcEvent {
  const AgoraRtcEvent._();
}

class AgoraJoinSuccess extends AgoraRtcEvent {
  const AgoraJoinSuccess({
    required this.uid,
    required this.channelId,
    required this.elapsed,
  }) : super._();
  final int uid;
  final String channelId;
  final int elapsed;
}

class AgoraLeave extends AgoraRtcEvent {
  const AgoraLeave({required this.uid, required this.channelId}) : super._();
  final int uid;
  final String channelId;
}

class AgoraRemoteUserJoined extends AgoraRtcEvent {
  const AgoraRemoteUserJoined(this.remoteUid) : super._();
  final int remoteUid;
}

class AgoraRemoteUserOffline extends AgoraRtcEvent {
  const AgoraRemoteUserOffline(this.remoteUid, this.reason) : super._();
  final int remoteUid;
  final UserOfflineReasonType reason;
}

class AgoraConnectionStateChanged extends AgoraRtcEvent {
  const AgoraConnectionStateChanged(this.state, [this.reason]) : super._();
  final AgoraConnectionState state;
  final String? reason;
}

class AgoraTokenPrivilegeWillExpire extends AgoraRtcEvent {
  const AgoraTokenPrivilegeWillExpire() : super._();
}

class AgoraErrorEvent extends AgoraRtcEvent {
  const AgoraErrorEvent(this.message, [this.code]) : super._();
  final String message;
  final int? code;
}

/// Reusable wrapper around Agora RtcEngine for calling and live audio streaming.
/// Create one per app/session; call [initialize], then [joinChannel]; [leaveChannel] and [dispose] when done.
class AgoraRtcService {
  AgoraRtcService();

  RtcEngine? _engine;
  final StreamController<AgoraRtcEvent> _eventController =
      StreamController<AgoraRtcEvent>.broadcast();
  bool _disposed = false;

  /// Stream of Agora events (join success, remote users, connection state, errors).
  Stream<AgoraRtcEvent> get events => _eventController.stream;

  /// Current connection state.
  AgoraConnectionState get connectionState => _connectionState;
  AgoraConnectionState _connectionState = AgoraConnectionState.disconnected;

  /// Uids of remote users currently in the channel.
  Set<int> get remoteUids => Set<int>.from(_remoteUids);
  final Set<int> _remoteUids = {};

  /// Whether the local microphone is muted.
  bool get isMuted => _isMuted;
  bool _isMuted = false;

  /// Whether we are in a channel (joined and not yet left).
  bool get isInChannel =>
      _engine != null && _connectionState == AgoraConnectionState.connected;

  /// Initialize the RTC engine with [appId]. Call once before [joinChannel].
  Future<void> initialize(String appId) async {
    if (_disposed) return;
    if (_engine != null) {
      debugPrint('AgoraRtcService: already initialized');
      return;
    }

    _engine = createAgoraRtcEngine();
    await _engine!.initialize(
      RtcEngineContext(
        appId: appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ),
    );

    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          if (_disposed) return;
          _connectionState = AgoraConnectionState.connected;
          _eventController.add(
            AgoraJoinSuccess(
              uid: connection.localUid ?? 0,
              channelId: connection.channelId ?? '',
              elapsed: elapsed,
            ),
          );
          _eventController.add(
            AgoraConnectionStateChanged(AgoraConnectionState.connected),
          );
        },
        onLeaveChannel: (RtcConnection connection, RtcStats stats) {
          if (_disposed) return;
          _connectionState = AgoraConnectionState.disconnected;
          _remoteUids.clear();
          _eventController.add(
            AgoraLeave(
              uid: connection.localUid ?? 0,
              channelId: connection.channelId ?? '',
            ),
          );
          _eventController.add(
            AgoraConnectionStateChanged(AgoraConnectionState.disconnected),
          );
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          if (_disposed) return;
          _remoteUids.add(remoteUid);
          _eventController.add(AgoraRemoteUserJoined(remoteUid));
        },
        onUserOffline:
            (
              RtcConnection connection,
              int remoteUid,
              UserOfflineReasonType reason,
            ) {
              if (_disposed) return;
              _remoteUids.remove(remoteUid);
              _eventController.add(AgoraRemoteUserOffline(remoteUid, reason));
            },
        onConnectionStateChanged:
            (
              RtcConnection connection,
              ConnectionStateType state,
              ConnectionChangedReasonType reason,
            ) {
              if (_disposed) return;
              switch (state) {
                case ConnectionStateType.connectionStateDisconnected:
                  _connectionState = AgoraConnectionState.disconnected;
                  break;
                case ConnectionStateType.connectionStateConnecting:
                  _connectionState = AgoraConnectionState.connecting;
                  break;
                case ConnectionStateType.connectionStateConnected:
                  _connectionState = AgoraConnectionState.connected;
                  break;
                case ConnectionStateType.connectionStateReconnecting:
                  _connectionState = AgoraConnectionState.reconnecting;
                  break;
                case ConnectionStateType.connectionStateFailed:
                  _connectionState = AgoraConnectionState.failed;
                  break;
              }
              _eventController.add(
                AgoraConnectionStateChanged(
                  _connectionState,
                  reason.toString(),
                ),
              );
            },
        onTokenPrivilegeWillExpire: (RtcConnection connection, String token) {
          if (_disposed) return;
          _eventController.add(const AgoraTokenPrivilegeWillExpire());
        },
        onError: (ErrorCodeType err, String msg) {
          if (_disposed) return;
          _eventController.add(AgoraErrorEvent(msg, err.index));
        },
      ),
    );
  }

  /// Join channel with [token], [channelId], and [uid]. [role] sets publish vs subscribe.
  Future<void> joinChannel({
    required String token,
    required String channelId,
    required int uid,
    AgoraClientRole role = AgoraClientRole.publisher,
  }) async {
    if (_disposed || _engine == null) {
      throw StateError('AgoraRtcService: initialize first');
    }

    _connectionState = AgoraConnectionState.connecting;
    _eventController.add(
      const AgoraConnectionStateChanged(AgoraConnectionState.connecting),
    );

    final clientRole = role == AgoraClientRole.publisher
        ? ClientRoleType.clientRoleBroadcaster
        : ClientRoleType.clientRoleAudience;

    await _engine!.setClientRole(role: clientRole);
    await _engine!.joinChannel(
      token: token,
      channelId: channelId,
      uid: uid,
      options: ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileCommunication,
        clientRoleType: clientRole,
        publishMicrophoneTrack: role == AgoraClientRole.publisher,
        autoSubscribeAudio: true,
      ),
    );
  }

  /// Leave the current channel.
  Future<void> leaveChannel() async {
    if (_engine == null) return;
    await _engine!.leaveChannel();
  }

  /// Mute or unmute local audio. Only applies when role is publisher.
  Future<void> muteLocalAudio(bool mute) async {
    if (_engine == null) return;
    await _engine!.muteLocalAudioStream(mute);
    _isMuted = mute;
  }

  /// Toggle mute state. Returns new mute state.
  Future<bool> toggleMute() async {
    _isMuted = !_isMuted;
    await muteLocalAudio(_isMuted);
    return _isMuted;
  }

  /// Renew token (e.g. after [AgoraTokenPrivilegeWillExpire]).
  Future<void> renewToken(String newToken) async {
    if (_engine == null) return;
    await _engine!.renewToken(newToken);
  }

  /// Release the engine. Call when done (e.g. after leaving channel).
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _engine?.leaveChannel();
    await _engine?.release();
    _engine = null;
    _remoteUids.clear();
    _connectionState = AgoraConnectionState.disconnected;
    await _eventController.close();
  }
}
