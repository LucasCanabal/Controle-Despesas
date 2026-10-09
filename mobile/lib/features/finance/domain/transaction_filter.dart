import 'package:controle_ds/features/finance/domain/transaction.dart';

final class TransactionFilter {
  const TransactionFilter({this.from, this.to, this.type, this.categoryId});

  final DateTime? from;
  final DateTime? to;
  final TransactionType? type;
  final String? categoryId;

  TransactionFilter copyWith({
    DateTime? from,
    DateTime? to,
    TransactionType? type,
    String? categoryId,
    bool clearFrom = false,
    bool clearTo = false,
    bool clearType = false,
    bool clearCategory = false,
  }) => TransactionFilter(
    from: clearFrom ? null : from ?? this.from,
    to: clearTo ? null : to ?? this.to,
    type: clearType ? null : type ?? this.type,
    categoryId: clearCategory ? null : categoryId ?? this.categoryId,
  );
}
