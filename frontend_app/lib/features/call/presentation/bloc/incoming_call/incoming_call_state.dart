import 'package:equatable/equatable.dart';
import '../../../domain/entities/call_token_entity.dart';

/// States for the incoming call screen.
abstract class IncomingCallState extends Equatable {
  const IncomingCallState();

  @override
  List<Object?> get props => [];
}

class IncomingCallInitial extends IncomingCallState {
  const IncomingCallInitial();
}

class IncomingCallLoading extends IncomingCallState {
  const IncomingCallLoading();
}

/// Callee accepted; navigate to call screen with [token].
class IncomingCallAccepted extends IncomingCallState {
  final CallTokenEntity token;
  const IncomingCallAccepted(this.token);

  @override
  List<Object?> get props => [token];
}

/// Callee declined; pop.
class IncomingCallDeclined extends IncomingCallState {
  const IncomingCallDeclined();
}

/// Call ended by caller (cancelled).
class IncomingCallEndedByCaller extends IncomingCallState {
  const IncomingCallEndedByCaller();
}

class IncomingCallError extends IncomingCallState {
  final String message;
  const IncomingCallError(this.message);

  @override
  List<Object?> get props => [message];
}
