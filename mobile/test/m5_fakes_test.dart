import 'package:controle_ds/core/errors/app_exception.dart';
import 'package:controle_ds/features/calculator/data/fake_compound_interest_repository.dart';
import 'package:controle_ds/features/exchange/data/fake_exchange_repository.dart';
import 'package:controle_ds/features/portfolio/data/fake_portfolio_repository.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'fake exchange starts empty and rejects invalid or withdrawal keys',
    () async {
      final repository = FakeExchangeRepository();
      expect(await repository.getInfo(), isNull);

      await expectLater(
        repository.saveCredentials('short', 'secret'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.code,
            'code',
            'EXCHANGE_KEY_INVALID',
          ),
        ),
      );
      await expectLater(
        repository.saveCredentials('withdraw-key-123', 'secret'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.code,
            'code',
            'EXCHANGE_KEY_WITHDRAW_ENABLED',
          ),
        ),
      );

      final info = await repository.saveCredentials('safe-key-1234', 'secret');
      expect(info.keyHint, '…1234');
      expect(await repository.getInfo(), info);
    },
  );

  test(
    'fake portfolio begins stale, syncs and enforces one-minute limit',
    () async {
      final repository = FakePortfolioRepository(
        now: () => DateTime.utc(2026, 10, 6, 13),
      );
      expect((await repository.getPortfolio()).stale, isTrue);
      expect((await repository.sync()).stale, isFalse);

      await expectLater(
        repository.sync(),
        throwsA(
          isA<ApiException>().having(
            (error) => error.code,
            'code',
            'RATE_LIMITED',
          ),
        ),
      );
    },
  );

  test(
    'fake compound interest accepts a zero rate without dividing by zero',
    () async {
      final result = await FakeCompoundInterestRepository().calculate(
        initialAmount: Decimal.parse('100'),
        monthlyContribution: Decimal.parse('25'),
        monthlyRate: Decimal.zero,
        months: 2,
      );

      expect(result.finalValue, Decimal.parse('150'));
      expect(result.totalInvested, Decimal.parse('150'));
      expect(result.totalInterest, Decimal.zero);
    },
  );
}
