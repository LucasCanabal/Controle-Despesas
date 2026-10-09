import 'package:controle_ds/features/calculator/domain/compound_interest_result.dart';
import 'package:decimal/decimal.dart';

abstract interface class CompoundInterestRepository {
  Future<CompoundInterestResult> calculate({
    required Decimal initialAmount,
    required Decimal monthlyContribution,
    required Decimal monthlyRate,
    required int months,
  });
}
