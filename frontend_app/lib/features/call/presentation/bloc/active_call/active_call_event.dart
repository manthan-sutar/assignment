import 'package:equatable/equatable.dart';
import '../../../domain/entities/call_token_entity.dart';

/// Events for the in-call screen (joined Agora channel).
abstract class ActiveCallEvent extends Equatable {
  const ActiveCallEvent();

  @override
  List<Object?> get props => [];
}

/// Join the call with [token]. Emitted when the call screen is shown.
class ActiveCallJoin extends ActiveCallEvent {
  final CallTokenEntity token;
  const ActiveCallJoin(this.token);

  @override
  List<Object?> get props => [token];
}

class ActiveCallMuteToggle extends ActiveCallEvent {
  const ActiveCallMuteToggle();
}

class ActiveCallEnd extends ActiveCallEvent {
  const ActiveCallEnd();
}
