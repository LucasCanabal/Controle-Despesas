import 'package:controle_ds/core/errors/app_exception.dart';
import 'package:controle_ds/core/errors/error_messages.dart';
import 'package:controle_ds/core/security/local_auth_service.dart';
import 'package:controle_ds/features/bot/data/fake_bot_repository.dart';
import 'package:controle_ds/features/bot/domain/bot_settings.dart';
import 'package:controle_ds/features/bot/domain/bot_state.dart';
import 'package:controle_ds/features/bot/presentation/bot_panel_page.dart';
import 'package:controle_ds/features/bot/presentation/bot_settings_page.dart';
import 'package:controle_ds/features/exchange/data/fake_exchange_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('panel switch follows state transition permissions', (
    tester,
  ) async {
    for (final state in BotState.values) {
      final repository = FakeBotRepository();
      repository.setStateForTest(state);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [botRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(home: BotPanelPage()),
        ),
      );
      await tester.pumpAndSettle();

      final toggle = tester.widget<SwitchListTile>(
        find.byKey(const Key('bot-enable-switch')),
      );
      expect(
        toggle.onChanged != null,
        state == BotState.inactive ||
            state == BotState.running ||
            state == BotState.paused,
        reason: state.name,
      );
      expect(find.byKey(const Key('bot-risk-warning')), findsOneWidget);
      if (state == BotState.error) {
        expect(
          find.text('A corretora está indisponível no momento.'),
          findsOneWidget,
        );
      }
    }
  });

  testWidgets('LIVE is displayed but disabled in bot settings', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: BotSettingsPage())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('bot-settings-mode')));
    await tester.pumpAndSettle();
    final live = tester.widget<DropdownMenuItem<BotMode>>(
      find.byWidgetPredicate(
        (widget) =>
            widget is DropdownMenuItem<BotMode> && widget.value == BotMode.live,
      ),
    );
    expect(live.enabled, isFalse);
    expect(find.textContaining('fase futura'), findsWidgets);
  });

  testWidgets('LIVE option on the panel is visible and disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          botRepositoryProvider.overrideWithValue(FakeBotRepository()),
        ],
        child: const MaterialApp(home: BotPanelPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('bot-mode')));
    await tester.pumpAndSettle();
    final live = tester.widget<DropdownMenuItem<BotMode>>(
      find.byWidgetPredicate(
        (widget) =>
            widget is DropdownMenuItem<BotMode> && widget.value == BotMode.live,
      ),
    );
    expect(live.enabled, isFalse);
    expect(find.textContaining('indisponível nesta fase'), findsOneWidget);
  });

  testWidgets('bot settings validates positive values and at least one pair', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: BotSettingsPage())),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('bot-capital')), '0');
    await tester.enterText(find.byKey(const Key('bot-allowed-pairs')), '');
    await tester.drag(find.byType(ListView), const Offset(0, -1000));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-bot-settings')));
    await tester.pumpAndSettle();

    expect(find.text('O valor deve ser maior que zero.'), findsWidgets);
    expect(find.text('Informe pelo menos um par.'), findsOneWidget);
  });

  testWidgets('canceling kill confirmation does not call the API', (
    tester,
  ) async {
    final repository = FakeBotRepository()..setStateForTest(BotState.running);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [botRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: BotPanelPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('bot-kill-switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(repository.killCalls, 0);
  });

  testWidgets('declining local authentication does not call kill', (
    tester,
  ) async {
    final repository = FakeBotRepository()..setStateForTest(BotState.running);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          botRepositoryProvider.overrideWithValue(repository),
          localAuthProvider.overrideWithValue(_LocalAuth(false)),
        ],
        child: const MaterialApp(home: BotPanelPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('bot-kill-switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-bot-kill')));
    await tester.pumpAndSettle();

    expect(repository.killCalls, 0);
  });

  testWidgets('kill requires both confirmations then calls kill once', (
    tester,
  ) async {
    final repository = FakeBotRepository()..setStateForTest(BotState.running);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          botRepositoryProvider.overrideWithValue(repository),
          localAuthProvider.overrideWithValue(_LocalAuth(true)),
        ],
        child: const MaterialApp(home: BotPanelPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('bot-kill-switch')));
    await tester.pumpAndSettle();
    expect(find.textContaining('cancela ordens abertas'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-bot-kill')));
    await tester.pumpAndSettle();

    expect(repository.killCalls, 1);
    expect(repository.getStatusCalls, greaterThanOrEqualTo(1));
    expect(repository.stateForTest, BotState.inactive);
  });

  testWidgets('starting without connected exchange shows guidance only', (
    tester,
  ) async {
    final repository = FakeBotRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          botRepositoryProvider.overrideWithValue(repository),
          exchangeRepositoryProvider.overrideWithValue(
            FakeExchangeRepository(),
          ),
        ],
        child: const MaterialApp(home: BotPanelPage()),
      ),
    );
    await tester.pumpAndSettle();

    final toggle = tester.widget<SwitchListTile>(
      find.byKey(const Key('bot-enable-switch')),
    );
    toggle.onChanged!(true);
    await tester.pumpAndSettle();
    expect(find.textContaining('Conecte uma corretora'), findsOneWidget);
    expect(repository.startCalls, 0);
  });

  testWidgets('mapped bot start errors do not lock the panel', (tester) async {
    final repository = FakeBotRepository()
      ..setStartErrorForTest(
        const ApiException(
          code: 'PAPER_PERIOD_NOT_MET',
          message: 'backend detail',
          statusCode: 403,
        ),
      );
    final exchange = FakeExchangeRepository();
    await exchange.saveCredentials('safe-key-1234', 'secret');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          botRepositoryProvider.overrideWithValue(repository),
          exchangeRepositoryProvider.overrideWithValue(exchange),
        ],
        child: const MaterialApp(home: BotPanelPage()),
      ),
    );
    await tester.pumpAndSettle();

    final toggle = tester.widget<SwitchListTile>(
      find.byKey(const Key('bot-enable-switch')),
    );
    toggle.onChanged!(true);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'O período mínimo de operação em modo PAPER ainda não foi concluído.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('bot-risk-warning')), findsOneWidget);
  });

  testWidgets('API start errors show their mapped messages', (tester) async {
    const cases = {
      'BOT_INVALID_STATE':
          'Esta ação não está disponível no estado atual do robô.',
      'CONSENT_REQUIRED':
          'É necessário aceitar o consentimento para continuar.',
      'PAPER_PERIOD_NOT_MET':
          'O período mínimo de operação em modo PAPER ainda não foi concluído.',
    };
    for (final entry in cases.entries) {
      final repository = FakeBotRepository()
        ..setStartErrorForTest(
          ApiException(
            code: entry.key,
            message: 'Detalhe interno.',
            statusCode: entry.key == 'BOT_INVALID_STATE' ? 409 : 403,
          ),
        );
      final exchange = FakeExchangeRepository();
      await exchange.saveCredentials('safe-key-1234', 'secret');
      await tester.pumpWidget(
        ProviderScope(
          key: ValueKey(entry.key),
          overrides: [
            botRepositoryProvider.overrideWithValue(repository),
            exchangeRepositoryProvider.overrideWithValue(exchange),
          ],
          child: const MaterialApp(home: BotPanelPage()),
        ),
      );
      await tester.pumpAndSettle();
      tester
          .widget<SwitchListTile>(find.byKey(const Key('bot-enable-switch')))
          .onChanged!(true);
      await tester.pumpAndSettle();
      expect(find.text(messageForCode(entry.key)), findsOneWidget);
      expect(find.byKey(const Key('bot-risk-warning')), findsOneWidget);
    }
  });
}

class _LocalAuth implements LocalAuthService {
  const _LocalAuth(this.confirmed);

  final bool confirmed;

  @override
  Future<bool> confirm(String reason) async => confirmed;
}
