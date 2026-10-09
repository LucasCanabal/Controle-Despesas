import 'dart:convert';
import 'dart:typed_data';

import 'package:controle_ds/core/config/app_config.dart';
import 'package:controle_ds/features/auth/data/auth_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'uses the authentication contract request bodies and statuses',
    () async {
      final adapter = _RecordingAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'))
        ..httpClientAdapter = adapter;
      final api = AuthApi(dio: dio, termsVersion: AppConfig.termsVersion);

      final loginResponse = await api.login(
        email: 'person@example.com',
        password: 'password-123',
      );
      final registerResponse = await api.register(
        name: 'Person Name',
        email: 'person@example.com',
        password: 'password-123',
        acceptedTerms: true,
      );
      final refreshResponse = await api.refresh(refreshToken: 'refresh-1');
      await api.logout(refreshToken: 'refresh-2');
      await api.forgotPassword(email: 'person@example.com');
      await api.resetPassword(token: 'reset-1', newPassword: 'new-password');

      expect(loginResponse['access_token'], 'access');
      expect(registerResponse['user'], {'id': 'user-1', 'name': 'Person Name'});
      expect(refreshResponse['refresh_token'], 'refresh-2');
      expect(adapter.requests.map((request) => request.path), [
        '/auth/login',
        '/auth/register',
        '/auth/refresh',
        '/auth/logout',
        '/auth/forgot-password',
        '/auth/reset-password',
      ]);
      expect(adapter.requests.map((request) => request.method), [
        'POST',
        'POST',
        'POST',
        'POST',
        'POST',
        'POST',
      ]);
      expect(adapter.requests.map((request) => request.body), [
        {'email': 'person@example.com', 'password': 'password-123'},
        {
          'name': 'Person Name',
          'email': 'person@example.com',
          'password': 'password-123',
          'accepted_terms': true,
          'terms_version': '2026-10',
        },
        {'refresh_token': 'refresh-1'},
        {'refresh_token': 'refresh-2'},
        {'email': 'person@example.com'},
        {'token': 'reset-1', 'new_password': 'new-password'},
      ]);
      expect(adapter.statusCodes, [200, 201, 200, 204, 202, 204]);
      dio.close();
    },
  );
}

class _RecordedRequest {
  const _RecordedRequest({
    required this.method,
    required this.path,
    required this.body,
  });

  final String method;
  final String path;
  final Map<String, Object?>? body;
}

class _RecordingAdapter implements HttpClientAdapter {
  final requests = <_RecordedRequest>[];
  final statusCodes = <int>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = _decodeBody(options.data);
    requests.add(
      _RecordedRequest(method: options.method, path: options.path, body: body),
    );
    final isAuthResponse =
        options.path.endsWith('/auth/login') ||
        options.path.endsWith('/auth/register') ||
        options.path.endsWith('/auth/refresh');
    final statusCode = options.path.endsWith('/auth/register')
        ? 201
        : options.path.endsWith('/auth/forgot-password')
        ? 202
        : options.path.endsWith('/auth/logout') ||
              options.path.endsWith('/auth/reset-password')
        ? 204
        : 200;
    statusCodes.add(statusCode);
    final response = isAuthResponse
        ? {
            'access_token': 'access',
            'refresh_token': options.path.endsWith('/auth/refresh')
                ? 'refresh-2'
                : 'refresh-1',
            'token_type': 'bearer',
            'expires_in': 900,
            'user': {'id': 'user-1', 'name': 'Person Name'},
          }
        : null;
    return ResponseBody.fromString(
      response == null ? '' : jsonEncode(response),
      statusCode,
      headers: isAuthResponse
          ? {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            }
          : null,
    );
  }

  Map<String, Object?>? _decodeBody(Object? data) {
    if (data is Map) {
      return {
        for (final entry in data.entries) entry.key as String: entry.value,
      };
    }
    if (data is String) {
      final decoded = jsonDecode(data);
      if (decoded is Map) {
        return {
          for (final entry in decoded.entries) entry.key as String: entry.value,
        };
      }
    }
    return null;
  }

  @override
  void close({bool force = false}) {}
}
