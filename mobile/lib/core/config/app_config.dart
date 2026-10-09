import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final class AppConfig {
  static const termsVersion = '2026-10';

  const AppConfig({required this.env, required this.baseUrl});

  final String env;
  final String baseUrl;

  factory AppConfig.fromEnvironment({
    String? env,
    String? baseUrl,
    TargetPlatform? platform,
    bool? isWeb,
  }) {
    final resolvedPlatform = platform ?? defaultTargetPlatform;
    final resolvedIsWeb = isWeb ?? kIsWeb;
    final defaultBaseUrl =
        !resolvedIsWeb && resolvedPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:8000/api/v1'
        : 'http://localhost:8000/api/v1';
    final configuredBaseUrl =
        baseUrl ?? const String.fromEnvironment('API_BASE_URL');
    final configuredEnv = env ?? const String.fromEnvironment('APP_ENV');

    return AppConfig(
      env: configuredEnv.isEmpty ? 'dev' : configuredEnv,
      baseUrl: (configuredBaseUrl.isEmpty ? defaultBaseUrl : configuredBaseUrl)
          .replaceFirst(RegExp(r'/+$'), ''),
    );
  }
}

final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);
