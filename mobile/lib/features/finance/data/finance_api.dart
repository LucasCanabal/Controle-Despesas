import 'package:controle_ds/core/network/dio_client.dart';
import 'package:controle_ds/core/pagination/page.dart';
import 'package:controle_ds/features/finance/domain/category.dart';
import 'package:controle_ds/features/finance/domain/dashboard_summary.dart';
import 'package:controle_ds/features/finance/domain/transaction.dart';
import 'package:controle_ds/features/finance/domain/transaction_filter.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final financeApiProvider = Provider<FinanceApi>(
  (ref) => FinanceApi(ref.watch(dioProvider)),
);

class FinanceApi {
  const FinanceApi(this._dio);

  final Dio _dio;

  Future<Map<String, Object?>> getSummary(String month) async =>
      _objectResponse(
        await _dio.get<Object?>(
          '/dashboard/summary',
          queryParameters: {'month': month},
        ),
      );

  Future<Map<String, Object?>> listTransactions(
    TransactionFilter filter, {
    String? cursor,
    int limit = 50,
  }) async {
    if (limit < 1 || limit > 100) {
      throw RangeError.range(limit, 1, 100, 'limit');
    }
    final query = <String, Object?>{'limit': limit};
    if (filter.from != null) {
      query['from'] = _dateOnly(filter.from!);
    }
    if (filter.to != null) {
      query['to'] = _dateOnly(filter.to!);
    }
    if (filter.type != null) {
      query['type'] = filter.type!.apiValue;
    }
    if (filter.categoryId != null) {
      query['category_id'] = filter.categoryId;
    }
    if (cursor != null) {
      query['cursor'] = cursor;
    }
    return _objectResponse(
      await _dio.get<Object?>('/transactions', queryParameters: query),
    );
  }

  Future<Map<String, Object?>> createTransaction(
    TransactionDraft draft,
  ) async => _objectResponse(
    await _dio.post<Object?>('/transactions', data: draft.toJson()),
  );

  Future<Map<String, Object?>> updateTransaction(
    String id,
    TransactionDraft draft,
  ) async => _objectResponse(
    await _dio.patch<Object?>('/transactions/$id', data: draft.toJson()),
  );

  Future<void> deleteTransaction(String id) async {
    await _dio.delete<void>('/transactions/$id');
  }

  Future<Map<String, Object?>> listCategories() async =>
      _objectResponse(await _dio.get<Object?>('/categories'));

  Future<void> createCategory(String name) async {
    await _dio.post<void>('/categories', data: {'name': name});
  }

  Future<void> updateCategory(String id, {String? name, bool? archived}) async {
    final body = <String, Object?>{};
    if (name != null) {
      body['name'] = name;
    }
    if (archived != null) {
      body['archived'] = archived;
    }
    await _dio.patch<void>('/categories/$id', data: body);
  }

  Future<void> archiveCategory(String id) async {
    await _dio.delete<void>('/categories/$id');
  }

  DashboardSummary parseSummary(Map<String, Object?> json) =>
      DashboardSummary.fromJson(json);

  Page<Transaction> parseTransactions(Map<String, Object?> json) =>
      Page<Transaction>.fromJson(json, Transaction.fromJson);

  List<Category> parseCategories(Map<String, Object?> json) {
    final rawItems = json['items'];
    if (rawItems is! List) {
      throw const FormatException('Formato de categorias inválido.');
    }
    return rawItems
        .map((item) => Category.fromJson(_objectMap(item)))
        .toList(growable: false);
  }

  Map<String, Object?> _objectResponse(Response<Object?> response) =>
      _objectMap(response.data);
}

Map<String, Object?> _objectMap(Object? value) {
  if (value is! Map) {
    throw const FormatException('A resposta da API deve ser um objeto.');
  }
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) {
      throw const FormatException('As chaves da resposta devem ser strings.');
    }
    result[entry.key as String] = entry.value;
  }
  return result;
}

String _dateOnly(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
