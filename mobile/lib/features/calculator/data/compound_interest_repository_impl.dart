import 'package:controle_ds/features/calculator/data/compound_interest_api.dart';
import 'package:controle_ds/features/calculator/domain/compound_interest_repository.dart';
import 'package:controle_ds/features/calculator/domain/compound_interest_result.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final compoundInterestRepositoryImplProvider =
    Provider<CompoundInterestRepository>(
      (ref) => CompoundInterestRepositoryImpl(
        ref.watch(compoundInterestApiProvider),
      ),
    );

final class CompoundInterestRepositoryImpl
    implements CompoundInterestRepository {
  const CompoundInterestRepositoryImpl(this._api);

  final CompoundInterestApi _api;

  @override
  Future<CompoundInterestResult> calculate({
    required Decimal initialAmount,
    required Decimal monthlyContribution,
    required Decimal monthlyRate,
    required int months,
  }) async => CompoundInterestResult.fromJson(
    await _api.calculate(
      initialAmount: initialAmount,
      monthlyContribution: monthlyContribution,
      monthlyRate: monthlyRate,
      months: months,
    ),
  );
}
