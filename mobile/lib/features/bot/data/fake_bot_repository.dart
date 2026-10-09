import 'package:controle_ds/core/errors/app_exception.dart';
import 'package:controle_ds/core/money/money.dart';
import 'package:controle_ds/core/pagination/page.dart';
import 'package:controle_ds/features/bot/domain/bot_order.dart';
import 'package:controle_ds/features/bot/domain/bot_order_filter.dart';
import 'package:controle_ds/features/bot/domain/bot_repository.dart';
import 'package:controle_ds/features/bot/domain/bot_settings.dart';
import 'package:controle_ds/features/bot/domain/bot_state.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final botRepositoryProvider = Provider<BotRepository>((ref) {
  // TODO: switch to botRepositoryImplProvider when backend S15 exists.
  return FakeBotRepository();
});

final class FakeBotRepository implements BotRepository {
  FakeBotRepository({DateTime Function()? now})
    : _now = now ?? DateTime.now,
      _status = BotStatus(
        state: BotState.inactive,
        mode: BotMode.paper,
        maxCapitalAllocation: parseMoney('1000.00'),
        lastRunAt: null,
        nextRunAt: null,
        openOrders: 3,
        pnlToday: parseMoney('12.50'),
        lastError: null,
        paperDaysCompleted: 0,
        liveAllowed: false,
      ) {
    _orders.addAll(_sampleOrders(_now()));
  }

  final DateTime Function() _now;
  final List<BotOrder> _orders = [];
  late BotStatus _status;
  BotSettings _settings = BotSettings(
    mode: BotMode.paper,
    strategyId: 'dca_v1',
    orderAmount: parseMoney('50.00'),
    intervalHours: 24,
    maxCapitalAllocation: parseMoney('1000.00'),
    maxOrderSize: parseMoney('100.00'),
    maxDailyLoss: parseMoney('50.00'),
    maxTotalLoss: parseMoney('200.00'),
    riskLevel: BotRiskLevel.medium,
    allowedPairs: const ['BTC/USDT', 'ETH/USDT'],
    consent: const BotConsent(accepted: false, version: null),
  );
  int getStatusCalls = 0;
  int startCalls = 0;
  int stopCalls = 0;
  int killCalls = 0;
  int saveSettingsCalls = 0;
  ApiException? _startErrorForTest;
  BotState get stateForTest => _status.state;

  @override
  Future<BotSettings> getSettings() async => _settings;

  @override
  Future<BotSettings> saveSettings(BotSettings settings) async {
    saveSettingsCalls++;
    _settings = BotSettings(
      mode: BotMode.paper,
      strategyId: settings.strategyId,
      orderAmount: settings.orderAmount,
      intervalHours: settings.intervalHours,
      maxCapitalAllocation: settings.maxCapitalAllocation,
      maxOrderSize: settings.maxOrderSize,
      maxDailyLoss: settings.maxDailyLoss,
      maxTotalLoss: settings.maxTotalLoss,
      riskLevel: settings.riskLevel,
      allowedPairs: List.unmodifiable(settings.allowedPairs),
      consent: _settings.consent,
    );
    _status = _copyStatus(maxCapitalAllocation: _settings.maxCapitalAllocation);
    return _settings;
  }

  @override
  Future<BotStatus> getStatus() async {
    getStatusCalls++;
    return _status;
  }

  @override
  Future<BotStatus> start() async {
    startCalls++;
    final injectedError = _startErrorForTest;
    if (injectedError != null) throw injectedError;
    if (_status.state != BotState.inactive &&
        _status.state != BotState.paused) {
      _invalidState();
    }
    _status = _copyStatus(
      state: BotState.running,
      lastRunAt: _now().toUtc(),
      nextRunAt: _now().toUtc().add(Duration(hours: _settings.intervalHours)),
      clearError: true,
    );
    return _status;
  }

  @override
  Future<BotStatus> stop() async {
    stopCalls++;
    if (!{
      BotState.running,
      BotState.paused,
      BotState.error,
      BotState.stoppedByRisk,
    }.contains(_status.state)) {
      _invalidState();
    }
    _status = _copyStatus(
      state: BotState.inactive,
      nextRunAt: null,
      clearError: true,
    );
    return _status;
  }

  @override
  Future<BotStatus> kill() async {
    killCalls++;
    if (!{
      BotState.running,
      BotState.paused,
      BotState.error,
      BotState.stoppedByRisk,
    }.contains(_status.state)) {
      _invalidState();
    }
    for (var index = 0; index < _orders.length; index++) {
      final order = _orders[index];
      if (order.status == BotOrderStatus.open) {
        _orders[index] = _copyOrder(order, status: BotOrderStatus.canceled);
      }
    }
    _status = _copyStatus(
      state: BotState.inactive,
      nextRunAt: null,
      openOrders: 0,
      clearError: true,
    );
    return _status;
  }

