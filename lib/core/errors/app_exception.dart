/// Domain and application-level exceptions.
class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic cause;

  const AppException(this.message, {this.code, this.cause});

  @override
  String toString() => 'AppException: $message (code: $code)';
}

class AuthException extends AppException {
  const AuthException(super.message, {super.code, super.cause});
}

class SessionExpiredException extends AuthException {
  const SessionExpiredException([super.message = 'Session has expired'])
      : super(code: 'SESSION_EXPIRED');
}

class PermissionException extends AppException {
  const PermissionException(super.message, {super.code, super.cause});
}
