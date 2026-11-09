/// Base exception for application errors.
///
/// Service layers throw these so providers and UI can present consistent
/// error messages to the user.
abstract class AppException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic originalError;

  const AppException(this.message, {this.statusCode, this.originalError});

  @override
  String toString() =>
      'AppException: $message${statusCode != null ? ' (status $statusCode)' : ''}';
}

/// Thrown when the request could not be authenticated or authorized.
class AuthException extends AppException {
  const AuthException(super.message, {super.statusCode, super.originalError});
}

/// Thrown when the requested resource is not found.
class NotFoundException extends AppException {
  const NotFoundException(super.message, {super.statusCode, super.originalError});
}

/// Thrown when the backend returns a validation error.
class ValidationException extends AppException {
  final Map<String, List<String>>? fieldErrors;

  const ValidationException(super.message,
      {this.fieldErrors, super.statusCode, super.originalError});
}

/// Thrown when the network is unavailable or the request fails.
class NetworkException extends AppException {
  const NetworkException(super.message, {super.statusCode, super.originalError});
}
