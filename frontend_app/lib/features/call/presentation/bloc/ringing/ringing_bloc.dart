import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../core/errors/call_exceptions.dart';
import '../../../domain/repositories/call_repository.dart';
import 'ringing_event.dart';
import 'ringing_state.dart';

/// BLoC for caller-side "ringing" flow: create offer, wait for accept/decline/cancel/timeout.
class RingingBloc extends Bloc<RingingEvent, RingingState> {
  RingingBloc({required CallRepository callRepository})
      : _callRepository = callRepository,
        super(const RingingInitial()) {
    on<RingingCreateOffer>(_onCreateOffer);
    on<RingingCallAccepted>(_onCallAccepted);
    on<RingingCallDeclined>(_onCallDeclined);
    on<RingingCallCancelled>(_onCallCancelled);
    on<RingingTimeout>(_onTimeout);
  }

  final CallRepository _callRepository;

  Future<void> _onCreateOffer(
    RingingCreateOffer event,
    Emitter<RingingState> emit,
  ) async {
    emit(const RingingCreating());
    try {
      final result = await _callRepository.createOffer(event.calleeUserId);
      final callId = result['callId'] as String?;
      if (callId == null || callId.isEmpty) {
        emit(const RingingError('Invalid response'));
        return;
      }
      emit(RingingWaiting(callId));
    } catch (e) {
      emit(RingingError(e is CallException ? e.message : e.toString()));
    }
  }

  Future<void> _onCallAccepted(
    RingingCallAccepted event,
    Emitter<RingingState> emit,
  ) async {
    final current = state;
    if (current is! RingingWaiting) return;
    try {
      final token = await _callRepository.getToken(channelName: event.channelName);
      emit(RingingAccepted(token));
    } catch (e) {
      emit(RingingError(e is CallException ? e.message : e.toString()));
    }
  }

  void _onCallDeclined(RingingCallDeclined event, Emitter<RingingState> emit) {
    emit(const RingingEnded('declined'));
  }

  void _onCallCancelled(RingingCallCancelled event, Emitter<RingingState> emit) {
    emit(const RingingEnded('cancelled'));
  }

  void _onTimeout(RingingTimeout event, Emitter<RingingState> emit) {
    emit(const RingingEnded('timeout'));
  }

  /// Caller cancels the call. Call from UI; then pop.
  Future<void> cancelCall(String callId) async {
    try {
      await _callRepository.cancelOffer(callId);
    } catch (_) {}
  }
}
