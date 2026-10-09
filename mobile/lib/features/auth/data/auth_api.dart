import 'package:controle_ds/core/config/app_config.dart';
import 'package:controle_ds/core/network/dio_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authApiProvider = Provider<AuthApi>(
  (ref) => AuthApi(
    dio: ref.watch(dioProvider),
    termsVersion: AppConfig.termsVersion,
  ),
);

class AuthApi {
  const AuthApi({required this.dio, required this.termsVersion});

  final Dio dio;
  final String termsVersion;

  Future<Map<String, Object?>> login({
    required String email,
    required String password,
  }) => _postObject('/auth/login', {'email': email, 'password': password});

  Future<Map<String, Object?>> register({
    required String name,
    required String email,
    required String password,
    required bool acceptedTerms,
  }) => _postObject('/auth/register', {
    'name': name,
    'email': email,
    'password': password,
    'accepted_terms': acceptedTerms,
    'terms_version': termsVersion,
  });

  Future<Map<String, Object?>> refresh({required String refreshToken}) =>
      _postObject('/auth/refresh', {'refresh_token': refreshToken});

  Future<void> logout({required String refreshToken}) async {
    await dio.post<void>('/auth/logout', data: {'refresh_token': refreshToken});
  }

  Future<void> forgotPassword({required String email}) async {
    await dio.post<void>('/auth/forgot-password', data: {'email': email});
  }

  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    await dio.post<void>(
      '/auth/reset-password',
      data: {'token': token, 'new_password': newPassword},
    );
  }

  Future<Map<String, Object?>> _postObject(
    String path,
    Map<String, Object?> body,
  ) async {
    final response = await dio.post<Object?>(path, data: body);
    final data = response.data;
    if (data is! Map) {
      throw const FormatException('Resposta de autenticação inválida.');
    }
    final result = <String, Object?>{};
    for (final entry in data.entries) {
      if (entry.key is! String) {
        throw const FormatException(
          'As chaves da resposta de autenticação devem ser strings.',
        );
      }
      result[entry.key as String] = entry.value;
    }
    return result;
  }
}
