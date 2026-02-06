import 'package:equatable/equatable.dart';

import '../../domain/entities/reel_entity.dart';

abstract class ReelsState extends Equatable {
  const ReelsState();

  @override
  List<Object?> get props => [];
}

class ReelsInitial extends ReelsState {
  const ReelsInitial();
}

class ReelsLoading extends ReelsState {
  const ReelsLoading();
}

class ReelsLoaded extends ReelsState {
  const ReelsLoaded(this.reels);

  final List<ReelEntity> reels;

  @override
  List<Object?> get props => [reels];
}

class ReelsError extends ReelsState {
  const ReelsError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
