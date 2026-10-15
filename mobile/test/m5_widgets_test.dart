import 'package:controle_ds/core/errors/app_exception.dart';
import 'package:controle_ds/core/security/local_auth_service.dart';
import 'package:controle_ds/features/calculator/data/fake_compound_interest_repository.dart';
import 'package:controle_ds/features/calculator/domain/compound_interest_repository.dart';
import 'package:controle_ds/features/calculator/domain/compound_interest_result.dart';
import 'package:controle_ds/features/calculator/presentation/compound_interest_page.dart';
import 'package:controle_ds/features/exchange/data/fake_exchange_repository.dart';
import 'package:controle_ds/features/exchange/domain/exchange_credential_info.dart';
import 'package:controle_ds/features/exchange/domain/exchange_repository.dart';
import 'package:controle_ds/features/exchange/domain/exchange_status.dart';
import 'package:controle_ds/features/exchange/presentation/exchange_page.dart';
import 'package:controle_ds/features/portfolio/data/fake_portfolio_repository.dart';
import 'package:controle_ds/features/portfolio/presentation/portfolio_page.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  testWidgets(
    'exchange clears credentials and never displays them after save',
    (tester) async {
      final repository = _RecordingExchangeRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            exchangeRepositoryProvider.overrideWithValue(repository),
            localAuthProvider.overrideWithValue(_ConfirmingAuthService(true)),
          ],
          child: const MaterialApp(home: ExchangePage()),
        ),
      );
      await tester.pumpAndSettle();
      const key = 'binance-key-1234';
      const secret = 'secret-never-display';
      await tester.enterText(find.byKey(const Key('exchange-api-key')), key);
      await tester.enterText(
        find.byKey(const Key('exchange-api-secret')),
        secret,
      );
      await tester.tap(find.byKey(const Key('save-exchange-credentials')));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();

      expect(repository.saveCalls, 1);
      expect(find.text(key), findsNothing);
      expect(find.text(secret), findsNothing);
      expect(find.textContaining('…1234'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('exchange-api-key')))
            .controller!
            .text,
        isEmpty,
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('exchange-api-secret')))
            .controller!
            .text,
        isEmpty,
      );
    },
  );

  testWidgets('withdraw-enabled error maps message and IP whitelist guidance', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          exchangeRepositoryProvider.overrideWithValue(
            _RecordingExchangeRepository(withdrawEnabled: true),
          ),
          localAuthProvider.overrideWithValue(_ConfirmingAuthService(true)),
        ],
        child: const MaterialApp(home: ExchangePage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('exchange-api-key')),
      'withdraw-key-123',
    );
    await tester.enterText(
      find.byKey(const Key('exchange-api-secret')),
      'private-secret',
    );
    await tester.tap(find.byKey(const Key('save-exchange-credentials')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Desative a permissão de saque'),
      findsOneWidget,
    );
    expect(find.textContaining('IP whitelist'), findsWidgets);
    expect(find.text('private-secret'), findsNothing);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('exchange-api-key')))
          .controller!
          .text,
      isEmpty,
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('exchange-api-secret')))
          .controller!
          .text,
      isEmpty,
    );
  });

  testWidgets('invalid exchange key shows mapped message and clears fields', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localAuthProvider.overrideWithValue(_ConfirmingAuthService(true)),
        ],
        child: const MaterialApp(home: ExchangePage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('exchange-api-key')), 'short');
    await tester.enterText(
      find.byKey(const Key('exchange-api-secret')),
      'private-secret',
    );
    await tester.tap(find.byKey(const Key('save-exchange-credentials')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('A chave da corretora é inválida.'),
      findsOneWidget,
    );
    expect(find.text('private-secret'), findsNothing);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('exchange-api-key')))
          .controller!
          .text,
      isEmpty,
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('exchange-api-secret')))
          .controller!
          .text,
      isEmpty,
    );
  });

  testWidgets('saving without local confirmation never calls repository', (
    tester,
  ) async {
    final repository = _RecordingExchangeRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          exchangeRepositoryProvider.overrideWithValue(repository),
          localAuthProvider.overrideWithValue(_ConfirmingAuthService(false)),
        ],
        child: const MaterialApp(home: ExchangePage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('exchange-api-key')),
      'binance-key-1234',
    );
    await tester.enterText(
      find.byKey(const Key('exchange-api-secret')),
      'private-secret',
    );
    await tester.tap(find.byKey(const Key('save-exchange-credentials')));
    await tester.pumpAndSettle();

    expect(repository.saveCalls, 0);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('exchange-api-key')))
          .controller!
          .text,
      isEmpty,
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('exchange-api-secret')))
          .controller!
          .text,
      isEmpty,
    );
  });

  testWidgets('removing without local confirmation never calls repository', (
    tester,
  ) async {
    final repository = _RecordingExchangeRepository(
      initialInfo: const ExchangeCredentialInfo(
        status: ExchangeStatus.connected,
        keyHint: '…1234',
        lastCheckedAt: null,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          exchangeRepositoryProvider.overrideWithValue(repository),
          localAuthProvider.overrideWithValue(_ConfirmingAuthService(false)),
        ],
        child: const MaterialApp(home: ExchangePage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('remove-exchange-credentials')));
    await tester.pumpAndSettle();
    expect(find.textContaining('o robô será desativado'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-remove-exchange')));
    await tester.pumpAndSettle();

    expect(repository.removeCalls, 0);
  });

  testWidgets('stale portfolio shows warning and rate limit is messaged', (
    tester,
  ) async {
    final repository = FakePortfolioRepository(
      now: () => DateTime.utc(2026, 10, 6, 13),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [portfolioRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: PortfolioPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('portfolio-stale-warning')), findsOneWidget);
    await tester.drag(
      find.byKey(const Key('portfolio-content')),
      const Offset(0, 500),
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('portfolio-content')),
      const Offset(0, 500),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Muitas solicitações'), findsOneWidget);
  });

  testWidgets('calculator accepts zero rate and rejects negative amounts', (
    tester,
  ) async {
    final repository = _RecordingCalculatorRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          compoundInterestRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: CompoundInterestPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('calc-initial-amount')), '100');
    await tester.enterText(
      find.byKey(const Key('calc-monthly-contribution')),
      '10',
    );
    await tester.enterText(find.byKey(const Key('calc-monthly-rate')), '0');
    await tester.enterText(find.byKey(const Key('calc-months')), '2');
    await tester.tap(find.byKey(const Key('calculate-compound-interest')));
    await tester.pumpAndSettle();
    expect(repository.calls, 1);
    expect(repository.lastRate, Decimal.zero);
    expect(find.text('Resultado'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('calc-initial-amount')), '-1');
    await tester.tap(find.byKey(const Key('calculate-compound-interest')));
    await tester.pumpAndSettle();
    expect(
      find.text('O valor deve ser maior ou igual a zero.'),
      findsOneWidget,
    );
    expect(repository.calls, 1);
  });
}

