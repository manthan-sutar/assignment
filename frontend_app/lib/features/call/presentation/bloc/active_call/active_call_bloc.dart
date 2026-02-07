import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/services/agora_rtc_service.dart';
import '../../../data/services/call_permission_service.dart';
import '../../../domain/entities/agora_client_role.dart';
import 'active_call_event.dart';
import 'active_call_state.dart';

/// BLoC for the active call screen: join Agora channel, mute, end.
/// Subscribes to [AgoraRtcService.events] to emit Connected/Error.
class ActiveCallBloc extends Bloc<ActiveCallEvent, ActiveCallState> {
  ActiveCallBloc({
    required AgoraRtcService agora,
    CallPermissionService? permission,
  })  : _agora = agora,
        _permission = permission ?? CallPermissionService(),
        super(const ActiveCallInitial()) {
    _eventSub = _agora.events.listen(_onAgoraEvent);
    on<ActiveCallJoin>(_onJoin);
    on<ActiveCallMuteToggle>(_onMuteToggle);
    on<ActiveCallEnd>(_onEnd);
    on<_ActiveCallJoinSuccess>(_onJoinSuccess);
    on<_ActiveCallJoinError>(_onJoinError);
    on<_ActiveCallRemoteUsersChanged>(_onRemoteUsersChanged);
  }

  final AgoraRtcService _agora;
  final CallPermissionService _permission;
  StreamSubscription<dynamic>? _eventSub;

  void _onAgoraEvent(dynamic event) {
    if (event is AgoraJoinSuccess) {
      debugPrint('[Agora] ActiveCallBloc join success');
      add(const _ActiveCallJoinSuccess());
    } else if (event is AgoraErrorEvent) {
      debugPrint('[Agora] ActiveCallBloc error: ${event.message}');
      add(_ActiveCallJoinError(event.message));
    } else if (event is AgoraRemoteUserJoined || event is AgoraRemoteUserOffline) {
      add(_ActiveCallRemoteUsersChanged(_agora.remoteUids.length));
    }
  }

  Future<void> _onJoin(ActiveCallJoin event, Emitter<ActiveCallState> emit) async {
    emit(const ActiveCallJoining());
    final t = event.token;
    if (t.token.isEmpty || t.appId.isEmpty || t.channelName.isEmpty) {
      emit(const ActiveCallError('Invalid call token (missing token, appId, or channel)'));
      return;
    }
    final granted = await _permission.requestMicrophone();
    if (!granted) {
      emit(const ActiveCallError('Microphone permission required'));
      return;
    }
    try {
      await _agora.initialize(t.appId);
      await _agora.joinChannel(
        token: t.token,
        channelId: t.channelName,
        uid: t.uid,
        role: AgoraClientRole.publisher,
      );
    } catch (e, st) {
      debugPrint('[Agora] ActiveCallBloc join error: $e\n$st');
      final msg = e
          .toString()
          .replaceFirst(RegExp(r'^(Exception|StateError|FormatException):\s*'), '')
          .trim();
      emit(ActiveCallError(msg.isEmpty ? 'Failed to join call' : msg));
    }
  }

  void _onMuteToggle(ActiveCallMuteToggle event, Emitter<ActiveCallState> emit) async {
    final current = state;
    if (current is! ActiveCallConnected) return;
    try {
      final muted = await _agora.toggleMute();
      emit(ActiveCallConnected(
        muted: muted,
        remoteUserCount: current.remoteUserCount,
      ));
    } catch (_) {}
  }

  void _onJoinSuccess(_ActiveCallJoinSuccess event, Emitter<ActiveCallState> emit) {
    emit(const ActiveCallConnected(muted: false, remoteUserCount: 0));
  }

  void _onJoinError(_ActiveCallJoinError event, Emitter<ActiveCallState> emit) {
    emit(ActiveCallError(event.message));
  }

  void _onRemoteUsersChanged(
    _ActiveCallRemoteUsersChanged event,
    Emitter<ActiveCallState> emit,
  ) {
    final current = state;
    if (current is ActiveCallConnected) {
      emit(ActiveCallConnected(
        muted: current.muted,
        remoteUserCount: event.count,
      ));
    }
  }

  Future<void> _onEnd(ActiveCallEnd event, Emitter<ActiveCallState> emit) async {
    await _eventSub?.cancel();
    await _agora.leaveChannel();
    await _agora.dispose();
    emit(const ActiveCallEnded());
  }

  @override
  Future<void> close() {
    _eventSub?.cancel();
    return super.close();
  }
}

/// Internal events (from Agora stream) to update state on main bloc.
class _ActiveCallJoinSuccess extends ActiveCallEvent {
  const _ActiveCallJoinSuccess();
}

class _ActiveCallJoinError extends ActiveCallEvent {
  final String message;
  _ActiveCallJoinError(this.message);

  @override
  List<Object?> get props => [message];
}

class _ActiveCallRemoteUsersChanged extends ActiveCallEvent {
  final int count;
  _ActiveCallRemoteUsersChanged(this.count);

  @override
  List<Object?> get props => [count];
}
