import 'package:controle_ds/core/pagination/page.dart';
import 'package:controle_ds/features/finance/domain/category.dart';
import 'package:controle_ds/features/finance/domain/dashboard_summary.dart';
import 'package:controle_ds/features/finance/domain/transaction.dart';
import 'package:controle_ds/features/finance/domain/transaction_filter.dart';

abstract interface class FinanceRepository {
  Future<DashboardSummary> getSummary(String month);

  Future<Page<Transaction>> listTransactions(
    TransactionFilter filter, {
    String? cursor,
  });

  Future<Transaction> create(TransactionDraft draft);

  Future<Transaction> update(String id, TransactionDraft draft);

  Future<void> delete(String id);

  Future<List<Category>> listCategories();

  Future<Category> createCategory(String name);

  Future<Category> updateCategory(Category category);

  Future<void> archiveCategory(String id);
}
