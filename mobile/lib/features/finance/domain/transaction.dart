import 'package:controle_ds/core/money/money.dart';
import 'package:decimal/decimal.dart';

enum TransactionType {
  income('INCOME'),
  expense('EXPENSE');

  const TransactionType(this.apiValue);

  final String apiValue;

  static TransactionType fromApi(String value) => switch (value) {
    'INCOME' => TransactionType.income,
    'EXPENSE' => TransactionType.expense,
    _ => throw FormatException('Tipo de transação inválido: $value'),
  };
}

final class Transaction {
  const Transaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.categoryId,
    required this.date,
  });

  final String id;
  final TransactionType type;
  final Decimal amount;
  final String description;
  final String? categoryId;
  final DateTime date;

  factory Transaction.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final type = json['type'];
    final amount = json['amount'];
    final description = json['description'];
    final categoryId = json['category_id'];
    final date = json['date'];
    if (id is! String ||
        type is! String ||
        amount is! String ||
        description is! String ||
        (categoryId != null && categoryId is! String) ||
        date is! String) {
      throw const FormatException('Formato de transação inválido.');
    }
    return Transaction(
      id: id,
      type: TransactionType.fromApi(type),
      amount: parseMoney(amount),
      description: description,
      categoryId: categoryId as String?,
      date: DateTime.parse(date),
    );
  }

  Map<String, Object?> toJson() => {
    'type': type.apiValue,
    'amount': moneyToJson(amount),
    'description': description,
    'category_id': categoryId,
    'date': _dateOnly(date),
  };
}

final class TransactionDraft {
  const TransactionDraft({
    required this.type,
    required this.amount,
    required this.description,
    required this.categoryId,
    required this.date,
  });

  final TransactionType type;
  final Decimal amount;
  final String description;
  final String categoryId;
  final DateTime date;

  Map<String, Object?> toJson() => {
    'type': type.apiValue,
    'amount': moneyToJson(amount),
    'description': description,
    'category_id': categoryId,
    'date': _dateOnly(date),
  };
}

String _dateOnly(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
