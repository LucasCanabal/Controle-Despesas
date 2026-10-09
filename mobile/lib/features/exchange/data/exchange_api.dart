import 'package:controle_ds/core/network/dio_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final exchangeApiProvider = Provider<ExchangeApi>(
  (ref) => ExchangeApi(ref.watch(dioProvider)),
);

final class ExchangeApi {
  const ExchangeApi(this._dio);

  final Dio _dio;

  Future<Map<String, Object?>> saveCredentials(
    String apiKey,
    String apiSecret,
  ) async => _objectResponse(
    await _dio.put<Object?>(
      '/exchange/credentials',
      data: {
        'exchange': 'BINANCE',
        'api_key': apiKey,
        'api_secret': apiSecret,
      },
    ),
  );

  Future<Map<String, Object?>> getCredentials() async => _objectResponse(
    await _dio.get<Object?>('/exchange/credentials'),
  );

  Future<void> deleteCredentials() async {
    await _dio.delete<void>('/exchange/credentials');
  }

  Map<String, Object?> _objectResponse(Response<Object?> response) {
    final value = response.data;
    if (value is! Map) {
      throw const FormatException('A resposta da API deve ser um objeto.');
    }
    return {
      for (final entry in value.entries)
        if (entry.key is String) entry.key as String: entry.value,
    };
  }
}
