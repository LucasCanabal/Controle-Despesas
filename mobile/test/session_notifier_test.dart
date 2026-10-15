import 'package:controle_ds/core/storage/token_storage.dart';
import 'package:controle_ds/features/auth/data/fake_auth_repository.dart';
import 'package:controle_ds/features/auth/domain/auth_repository.dart';
import 'package:controle_ds/features/auth/domain/user.dart';
import 'package:controle_ds/features/auth/presentation/session_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('returns unauthenticated when no tokens are stored', () async {
    final storage = _MemoryTokenStorage();
    final repository = _TestAuthRepository();
    final container = _container(storage, repository);
    addTearDown(container.dispose);

    final session = await container.read(sessionNotifierProvider.future);

    expect(session.status, SessionStatus.unauthenticated);
    expect(repository.refreshCalls, 0);
  });

  test('restores authenticated session using refresh token', () async {
    final storage = _MemoryTokenStorage(
      const AuthTokens(accessToken: 'access', refreshToken: 'refresh'),
    );
    final user = const User(id: 'user-1', name: 'Ana');
    final repository = _TestAuthRepository(refreshResult: user);
    final container = _container(storage, repository);
    addTearDown(container.dispose);

    final session = await container.read(sessionNotifierProvider.future);

    expect(session.status, SessionStatus.authenticated);
    expect(session.user?.id, user.id);
    expect(repository.lastRefreshToken, 'refresh');
  });

  test(
    'clears tokens and returns unauthenticated when refresh fails',
    () async {
      final storage = _MemoryTokenStorage(
        const AuthTokens(accessToken: 'access', refreshToken: 'refresh'),
      );
      final repository = _TestAuthRepository(
        refreshError: StateError('expired'),
      );
      final container = _container(storage, repository);
      addTearDown(container.dispose);

      final session = await container.read(sessionNotifierProvider.future);

      expect(session.status, SessionStatus.unauthenticated);
      expect(storage.tokens, isNull);
    },
  );

  test(
    'logout clears local tokens even when repository logout fails',
    () async {
      final storage = _MemoryTokenStorage(
        const AuthTokens(accessToken: 'access', refreshToken: 'refresh'),
      );
      final repository = _TestAuthRepository(
        refreshResult: const User(id: 'user-1', name: 'Ana'),
        logoutError: StateError('API unavailable'),
      );
      final container = _container(storage, repository);
      addTearDown(container.dispose);
      await container.read(sessionNotifierProvider.future);

      await expectLater(
        container.read(sessionNotifierProvider.notifier).logout(),
        throwsA(isA<StateError>()),
      );

      expect(storage.tokens, isNull);
      expect(
        container.read(sessionNotifierProvider).requireValue.status,
        SessionStatus.unauthenticated,
      );
    },
  );
}

ProviderContainer _container(
  _MemoryTokenStorage storage,
  AuthRepository repository,
) => ProviderContainer(
  overrides: [
    tokenStorageProvider.overrideWithValue(storage),
    authRepositoryProvider.overrideWithValue(repository),
  ],
);

class _TestAuthRepository implements AuthRepository {
  _TestAuthRepository({
    this.refreshResult,
    this.refreshError,
    this.logoutError,
  });

  final User? refreshResult;
  final Object? refreshError;
  final Object? logoutError;
  int refreshCalls = 0;
  String? lastRefreshToken;

  @override
  Future<User> refresh(String refreshToken) async {
    refreshCalls++;
    lastRefreshToken = refreshToken;
    if (refreshError != null) {
      throw refreshError!;
    }
    return refreshResult!;
  }

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
  Future<void> logout() async {
    if (logoutError != null) {
      throw logoutError!;
    }
  }

  @override
  Future<void> forgotPassword(String email) async {}

  @override
  Future<void> resetPassword(String token, String newPassword) async {}
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
