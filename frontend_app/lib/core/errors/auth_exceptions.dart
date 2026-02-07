/**
 * Authentication Exceptions
 * Custom exceptions for auth-related errors
 */
class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}

class SignInException extends AuthException {
  SignInException(String message) : super(message);
}

class SignUpException extends AuthException {
  SignUpException(String message) : super(message);
}

class TokenException extends AuthException {
  TokenException(String message) : super(message);
}

class ProfileUpdateException extends AuthException {
  ProfileUpdateException(String message) : super(message);
}
