import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:controle_ds/core/errors/app_exception.dart';
import 'package:controle_ds/core/network/auth_interceptor.dart';
import 'package:controle_ds/core/network/error_interceptor.dart';
import 'package:controle_ds/core/session/session_events.dart';
import 'package:controle_ds/core/storage/token_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('injects the bearer access token', () async {
    final storage = _MemoryTokenStorage(
      const AuthTokens(accessToken: 'access-1', refreshToken: 'refresh-1'),
    );
    late RequestOptions observed;
    final dio = _client(
      storage: storage,
      respond: (options) async {
        observed = options;
        return _jsonResponse({'ok': true}, 200);
      },
    );

    await dio.get<Object?>('/private');

    expect(observed.headers['Authorization'], 'Bearer access-1');
    dio.close();
  });

  test('refreshes once after 401 and retries the original request', () async {
    final storage = _MemoryTokenStorage(
      const AuthTokens(accessToken: 'old-access', refreshToken: 'old-refresh'),
    );
    var refreshCalls = 0;
    var originalCalls = 0;
    final dio = _client(
      storage: storage,
      respond: (options) async {
        if (options.path.endsWith('/auth/refresh')) {
          refreshCalls++;
          return _jsonResponse({
            'access_token': 'new-access',
            'refresh_token': 'new-refresh',
          }, 200);
        }
        originalCalls++;
        if (options.headers['Authorization'] == 'Bearer old-access') {
          return _jsonResponse({
            'error': {'code': 'TOKEN_EXPIRED'},
          }, 401);
        }
        return _jsonResponse({'ok': true}, 200);
      },
    );

    final response = await dio.get<Map<String, Object?>>('/private');

    expect(response.data, {'ok': true});
    expect(refreshCalls, 1);
    expect(originalCalls, 2);
    expect(storage.tokens?.accessToken, 'new-access');
    dio.close();
  });

  test('clears tokens and signals session expiry when refresh fails', () async {
    final storage = _MemoryTokenStorage(
      const AuthTokens(accessToken: 'old-access', refreshToken: 'bad-refresh'),
    );
    var expiredSignals = 0;
    final dio = _client(
      storage: storage,
      onSessionExpired: () => expiredSignals++,
      respond: (options) async {
        if (options.path.endsWith('/auth/refresh')) {
          return _jsonResponse({
            'error': {'code': 'TOKEN_REUSED'},
          }, 401);
        }
        return _jsonResponse({
          'error': {'code': 'TOKEN_EXPIRED'},
        }, 401);
      },
    );

    final error = await dio
        .get<Object?>('/private')
        .then<Object?>(
          (_) => fail('Expected an authentication failure'),
          onError: (Object error) => error,
        );

    expect(error, isA<DioException>());
    expect((error as DioException).error, isA<UnauthorizedException>());
    expect(storage.tokens, isNull);
    expect(expiredSignals, 1);
    dio.close();
  });

  test(
    'expires the session if the retried request still returns 401',
    () async {
      final storage = _MemoryTokenStorage(
        const AuthTokens(
          accessToken: 'old-access',
          refreshToken: 'old-refresh',
        ),
      );
      var expiredSignals = 0;
      final dio = _client(
        storage: storage,
        onSessionExpired: () => expiredSignals++,
        respond: (options) async {
          if (options.path.endsWith('/auth/refresh')) {
            return _jsonResponse({
              'access_token': 'new-access',
              'refresh_token': 'new-refresh',
            }, 200);
          }
          return _jsonResponse({
            'error': {'code': 'TOKEN_EXPIRED'},
          }, 401);
        },
      );

      final error = await dio
          .get<Object?>('/private')
          .then<Object?>(
            (_) => fail('Expected an authentication failure'),
            onError: (Object error) => error,
          );

      expect(error, isA<DioException>());
      expect((error as DioException).error, isA<UnauthorizedException>());
      expect(storage.tokens, isNull);
      expect(expiredSignals, 1);
      dio.close();
    },
  );

  test('uses one refresh for simultaneous 401 responses', () async {
    final storage = _MemoryTokenStorage(
      const AuthTokens(accessToken: 'old-access', refreshToken: 'old-refresh'),
    );
    final refreshStarted = Completer<void>();
    final releaseRefresh = Completer<void>();
    var refreshCalls = 0;
    final dio = _client(
      storage: storage,
      respond: (options) async {
        if (options.path.endsWith('/auth/refresh')) {
          refreshCalls++;
          refreshStarted.complete();
          await releaseRefresh.future;
          return _jsonResponse({
            'access_token': 'new-access',
            'refresh_token': 'new-refresh',
          }, 200);
        }
        if (options.headers['Authorization'] == 'Bearer old-access') {
          return _jsonResponse({
            'error': {'code': 'TOKEN_EXPIRED'},
          }, 401);
        }
        return _jsonResponse({'ok': true}, 200);
      },
    );

    final first = dio.get<Object?>('/private/first');
    final second = dio.get<Object?>('/private/second');
    await refreshStarted.future;
    await Future<void>.delayed(Duration.zero);
    releaseRefresh.complete();
    await Future.wait([first, second]);

    expect(refreshCalls, 1);
    dio.close();
  });

  test('session expiration notifier can be signaled and reset', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(sessionExpiredProvider), isFalse);
    container.read(sessionExpiredProvider.notifier).expire();
    expect(container.read(sessionExpiredProvider), isTrue);
    container.read(sessionExpiredProvider.notifier).reset();
    expect(container.read(sessionExpiredProvider), isFalse);
  });
}

Dio _client({
  required _MemoryTokenStorage storage,
  required Future<ResponseBody> Function(RequestOptions) respond,
  void Function()? onSessionExpired,
}) {
  final client = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'));
  final refreshDio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'))
    ..httpClientAdapter = _CallbackAdapter(respond);
  client.interceptors.addAll([
    AuthInterceptor(
      client: client,
      refreshDio: refreshDio,
      tokenStorage: storage,
      onSessionExpired: onSessionExpired ?? () {},
    ),
    ErrorInterceptor(),
  ]);
  client.httpClientAdapter = _CallbackAdapter(respond);
  return client;
}

ResponseBody _jsonResponse(Object? body, int statusCode) =>
    ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

class _MemoryTokenStorage extends TokenStorage {
  _MemoryTokenStorage(this.tokens) : super(const FlutterSecureStorage());

  AuthTokens? tokens;

  @override
  Future<AuthTokens?> read() async => tokens;

  @override
  Future<void> save(AuthTokens tokens) async {
    this.tokens = tokens;
  }

  @override
  Future<void> clear() async {
    tokens = null;
  }
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
