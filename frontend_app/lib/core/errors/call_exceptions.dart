/// Base exception for call feature.
class CallException implements Exception {
  CallException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'CallException: $message';
}

class CallUnauthorizedException extends CallException {
  CallUnauthorizedException([String message = 'Please sign in again.'])
      : super(message, statusCode: 401);
}

class CallNetworkException extends CallException {
  CallNetworkException(super.message);
}

class CallServerException extends CallException {
  CallServerException(super.message, {super.statusCode});
}
