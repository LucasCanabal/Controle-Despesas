import 'package:controle_ds/core/errors/app_exception.dart';
import 'package:controle_ds/features/bot/data/fake_bot_repository.dart';
import 'package:controle_ds/features/bot/domain/bot_order_filter.dart';
import 'package:controle_ds/features/bot/domain/bot_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fake begins inactive with twelve mixed orders and enforces states', () async {
    final repository = FakeBotRepository();
    expect((await repository.getStatus()).state, BotState.inactive);
    final orders = await repository.listOrders(const BotOrderFilter());
    expect(orders.items, hasLength(12));
    expect(orders.items.map((order) => order.isSimulated), containsAll([true, false]));
    expect(orders.items.map((order) => order.pair).toSet(), {
      'BTC/USDT',
      'ETH/USDT',
    });

    expect((await repository.start()).state, BotState.running);
    await expectLater(
      repository.start(),
      throwsA(
        isA<ApiException>().having(
          (error) => error.code,
          'code',
          'BOT_INVALID_STATE',
        ),
      ),
    );
    expect((await repository.stop()).state, BotState.inactive);
  });

  test('fake kill returns inactive and cancels every open order', () async {
    final repository = FakeBotRepository();
    await repository.start();
    final openOrders = await repository.listOrders(const BotOrderFilter());
    expect(
      openOrders.items.where((order) => order.status.name == 'open'),
      isNotEmpty,
    );

    final result = await repository.kill();
    final orders = await repository.listOrders(const BotOrderFilter());
    expect(result.state, BotState.inactive);
    expect(result.openOrders, 0);
    expect(
      orders.items.where((order) => order.status.name == 'open'),
      isEmpty,
    );
  });
}
