import 'package:controle_ds/core/money/money.dart';
import 'package:decimal/decimal.dart';

enum BotOrderSide {
  buy,
  sell;

  factory BotOrderSide.fromJson(Object? value) => switch (value) {
    'BUY' => BotOrderSide.buy,
    'SELL' => BotOrderSide.sell,
    _ => throw const FormatException('Lado da ordem inválido.'),
  };

  String toJson() => this == BotOrderSide.buy ? 'BUY' : 'SELL';
}

enum BotOrderStatus {
  open,
  filled,
  canceled,
  rejected;

  factory BotOrderStatus.fromJson(Object? value) => switch (value) {
    'OPEN' => BotOrderStatus.open,
    'FILLED' => BotOrderStatus.filled,
    'CANCELED' => BotOrderStatus.canceled,
    'REJECTED' => BotOrderStatus.rejected,
    _ => throw const FormatException('Status da ordem inválido.'),
  };
}

final class BotOrder {
  const BotOrder({
    required this.id,
    required this.pair,
    required this.side,
    required this.quantity,
    required this.averagePrice,
    required this.fee,
    required this.status,
    required this.isSimulated,
    required this.exchangeOrderId,
    required this.strategyId,
    required this.signalReason,
    required this.createdAt,
  });

  final String id;
  final String pair;
  final BotOrderSide side;
  final Decimal quantity;
  final Decimal averagePrice;
  final Decimal fee;
  final BotOrderStatus status;
  final bool isSimulated;
  final String? exchangeOrderId;
  final String strategyId;
  final String signalReason;
  final DateTime createdAt;

  factory BotOrder.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final pair = json['pair'];
    final quantity = json['quantity'];
    final avgPrice = json['avg_price'];
    final fee = json['fee'];
    final simulated = json['is_simulated'];
    final exchangeOrderId = json['exchange_order_id'];
    final strategyId = json['strategy_id'];
    final reason = json['signal_reason'];
    final createdAt = json['created_at'];
    if (id is! String ||
        pair is! String ||
        quantity is! String ||
        avgPrice is! String ||
        fee is! String ||
        simulated is! bool ||
        (exchangeOrderId != null && exchangeOrderId is! String) ||
        strategyId is! String ||
        reason is! String ||
        createdAt is! String) {
      throw const FormatException('Formato da ordem do robô inválido.');
    }
    return BotOrder(
      id: id,
      pair: pair,
      side: BotOrderSide.fromJson(json['side']),
      quantity: parseMoney(quantity),
      averagePrice: parseMoney(avgPrice),
      fee: parseMoney(fee),
      status: BotOrderStatus.fromJson(json['status']),
      isSimulated: simulated,
      exchangeOrderId: exchangeOrderId as String?,
      strategyId: strategyId,
      signalReason: reason,
      createdAt: DateTime.parse(createdAt),
    );
  }
}
