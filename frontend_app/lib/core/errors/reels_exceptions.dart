/**
 * Reels Exceptions
 * Used by reels data layer; presentation layer maps to user-facing messages.
 */
class ReelsException implements Exception {
  final String message;
  final int? statusCode;

  ReelsException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ReelsNetworkException extends ReelsException {
  ReelsNetworkException(String message) : super(message);
}

class ReelsUnauthorizedException extends ReelsException {
  ReelsUnauthorizedException([String message = 'Please sign in again'])
      : super(message, statusCode: 401);
}

class ReelsServerException extends ReelsException {
  ReelsServerException([String message = 'Server error. Try again later.'])
      : super(message);
}
