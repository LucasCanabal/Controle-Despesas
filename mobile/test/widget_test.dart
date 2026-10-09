import 'package:controle_ds/app.dart';
import 'package:controle_ds/core/errors/app_exception.dart';
import 'package:controle_ds/core/storage/token_storage.dart';
import 'package:controle_ds/features/auth/data/fake_auth_repository.dart';
import 'package:controle_ds/features/auth/domain/auth_repository.dart';
import 'package:controle_ds/features/auth/domain/user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app restores an unauthenticated session to login', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(_MemoryTokenStorage()),
          authRepositoryProvider.overrideWithValue(_AuthRepository()),
        ],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login-submit')), findsOneWidget);
  });
}

class _AuthRepository implements AuthRepository {
  @override
  Future<User> refresh(String refreshToken) =>
      throw const UnauthorizedException();

  @override
  Future<User> login(String email, String password) =>
      throw UnimplementedError();

  @override
  Future<User> register(
    String name,
    String email,
    String password,
    bool acceptedTerms,
  ) => throw UnimplementedError();

  @override
  Future<void> logout() async {}

  @override
  Future<void> forgotPassword(String email) async {}

  @override
  Future<void> resetPassword(String token, String newPassword) async {}
}

class _MemoryTokenStorage extends TokenStorage {
  _MemoryTokenStorage() : super(const FlutterSecureStorage());

  @override
  Future<AuthTokens?> read() async => null;

  @override
  Future<void> save(AuthTokens tokens) async {}

  @override
  Future<void> clear() async {}
}
