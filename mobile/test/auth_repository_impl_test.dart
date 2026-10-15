import 'dart:convert';
import 'dart:typed_data';

import 'package:controle_ds/core/config/app_config.dart';
import 'package:controle_ds/core/storage/token_storage.dart';
import 'package:controle_ds/features/auth/data/auth_api.dart';
import 'package:controle_ds/features/auth/data/auth_repository_impl.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('login maps the user and saves access and refresh tokens', () async {
    final storage = _MemoryTokenStorage();
    final repository = _repository(storage, _responses());

    final user = await repository.login('ana@example.com', 'password-123');

    expect(user.id, 'user-1');
    expect(user.name, 'Ana');
    expect(storage.tokens?.accessToken, 'access-1');
    expect(storage.tokens?.refreshToken, 'refresh-1');
  });

  test('register maps the user and saves tokens', () async {
    final adapter = _responses();
    final storage = _MemoryTokenStorage();
    final repository = _repository(storage, adapter);

    final user = await repository.register(
      'Ana',
      'ana@example.com',
      'password-123',
      true,
    );

    expect(user.name, 'Ana');
    expect(storage.tokens?.refreshToken, 'refresh-1');
    expect(adapter.lastRequest?.body?['accepted_terms'], isTrue);
    expect(adapter.lastRequest?.body?['terms_version'], AppConfig.termsVersion);
  });

  test('refresh rotates and saves the returned tokens', () async {
    final storage = _MemoryTokenStorage();
    final repository = _repository(storage, _responses());

    final user = await repository.refresh('refresh-old');

    expect(user.id, 'user-1');
    expect(storage.tokens?.accessToken, 'access-2');
    expect(storage.tokens?.refreshToken, 'refresh-2');
  });

  test('logout sends the stored refresh token', () async {
    final storage = _MemoryTokenStorage(
      const AuthTokens(accessToken: 'access', refreshToken: 'refresh-current'),
    );
    final adapter = _responses();
    final repository = _repository(storage, adapter);

    await repository.logout();

    expect(adapter.lastRequest?.path, '/auth/logout');
    expect(adapter.lastRequest?.body, {'refresh_token': 'refresh-current'});
    expect(storage.tokens?.refreshToken, 'refresh-current');
  });
}

AuthRepositoryImpl _repository(
  _MemoryTokenStorage storage,
  _ResponseAdapter adapter,
) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'))
    ..httpClientAdapter = adapter;
  return AuthRepositoryImpl(
    api: AuthApi(dio: dio, termsVersion: AppConfig.termsVersion),
    tokenStorage: storage,
  );
}

_ResponseAdapter _responses() => _ResponseAdapter();

class _Request {
  const _Request(this.method, this.path, this.body);

  final String method;
  final String path;
  final Map<String, Object?>? body;
}

class _ResponseAdapter implements HttpClientAdapter {
  _Request? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final decodedBody = switch (options.data) {
      Map data => {
        for (final entry in data.entries) entry.key as String: entry.value,
      },
      String data => _decodeJsonMap(data),
      _ => null,
    };
    lastRequest = _Request(options.method, options.path, decodedBody);

    if (options.path.endsWith('/auth/logout')) {
      return ResponseBody.fromString('', 204);
    }
    final tokenSuffix = decodedBody?['refresh_token'] == 'refresh-old'
        ? '2'
        : '1';
    return ResponseBody.fromString(
      jsonEncode({
        'access_token': 'access-$tokenSuffix',
        'refresh_token': 'refresh-$tokenSuffix',
        'token_type': 'bearer',
        'expires_in': 900,
        'user': {'id': 'user-1', 'name': 'Ana'},
      }),
      options.path.endsWith('/auth/register') ? 201 : 200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  Map<String, Object?>? _decodeJsonMap(String source) {
    final value = jsonDecode(source);
    if (value is! Map) {
      return null;
    }
    return {
      for (final entry in value.entries) entry.key as String: entry.value,
    };
  }

  @override
  void close({bool force = false}) {}
}

class _MemoryTokenStorage extends TokenStorage {
  _MemoryTokenStorage([this.tokens]) : super(const FlutterSecureStorage());

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
