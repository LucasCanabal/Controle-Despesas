sealed class AppException implements Exception {
  const AppException();
}

final class ApiException extends AppException {
  const ApiException({
    required this.code,
    required this.message,
    required this.statusCode,
    this.details = const [],
    this.requestId,
  });

  final String code;
  final String message;
  final int? statusCode;
  final List<Map<String, Object?>> details;
  final String? requestId;

  @override
  String toString() => 'ApiException($code, $statusCode): $message';
}

final class NetworkException extends AppException {
  const NetworkException(this.message);

  final String message;

  @override
  String toString() => 'NetworkException: $message';
}

final class UnauthorizedException extends AppException {
  const UnauthorizedException([
    this.message = 'Sua sessão expirou. Entre novamente.',
  ]);

  final String message;

  @override
  String toString() => 'UnauthorizedException: $message';
}
