import 'dart:async';

import 'package:controle_ds/app.dart';
import 'package:controle_ds/core/errors/app_exception.dart';
import 'package:controle_ds/core/router/app_router.dart';
import 'package:controle_ds/core/storage/token_storage.dart';
import 'package:controle_ds/features/auth/data/fake_auth_repository.dart';
import 'package:controle_ds/features/auth/domain/auth_repository.dart';
import 'package:controle_ds/features/auth/domain/user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  testWidgets('login validates fields locally', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login-submit')), findsOneWidget);
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Informe seu e-mail.'), findsOneWidget);
    expect(
      find.text('A senha deve ter pelo menos 10 caracteres.'),
      findsOneWidget,
    );
  });

  testWidgets('login button is disabled while authentication is loading', (
    tester,
  ) async {
    final repository = _TestAuthRepository();
    final loginCompleter = Completer<User>();
    repository.loginHandler = (_, _) => loginCompleter.future;
    await tester.pumpWidget(_app(repository: repository));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('login-email')),
      'ana@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('login-password')),
      'senha-com-10',
    );
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pump();

    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('login-submit')))
          .onPressed,
      isNull,
    );

    loginCompleter.complete(const User(id: 'user-1', name: 'Ana'));
    await tester.pumpAndSettle();
    expect(find.text('Resumo financeiro'), findsOneWidget);
  });

  testWidgets('login displays the server error mapped by code', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('login-email')),
      'ana@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('login-password')),
      'senha-com-10',
    );
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();

    expect(find.text('E-mail ou senha inválidos.'), findsOneWidget);
  });

  testWidgets('registration requires terms acceptance', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Criar conta'));
    await tester.pumpAndSettle();

    final submit = find.byKey(const Key('register-submit'));
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    await tester.enterText(find.byKey(const Key('register-name')), 'Ana Silva');
    await tester.enterText(
      find.byKey(const Key('register-email')),
      'ana@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('register-password')),
      'senha-com-10',
    );
    await tester.tap(find.byKey(const Key('register-terms')));
    await tester.pump();
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
  });

  testWidgets('registration validates the minimum password length', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Criar conta'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('register-name')), 'Ana Silva');
    await tester.enterText(
      find.byKey(const Key('register-email')),
      'ana@example.com',
    );
    await tester.enterText(find.byKey(const Key('register-password')), 'short');
    await tester.tap(find.byKey(const Key('register-terms')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('register-submit')));
    await tester.pumpAndSettle();

    expect(
      find.text('A senha deve ter pelo menos 10 caracteres.'),
      findsOneWidget,
    );
  });

  testWidgets('forgot password shows the same privacy-preserving message', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Esqueci minha senha'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('forgot-email')),
      'nao-existe@example.com',
    );
    await tester.tap(find.byKey(const Key('forgot-submit')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Se o e-mail estiver cadastrado, você receberá instruções '
        'para redefinir sua senha.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('registered routes apply session redirects without a session', (
    tester,
  ) async {
    final container = _container();
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const App()),
    );
    await tester.pumpAndSettle();

    final router = container.read(routerProvider);
    const routes = {
      '/splash': '/login',
      '/login': '/login',
      '/register': '/register',
      '/forgot-password': '/forgot-password',
      '/reset-password': '/reset-password',
      '/home': '/login',
    };
    for (final entry in routes.entries) {
      router.go(entry.key);
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        entry.value,
        reason: '${entry.key} must resolve correctly without a session',
      );
    }
    container.dispose();
  });
}

Widget _app({_TestAuthRepository? repository}) => ProviderScope(
  overrides: [
    tokenStorageProvider.overrideWithValue(_MemoryTokenStorage()),
    authRepositoryProvider.overrideWithValue(
      repository ?? _TestAuthRepository(),
    ),
  ],
  child: const App(),
);

ProviderContainer _container() => ProviderContainer(
  overrides: [
    tokenStorageProvider.overrideWithValue(_MemoryTokenStorage()),
    authRepositoryProvider.overrideWithValue(_TestAuthRepository()),
  ],
);

class _TestAuthRepository implements AuthRepository {
  Future<User> Function(String email, String password)? loginHandler;

  @override
  Future<User> login(String email, String password) async {
    final handler = loginHandler;
    if (handler != null) {
      return handler(email, password);
    }
    throw const ApiException(
      code: 'INVALID_CREDENTIALS',
      message: 'Invalid credentials',
      statusCode: 401,
    );
  }

  @override
  Future<User> register(
    String name,
    String email,
    String password,
    bool acceptedTerms,
  ) async => const User(id: 'user-1', name: 'Ana');

  @override
  Future<User> refresh(String refreshToken) async =>
      throw const UnauthorizedException();

  @override
  Future<void> logout() async {}

  @override
  Future<void> forgotPassword(String email) async {}

  @override
  Future<void> resetPassword(String token, String newPassword) async {}
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
