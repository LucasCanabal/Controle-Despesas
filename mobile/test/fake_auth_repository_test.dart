import 'package:controle_ds/core/errors/app_exception.dart';
import 'package:controle_ds/core/storage/token_storage.dart';
import 'package:controle_ds/features/auth/data/fake_auth_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _MemoryTokenStorage storage;
  late FakeAuthRepository repository;

  setUp(() {
    storage = _MemoryTokenStorage();
    repository = FakeAuthRepository(tokenStorage: storage);
  });

  test('registers, logs in and restores a fake user', () async {
    final user = await repository.register(
      'Ana Silva',
      'ana@example.com',
      'uma-senha-valida',
      true,
    );
    final loginUser = await repository.login(
      'ANA@example.com',
      'uma-senha-valida',
    );

    expect(loginUser.id, user.id);
    expect(storage.tokens?.accessToken, isNotEmpty);
    final restored = await repository.refresh(storage.tokens!.refreshToken);
    expect(restored.id, user.id);
  });

  test('logs in with the pre-registered test user', () async {
    final user = await repository.login(
      'teste@controleds.com',
      'senha1234567',
    );

    expect(user.name, 'Teste');
    expect(storage.tokens?.accessToken, isNotEmpty);
  });

  test('returns INVALID_CREDENTIALS for invalid login', () async {
    final error = await _capture(
      () => repository.login('missing@example.com', 'uma-senha-valida'),
    );

    expect(error, isA<ApiException>());
    expect((error! as ApiException).code, 'INVALID_CREDENTIALS');
  });

  test('returns EMAIL_ALREADY_REGISTERED case-insensitively', () async {
    await repository.register(
      'Ana Silva',
      'ana@example.com',
      'uma-senha-valida',
      true,
    );
    final error = await _capture(
      () => repository.register(
        'Ana',
        'ANA@example.com',
        'outra-senha-valida',
        true,
      ),
    );

    expect(error, isA<ApiException>());
    expect((error! as ApiException).code, 'EMAIL_ALREADY_REGISTERED');
  });

  test('returns TOO_MANY_ATTEMPTS after five failed logins', () async {
    for (var attempt = 0; attempt < 5; attempt++) {
      await _capture(
        () => repository.login('missing@example.com', 'senha-incorreta'),
      );
    }

    final error = await _capture(
      () => repository.login('missing@example.com', 'senha-incorreta'),
    );

    expect(error, isA<ApiException>());
    expect((error! as ApiException).code, 'TOO_MANY_ATTEMPTS');
  });
}

Future<Object?> _capture(Future<void> Function() action) async {
  try {
    await action();
    return null;
  } on Object catch (error) {
    return error;
  }
}

class _MemoryTokenStorage extends TokenStorage {
  _MemoryTokenStorage() : super(const FlutterSecureStorage());

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
