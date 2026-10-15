import 'package:controle_ds/core/network/dio_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final portfolioApiProvider = Provider<PortfolioApi>(
  (ref) => PortfolioApi(ref.watch(dioProvider)),
);

final class PortfolioApi {
  const PortfolioApi(this._dio);

  final Dio _dio;

  Future<Map<String, Object?>> getPortfolio() async =>
      _objectResponse(await _dio.get<Object?>('/portfolio'));

  Future<Map<String, Object?>> sync() async =>
      _objectResponse(await _dio.post<Object?>('/portfolio/sync'));

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
