import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../core/errors/call_exceptions.dart';
import '../../../data/services/call_permission_service.dart';
import '../../../domain/repositories/call_repository.dart';
import 'incoming_call_event.dart';
import 'incoming_call_state.dart';

/// BLoC for incoming call screen: accept (get token, then navigate) or decline.
class IncomingCallBloc extends Bloc<IncomingCallEvent, IncomingCallState> {
  IncomingCallBloc({
    required String callId,
    required CallRepository callRepository,
  })  : _callId = callId,
        _callRepository = callRepository,
        _permission = CallPermissionService(),
        super(const IncomingCallInitial()) {
    on<IncomingCallAcceptRequested>(_onAccept);
    on<IncomingCallDeclineRequested>(_onDecline);
    on<IncomingCallCancelled>(_onCancelled);
  }

  final String _callId;
  final CallRepository _callRepository;
  final CallPermissionService _permission;

  Future<void> _onAccept(
    IncomingCallAcceptRequested event,
    Emitter<IncomingCallState> emit,
  ) async {
    emit(const IncomingCallLoading());
    final granted = await _permission.requestMicrophone();
    if (!granted) {
      emit(const IncomingCallError('Microphone permission required for the call'));
      return;
    }
    try {
      final token = await _callRepository.acceptOffer(_callId);
      emit(IncomingCallAccepted(token));
    } catch (e) {
      emit(IncomingCallError(e is CallException ? e.message : e.toString()));
    }
  }

  Future<void> _onDecline(
    IncomingCallDeclineRequested event,
    Emitter<IncomingCallState> emit,
  ) async {
    emit(const IncomingCallLoading());
    try {
      await _callRepository.declineOffer(_callId);
      emit(const IncomingCallDeclined());
    } catch (e) {
      emit(IncomingCallError(e is CallException ? e.message : e.toString()));
    }
  }

  void _onCancelled(IncomingCallCancelled event, Emitter<IncomingCallState> emit) {
    emit(const IncomingCallEndedByCaller());
  }
}
