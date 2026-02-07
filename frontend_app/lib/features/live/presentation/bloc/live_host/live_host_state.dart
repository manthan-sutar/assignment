import 'package:equatable/equatable.dart';

abstract class LiveHostState extends Equatable {
  const LiveHostState();

  @override
  List<Object?> get props => [];
}

class LiveHostInitial extends LiveHostState {
  const LiveHostInitial();
}

class LiveHostJoining extends LiveHostState {
  const LiveHostJoining();
}

class LiveHostLive extends LiveHostState {
  const LiveHostLive();
}

class LiveHostError extends LiveHostState {
  final String message;
  const LiveHostError(this.message);

  @override
  List<Object?> get props => [message];
}

class LiveHostEnded extends LiveHostState {
  const LiveHostEnded();
}
