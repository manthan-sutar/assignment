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
  const ReelsLoaded({
    required this.reels,
    this.nextCursor,
    this.isLoadingMore = false,
  });

  final List<ReelEntity> reels;
  final String? nextCursor;
  final bool isLoadingMore;

  bool get hasMore => nextCursor != null && nextCursor!.isNotEmpty;

  @override
  List<Object?> get props => [reels, nextCursor, isLoadingMore];
}

class ReelsError extends ReelsState {
  const ReelsError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
