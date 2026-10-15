import 'package:controle_ds/core/money/money.dart';
import 'package:controle_ds/core/network/dio_client.dart';
import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final compoundInterestApiProvider = Provider<CompoundInterestApi>(
  (ref) => CompoundInterestApi(ref.watch(dioProvider)),
);

final class CompoundInterestApi {
  const CompoundInterestApi(this._dio);

  final Dio _dio;

  Future<Map<String, Object?>> calculate({
    required Decimal initialAmount,
    required Decimal monthlyContribution,
    required Decimal monthlyRate,
    required int months,
  }) async {
    final response = await _dio.post<Object?>(
      '/calculations/compound-interest',
      data: {
        'initial_amount': moneyToJson(initialAmount),
        'monthly_contribution': moneyToJson(monthlyContribution),
        'monthly_rate': moneyToJson(monthlyRate),
        'months': months,
      },
    );
    final value = response.data;
    if (value is! Map) {
      throw const FormatException('A resposta da API deve ser um objeto.');
    }
    return {
      for (final entry in value.entries)
        if (entry.key is String) entry.key as String: entry.value,
    };
  }
}
