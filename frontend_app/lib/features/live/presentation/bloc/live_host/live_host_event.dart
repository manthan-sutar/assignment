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

class LiveHostEndRequested extends LiveHostEvent {
  const LiveHostEndRequested();
}
