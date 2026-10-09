import 'package:controle_ds/core/money/money.dart';
import 'package:controle_ds/features/finance/domain/transaction.dart';
import 'package:decimal/decimal.dart';

final class DashboardSummary {
  const DashboardSummary({
    required this.month,
    required this.totalIncome,
    required this.totalExpense,
    required this.monthBalance,
    required this.cumulativeBalance,
    required this.byCategory,
    required this.recentTransactions,
  });

  final String month;
  final Decimal totalIncome;
  final Decimal totalExpense;
  final Decimal monthBalance;
  final Decimal cumulativeBalance;
  final List<CategoryTotal> byCategory;
  final List<Transaction> recentTransactions;

  factory DashboardSummary.fromJson(Map<String, Object?> json) {
    final month = json['month'];
    final income = json['total_income'];
    final expense = json['total_expense'];
    final monthBalance = json['month_balance'];
    final cumulativeBalance = json['cumulative_balance'];
    final rawCategories = json['by_category'];
    final rawTransactions = json['recent_transactions'];
    if (month is! String ||
        income is! String ||
        expense is! String ||
        monthBalance is! String ||
        cumulativeBalance is! String ||
        rawCategories is! List ||
        rawTransactions is! List) {
      throw const FormatException('Formato de resumo financeiro inválido.');
    }
    return DashboardSummary(
      month: month,
      totalIncome: parseMoney(income),
      totalExpense: parseMoney(expense),
      monthBalance: parseMoney(monthBalance),
      cumulativeBalance: parseMoney(cumulativeBalance),
      byCategory: rawCategories
          .map((value) => CategoryTotal.fromJson(_objectMap(value)))
          .toList(growable: false),
      recentTransactions: rawTransactions
          .map((value) => Transaction.fromJson(_objectMap(value)))
          .toList(growable: false),
    );
  }
}

final class CategoryTotal {
  const CategoryTotal({
    required this.categoryId,
    required this.name,
    required this.total,
  });

  final String categoryId;
  final String name;
  final Decimal total;

  factory CategoryTotal.fromJson(Map<String, Object?> json) {
    final categoryId = json['category_id'];
    final name = json['name'];
    final total = json['total'];
    if (categoryId is! String || name is! String || total is! String) {
      throw const FormatException('Formato de total por categoria inválido.');
    }
    return CategoryTotal(
      categoryId: categoryId,
      name: name,
      total: parseMoney(total),
    );
  }
}

Map<String, Object?> _objectMap(Object? value) {
  if (value is! Map) {
    throw const FormatException('O item da resposta deve ser um objeto.');
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
