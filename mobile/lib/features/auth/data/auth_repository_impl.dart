import 'package:controle_ds/core/storage/token_storage.dart';
import 'package:controle_ds/features/auth/data/auth_api.dart';
import 'package:controle_ds/features/auth/domain/auth_repository.dart';
import 'package:controle_ds/features/auth/domain/user.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authRepositoryImplProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(
    api: ref.watch(authApiProvider),
    tokenStorage: ref.watch(tokenStorageProvider),
  ),
);

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl({required this.api, required this.tokenStorage});

  final AuthApi api;
  final TokenStorage tokenStorage;

  @override
  Future<User> login(String email, String password) async {
    final response = await api.login(email: email, password: password);
    return _saveTokensAndParseUser(response);
  }

  @override
  Future<User> register(
    String name,
    String email,
    String password,
    bool acceptedTerms,
  ) async {
    final response = await api.register(
      name: name,
      email: email,
      password: password,
      acceptedTerms: acceptedTerms,
    );
    return _saveTokensAndParseUser(response);
  }

  @override
  Future<User> refresh(String refreshToken) async {
    final response = await api.refresh(refreshToken: refreshToken);
    return _saveTokensAndParseUser(response);
  }

  @override
  Future<void> logout() async {
    final tokens = await tokenStorage.read();
    if (tokens != null) {
      await api.logout(refreshToken: tokens.refreshToken);
    }
  }

  @override
  Future<void> forgotPassword(String email) => api.forgotPassword(email: email);

  @override
  Future<void> resetPassword(String token, String newPassword) =>
      api.resetPassword(token: token, newPassword: newPassword);

  Future<User> _saveTokensAndParseUser(Map<String, Object?> response) async {
    final accessToken = response['access_token'];
    final refreshToken = response['refresh_token'];
    final rawUser = response['user'];
    if (accessToken is! String ||
        refreshToken is! String ||
        rawUser is! Map ||
        rawUser['id'] is! String ||
        rawUser['name'] is! String) {
      throw const FormatException('Resposta de autenticação inválida.');
    }

    final user = User(
      id: rawUser['id'] as String,
      name: rawUser['name'] as String,
    );
    await tokenStorage.save(
      AuthTokens(accessToken: accessToken, refreshToken: refreshToken),
    );
    return user;
  }
}
