import 'package:controle_ds/core/money/money.dart';
import 'package:decimal/decimal.dart';

enum BotMode {
  paper,
  live;

  factory BotMode.fromJson(Object? value) => switch (value) {
    'PAPER' => BotMode.paper,
    'LIVE' => BotMode.live,
    _ => throw const FormatException('Modo do robô inválido.'),
  };

  String toJson() => switch (this) {
    BotMode.paper => 'PAPER',
    BotMode.live => 'LIVE',
  };
}

enum BotRiskLevel {
  low,
  medium,
  high;

  factory BotRiskLevel.fromJson(Object? value) => switch (value) {
    'LOW' => BotRiskLevel.low,
    'MEDIUM' => BotRiskLevel.medium,
    'HIGH' => BotRiskLevel.high,
    _ => throw const FormatException('Nível de risco inválido.'),
  };

  String toJson() => switch (this) {
    BotRiskLevel.low => 'LOW',
    BotRiskLevel.medium => 'MEDIUM',
    BotRiskLevel.high => 'HIGH',
  };
}

final class BotConsent {
  const BotConsent({required this.accepted, required this.version});

  final bool accepted;
  final String? version;

  factory BotConsent.fromJson(Map<String, Object?> json) {
    final accepted = json['accepted'];
    final version = json['version'];
    if (accepted is! bool || (version != null && version is! String)) {
      throw const FormatException('Formato do consentimento inválido.');
    }
    return BotConsent(accepted: accepted, version: version as String?);
  }
}

final class BotSettings {
  const BotSettings({
    required this.mode,
    required this.strategyId,
    required this.orderAmount,
    required this.intervalHours,
    required this.maxCapitalAllocation,
    required this.maxOrderSize,
    required this.maxDailyLoss,
    required this.maxTotalLoss,
    required this.riskLevel,
    required this.allowedPairs,
    required this.consent,
  });

  final BotMode mode;
  final String strategyId;
  final Decimal orderAmount;
  final int intervalHours;
  final Decimal maxCapitalAllocation;
  final Decimal maxOrderSize;
  final Decimal maxDailyLoss;
  final Decimal maxTotalLoss;
  final BotRiskLevel riskLevel;
  final List<String> allowedPairs;
  final BotConsent consent;

  factory BotSettings.fromJson(Map<String, Object?> json) {
    final mode = json['mode'];
    final strategyId = json['strategy_id'];
    final params = json['strategy_params'];
    final capital = json['max_capital_allocation'];
    final orderSize = json['max_order_size'];
    final dailyLoss = json['max_daily_loss'];
    final totalLoss = json['max_total_loss'];
    final pairs = json['allowed_pairs'];
    final rawConsent = json['consent'];
    if (strategyId is! String ||
        params is! Map ||
        capital is! String ||
        orderSize is! String ||
        dailyLoss is! String ||
        totalLoss is! String ||
        pairs is! List ||
        !pairs.every((pair) => pair is String) ||
        rawConsent is! Map) {
      throw const FormatException('Formato de configuração do robô inválido.');
    }
    final strategyParams = _objectMap(params);
    final amount = strategyParams['order_amount'];
    final interval = strategyParams['interval_hours'];
    if (amount is! String || interval is! int) {
      throw const FormatException('Parâmetros da estratégia DCA inválidos.');
    }
    return BotSettings(
      mode: BotMode.fromJson(mode),
      strategyId: strategyId,
      orderAmount: parseMoney(amount),
      intervalHours: interval,
      maxCapitalAllocation: parseMoney(capital),
      maxOrderSize: parseMoney(orderSize),
      maxDailyLoss: parseMoney(dailyLoss),
      maxTotalLoss: parseMoney(totalLoss),
      riskLevel: BotRiskLevel.fromJson(json['risk_level']),
      allowedPairs: List.unmodifiable(pairs.cast<String>()),
      consent: BotConsent.fromJson(_objectMap(rawConsent)),
    );
  }

  Map<String, Object?> toJson() => {
    'mode': 'PAPER',
    'strategy_id': strategyId,
    'strategy_params': {
      'order_amount': moneyToJson(orderAmount),
      'interval_hours': intervalHours,
    },
    'max_capital_allocation': moneyToJson(maxCapitalAllocation),
    'max_order_size': moneyToJson(maxOrderSize),
    'max_daily_loss': moneyToJson(maxDailyLoss),
    'max_total_loss': moneyToJson(maxTotalLoss),
    'risk_level': riskLevel.toJson(),
    'allowed_pairs': allowedPairs,
  };
}

Map<String, Object?> _objectMap(Object? value) {
  if (value is! Map) {
    throw const FormatException('O campo deve ser um objeto.');
  }
  return {
    for (final entry in value.entries)
      if (entry.key is String) entry.key as String: entry.value,
  };
}
