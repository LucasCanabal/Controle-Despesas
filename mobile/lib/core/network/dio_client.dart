import 'package:controle_ds/core/config/app_config.dart';
import 'package:controle_ds/core/network/auth_interceptor.dart';
import 'package:controle_ds/core/network/error_interceptor.dart';
import 'package:controle_ds/core/session/session_events.dart';
import 'package:controle_ds/core/storage/token_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final refreshDioProvider = Provider<Dio>((ref) {
  final config = ref.watch(appConfigProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: config.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
    ),
  );
  ref.onDispose(dio.close);
  return dio;
});

final dioProvider = Provider<Dio>((ref) {
  final config = ref.watch(appConfigProvider);
  final client = Dio(
    BaseOptions(
      baseUrl: config.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
    ),
  );
  client.interceptors.addAll([
    AuthInterceptor(
      client: client,
      refreshDio: ref.watch(refreshDioProvider),
      tokenStorage: ref.watch(tokenStorageProvider),
      onSessionExpired: () =>
          ref.read(sessionExpiredProvider.notifier).expire(),
    ),
    ErrorInterceptor(),
  ]);
  ref.onDispose(client.close);
  return client;
});
