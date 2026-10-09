import 'dart:convert';
import 'dart:typed_data';

import 'package:controle_ds/core/money/money.dart';
import 'package:controle_ds/features/bot/data/bot_api.dart';
import 'package:controle_ds/features/bot/domain/bot_order_filter.dart';
import 'package:controle_ds/features/bot/domain/bot_settings.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BotApi calls bot settings/status/action/consent/order routes', () async {
    final adapter = _BotAdapter();
    final dio = _dio(adapter);
    final api = BotApi(dio);
    final settings = _settings(mode: BotMode.live);

    await api.getSettings();
    await api.saveSettings(settings);
    await api.getStatus();
    await api.start();
    await api.stop();
    await api.kill();
    await api.acceptConsent('2026-10');
    await api.listOrders(
      BotOrderFilter(
        simulated: true,
        pair: 'BTC/USDT',
        from: DateTime(2026, 10, 1),
        to: DateTime(2026, 10, 31),
      ),
      cursor: 'cursor-1',
      limit: 25,
    );

    expect(
      adapter.requests
          .map((request) => '${request.method} ${request.path}'),
      [
        'GET /bot/settings',
        'PUT /bot/settings',
        'GET /bot/status',
        'POST /bot/start',
        'POST /bot/stop',
        'POST /bot/kill',
        'POST /bot/consent',
        'GET /bot/orders',
      ],
    );
    expect(adapter.requests[1].body, {
      'mode': 'PAPER',
      'strategy_id': 'dca_v1',
      'strategy_params': {'order_amount': '50', 'interval_hours': 24},
      'max_capital_allocation': '1000',
      'max_order_size': '100',
      'max_daily_loss': '50',
      'max_total_loss': '200',
      'risk_level': 'HIGH',
      'allowed_pairs': ['BTC/USDT'],
    });
    expect(adapter.requests[3].body, isNull);
    expect(adapter.requests[4].body, isNull);
    expect(adapter.requests[5].body, isNull);
    expect(adapter.requests[6].body, {'version': '2026-10'});
    expect(adapter.requests.last.query, {
      'simulated': true,
      'pair': 'BTC/USDT',
      'from': '2026-10-01',
      'to': '2026-10-31',
      'cursor': 'cursor-1',
      'limit': 25,
    });
    dio.close();
  });

  test('BotApi serializes every state and monetary field correctly', () {
    final settings = BotSettings.fromJson({
      ..._settings(mode: BotMode.paper).toJson(),
      'risk_level': 'MEDIUM',
      'consent': {'accepted': false, 'version': null},
    });
    expect(settings.mode, BotMode.paper);
    expect(settings.maxCapitalAllocation, parseMoney('1000'));

    final api = BotApi(Dio());
    final status = api.parseStatus(_statusJson('RUNNING'));
    expect(status.state.name, 'running');
    expect(status.pnlToday, parseMoney('12.50'));
    final page = api.parseOrders({
      'items': [_orderJson('order-1')],
      'next_cursor': null,
    });
    expect(page.items.single.isSimulated, isTrue);
    expect(page.items.single.quantity, parseMoney('0.01'));
  });
}

BotSettings _settings({required BotMode mode}) => BotSettings(
  mode: mode,
  strategyId: 'dca_v1',
  orderAmount: parseMoney('50'),
  intervalHours: 24,
  maxCapitalAllocation: parseMoney('1000'),
  maxOrderSize: parseMoney('100'),
  maxDailyLoss: parseMoney('50'),
  maxTotalLoss: parseMoney('200'),
  riskLevel: BotRiskLevel.high,
  allowedPairs: const ['BTC/USDT'],
  consent: const BotConsent(accepted: true, version: '2026-10'),
);

Map<String, Object?> _statusJson(String state) => {
  'state': state,
  'mode': 'PAPER',
  'max_capital_allocation': '1000.00',
  'last_run_at': null,
  'next_run_at': null,
  'open_orders': 1,
  'pnl_today': '12.50',
  'last_error': null,
  'paper_days_completed': 0,
  'live_allowed': false,
};

Map<String, Object?> _settingsJson() => {
  'mode': 'PAPER',
  'strategy_id': 'dca_v1',
  'strategy_params': {'order_amount': '50.00', 'interval_hours': 24},
  'max_capital_allocation': '1000.00',
  'max_order_size': '100.00',
  'max_daily_loss': '50.00',
  'max_total_loss': '200.00',
  'risk_level': 'MEDIUM',
  'allowed_pairs': ['BTC/USDT'],
  'consent': {'accepted': false, 'version': null},
};

Map<String, Object?> _orderJson(String id) => {
  'id': id,
  'pair': 'BTC/USDT',
  'side': 'BUY',
  'quantity': '0.010',
  'avg_price': '65000.00',
  'fee': '0.10',
  'status': 'FILLED',
  'is_simulated': true,
  'exchange_order_id': null,
  'strategy_id': 'dca_v1',
  'signal_reason': 'Compra periódica DCA',
  'created_at': '2026-10-06T13:00:00Z',
};

Dio _dio(_BotAdapter adapter) =>
    Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'))
      ..httpClientAdapter = adapter;

class _RecordedRequest {
  const _RecordedRequest(
    this.method,
    this.path,
    this.query,
    this.body,
  );

  final String method;
  final String path;
  final Map<String, Object?> query;
  final Map<String, Object?>? body;
}

class _BotAdapter implements HttpClientAdapter {
  final requests = <_RecordedRequest>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(
      _RecordedRequest(
        options.method,
        options.path,
        Map<String, Object?>.from(options.queryParameters),
        _bodyMap(options.data),
      ),
    );
    if (options.path == '/bot/settings') return _json(_settingsJson());
    if (options.path == '/bot/orders') {
      return _json({
        'items': [_orderJson('order-1')],
        'next_cursor': null,
      });
    }
    if (options.path == '/bot/consent') return ResponseBody.fromString('', 204);
    final state = options.method == 'POST' && options.path == '/bot/start'
        ? 'RUNNING'
        : 'INACTIVE';
    return _json(_statusJson(state));
  }

  ResponseBody _json(Object value) => ResponseBody.fromString(
    jsonEncode(value),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

Map<String, Object?>? _bodyMap(Object? value) {
  if (value is Map) {
    return {
      for (final entry in value.entries) entry.key as String: entry.value,
    };
  }
  return null;
}
