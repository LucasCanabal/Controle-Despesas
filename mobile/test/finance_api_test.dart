import 'dart:convert';
import 'dart:typed_data';

import 'package:controle_ds/core/money/money.dart';
import 'package:controle_ds/features/finance/data/finance_api.dart';
import 'package:controle_ds/features/finance/domain/transaction.dart';
import 'package:controle_ds/features/finance/domain/transaction_filter.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses documented transaction and category endpoint shapes', () async {
    final adapter = _FinanceAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'))
      ..httpClientAdapter = adapter;
    final api = FinanceApi(dio);

    await api.getSummary('2026-10');
    await api.listTransactions(
      TransactionFilter(
        from: DateTime(2026, 10, 1),
        to: DateTime(2026, 10, 31),
        type: TransactionType.expense,
        categoryId: 'cat-1',
      ),
      cursor: 'cursor-1',
      limit: 25,
    );
    await api.createTransaction(
      TransactionDraft(
        type: TransactionType.expense,
        amount: parseMoney('150.75'),
        description: 'Conta de Luz',
        categoryId: 'cat-1',
        date: DateTime(2026, 10, 5),
      ),
    );
    await api.updateTransaction(
      'tx-1',
      TransactionDraft(
        type: TransactionType.income,
        amount: parseMoney('200.00'),
        description: 'Reembolso',
        categoryId: 'cat-2',
        date: DateTime(2026, 10, 6),
      ),
    );
    await api.deleteTransaction('tx-1');
    await api.listCategories();
    await api.createCategory('Saúde');
    await api.updateCategory('cat-1', name: 'Casa', archived: false);
    await api.archiveCategory('cat-1');

    expect(adapter.requests.map((item) => item.path), [
      '/dashboard/summary',
      '/transactions',
      '/transactions',
      '/transactions/tx-1',
      '/transactions/tx-1',
      '/categories',
      '/categories',
      '/categories/cat-1',
      '/categories/cat-1',
    ]);
    expect(adapter.requests[0].queryParameters, {'month': '2026-10'});
    expect(adapter.requests[1].queryParameters, {
      'from': '2026-10-01',
      'to': '2026-10-31',
      'type': 'EXPENSE',
      'category_id': 'cat-1',
      'cursor': 'cursor-1',
      'limit': 25,
    });
    expect(adapter.requests[2].body, {
      'type': 'EXPENSE',
      'amount': '150.75',
      'description': 'Conta de Luz',
      'category_id': 'cat-1',
      'date': '2026-10-05',
    });
    expect(adapter.requests[3].method, 'PATCH');
    expect(adapter.requests[4].method, 'DELETE');
    expect(adapter.requests[6].body, {'name': 'Saúde'});
    expect(adapter.requests[7].body, {'name': 'Casa', 'archived': false});
    expect(adapter.requests[8].method, 'DELETE');
    expect(adapter.deleteStatuses, [204, 204]);
    dio.close();
  });

  test('rejects pagination limits outside the contract maximum', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'));
    final api = FinanceApi(dio);

    await expectLater(
      api.listTransactions(const TransactionFilter(), limit: 101),
      throwsRangeError,
    );
  });
}

class _RecordedRequest {
  const _RecordedRequest(
    this.method,
    this.path,
    this.queryParameters,
    this.body,
  );

  final String method;
  final String path;
  final Map<String, Object?> queryParameters;
  final Map<String, Object?>? body;
}

class _FinanceAdapter implements HttpClientAdapter {
  final requests = <_RecordedRequest>[];
  final deleteStatuses = <int>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = _bodyMap(options.data);
    requests.add(
      _RecordedRequest(
        options.method,
        options.path,
        Map<String, Object?>.from(options.queryParameters),
        body,
      ),
    );
    if (options.method == 'DELETE') {
      deleteStatuses.add(204);
      return ResponseBody.fromString('', 204);
    }
    if (options.path == '/dashboard/summary') {
      return _json({
        'month': '2026-10',
        'total_income': '0',
        'total_expense': '0',
        'month_balance': '0',
        'cumulative_balance': '0',
        'by_category': [],
        'recent_transactions': [],
      });
    }
    if (options.path == '/transactions' && options.method == 'GET') {
      return _json({'items': [], 'next_cursor': null});
    }
    if (options.path == '/categories' && options.method == 'GET') {
      return _json({'items': []});
    }
    return _json({
      'id': 'tx-1',
      'type': 'EXPENSE',
      'amount': '150.75',
      'description': 'Conta de Luz',
      'category_id': 'cat-1',
      'date': '2026-10-05',
    });
  }

  ResponseBody _json(Object value) => ResponseBody.fromString(
    jsonEncode(value),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  Map<String, Object?>? _bodyMap(Object? value) {
    if (value is Map) {
      return {
        for (final entry in value.entries) entry.key as String: entry.value,
      };
    }
    if (value is String) {
      final decoded = jsonDecode(value);
      if (decoded is Map) {
        return {
          for (final entry in decoded.entries) entry.key as String: entry.value,
        };
      }
    }
    return null;
  }

  @override
  void close({bool force = false}) {}
}
