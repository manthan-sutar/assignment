import 'package:equatable/equatable.dart';
import '../../../domain/entities/start_live_entity.dart';

abstract class LiveHostEvent extends Equatable {
  const LiveHostEvent();

  @override
  List<Object?> get props => [];
}

class LiveHostJoinRequested extends LiveHostEvent {
  final StartLiveEntity startData;
  const LiveHostJoinRequested(this.startData);

  @override
  List<Object?> get props => [startData];
}

/// Leave the host screen and Agora channel but keep the stream live (can re-enter via hub).
class LiveHostLeaveRequested extends LiveHostEvent {
  const LiveHostLeaveRequested();
}

/// End the live stream on the server, then leave.
class LiveHostEndRequested extends LiveHostEvent {
  const LiveHostEndRequested();
}
