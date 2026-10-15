import 'package:controle_ds/core/session/session_events.dart';
import 'package:controle_ds/core/storage/token_storage.dart';
import 'package:controle_ds/features/auth/data/fake_auth_repository.dart';
import 'package:controle_ds/features/auth/domain/auth_repository.dart';
import 'package:controle_ds/features/auth/domain/user.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SessionStatus { unknown, authenticated, unauthenticated }

final class SessionState {
  const SessionState._({required this.status, this.user});

  const SessionState.unknown() : this._(status: SessionStatus.unknown);

  const SessionState.authenticated(User user)
    : this._(status: SessionStatus.authenticated, user: user);

  const SessionState.unauthenticated()
    : this._(status: SessionStatus.unauthenticated);

  final SessionStatus status;
  final User? user;
}

final sessionNotifierProvider =
    AsyncNotifierProvider<SessionNotifier, SessionState>(SessionNotifier.new);

class SessionNotifier extends AsyncNotifier<SessionState> {
  late AuthRepository _authRepository;
  late TokenStorage _tokenStorage;

  @override
  Future<SessionState> build() async {
    _authRepository = ref.watch(authRepositoryProvider);
    _tokenStorage = ref.watch(tokenStorageProvider);
    ref.listen<bool>(sessionExpiredProvider, (previous, expired) {
      if (expired) {
        state = const AsyncData(SessionState.unauthenticated());
      }
    });
    return _restoreSession();
  }

  Future<SessionState> _restoreSession() async {
    final tokens = await _tokenStorage.read();
    if (tokens == null) {
      return const SessionState.unauthenticated();
    }
    try {
      final user = await _authRepository.refresh(tokens.refreshToken);
      return SessionState.authenticated(user);
    } on Object {
      await _tokenStorage.clear();
      return const SessionState.unauthenticated();
    }
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      ref.read(sessionExpiredProvider.notifier).reset();
      final user = await _authRepository.login(email, password);
      return SessionState.authenticated(user);
    });
  }

  Future<void> register(
    String name,
    String email,
    String password,
    bool acceptedTerms,
  ) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      ref.read(sessionExpiredProvider.notifier).reset();
      final user = await _authRepository.register(
        name,
        email,
        password,
        acceptedTerms,
      );
      return SessionState.authenticated(user);
    });
  }

  Future<void> logout() async {
    Object? apiError;
    StackTrace? apiStackTrace;
    try {
      await _authRepository.logout();
    } on Object catch (error, stackTrace) {
      apiError = error;
      apiStackTrace = stackTrace;
    }

    try {
      await _tokenStorage.clear();
    } finally {
      state = const AsyncData(SessionState.unauthenticated());
      ref.read(sessionExpiredProvider.notifier).reset();
    }

    if (apiError != null) {
      Error.throwWithStackTrace(apiError, apiStackTrace!);
    }
  }

  Future<void> forgotPassword(String email) =>
      _authRepository.forgotPassword(email);

  Future<void> resetPassword(String token, String newPassword) =>
      _authRepository.resetPassword(token, newPassword);
}
