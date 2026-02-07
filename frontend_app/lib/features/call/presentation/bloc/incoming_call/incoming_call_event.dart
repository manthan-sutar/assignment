import 'package:equatable/equatable.dart';

/// Events for the incoming call screen (callee: accept or decline).
abstract class IncomingCallEvent extends Equatable {
  const IncomingCallEvent();

  @override
  List<Object?> get props => [];
}

/// User tapped Accept.
class IncomingCallAcceptRequested extends IncomingCallEvent {
  const IncomingCallAcceptRequested();
}

/// User tapped Decline.
class IncomingCallDeclineRequested extends IncomingCallEvent {
  const IncomingCallDeclineRequested();
}

/// Call was cancelled by caller (from signaling).
class IncomingCallCancelled extends IncomingCallEvent {
  const IncomingCallCancelled();
}
