import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/reels_repository.dart';
import '../../../../core/errors/reels_exceptions.dart';
import 'reels_event.dart';
import 'reels_state.dart';

class ReelsBloc extends Bloc<ReelsEvent, ReelsState> {
  ReelsBloc({required ReelsRepository reelsRepository})
      : _reelsRepository = reelsRepository,
        super(const ReelsInitial()) {
    on<ReelsLoadRequested>(_onLoadRequested);
    on<ReelsLoadMoreRequested>(_onLoadMoreRequested);
  }

  final ReelsRepository _reelsRepository;

  Future<void> _onLoadRequested(
    ReelsLoadRequested event,
    Emitter<ReelsState> emit,
  ) async {
    emit(const ReelsLoading());
    try {
      final result = await _reelsRepository.getReels();
      emit(ReelsLoaded(
        reels: result.reels,
        nextCursor: result.nextCursor,
      ));
    } on ReelsUnauthorizedException {
      emit(const ReelsError('Please sign in again.'));
    } on ReelsNetworkException catch (e) {
      emit(ReelsError(e.message));
    } on ReelsServerException catch (e) {
      emit(ReelsError(e.message));
    } on ReelsException catch (e) {
      emit(ReelsError(e.message));
    } catch (e) {
      emit(const ReelsError('Something went wrong. Try again.'));
    }
  }

  Future<void> _onLoadMoreRequested(
    ReelsLoadMoreRequested event,
    Emitter<ReelsState> emit,
  ) async {
    final current = state;
    if (current is! ReelsLoaded || !current.hasMore || current.isLoadingMore) {
      return;
    }
    emit(ReelsLoaded(
      reels: current.reels,
      nextCursor: current.nextCursor,
      isLoadingMore: true,
    ));
    try {
      final result = await _reelsRepository.getReels(
        cursor: current.nextCursor,
      );
      final merged = List<dynamic>.from(current.reels)..addAll(result.reels);
      emit(ReelsLoaded(
        reels: merged.cast(),
        nextCursor: result.nextCursor,
      ));
    } on ReelsUnauthorizedException {
      emit(current);
      emit(const ReelsError('Please sign in again.'));
    } on ReelsNetworkException catch (e) {
      emit(current);
      emit(ReelsError(e.message));
    } on ReelsServerException catch (e) {
      emit(current);
      emit(ReelsError(e.message));
    } on ReelsException catch (e) {
      emit(current);
      emit(ReelsError(e.message));
    } catch (e) {
      emit(current);
      emit(const ReelsError('Something went wrong. Try again.'));
    }
  }
}