  @override
  Future<void> acceptConsent(String version) async {
    _settings = BotSettings(
      mode: _settings.mode,
      strategyId: _settings.strategyId,
      orderAmount: _settings.orderAmount,
      intervalHours: _settings.intervalHours,
      maxCapitalAllocation: _settings.maxCapitalAllocation,
      maxOrderSize: _settings.maxOrderSize,
      maxDailyLoss: _settings.maxDailyLoss,
      maxTotalLoss: _settings.maxTotalLoss,
      riskLevel: _settings.riskLevel,
      allowedPairs: _settings.allowedPairs,
      consent: BotConsent(accepted: true, version: version),
    );
  }

  @override
  Future<Page<BotOrder>> listOrders(
    BotOrderFilter filter, {
    String? cursor,
    int limit = 20,
  }) async {
    if (limit < 1 || limit > 100) {
      throw RangeError.range(limit, 1, 100, 'limit');
    }
    final matching = _orders
        .where((order) {
          if (filter.simulated != null &&
              order.isSimulated != filter.simulated) {
            return false;
          }
          if (filter.pair != null &&
              filter.pair!.isNotEmpty &&
              order.pair != filter.pair) {
            return false;
          }
          final created = DateTime(
            order.createdAt.year,
            order.createdAt.month,
            order.createdAt.day,
          );
          if (filter.from != null &&
              created.isBefore(_dateOnly(filter.from!))) {
            return false;
          }
          if (filter.to != null && created.isAfter(_dateOnly(filter.to!))) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
    final start = cursor == null ? 0 : int.tryParse(cursor) ?? matching.length;
    if (start < 0 || start > matching.length) {
      throw const FormatException('Cursor de ordens inválido.');
    }
    final end = (start + limit).clamp(0, matching.length);
    return Page(
      items: matching.sublist(start, end),
      nextCursor: end < matching.length ? '$end' : null,
    );
  }

  void setStateForTest(BotState state) {
    _status = _copyStatus(
      state: state,
      lastError: state == BotState.error
          ? BotLastError(
              code: 'EXCHANGE_UNAVAILABLE',
              message: 'Erro da corretora.',
              occurredAt: _now().toUtc(),
            )
          : null,
      clearError: state != BotState.error,
    );
  }

  void setStartErrorForTest(ApiException? error) {
    _startErrorForTest = error;
  }

  Never _invalidState() => throw const ApiException(
    code: 'BOT_INVALID_STATE',
    message: 'Ação inválida para o estado atual.',
    statusCode: 409,
  );

  BotStatus _copyStatus({
    BotState? state,
    Decimal? maxCapitalAllocation,
    DateTime? lastRunAt,
    DateTime? nextRunAt,
    int? openOrders,
    Decimal? pnlToday,
    BotLastError? lastError,
    bool clearError = false,
  }) => BotStatus(
    state: state ?? _status.state,
    mode: BotMode.paper,
    maxCapitalAllocation: maxCapitalAllocation ?? _status.maxCapitalAllocation,
    lastRunAt: lastRunAt ?? _status.lastRunAt,
    nextRunAt: nextRunAt,
    openOrders: openOrders ?? _status.openOrders,
    pnlToday: pnlToday ?? _status.pnlToday,
    lastError: clearError ? null : lastError ?? _status.lastError,
    paperDaysCompleted: _status.paperDaysCompleted,
    liveAllowed: false,
  );
}

List<BotOrder> _sampleOrders(DateTime now) {
  final utcNow = now.toUtc();
  const statuses = [
    BotOrderStatus.open,
    BotOrderStatus.filled,
    BotOrderStatus.canceled,
    BotOrderStatus.rejected,
    BotOrderStatus.filled,
    BotOrderStatus.open,
    BotOrderStatus.filled,
    BotOrderStatus.canceled,
    BotOrderStatus.filled,
    BotOrderStatus.rejected,
    BotOrderStatus.filled,
    BotOrderStatus.open,
  ];
  return List.generate(12, (index) {
    final simulated = index % 3 != 0;
    return BotOrder(
      id: 'order-${index + 1}',
      pair: index.isEven ? 'BTC/USDT' : 'ETH/USDT',
      side: index.isEven ? BotOrderSide.buy : BotOrderSide.sell,
      quantity: parseMoney(index.isEven ? '0.010' : '0.250'),
      averagePrice: parseMoney(index.isEven ? '65000.00' : '3200.00'),
      fee: parseMoney('0.10'),
      status: statuses[index],
      isSimulated: simulated,
      exchangeOrderId: simulated ? null : 'exchange-${index + 1}',
      strategyId: 'dca_v1',
      signalReason: 'Compra periódica DCA',
      createdAt: utcNow.subtract(Duration(hours: index * 4)),
    );
  });
}

BotOrder _copyOrder(BotOrder order, {required BotOrderStatus status}) =>
    BotOrder(
      id: order.id,
      pair: order.pair,
      side: order.side,
      quantity: order.quantity,
      averagePrice: order.averagePrice,
      fee: order.fee,
      status: status,
      isSimulated: order.isSimulated,
      exchangeOrderId: order.exchangeOrderId,
      strategyId: order.strategyId,
      signalReason: order.signalReason,
      createdAt: order.createdAt,
    );

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