class _ConfirmingAuthService implements LocalAuthService {
  const _ConfirmingAuthService(this.confirmed);

  final bool confirmed;

  @override
  Future<bool> confirm(String reason) async => confirmed;
}

class _RecordingExchangeRepository implements ExchangeRepository {
  _RecordingExchangeRepository({
    this.withdrawEnabled = false,
    ExchangeCredentialInfo? initialInfo,
  }) : _info = initialInfo;

  final bool withdrawEnabled;
  int saveCalls = 0;
  int removeCalls = 0;
  ExchangeCredentialInfo? _info;

  @override
  Future<ExchangeCredentialInfo> saveCredentials(
    String apiKey,
    String apiSecret,
  ) async {
    saveCalls++;
    if (withdrawEnabled) {
      throw const ApiException(
        code: 'EXCHANGE_KEY_WITHDRAW_ENABLED',
        message: 'Erro seguro.',
        statusCode: 422,
      );
    }
    return _info = ExchangeCredentialInfo(
      status: ExchangeStatus.connected,
      keyHint: '…${apiKey.substring(apiKey.length - 4)}',
      lastCheckedAt: DateTime.utc(2026, 10, 6),
    );
  }

  @override
  Future<ExchangeCredentialInfo?> getInfo() async => _info;

  @override
  Future<void> remove() async {
    removeCalls++;
    _info = null;
  }
}

class _RecordingCalculatorRepository implements CompoundInterestRepository {
  int calls = 0;
  Decimal? lastRate;
  final _fake = FakeCompoundInterestRepository();

  @override
  Future<CompoundInterestResult> calculate({
    required Decimal initialAmount,
    required Decimal monthlyContribution,
    required Decimal monthlyRate,
    required int months,
  }) async {
    calls++;
    lastRate = monthlyRate;
    return _fake.calculate(
      initialAmount: initialAmount,
      monthlyContribution: monthlyContribution,
      monthlyRate: monthlyRate,
      months: months,
    );
  }
}
