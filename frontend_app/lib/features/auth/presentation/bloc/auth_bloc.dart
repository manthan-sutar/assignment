import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

/**
 * Auth BLoC
 * Manages authentication state and business logic.
 * Handles sign in, sign up, sign out, and auth status checks.
 * Errors are normalized to user-friendly messages.
 */
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({required AuthRepository authRepository})
    : _authRepository = authRepository,
      super(const AuthInitial()) {
    on<SendOTPRequested>(_onSendOTP);
    on<VerifyOTPRequested>(_onVerifyOTP);
    on<SignUpWithPhoneRequested>(_onSignUpWithPhone);
    on<ProfileUpdateRequested>(_onProfileUpdate);
    on<SignOutRequested>(_onSignOut);
    on<CheckAuthStatus>(_onCheckAuthStatus);
  }

  final AuthRepository _authRepository;

  static String _userFriendlyMessage(Object e) {
    final msg = e
        .toString()
        .replaceFirst(
          RegExp(
            r'^(Exception|AuthException|SignInException|SignUpException|TokenException|ProfileUpdateException):\s*',
          ),
          '',
        )
        .trim();
    if (msg.isEmpty) return 'Something went wrong. Please try again.';
    if (msg.toLowerCase().contains('network') ||
        msg.toLowerCase().contains('socket')) {
      return 'Network error. Check your connection and try again.';
    }
    if (msg.toLowerCase().contains('too many requests') ||
        msg.toLowerCase().contains('quota')) {
      return 'Too many attempts. Please try again later.';
    }
    return msg;
  }

  /// Handle send OTP
  Future<void> _onSendOTP(
    SendOTPRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final verificationId = await _authRepository.sendOTP(event.phoneNumber);
      emit(OTPSent(verificationId, event.phoneNumber));
    } catch (e) {
      emit(AuthError(_userFriendlyMessage(e)));
    }
  }

  /// Handle verify OTP and sign in
  Future<void> _onVerifyOTP(
    VerifyOTPRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final user = await _authRepository.verifyOTPAndSignIn(
        event.verificationId,
        event.otp,
      );
      if (user != null) {
        emit(AuthAuthenticated(user));
      } else {
        // User not found - Firebase user is still signed in (OTP verified)
        // Get Firebase user info for the sign-up dialog
        final firebaseUser = await _authRepository.getFirebaseUserInfo();
        if (firebaseUser != null) {
          emit(
            AuthUserNotFound(
              phoneNumber: firebaseUser['phoneNumber'] ?? '',
              firebaseUid: firebaseUser['uid'] ?? '',
            ),
          );
        } else {
          emit(const AuthUserNotFound(phoneNumber: '', firebaseUid: ''));
        }
      }
    } catch (e) {
      emit(AuthError(_userFriendlyMessage(e)));
    }
  }

  /// Handle sign up with phone
  Future<void> _onSignUpWithPhone(
    SignUpWithPhoneRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final user = await _authRepository.signUpWithPhone(event.consent);
      emit(AuthAuthenticated(user));
    } catch (e) {
      emit(AuthError(_userFriendlyMessage(e)));
    }
  }

  /// Handle profile update (onboarding)
  Future<void> _onProfileUpdate(
    ProfileUpdateRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final user = await _authRepository.updateProfile(
        event.displayName,
        photoPath: event.photoPath,
      );
      emit(AuthAuthenticated(user));
    } catch (e) {
      emit(AuthError(_userFriendlyMessage(e)));
    }
  }

  /// Handle sign out
  Future<void> _onSignOut(
    SignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      await _authRepository.signOut();
      emit(const AuthUnauthenticated());
    } catch (e) {
      emit(AuthError(_userFriendlyMessage(e)));
    }
  }

  /// Check authentication status
  Future<void> _onCheckAuthStatus(
    CheckAuthStatus event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final user = await _authRepository.getCurrentUser();
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
