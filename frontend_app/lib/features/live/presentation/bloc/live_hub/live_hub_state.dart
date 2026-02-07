import 'package:equatable/equatable.dart';
import '../../../domain/entities/live_session_entity.dart';
import '../../../domain/entities/start_live_entity.dart';

/// States for the live hub.
abstract class LiveHubState extends Equatable {
  const LiveHubState();

  @override
  List<Object?> get props => [];
}

class LiveHubInitial extends LiveHubState {
  const LiveHubInitial();
}

class LiveHubLoading extends LiveHubState {
  const LiveHubLoading();
}

class LiveHubLoaded extends LiveHubState {
  final List<LiveSessionEntity> sessions;
  final bool endingLive;
  const LiveHubLoaded(this.sessions, {this.endingLive = false});

  @override
  List<Object?> get props => [sessions, endingLive];
}

/// Go live API succeeded; navigate to host page with [startData].
class LiveHubStartSuccess extends LiveHubState {
  final StartLiveEntity startData;
  const LiveHubStartSuccess(this.startData);

  @override
  List<Object?> get props => [startData];
}

class LiveHubError extends LiveHubState {
  final String message;
  const LiveHubError(this.message);

  @override
  List<Object?> get props => [message];
}
