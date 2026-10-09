import 'package:controle_ds/core/errors/app_exception.dart';
import 'package:controle_ds/core/storage/token_storage.dart';
import 'package:dio/dio.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.client,
    required this.refreshDio,
    required this.tokenStorage,
    required this.onSessionExpired,
  });

  static const _retriedKey = 'auth_refresh_retried';
  static const _publicPaths = <String>[
    '/auth/register',
    '/auth/login',
    '/auth/refresh',
    '/auth/forgot-password',
    '/auth/reset-password',
    '/health',
  ];

  final Dio client;
  final Dio refreshDio;
  final TokenStorage tokenStorage;
  final void Function() onSessionExpired;

  Future<AuthTokens>? _refreshInFlight;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (_isPublic(options.path)) {
      handler.next(options);
      return;
    }
    try {
      final tokens = await tokenStorage.read();
      if (tokens != null) {
        options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
      }
      handler.next(options);
    } on Object catch (error) {
      handler.reject(DioException(requestOptions: options, error: error));
    }
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    if (err.response?.statusCode != 401 || _isPublic(options.path)) {
      handler.next(err);
      return;
    }

    if (options.extra[_retriedKey] == true) {
      try {
        await _expireSession();
        handler.reject(
          DioException(
            requestOptions: options,
            response: err.response,
            type: err.type,
            error: const UnauthorizedException(),
          ),
        );
      } on Object catch (cause) {
        if (cause is DioException) {
          handler.reject(cause);
          return;
        }
        handler.reject(
          DioException(
            requestOptions: options,
            response: err.response,
            type: err.type,
            error: cause,
          ),
        );
      }
      return;
    }

    try {
      final latestTokens = await tokenStorage.read();
      if (latestTokens == null) {
        await _expireSession();
        throw const UnauthorizedException();
      }

      final sentAccessToken = _accessTokenFromHeader(
        options.headers['Authorization'],
      );
      final tokens =
          sentAccessToken != null && sentAccessToken != latestTokens.accessToken
          ? latestTokens
          : await _refreshOnce();

      options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
      options.extra[_retriedKey] = true;
      handler.resolve(await client.fetch<Object?>(options));
    } on Object catch (cause) {
      if (cause is DioException) {
        handler.reject(cause);
        return;
      }
      handler.reject(
        DioException(
          requestOptions: options,
          response: err.response,
          type: err.type,
          error: cause,
        ),
      );
    }
  }

  Future<AuthTokens> _refreshOnce() {
    final pending = _refreshInFlight;
    if (pending != null) {
      return pending;
    }
    final refresh = _performRefresh();
    _refreshInFlight = refresh;
    return refresh.whenComplete(() {
      if (identical(_refreshInFlight, refresh)) {
        _refreshInFlight = null;
      }
    });
  }

  Future<AuthTokens> _performRefresh() async {
    try {
      final currentTokens = await tokenStorage.read();
      if (currentTokens == null) {
        throw const UnauthorizedException();
      }
      final response = await refreshDio.post<Object?>(
        '/auth/refresh',
        data: {'refresh_token': currentTokens.refreshToken},
      );
      final data = response.data;
      if (data is! Map ||
          data['access_token'] is! String ||
          data['refresh_token'] is! String) {
        throw const FormatException(
          'Resposta de refresh sem access_token ou refresh_token.',
        );
      }
      final tokens = AuthTokens(
        accessToken: data['access_token'] as String,
        refreshToken: data['refresh_token'] as String,
      );
      await tokenStorage.save(tokens);
      return tokens;
    } on Object {
      await _expireSession();
      throw const UnauthorizedException();
    }
  }

  Future<void> _expireSession() async {
    try {
      await tokenStorage.clear();
    } finally {
      onSessionExpired();
    }
  }

  bool _isPublic(String path) =>
      _publicPaths.any((publicPath) => path.endsWith(publicPath));

  String? _accessTokenFromHeader(Object? header) {
    if (header is! String || !header.startsWith('Bearer ')) {
      return null;
    }
    return header.substring('Bearer '.length);
  }
}
