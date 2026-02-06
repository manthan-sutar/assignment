import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

/**
 * Auth BLoC
 * Manages authentication state and business logic
 * Handles sign in, sign up, sign out, and auth status checks
 */
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;

  AuthBloc({required this.authRepository}) : super(const AuthInitial()) {
    on<SendOTPRequested>(_onSendOTP);
    on<VerifyOTPRequested>(_onVerifyOTP);
    on<SignUpWithPhoneRequested>(_onSignUpWithPhone);
    on<SignOutRequested>(_onSignOut);
    on<CheckAuthStatus>(_onCheckAuthStatus);
  }

  /// Handle send OTP
  Future<void> _onSendOTP(
    SendOTPRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final verificationId = await authRepository.sendOTP(event.phoneNumber);
      emit(OTPSent(verificationId, event.phoneNumber));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  /// Handle verify OTP and sign in
  Future<void> _onVerifyOTP(
    VerifyOTPRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final user = await authRepository.verifyOTPAndSignIn(event.verificationId, event.otp);
      if (user != null) {
        emit(AuthAuthenticated(user));
      } else {
        // User not found - Firebase user is still signed in (OTP verified)
        // Get Firebase user info for the sign-up dialog
        final firebaseUser = await authRepository.getFirebaseUserInfo();
        if (firebaseUser != null) {
          emit(AuthUserNotFound(
            phoneNumber: firebaseUser['phoneNumber'] ?? '',
            firebaseUid: firebaseUser['uid'] ?? '',
          ));
        } else {
          emit(const AuthUserNotFound(
            phoneNumber: '',
            firebaseUid: '',
          ));
        }
      }
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  /// Handle sign up with phone
  Future<void> _onSignUpWithPhone(
    SignUpWithPhoneRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final user = await authRepository.signUpWithPhone(event.consent);
      emit(AuthAuthenticated(user));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  /// Handle sign out
  Future<void> _onSignOut(
    SignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      await authRepository.signOut();
      emit(const AuthUnauthenticated());
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  /// Check authentication status
  Future<void> _onCheckAuthStatus(
    CheckAuthStatus event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final user = await authRepository.getCurrentUser();
      if (user != null) {
        emit(AuthAuthenticated(user));
      } else {
        emit(const AuthUnauthenticated());
      }
    } catch (e) {
      emit(const AuthUnauthenticated());
    }
  }
}
