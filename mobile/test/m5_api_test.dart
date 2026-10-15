import 'dart:convert';
import 'dart:typed_data';

import 'package:controle_ds/core/money/money.dart';
import 'package:controle_ds/features/calculator/data/compound_interest_api.dart';
import 'package:controle_ds/features/exchange/data/exchange_api.dart';
import 'package:controle_ds/features/portfolio/data/portfolio_api.dart';
import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('exchange API sends only documented routes and request fields', () async {
    final adapter = _RecordingAdapter();
    final dio = _dio(adapter);
    final api = ExchangeApi(dio);

    await api.saveCredentials('binance-key-1234', 'private-secret');
    await api.getCredentials();
    await api.deleteCredentials();

    expect(
      adapter.requests.map((request) => '${request.method} ${request.path}'),
      [
        'PUT /exchange/credentials',
        'GET /exchange/credentials',
        'DELETE /exchange/credentials',
      ],
    );
    expect(adapter.requests.first.body, {
      'exchange': 'BINANCE',
      'api_key': 'binance-key-1234',
      'api_secret': 'private-secret',
    });
    dio.close();
  });

  test('portfolio API uses GET and bodyless POST endpoints', () async {
    final adapter = _RecordingAdapter();
    final dio = _dio(adapter);
    final api = PortfolioApi(dio);

    await api.getPortfolio();
    await api.sync();

    expect(
      adapter.requests.map((request) => '${request.method} ${request.path}'),
      ['GET /portfolio', 'POST /portfolio/sync'],
    );
    expect(adapter.requests.last.body, isNull);
    dio.close();
  });

  test('compound-interest API sends decimal strings and integer months', () async {
    final adapter = _RecordingAdapter();
    final dio = _dio(adapter);
    final api = CompoundInterestApi(dio);

    await api.calculate(
      initialAmount: parseMoney('100.00'),
      monthlyContribution: parseMoney('25.50'),
      monthlyRate: Decimal.zero,
      months: 12,
    );

    expect(
      adapter.requests.single.method,
      'POST',
    );
    expect(
      adapter.requests.single.path,
      '/calculations/compound-interest',
    );
    expect(adapter.requests.single.body, {
      'initial_amount': '100',
      'monthly_contribution': '25.5',
      'monthly_rate': '0',
      'months': 12,
    });
    dio.close();
  });
}

Dio _dio(_RecordingAdapter adapter) =>
    Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'))
      ..httpClientAdapter = adapter;

class _Request {
  const _Request(this.method, this.path, this.body);

  final String method;
  final String path;
  final Map<String, Object?>? body;
}

class _RecordingAdapter implements HttpClientAdapter {
  final requests = <_Request>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = _parseBody(options.data);
    requests.add(_Request(options.method, options.path, body));
    if (options.method == 'DELETE') {
      return ResponseBody.fromString('', 204);
    }
    if (options.path == '/exchange/credentials') {
      return _json({
        'status': 'CONNECTED',
        'key_hint': '…1234',
        'last_checked_at': '2026-10-06T13:00:00Z',
      });
    }
    if (options.path == '/portfolio' ||
        options.path == '/portfolio/sync') {
      return _json({
        'total_value_usdt': '10.00',
        'total_value_display': '10.00',
        'display_currency': 'USDT',
        'total_pnl': '1.00',
        'total_pnl_percent': null,
        'stale': false,
        'last_synced_at': null,
        'assets': [],
      });
    }
    return _json({
      'final_value': '10.00',
      'total_invested': '9.00',
      'total_interest': '1.00',
    });
  }

  ResponseBody _json(Object value) => ResponseBody.fromString(
    jsonEncode(value),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  Map<String, Object?>? _parseBody(Object? value) {
    if (value is Map) {
      return {
        for (final entry in value.entries) entry.key as String: entry.value,
      };
    }
    return null;
  }

  @override
  void close({bool force = false}) {}
}
