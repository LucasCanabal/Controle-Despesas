import 'package:controle_ds/core/money/money.dart';
import 'package:controle_ds/features/bot/domain/bot_settings.dart';
import 'package:decimal/decimal.dart';

enum BotState {
  inactive,
  starting,
  running,
  paused,
  stoppedByRisk,
  error;

  factory BotState.fromJson(Object? value) => switch (value) {
    'INACTIVE' => BotState.inactive,
    'STARTING' => BotState.starting,
    'RUNNING' => BotState.running,
    'PAUSED' => BotState.paused,
    'STOPPED_BY_RISK' => BotState.stoppedByRisk,
    'ERROR' => BotState.error,
    _ => throw const FormatException('Estado do robô inválido.'),
  };

  String toJson() => switch (this) {
    BotState.inactive => 'INACTIVE',
    BotState.starting => 'STARTING',
    BotState.running => 'RUNNING',
    BotState.paused => 'PAUSED',
    BotState.stoppedByRisk => 'STOPPED_BY_RISK',
    BotState.error => 'ERROR',
  };
}

final class BotLastError {
  const BotLastError({
    required this.code,
    required this.message,
    required this.occurredAt,
  });

  final String code;
  final String message;
  final DateTime occurredAt;

  factory BotLastError.fromJson(Map<String, Object?> json) {
    final code = json['code'];
    final message = json['message'];
    final occurredAt = json['occurred_at'];
    if (code is! String || message is! String || occurredAt is! String) {
      throw const FormatException('Formato do erro do robô inválido.');
    }
    return BotLastError(
      code: code,
      message: message,
      occurredAt: DateTime.parse(occurredAt),
    );
  }
}

final class BotStatus {
  const BotStatus({
    required this.state,
    required this.mode,
    required this.maxCapitalAllocation,
    required this.lastRunAt,
    required this.nextRunAt,
    required this.openOrders,
    required this.pnlToday,
    required this.lastError,
    required this.paperDaysCompleted,
    required this.liveAllowed,
  });

  final BotState state;
  final BotMode mode;
  final Decimal maxCapitalAllocation;
  final DateTime? lastRunAt;
  final DateTime? nextRunAt;
  final int openOrders;
  final Decimal pnlToday;
  final BotLastError? lastError;
  final int paperDaysCompleted;
  final bool liveAllowed;

  factory BotStatus.fromJson(Map<String, Object?> json) {
    final capital = json['max_capital_allocation'];
    final lastRunAt = json['last_run_at'];
    final nextRunAt = json['next_run_at'];
    final openOrders = json['open_orders'];
    final pnlToday = json['pnl_today'];
    final lastError = json['last_error'];
    final paperDaysCompleted = json['paper_days_completed'];
    final liveAllowed = json['live_allowed'];
    if (
        capital is! String ||
        (lastRunAt != null && lastRunAt is! String) ||
        (nextRunAt != null && nextRunAt is! String) ||
        openOrders is! int ||
        pnlToday is! String ||
        (lastError != null && lastError is! Map) ||
        paperDaysCompleted is! int ||
        liveAllowed is! bool) {
      throw const FormatException('Formato do status do robô inválido.');
    }
    return BotStatus(
      state: BotState.fromJson(json['state']),
      mode: BotMode.fromJson(json['mode']),
      maxCapitalAllocation: parseMoney(capital),
      lastRunAt: lastRunAt == null
          ? null
          : DateTime.parse(lastRunAt as String),
      nextRunAt: nextRunAt == null
          ? null
          : DateTime.parse(nextRunAt as String),
      openOrders: openOrders,
      pnlToday: parseMoney(pnlToday),
      lastError: lastError == null
          ? null
          : BotLastError.fromJson(_objectMap(lastError)),
      paperDaysCompleted: paperDaysCompleted,
      liveAllowed: liveAllowed,
    );
  }
}

Map<String, Object?> _objectMap(Object? value) {
  if (value is! Map) {
    throw const FormatException('O erro do robô deve ser um objeto.');
  }
  return {
    for (final entry in value.entries)
      if (entry.key is String) entry.key as String: entry.value,
  };
}
