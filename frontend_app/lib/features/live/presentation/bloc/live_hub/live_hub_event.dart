import 'package:equatable/equatable.dart';
import '../../../domain/entities/live_session_entity.dart';

/// Events for the live hub (list sessions, go live, end live, real-time updates).
abstract class LiveHubEvent extends Equatable {
  const LiveHubEvent();

  @override
  List<Object?> get props => [];
}

class LiveHubLoadSessions extends LiveHubEvent {
  const LiveHubLoadSessions();
}

class LiveHubGoLive extends LiveHubEvent {
  const LiveHubGoLive();
}

class LiveHubEndMyLive extends LiveHubEvent {
  const LiveHubEndMyLive();
}

/// Real-time: a host started a live stream (from signaling).
class LiveHubSessionStarted extends LiveHubEvent {
  final LiveSessionEntity session;
  const LiveHubSessionStarted(this.session);

  @override
  List<Object?> get props => [session.sessionId];
}

/// Real-time: a host ended a live stream (from signaling).
class LiveHubSessionEnded extends LiveHubEvent {
  final String sessionId;
  const LiveHubSessionEnded(this.sessionId);

  @override
  List<Object?> get props => [sessionId];
}
