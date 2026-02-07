import 'package:equatable/equatable.dart';
import '../../../domain/entities/call_token_entity.dart';

/// States for the caller-side ringing flow.
abstract class RingingState extends Equatable {
  const RingingState();

  @override
  List<Object?> get props => [];
}

class RingingInitial extends RingingState {
  const RingingInitial();
}

class RingingCreating extends RingingState {
  const RingingCreating();
}

class RingingWaiting extends RingingState {
  final String callId;
  const RingingWaiting(this.callId);

  @override
  List<Object?> get props => [callId];
}

/// Callee accepted; navigate to call screen with [token].
class RingingAccepted extends RingingState {
  final CallTokenEntity token;
  const RingingAccepted(this.token);

  @override
  List<Object?> get props => [token];
}

/// Call ended (declined, cancelled, or timeout).
class RingingEnded extends RingingState {
  final String status; // 'declined' | 'cancelled' | 'timeout'
  const RingingEnded(this.status);

  @override
  List<Object?> get props => [status];
}

class RingingError extends RingingState {
  final String message;
  const RingingError(this.message);

  @override
  List<Object?> get props => [message];
}
