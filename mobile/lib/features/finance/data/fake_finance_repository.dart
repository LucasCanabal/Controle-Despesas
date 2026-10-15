import 'package:controle_ds/core/money/money.dart';
import 'package:controle_ds/core/pagination/page.dart';
import 'package:controle_ds/features/finance/domain/category.dart';
import 'package:controle_ds/features/finance/domain/dashboard_summary.dart';
import 'package:controle_ds/features/finance/domain/finance_repository.dart';
import 'package:controle_ds/features/finance/domain/transaction.dart';
import 'package:controle_ds/features/finance/domain/transaction_filter.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  // TODO: switch to financeRepositoryImplProvider when backend S05/S06 exists.
  return FakeFinanceRepository();
});

class FakeFinanceRepository implements FinanceRepository {
  FakeFinanceRepository({DateTime Function()? now, this.pageSize = 20})
    : _now = now ?? DateTime.now {
    final current = _now();
    _categories.addAll([
      const Category(id: 'cat-home', name: 'Moradia', archived: false),
      const Category(id: 'cat-food', name: 'Alimentação', archived: false),
      const Category(id: 'cat-work', name: 'Salário', archived: false),
      const Category(id: 'cat-transport', name: 'Transporte', archived: false),
    ]);
    _transactions.addAll([
      Transaction(
        id: 'tx-income',
        type: TransactionType.income,
        amount: parseMoney('5000.00'),
        description: 'Salário',
        categoryId: 'cat-work',
        date: DateTime(current.year, current.month, 1),
      ),
      Transaction(
        id: 'tx-rent',
        type: TransactionType.expense,
        amount: parseMoney('1800.00'),
        description: 'Aluguel',
        categoryId: 'cat-home',
        date: DateTime(current.year, current.month, 3),
      ),
      Transaction(
        id: 'tx-food',
        type: TransactionType.expense,
        amount: parseMoney('325.50'),
        description: 'Mercado',
        categoryId: 'cat-food',
        date: DateTime(current.year, current.month, 5),
      ),
      Transaction(
        id: 'tx-transport',
        type: TransactionType.expense,
        amount: parseMoney('85.00'),
        description: 'Transporte',
        categoryId: 'cat-transport',
        date: DateTime(current.year, current.month, 7),
      ),
    ]);
  }

  final DateTime Function() _now;
  final int pageSize;
  final List<Category> _categories = [];
  final List<Transaction> _transactions = [];
  int _nextId = 1;

  @override
  Future<DashboardSummary> getSummary(String month) async {
    final selected = DateTime.parse('$month-01');
    final inMonth = _transactions.where(
      (item) =>
          item.date.year == selected.year && item.date.month == selected.month,
    );
    final income = inMonth
        .where((item) => item.type == TransactionType.income)
        .fold(Decimal.zero, (sum, item) => sum + item.amount);
    final expenses = inMonth
        .where((item) => item.type == TransactionType.expense)
        .fold(Decimal.zero, (sum, item) => sum + item.amount);
    final throughMonth = _transactions.where(
      (item) =>
          item.date.isBefore(DateTime(selected.year, selected.month + 1, 1)),
    );
    final cumulative = throughMonth.fold(
      Decimal.zero,
      (sum, item) => item.type == TransactionType.income
          ? sum + item.amount
          : sum - item.amount,
    );
    final categoryTotals = <String, Decimal>{};
    for (final transaction in inMonth.where(
      (item) => item.type == TransactionType.expense,
    )) {
      final categoryId = transaction.categoryId;
      if (categoryId != null) {
        categoryTotals.update(
          categoryId,
          (value) => value + transaction.amount,
          ifAbsent: () => transaction.amount,
        );
      }
    }
    final categoryById = {for (final item in _categories) item.id: item};
    final byCategory = categoryTotals.entries
        .map((entry) {
          final category = categoryById[entry.key];
          if (category == null) {
            return null;
          }
          return CategoryTotal(
            categoryId: category.id,
            name: category.name,
            total: entry.value,
          );
        })
        .whereType<CategoryTotal>()
        .toList(growable: false);
    final recent = inMonth.toList()..sort((a, b) => b.date.compareTo(a.date));
    return DashboardSummary(
      month: month,
      totalIncome: income,
      totalExpense: expenses,
      monthBalance: income - expenses,
      cumulativeBalance: cumulative,
      byCategory: byCategory,
      recentTransactions: recent.take(5).toList(growable: false),
    );
  }

  @override
  Future<Page<Transaction>> listTransactions(
    TransactionFilter filter, {
    String? cursor,
  }) async {
    final filtered = _transactions.where((item) {
      if (filter.from != null && item.date.isBefore(_dateOnly(filter.from!))) {
        return false;
      }
      if (filter.to != null && item.date.isAfter(_dateOnly(filter.to!))) {
        return false;
      }
      if (filter.type != null && item.type != filter.type) {
        return false;
      }
      if (filter.categoryId != null && item.categoryId != filter.categoryId) {
        return false;
      }
      return true;
    }).toList()..sort((a, b) => b.date.compareTo(a.date));
    final start = cursor == null ? 0 : int.tryParse(cursor) ?? filtered.length;
    final end = (start + pageSize).clamp(0, filtered.length);
    final items = start >= filtered.length
        ? <Transaction>[]
        : filtered.sublist(start, end);
    return Page(
      items: items,
      nextCursor: end < filtered.length ? '$end' : null,
    );
  }

  @override
  Future<Transaction> create(TransactionDraft draft) async {
    final transaction = Transaction(
      id: 'tx-${_nextId++}',
      type: draft.type,
      amount: draft.amount,
      description: draft.description,
      categoryId: draft.categoryId,
      date: _dateOnly(draft.date),
    );
    _transactions.add(transaction);
    return transaction;
  }

  @override
  Future<Transaction> update(String id, TransactionDraft draft) async {
    final index = _transactions.indexWhere((item) => item.id == id);
    if (index < 0) {
      throw StateError('Transação não encontrada.');
    }
    final transaction = Transaction(
      id: id,
      type: draft.type,
      amount: draft.amount,
      description: draft.description,
      categoryId: draft.categoryId,
      date: _dateOnly(draft.date),
    );
    _transactions[index] = transaction;
    return transaction;
  }

  @override
  Future<void> delete(String id) async {
    _transactions.removeWhere((item) => item.id == id);
  }

  @override
  Future<List<Category>> listCategories() async =>
      List.unmodifiable(_categories);

  @override
  Future<Category> createCategory(String name) async {
    final category = Category(
      id: 'cat-${_nextId++}',
      name: name,
      archived: false,
    );
    _categories.add(category);
    return category;
  }

  @override
  Future<Category> updateCategory(Category category) async {
    final index = _categories.indexWhere((item) => item.id == category.id);
    if (index < 0) {
      throw StateError('Categoria não encontrada.');
    }
    _categories[index] = category;
    return category;
  }

  @override
  Future<void> archiveCategory(String id) async {
    final index = _categories.indexWhere((item) => item.id == id);
    if (index < 0) {
      throw StateError('Categoria não encontrada.');
    }
    final category = _categories[index];
    _categories[index] = Category(
      id: category.id,
      name: category.name,
      archived: true,
    );
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}
