import 'package:controle_ds/core/money/money.dart';
import 'package:decimal/decimal.dart';

final class CompoundInterestResult {
  const CompoundInterestResult({
    required this.finalValue,
    required this.totalInvested,
    required this.totalInterest,
  });

  final Decimal finalValue;
  final Decimal totalInvested;
  final Decimal totalInterest;

  factory CompoundInterestResult.fromJson(Map<String, Object?> json) {
    final finalValue = json['final_value'];
    final totalInvested = json['total_invested'];
    final totalInterest = json['total_interest'];
    if (finalValue is! String ||
        totalInvested is! String ||
        totalInterest is! String) {
      throw const FormatException('Formato do resultado inválido.');
    }
    return CompoundInterestResult(
      finalValue: parseMoney(finalValue),
      totalInvested: parseMoney(totalInvested),
      totalInterest: parseMoney(totalInterest),
    );
  }
}
