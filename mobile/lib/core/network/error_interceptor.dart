import 'package:controle_ds/core/errors/app_exception.dart';
import 'package:dio/dio.dart';

class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.error is AppException) {
      handler.next(err);
      return;
    }

    final statusCode = err.response?.statusCode;
    final responseError = _structuredError(err.response?.data);
    if (statusCode != null && responseError != null) {
      final code = _stringValue(responseError['code']);
      final message = _stringValue(responseError['message']);
      if (code == null || message == null) {
        handler.next(err);
        return;
      }
      handler.reject(
        DioException(
          requestOptions: err.requestOptions,
          response: err.response,
          type: err.type,
          error: ApiException(
            code: code,
            message: message,
            statusCode: statusCode,
            details: _details(responseError['details']),
            requestId: _stringValue(responseError['request_id']),
          ),
        ),
      );
      return;
    }

    if (_isNetworkFailure(err)) {
      handler.reject(
        DioException(
          requestOptions: err.requestOptions,
          response: err.response,
          type: err.type,
          error: const NetworkException(
            'Não foi possível conectar. Verifique sua conexão e tente novamente.',
          ),
        ),
      );
      return;
    }

    handler.next(err);
  }

  bool _isNetworkFailure(DioException err) =>
      err.type == DioExceptionType.connectionError ||
      err.type == DioExceptionType.connectionTimeout ||
      err.type == DioExceptionType.sendTimeout ||
      err.type == DioExceptionType.receiveTimeout;

  Map<String, Object?>? _structuredError(Object? data) {
    if (data is! Map || data['error'] is! Map) {
      return null;
    }
    return _stringKeyedMap(data['error'] as Map);
  }

  List<Map<String, Object?>> _details(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value.whereType<Map>().map(_stringKeyedMap).toList(growable: false);
  }

  Map<String, Object?> _stringKeyedMap(Map value) => {
    for (final entry in value.entries)
      if (entry.key is String) entry.key as String: entry.value,
  };

  String? _stringValue(Object? value) => value is String ? value : null;
}
