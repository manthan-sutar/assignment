import 'package:equatable/equatable.dart';
import '../../../domain/entities/live_session_entity.dart';

abstract class LiveListenerEvent extends Equatable {
  const LiveListenerEvent();

  @override
  List<Object?> get props => [];
}

class LiveListenerJoinRequested extends LiveListenerEvent {
  final LiveSessionEntity session;
  const LiveListenerJoinRequested(this.session);

  @override
  List<Object?> get props => [session.sessionId];
}

class LiveListenerLeaveRequested extends LiveListenerEvent {
  const LiveListenerLeaveRequested();
}

class LiveListenerEndedByHost extends LiveListenerEvent {
  const LiveListenerEndedByHost();
}
