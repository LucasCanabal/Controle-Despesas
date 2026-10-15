import 'package:controle_ds/features/finance/data/fake_finance_repository.dart';
import 'package:controle_ds/features/finance/domain/category.dart';
import 'package:controle_ds/features/finance/domain/transaction.dart';
import 'package:controle_ds/features/finance/domain/transaction_filter.dart';
import 'package:controle_ds/features/finance/presentation/categories_notifier.dart';
import 'package:controle_ds/features/finance/presentation/dashboard_notifier.dart';
import 'package:controle_ds/features/finance/presentation/transactions_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'dashboard loads for the selected month and zero-fills empty months',
    () async {
      final repository = FakeFinanceRepository(
        now: () => DateTime(2026, 10, 6),
      );
      final container = _container(repository);
      addTearDown(container.dispose);

      final current = await container.read(dashboardNotifierProvider.future);
      expect(current.month, '2026-10');
      expect(current.totalIncome.toString(), '5000');

      container.read(selectedMonthProvider.notifier).select('2026-09');
      final emptyMonth = await container.read(dashboardNotifierProvider.future);
      expect(emptyMonth.month, '2026-09');
      expect(emptyMonth.totalIncome.toString(), '0');
      expect(emptyMonth.totalExpense.toString(), '0');
      expect(emptyMonth.monthBalance.toString(), '0');
      expect(emptyMonth.byCategory, isEmpty);
    },
  );

  test('loadMore adds a page without duplicate transaction IDs', () async {
    final repository = FakeFinanceRepository(
      now: () => DateTime(2026, 10, 6),
      pageSize: 2,
    );
    final container = _container(repository);
    addTearDown(container.dispose);
    await container.read(transactionsNotifierProvider.future);

    final notifier = container.read(transactionsNotifierProvider.notifier);
    await notifier.loadMore();
    final state = container.read(transactionsNotifierProvider).requireValue;

    expect(state.items, hasLength(4));
    expect(state.items.map((item) => item.id).toSet(), hasLength(4));
    expect(state.nextCursor, isNull);
  });

  test('setting a transaction filter starts a fresh result page', () async {
    final repository = FakeFinanceRepository(
      now: () => DateTime(2026, 10, 6),
      pageSize: 1,
    );
    final container = _container(repository);
    addTearDown(container.dispose);
    await container.read(transactionsNotifierProvider.future);

    await container
        .read(transactionsNotifierProvider.notifier)
        .setFilter(const TransactionFilter(type: TransactionType.income));
    final state = container.read(transactionsNotifierProvider).requireValue;

    expect(state.items, hasLength(1));
    expect(state.items.single.type, TransactionType.income);
    expect(state.nextCursor, isNull);
  });

  test('category notifier supports create, edit and archive', () async {
    final container = _container(FakeFinanceRepository());
    addTearDown(container.dispose);
    await container.read(categoriesNotifierProvider.future);

    final notifier = container.read(categoriesNotifierProvider.notifier);
    await notifier.create('Saúde');
    var categories = container.read(categoriesNotifierProvider).requireValue;
    final health = categories.firstWhere((item) => item.name == 'Saúde');
    expect(health.archived, isFalse);

    await notifier.updateCategory(
      Category(id: health.id, name: 'Saúde e bem-estar', archived: false),
    );
    await notifier.archive(health.id);
    categories = container.read(categoriesNotifierProvider).requireValue;
    final updated = categories.firstWhere((item) => item.id == health.id);
    expect(updated.name, 'Saúde e bem-estar');
    expect(updated.archived, isTrue);
  });
}

ProviderContainer _container(FakeFinanceRepository repository) =>
    ProviderContainer(
      overrides: [financeRepositoryProvider.overrideWithValue(repository)],
    );
