import 'package:controle_ds/core/errors/app_exception.dart';
import 'package:controle_ds/features/exchange/domain/exchange_credential_info.dart';
import 'package:controle_ds/features/exchange/domain/exchange_repository.dart';
import 'package:controle_ds/features/exchange/domain/exchange_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final exchangeRepositoryProvider = Provider<ExchangeRepository>((ref) {
  // TODO: switch to exchangeRepositoryImplProvider when backend S10 exists.
  return FakeExchangeRepository();
});

final class FakeExchangeRepository implements ExchangeRepository {
  ExchangeCredentialInfo? _info;

  @override
  Future<ExchangeCredentialInfo> saveCredentials(
    String apiKey,
    String apiSecret,
  ) async {
    if (apiKey.length < 8) {
      throw const ApiException(
        code: 'EXCHANGE_KEY_INVALID',
        message: 'Chave inválida.',
        statusCode: 422,
      );
    }
    if (apiKey.toLowerCase().contains('withdraw')) {
      throw const ApiException(
        code: 'EXCHANGE_KEY_WITHDRAW_ENABLED',
        message: 'Permissão de saque habilitada.',
        statusCode: 422,
      );
    }
    final hint = '…${apiKey.substring(apiKey.length - 4)}';
    _info = ExchangeCredentialInfo(
      status: ExchangeStatus.connected,
      keyHint: hint,
      lastCheckedAt: DateTime.now().toUtc(),
    );
    return _info!;
  }

  @override
  Future<ExchangeCredentialInfo?> getInfo() async => _info;

  @override
  Future<void> remove() async {
    _info = null;
  }
}
