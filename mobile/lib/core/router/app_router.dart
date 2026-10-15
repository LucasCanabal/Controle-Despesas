import 'package:controle_ds/features/auth/presentation/forgot_password_page.dart';
import 'package:controle_ds/features/auth/presentation/login_page.dart';
import 'package:controle_ds/features/auth/presentation/register_page.dart';
import 'package:controle_ds/features/auth/presentation/reset_password_page.dart';
import 'package:controle_ds/features/auth/presentation/session_notifier.dart';
import 'package:controle_ds/features/auth/presentation/splash_page.dart';
import 'package:controle_ds/features/finance/presentation/home_shell.dart';
import 'package:controle_ds/core/security/local_auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refreshListenable = _RouterRefreshListenable();
  ref.listen(sessionNotifierProvider, (previous, next) {
    if (previous != next) {
      refreshListenable.refresh();
    }
  });

  final router = GoRouter(
    navigatorKey: localAuthNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final session = ref.read(sessionNotifierProvider);
      final sessionState = session.asData?.value;
      final isAuthenticated =
          sessionState?.status == SessionStatus.authenticated;
      if (isAuthenticated &&
          const {
            '/splash',
            '/login',
            '/register',
            '/forgot-password',
            '/reset-password',
          }.contains(location)) {
        return '/home';
      }
      if (!isAuthenticated && location == '/home') {
        return '/login';
      }
      if (!isAuthenticated && location == '/splash' && !session.isLoading) {
        return '/login';
      }
      if (location != '/home') {
        return null;
      }
      return isAuthenticated ? null : '/login';
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashPage()),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) =>
            ResetPasswordPage(token: state.uri.queryParameters['token'] ?? ''),
      ),
      GoRoute(path: '/home', builder: (context, state) => const HomeShell()),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refreshListenable.dispose();
  });
  return router;
});

class _RouterRefreshListenable extends ChangeNotifier {
  void refresh() => notifyListeners();
}
