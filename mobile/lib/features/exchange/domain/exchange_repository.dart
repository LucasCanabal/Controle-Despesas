import 'package:controle_ds/features/exchange/domain/exchange_credential_info.dart';

abstract interface class ExchangeRepository {
  Future<ExchangeCredentialInfo> saveCredentials(
    String apiKey,
    String apiSecret,
  );

  Future<ExchangeCredentialInfo?> getInfo();

  Future<void> remove();
}
