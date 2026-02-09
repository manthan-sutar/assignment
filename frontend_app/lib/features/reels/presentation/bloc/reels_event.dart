import 'package:equatable/equatable.dart';

abstract class ReelsEvent extends Equatable {
  const ReelsEvent();

  @override
  List<Object?> get props => [];
}

class ReelsLoadRequested extends ReelsEvent {
  const ReelsLoadRequested();
}

class ReelsLoadMoreRequested extends ReelsEvent {
  const ReelsLoadMoreRequested();
}
