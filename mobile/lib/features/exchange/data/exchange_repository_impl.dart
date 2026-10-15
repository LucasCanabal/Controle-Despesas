import 'package:controle_ds/core/errors/app_exception.dart';
import 'package:controle_ds/features/exchange/data/exchange_api.dart';
import 'package:controle_ds/features/exchange/domain/exchange_credential_info.dart';
import 'package:controle_ds/features/exchange/domain/exchange_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final exchangeRepositoryImplProvider = Provider<ExchangeRepository>(
  (ref) => ExchangeRepositoryImpl(ref.watch(exchangeApiProvider)),
);

final class ExchangeRepositoryImpl implements ExchangeRepository {
  const ExchangeRepositoryImpl(this._api);

  final ExchangeApi _api;

  @override
  Future<ExchangeCredentialInfo> saveCredentials(
    String apiKey,
    String apiSecret,
  ) async => ExchangeCredentialInfo.fromJson(
    await _api.saveCredentials(apiKey, apiSecret),
  );

  @override
  Future<ExchangeCredentialInfo?> getInfo() async {
    try {
      return ExchangeCredentialInfo.fromJson(await _api.getCredentials());
    } on DioException catch (error) {
      final apiException = error.error;
      if (apiException is ApiException &&
          apiException.code == 'NOT_FOUND' &&
          apiException.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<void> remove() => _api.deleteCredentials();
}
