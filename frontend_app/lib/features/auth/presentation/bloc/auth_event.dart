import 'package:equatable/equatable.dart';

/**
 * Auth Events
 * Events that trigger state changes in AuthBloc
 */
abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Send OTP to phone number requested
class SendOTPRequested extends AuthEvent {
  final String phoneNumber;
  const SendOTPRequested(this.phoneNumber);

  @override
  List<Object?> get props => [phoneNumber];
}

/// Verify OTP and sign in requested
class VerifyOTPRequested extends AuthEvent {
  final String verificationId;
  final String otp;
  const VerifyOTPRequested(this.verificationId, this.otp);

  @override
  List<Object?> get props => [verificationId, otp];
}

/// Sign up with phone number requested (with consent)
class SignUpWithPhoneRequested extends AuthEvent {
  final bool consent;
  const SignUpWithPhoneRequested(this.consent);

  @override
  List<Object?> get props => [consent];
}

/// Sign out requested
class SignOutRequested extends AuthEvent {
  const SignOutRequested();
}

/// Check authentication status
class CheckAuthStatus extends AuthEvent {
  const CheckAuthStatus();
}

/// Update profile (onboarding: name and optional photo)
class ProfileUpdateRequested extends AuthEvent {
  final String displayName;
  final String? photoPath;
  const ProfileUpdateRequested(this.displayName, {this.photoPath});

  @override
  List<Object?> get props => [displayName, photoPath];
}
