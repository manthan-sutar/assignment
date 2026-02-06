import '../entities/user_entity.dart';

/**
 * Auth Repository Interface
 * Defines contract for authentication operations
 * Implementation will be in data layer
 */
abstract class AuthRepository {
  /// Send OTP to phone number
  /// Returns verification ID for OTP verification
  Future<String> sendOTP(String phoneNumber);

  /// Verify OTP and sign in
  /// Returns UserEntity if user exists, or null if user not found
  Future<UserEntity?> verifyOTPAndSignIn(String verificationId, String otp);

  /// Sign up with phone number and consent
  /// Creates new user account after OTP verification
  Future<UserEntity> signUpWithPhone(bool consent);

  /// Get current authenticated user
  Future<UserEntity?> getCurrentUser();

  /// Sign out current user
  Future<void> signOut();

  /// Check if user is authenticated
  Future<bool> isAuthenticated();

  /// Get Firebase user info (for sign-up flow)
  Future<Map<String, String>?> getFirebaseUserInfo();
}
