import 'package:equatable/equatable.dart';

/// Events for the caller-side ringing flow (create offer, wait for accept/decline/cancel).
abstract class RingingEvent extends Equatable {
  const RingingEvent();

  @override
  List<Object?> get props => [];
}

/// Start creating a call offer to [calleeUserId].
class RingingCreateOffer extends RingingEvent {
  final String calleeUserId;
  const RingingCreateOffer(this.calleeUserId);

  @override
  List<Object?> get props => [calleeUserId];
}

/// Callee accepted; [channelName] is the Agora channel to join.
class RingingCallAccepted extends RingingEvent {
  final String channelName;
  const RingingCallAccepted(this.channelName);

  @override
  List<Object?> get props => [channelName];
}

/// Callee declined the call.
class RingingCallDeclined extends RingingEvent {
  const RingingCallDeclined();
}

/// Call was cancelled (caller or timeout).
class RingingCallCancelled extends RingingEvent {
  const RingingCallCancelled();
}

/// Ringing timed out (no answer).
class RingingTimeout extends RingingEvent {
  const RingingTimeout();
}
