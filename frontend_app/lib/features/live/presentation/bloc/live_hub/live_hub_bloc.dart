import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/live_session_entity.dart';
import '../../../domain/repositories/live_repository.dart';
import 'live_hub_event.dart';
import 'live_hub_state.dart';

/// BLoC for the live hub: load sessions, go live, end live, real-time session updates.
class LiveHubBloc extends Bloc<LiveHubEvent, LiveHubState> {
  LiveHubBloc({required LiveRepository liveRepository})
    : _repo = liveRepository,
      super(const LiveHubInitial()) {
    on<LiveHubLoadSessions>(_onLoadSessions);
    on<LiveHubGoLive>(_onGoLive);
    on<LiveHubReenterHost>(_onReenterHost);
    on<LiveHubEndMyLive>(_onEndMyLive);
    on<LiveHubSessionStarted>(_onSessionStarted);
    on<LiveHubSessionEnded>(_onSessionEnded);
  }

  final LiveRepository _repo;

  static List<LiveSessionEntity> _deduplicateBySessionId(
    List<LiveSessionEntity> list,
  ) {
    final seen = <String>{};
    return list.where((s) => seen.add(s.sessionId)).toList();
  }

  Future<void> _onLoadSessions(
    LiveHubLoadSessions event,
    Emitter<LiveHubState> emit,
  ) async {
    emit(const LiveHubLoading());
    try {
      final list = await _repo.getSessions();
      emit(LiveHubLoaded(_deduplicateBySessionId(list)));
    } catch (e) {
      emit(LiveHubError(e.toString()));
    }
  }

  Future<void> _onGoLive(
    LiveHubGoLive event,
    Emitter<LiveHubState> emit,
  ) async {
    final current = state;
    if (current is LiveHubLoaded && current.endingLive) return;
    emit(const LiveHubLoading());
    try {
      final startData = await _repo.startLive();
      emit(LiveHubStartSuccess(startData));
    } catch (e) {
      final msg = e
          .toString()
          .replaceFirst(RegExp(r'^(Exception|CallException):\s*'), '')
          .trim();
      emit(LiveHubError(msg.isEmpty ? 'Failed to start live' : msg));
    }
  }

  Future<void> _onReenterHost(
    LiveHubReenterHost event,
    Emitter<LiveHubState> emit,
  ) async {
    final current = state;
    if (current is LiveHubLoaded && current.endingLive) return;
    emit(const LiveHubLoading());
    try {
      final startData = await _repo.getHostToken();
      if (startData != null) {
        emit(LiveHubStartSuccess(startData));
      } else {
        emit(const LiveHubError('Stream ended or not found'));
        add(const LiveHubLoadSessions());
      }
    } catch (e) {
      final msg = e
          .toString()
          .replaceFirst(RegExp(r'^(Exception|CallException):\s*'), '')
          .trim();
      emit(LiveHubError(msg.isEmpty ? 'Could not re-enter stream' : msg));
      add(const LiveHubLoadSessions());
    }
  }

  Future<void> _onEndMyLive(
    LiveHubEndMyLive event,
    Emitter<LiveHubState> emit,
  ) async {
    final current = state;
    if (current is! LiveHubLoaded) return;
    emit(LiveHubLoaded(current.sessions, endingLive: true));
    try {
      await _repo.endLive();
      add(const LiveHubLoadSessions());
    } catch (e) {
      final msg = e.toString().toLowerCase();
      final alreadyEnded =
          msg.contains('not live') ||
          msg.contains('already') ||
          msg.contains('400');
      if (alreadyEnded) {
        add(const LiveHubLoadSessions());
      } else {
        emit(LiveHubLoaded(current.sessions, endingLive: false));
        emit(LiveHubError(e.toString()));
      }
    }
  }

  void _onSessionStarted(
    LiveHubSessionStarted event,
    Emitter<LiveHubState> emit,
  ) {
    final current = state;
    if (current is! LiveHubLoaded) return;
    if (current.sessions.any((s) => s.sessionId == event.session.sessionId)) {
      return;
    }
    emit(
      LiveHubLoaded(
        List.from(current.sessions)..add(event.session),
        endingLive: current.endingLive,
      ),
    );
  }

  void _onSessionEnded(LiveHubSessionEnded event, Emitter<LiveHubState> emit) {
    final current = state;
    if (current is! LiveHubLoaded) return;
    emit(
      LiveHubLoaded(
        current.sessions.where((s) => s.sessionId != event.sessionId).toList(),
        endingLive: false,
      ),
    );
  }
}
