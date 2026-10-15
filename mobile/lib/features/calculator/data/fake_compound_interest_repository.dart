import 'package:controle_ds/features/calculator/domain/compound_interest_repository.dart';
import 'package:controle_ds/features/calculator/domain/compound_interest_result.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final compoundInterestRepositoryProvider = Provider<CompoundInterestRepository>(
  (ref) {
    // TODO: switch to compoundInterestRepositoryImplProvider when backend
    // S11 exists.
    return FakeCompoundInterestRepository();
  },
);

final class FakeCompoundInterestRepository
    implements CompoundInterestRepository {
  @override
  Future<CompoundInterestResult> calculate({
    required Decimal initialAmount,
    required Decimal monthlyContribution,
    required Decimal monthlyRate,
    required int months,
  }) async {
    // Demonstration only: production calculations belong to the API.
    final monthlyFraction = (monthlyRate / Decimal.fromInt(100)).toDecimal(
      scaleOnInfinitePrecision: 8,
    );
    var value = initialAmount;
    for (var month = 0; month < months; month++) {
      value = (value + value * monthlyFraction).round(scale: 2);
      value = (value + monthlyContribution).round(scale: 2);
    }
    final invested =
        (initialAmount + monthlyContribution * Decimal.fromInt(months)).round(
          scale: 2,
        );
    return CompoundInterestResult(
      finalValue: value,
      totalInvested: invested,
      totalInterest: (value - invested).round(scale: 2),
    );
  }
}
