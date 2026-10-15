import 'package:controle_ds/features/exchange/data/fake_exchange_repository.dart';
import 'package:controle_ds/features/exchange/domain/exchange_credential_info.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final exchangeInfoProvider = FutureProvider<ExchangeCredentialInfo?>(
  (ref) => ref.watch(exchangeRepositoryProvider).getInfo(),
);
