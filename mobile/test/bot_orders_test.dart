import 'package:controle_ds/core/pagination/page.dart';
import 'package:controle_ds/features/bot/data/fake_bot_repository.dart';
import 'package:controle_ds/features/bot/domain/bot_order_filter.dart';
import 'package:controle_ds/features/bot/domain/bot_repository.dart';
import 'package:controle_ds/features/bot/domain/bot_settings.dart';
import 'package:controle_ds/features/bot/domain/bot_state.dart';
import 'package:controle_ds/features/bot/presentation/bot_orders_page.dart';
import 'package:controle_ds/features/bot/presentation/bot_orders_notifier.dart';
import 'package:controle_ds/features/bot/domain/bot_order.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('orders can be filtered and each next page is unique', (
    tester,
  ) async {
    final repository = FakeBotRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [botRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: BotOrdersPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bot-order-order-1')), findsOneWidget);
    expect(find.byKey(const Key('simulated-order-label')), findsWidgets);

    await tester.tap(find.byKey(const Key('bot-orders-simulated-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simuladas').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bot-order-order-1')), findsNothing);
    expect(find.byKey(const Key('simulated-order-label')), findsWidgets);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(BotOrdersPage)),
    );
    await container.read(botOrdersNotifierProvider.notifier).loadMore();
    await tester.pumpAndSettle();
    await container.read(botOrdersNotifierProvider.notifier).loadMore();
    await tester.pumpAndSettle();
    final ids = tester
        .widgetList<Card>(find.byType(Card))
        .map((card) => (card.key! as ValueKey<String>).value)
        .toList();
    expect(ids.toSet().length, ids.length);
    await tester.enterText(
      find.byKey(const Key('bot-orders-pair-filter')),
      'ETH/USDT',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.textContaining('ETH/USDT ·'), findsWidgets);
    expect(find.textContaining('BTC/USDT ·'), findsNothing);
  });

  testWidgets('orders show an empty state when filters match nothing', (
    tester,
  ) async {
    final repository = _EmptyOrdersRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [botRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: BotOrdersPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bot-orders-empty')), findsOneWidget);
  });
}

class _EmptyOrdersRepository implements BotRepository {
  @override
  Future<Page<BotOrder>> listOrders(
    BotOrderFilter filter, {
    String? cursor,
    int limit = 20,
  }) async => const Page(items: [], nextCursor: null);

  @override
  Future<void> acceptConsent(String version) async {}

  @override
  Future<BotStatus> getStatus() => throw UnimplementedError();

  @override
  Future<BotSettings> getSettings() => throw UnimplementedError();

  @override
  Future<BotStatus> kill() => throw UnimplementedError();

  @override
  Future<BotSettings> saveSettings(BotSettings settings) =>
      throw UnimplementedError();

  @override
  Future<BotStatus> start() => throw UnimplementedError();

  @override
  Future<BotStatus> stop() => throw UnimplementedError();
}
