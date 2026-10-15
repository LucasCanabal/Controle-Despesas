import 'package:controle_ds/core/pagination/page.dart';
import 'package:controle_ds/features/finance/data/finance_api.dart';
import 'package:controle_ds/features/finance/domain/category.dart';
import 'package:controle_ds/features/finance/domain/dashboard_summary.dart';
import 'package:controle_ds/features/finance/domain/finance_repository.dart';
import 'package:controle_ds/features/finance/domain/transaction.dart';
import 'package:controle_ds/features/finance/domain/transaction_filter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final financeRepositoryImplProvider = Provider<FinanceRepository>(
  (ref) => FinanceRepositoryImpl(ref.watch(financeApiProvider)),
);

class FinanceRepositoryImpl implements FinanceRepository {
  const FinanceRepositoryImpl(this._api);

  final FinanceApi _api;

  @override
  Future<DashboardSummary> getSummary(String month) async =>
      _api.parseSummary(await _api.getSummary(month));

  @override
  Future<Page<Transaction>> listTransactions(
    TransactionFilter filter, {
    String? cursor,
  }) async => _api.parseTransactions(
    await _api.listTransactions(filter, cursor: cursor),
  );

  @override
  Future<Transaction> create(TransactionDraft draft) async =>
      Transaction.fromJson(await _api.createTransaction(draft));

  @override
  Future<Transaction> update(String id, TransactionDraft draft) async =>
      Transaction.fromJson(await _api.updateTransaction(id, draft));

  @override
  Future<void> delete(String id) => _api.deleteTransaction(id);

  @override
  Future<List<Category>> listCategories() async =>
      _api.parseCategories(await _api.listCategories());

  @override
  Future<Category> createCategory(String name) async {
    await _api.createCategory(name);
    return _categoryByName(name);
  }

  @override
  Future<Category> updateCategory(Category category) async {
    await _api.updateCategory(
      category.id,
      name: category.name,
      archived: category.archived,
    );
    return _categoryById(category.id);
  }

  @override
  Future<void> archiveCategory(String id) => _api.archiveCategory(id);

  Future<Category> _categoryByName(String name) async {
    final categories = await listCategories();
    return categories.firstWhere((category) => category.name == name);
  }

  Future<Category> _categoryById(String id) async {
    final categories = await listCategories();
    return categories.firstWhere((category) => category.id == id);
  }
}
