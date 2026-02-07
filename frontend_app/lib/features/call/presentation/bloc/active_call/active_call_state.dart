import 'package:equatable/equatable.dart';

/// States for the active call screen (in Agora channel).
abstract class ActiveCallState extends Equatable {
  const ActiveCallState();

  @override
  List<Object?> get props => [];
}

class ActiveCallInitial extends ActiveCallState {
  const ActiveCallInitial();
}

class ActiveCallJoining extends ActiveCallState {
  const ActiveCallJoining();
}

class ActiveCallConnected extends ActiveCallState {
  final bool muted;
  final int remoteUserCount;
  const ActiveCallConnected({this.muted = false, this.remoteUserCount = 0});

  @override
  List<Object?> get props => [muted, remoteUserCount];
}

class ActiveCallError extends ActiveCallState {
  final String message;
  const ActiveCallError(this.message);

  @override
  List<Object?> get props => [message];
}

class ActiveCallEnded extends ActiveCallState {
  const ActiveCallEnded();
}
