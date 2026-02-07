import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../call/data/services/agora_rtc_service.dart';
import '../../../../call/data/services/call_permission_service.dart';
import '../../../../call/domain/entities/agora_client_role.dart';
import '../../../../call/domain/repositories/call_repository.dart';
import '../../../domain/entities/live_session_entity.dart';
import 'live_listener_event.dart';
import 'live_listener_state.dart';

/// BLoC for live listener screen: join Agora as subscriber, leave, handle host end.
class LiveListenerBloc extends Bloc<LiveListenerEvent, LiveListenerState> {
  LiveListenerBloc({
    required AgoraRtcService agora,
    required LiveSessionEntity session,
    required CallRepository callRepository,
    CallPermissionService? permission,
  })  : _agora = agora,
        _session = session,
        _callRepository = callRepository,
        _permission = permission ?? CallPermissionService(),
        super(const LiveListenerInitial()) {
    _eventSub = _agora.events.listen(_onAgoraEvent);
    on<LiveListenerJoinRequested>(_onJoin);
    on<LiveListenerLeaveRequested>(_onLeave);
    on<LiveListenerEndedByHost>(_onEndedByHost);
    on<_LiveListenerJoinSuccess>(_onJoinSuccess);
    on<_LiveListenerJoinError>(_onJoinError);
  }

  final AgoraRtcService _agora;
  final LiveSessionEntity _session;
  final CallPermissionService _permission;
  final CallRepository _callRepository;
  StreamSubscription<dynamic>? _eventSub;

  void _onAgoraEvent(dynamic event) {
    if (event is AgoraJoinSuccess) {
      add(const _LiveListenerJoinSuccess());
    } else if (event is AgoraErrorEvent) {
      add(_LiveListenerJoinError(event.message));
    }
  }

  Future<void> _onJoin(
    LiveListenerJoinRequested event,
    Emitter<LiveListenerState> emit,
  ) async {
    emit(const LiveListenerJoining());
    try {
      final granted = await _permission.requestMicrophone();
      if (!granted) {
        emit(const LiveListenerError(
            'Microphone permission required to join'));
        return;
      }
      final tokenEntity = await _callRepository.getToken(
        channelName: _session.channelName,
        role: AgoraClientRole.subscriber,
      );
      final appId = await _callRepository.getAppId();
      await _agora.initialize(appId, useLiveBroadcasting: true);
      await _agora.joinChannel(
        token: tokenEntity.token,
        channelId: tokenEntity.channelName,
        uid: tokenEntity.uid,
        role: AgoraClientRole.subscriber,
        useLiveBroadcasting: true,
      );
    } catch (e) {
      debugPrint('[Live] Listener join error: $e');
      final msg = e
          .toString()
          .replaceFirst(RegExp(r'^(Exception|CallException):\s*'), '')
          .trim();
      emit(LiveListenerError(msg.isEmpty ? 'Failed to join live' : msg));
    }
  }

  void _onJoinSuccess(
      _LiveListenerJoinSuccess e, Emitter<LiveListenerState> emit) {
    emit(const LiveListenerConnected());
  }

  void _onJoinError(_LiveListenerJoinError e, Emitter<LiveListenerState> emit) {
    emit(LiveListenerError(e.message));
  }

  Future<void> _onLeave(
    LiveListenerLeaveRequested event,
    Emitter<LiveListenerState> emit,
  ) async {
    await _eventSub?.cancel();
    await _agora.leaveChannel();
    await _agora.dispose();
    emit(const LiveListenerEnded());
  }

  Future<void> _onEndedByHost(
    LiveListenerEndedByHost event,
    Emitter<LiveListenerState> emit,
  ) async {
    await _eventSub?.cancel();
    await _agora.leaveChannel();
    await _agora.dispose();
    emit(const LiveListenerHostEnded());
  }

  @override
  Future<void> close() {
    _eventSub?.cancel();
    return super.close();
  }
}

class _LiveListenerJoinSuccess extends LiveListenerEvent {
  const _LiveListenerJoinSuccess();
}

class _LiveListenerJoinError extends LiveListenerEvent {
  final String message;
  _LiveListenerJoinError(this.message);

  @override
  List<Object?> get props => [message];
}
