import 'package:equatable/equatable.dart';

abstract class LiveListenerState extends Equatable {
  const LiveListenerState();

  @override
  List<Object?> get props => [];
}

class LiveListenerInitial extends LiveListenerState {
  const LiveListenerInitial();
}

class LiveListenerJoining extends LiveListenerState {
  const LiveListenerJoining();
}

class LiveListenerConnected extends LiveListenerState {
  const LiveListenerConnected();
}

class LiveListenerHostEnded extends LiveListenerState {
  const LiveListenerHostEnded();
}

class LiveListenerError extends LiveListenerState {
  final String message;
  const LiveListenerError(this.message);

  @override
  List<Object?> get props => [message];
}

class LiveListenerEnded extends LiveListenerState {
  const LiveListenerEnded();
}
