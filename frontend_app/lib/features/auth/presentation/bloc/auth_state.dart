import 'package:equatable/equatable.dart';
import '../../domain/entities/user_entity.dart';

/**
 * Auth States
 * Represents different states of authentication
 */
abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// Initial state - app just started
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// Loading state - authentication in progress
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// Authenticated state - user is logged in
class AuthAuthenticated extends AuthState {
  final UserEntity user;
  const AuthAuthenticated(this.user);

  @override
  List<Object?> get props => [user];
}

/// Unauthenticated state - user is not logged in
class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// OTP sent state - OTP has been sent to phone number
class OTPSent extends AuthState {
  final String verificationId;
  final String phoneNumber;
  const OTPSent(this.verificationId, this.phoneNumber);

  @override
  List<Object?> get props => [verificationId, phoneNumber];
}

/// User not found state - user tried to sign in but doesn't exist
/// Shows sign-up prompt with user info
class AuthUserNotFound extends AuthState {
  final String phoneNumber;
  final String firebaseUid;

  const AuthUserNotFound({
    required this.phoneNumber,
    required this.firebaseUid,
  });

  @override
  List<Object?> get props => [phoneNumber, firebaseUid];
}

/// Error state - authentication failed
class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);

  @override
  List<Object?> get props => [message];
}
