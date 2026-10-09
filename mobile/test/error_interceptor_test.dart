import 'dart:typed_data';

import 'package:controle_ds/core/errors/app_exception.dart';
import 'package:controle_ds/core/network/error_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps the API error envelope into an ApiException', () async {
    final dio = _dio(
      (options) async => ResponseBody.fromString(
        '''
        {"error":{"code":"VALIDATION_ERROR","message":"Dados inválidos.",
        "details":[{"field":"amount","issue":"must be greater than 0"}],
        "request_id":"req-123"}}
        ''',
        422,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    );

    final exception = await dio
        .get<Object?>('/test')
        .then<Object?>(
          (_) => fail('Expected a DioException'),
          onError: (Object error) => error,
        );

    expect(exception, isA<DioException>());
    final apiException = (exception as DioException).error as ApiException;
    expect(apiException.code, 'VALIDATION_ERROR');
    expect(apiException.statusCode, 422);
    expect(apiException.requestId, 'req-123');
    expect(apiException.details.single['field'], 'amount');
  });

  test('maps connection timeouts into a NetworkException', () async {
    final dio = _dio((options) async {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionTimeout,
      );
    });

    final exception = await dio
        .get<Object?>('/test')
        .then<Object?>(
          (_) => fail('Expected a DioException'),
          onError: (Object error) => error,
        );

    expect(exception, isA<DioException>());
    expect((exception as DioException).error, isA<NetworkException>());
  });
}

Dio _dio(Future<ResponseBody> Function(RequestOptions) respond) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'));
  dio.interceptors.add(ErrorInterceptor());
  dio.httpClientAdapter = _CallbackAdapter(respond);
  return dio;
}

class _CallbackAdapter implements HttpClientAdapter {
  _CallbackAdapter(this.respond);

  final Future<ResponseBody> Function(RequestOptions) respond;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => respond(options);

  @override
  void close({bool force = false}) {}
}
