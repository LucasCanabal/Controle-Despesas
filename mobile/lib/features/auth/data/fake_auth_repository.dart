import 'package:controle_ds/core/errors/app_exception.dart';
import 'package:controle_ds/core/storage/token_storage.dart';
import 'package:controle_ds/features/auth/domain/auth_repository.dart';
import 'package:controle_ds/features/auth/domain/user.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  // TODO: switch to authRepositoryImplProvider when backend S04 exists.
  return FakeAuthRepository(tokenStorage: ref.watch(tokenStorageProvider));
});

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({required this.tokenStorage, DateTime Function()? now})
    : _now = now ?? DateTime.now {
    _accounts['teste@controleds.com'] = const _FakeAccount(
      user: User(id: 'fake-user-test', name: 'Teste'),
      password: 'senha1234567',
    );
  }

  static const _attemptWindow = Duration(minutes: 15);
  static const _maxFailedAttempts = 5;

  final TokenStorage tokenStorage;
  final DateTime Function() _now;
  final Map<String, _FakeAccount> _accounts = {};
  final Map<String, List<DateTime>> _failedAttempts = {};

  User? _activeUser;
  String? _activeRefreshToken;
  String? _passwordResetToken;
  int _tokenSequence = 0;

  @override
  Future<User> login(String email, String password) async {
    final normalizedEmail = email.trim().toLowerCase();
    final now = _now();
    final attempts = _failedAttempts.putIfAbsent(normalizedEmail, () => []);
    attempts.removeWhere(
      (attempt) => now.difference(attempt) >= _attemptWindow,
    );
    if (attempts.length >= _maxFailedAttempts) {
      throw const ApiException(
        code: 'TOO_MANY_ATTEMPTS',
        message: 'Muitas tentativas de login.',
        statusCode: 429,
      );
    }

    final account = _accounts[normalizedEmail];
    if (account == null || account.password != password) {
      attempts.add(now);
      throw const ApiException(
        code: 'INVALID_CREDENTIALS',
        message: 'E-mail ou senha inválidos.',
        statusCode: 401,
      );
    }

    attempts.clear();
    _activeUser = account.user;
    await _issueTokens();
    return account.user;
  }

  @override
  Future<User> register(
    String name,
    String email,
    String password,
    bool acceptedTerms,
  ) async {
    if (!acceptedTerms) {
      throw const ApiException(
        code: 'VALIDATION_ERROR',
        message: 'É necessário aceitar os termos.',
        statusCode: 422,
      );
    }

    final normalizedEmail = email.trim().toLowerCase();
    if (_accounts.containsKey(normalizedEmail)) {
      throw const ApiException(
        code: 'EMAIL_ALREADY_REGISTERED',
        message: 'Este e-mail já está cadastrado.',
        statusCode: 409,
      );
    }

    final user = User(id: 'fake-user-${_accounts.length + 1}', name: name);
    _accounts[normalizedEmail] = _FakeAccount(user: user, password: password);
    _activeUser = user;
    await _issueTokens();
    return user;
  }

  @override
  Future<User> refresh(String refreshToken) async {
    if (_activeUser == null || refreshToken != _activeRefreshToken) {
      throw const UnauthorizedException();
    }
    await _issueTokens();
    return _activeUser!;
  }

  @override
  Future<void> logout() async {
    _activeUser = null;
    _activeRefreshToken = null;
  }

  @override
  Future<void> forgotPassword(String email) async {
    _passwordResetToken = 'fake-reset-${email.trim().toLowerCase()}';
  }

  @override
  Future<void> resetPassword(String token, String newPassword) async {
    if (token != _passwordResetToken) {
      throw const ApiException(
        code: 'VALIDATION_ERROR',
        message: 'O link para redefinir a senha é inválido ou expirou.',
        statusCode: 422,
      );
    }

    final email = token.substring('fake-reset-'.length);
    final account = _accounts[email];
    if (account != null) {
      _accounts[email] = _FakeAccount(
        user: account.user,
        password: newPassword,
      );
    }
    _passwordResetToken = null;
  }

  Future<void> _issueTokens() async {
    _tokenSequence++;
    final tokens = AuthTokens(
      accessToken: 'fake-access-$_tokenSequence',
      refreshToken: 'fake-refresh-$_tokenSequence',
    );
    _activeRefreshToken = tokens.refreshToken;
    await tokenStorage.save(tokens);
  }
}

final class _FakeAccount {
  const _FakeAccount({required this.user, required this.password});

  final User user;
  final String password;
}
