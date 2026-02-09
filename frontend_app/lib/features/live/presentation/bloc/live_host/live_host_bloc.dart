import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../call/data/services/agora_rtc_service.dart';
import '../../../../call/data/services/call_permission_service.dart';
import '../../../../call/domain/entities/agora_client_role.dart';
import '../../../domain/repositories/live_repository.dart';
import 'live_host_event.dart';
import 'live_host_state.dart';

/// BLoC for live host screen: join Agora as publisher, end live.
class LiveHostBloc extends Bloc<LiveHostEvent, LiveHostState> {
  LiveHostBloc({
    required AgoraRtcService agora,
    required LiveRepository liveRepository,
    CallPermissionService? permission,
  })  : _agora = agora,
        _liveRepository = liveRepository,
        _permission = permission ?? CallPermissionService(),
        super(const LiveHostInitial()) {
    _eventSub = _agora.events.listen(_onAgoraEvent);
    on<LiveHostJoinRequested>(_onJoin);
    on<LiveHostLeaveRequested>(_onLeave);
    on<LiveHostEndRequested>(_onEnd);
    on<_LiveHostJoinSuccess>(_onJoinSuccess);
    on<_LiveHostJoinError>(_onJoinError);
  }

  final AgoraRtcService _agora;
  final LiveRepository _liveRepository;
  final CallPermissionService _permission;
  StreamSubscription<dynamic>? _eventSub;

  void _onAgoraEvent(dynamic event) {
    if (event is AgoraJoinSuccess) {
      add(const _LiveHostJoinSuccess());
    } else if (event is AgoraErrorEvent) {
      add(_LiveHostJoinError(event.message));
    }
  }

  Future<void> _onJoin(
    LiveHostJoinRequested event,
    Emitter<LiveHostState> emit,
  ) async {
    // Avoid duplicate join (e.g. from double-push or double-tap).
    if (state is LiveHostJoining) return;
    emit(const LiveHostJoining());
    final d = event.startData;
    try {
      if (d.appId.isEmpty || d.token.isEmpty || d.channelName.isEmpty) {
        emit(const LiveHostError(
          'Invalid stream config from server. Check backend Agora setup (AGORA_APP_ID, AGORA_APP_CERTIFICATE in .env).',
        ));
        return;
      }
      final granted = await _permission.requestMicrophone();
      if (!granted) {
        emit(const LiveHostError('Microphone permission required'));
        // Best-effort: end live on server so we don't keep a zombie session.
        try {
          await _liveRepository.endLive();
        } catch (_) {}
        return;
      }
      await _agora.initialize(d.appId, useLiveBroadcasting: true);
      await _agora.joinChannel(
        token: d.token,
        channelId: d.channelName,
        uid: d.uid,
        role: AgoraClientRole.publisher,
        useLiveBroadcasting: true,
      );
    } catch (e) {
      debugPrint('[Live] Host join error: $e');
      final msg = e.toString();
      final isRejected = msg.contains('-17') ||
          msg.contains('rejected') ||
          msg.contains('AgoraRtcException');
      emit(LiveHostError(
        isRejected
            ? 'Could not connect to the stream. Check that Agora is configured on the server (AGORA_APP_ID and AGORA_APP_CERTIFICATE in .env).'
            : (msg.length > 120 ? '${msg.substring(0, 120)}…' : msg),
      ));
      // Best-effort: ensure backend live session is cleaned up when join fails.
      try {
        await _liveRepository.endLive();
      } catch (_) {}
    }
  }

  void _onJoinSuccess(_LiveHostJoinSuccess e, Emitter<LiveHostState> emit) {
    emit(const LiveHostLive());
  }

  void _onJoinError(_LiveHostJoinError e, Emitter<LiveHostState> emit) {
    emit(LiveHostError(e.message));
  }

  Future<void> _onLeave(
    LiveHostLeaveRequested event,
    Emitter<LiveHostState> emit,
  ) async {
    await _eventSub?.cancel();
    await _agora.leaveChannel();
    await _agora.dispose();
    emit(const LiveHostEnded());
  }

  Future<void> _onEnd(
    LiveHostEndRequested event,
    Emitter<LiveHostState> emit,
  ) async {
    await _eventSub?.cancel();
    try {
      await _liveRepository.endLive();
    } catch (_) {}
    await _agora.leaveChannel();
    await _agora.dispose();
    emit(const LiveHostEnded());
  }

  /// Mute/unmute (e.g. for lifecycle). Returns new muted state.
  Future<bool> toggleMute() => _agora.toggleMute();

  bool get isMuted => _agora.isMuted;
  bool get isInChannel => _agora.isInChannel;

  @override
  Future<void> close() {
    _eventSub?.cancel();
    return super.close();
  }
}

class _LiveHostJoinSuccess extends LiveHostEvent {
  const _LiveHostJoinSuccess();
}

class _LiveHostJoinError extends LiveHostEvent {
  final String message;
  _LiveHostJoinError(this.message);

  @override
  List<Object?> get props => [message];
}
