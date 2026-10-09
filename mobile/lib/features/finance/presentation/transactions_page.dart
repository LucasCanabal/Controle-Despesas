import 'package:controle_ds/core/errors/app_exception.dart';
import 'package:controle_ds/core/errors/error_messages.dart';
import 'package:dio/dio.dart';
import 'package:controle_ds/features/finance/domain/category.dart';
import 'package:controle_ds/features/finance/domain/transaction.dart';
import 'package:controle_ds/features/finance/domain/transaction_filter.dart';
import 'package:controle_ds/features/finance/presentation/categories_notifier.dart';
import 'package:controle_ds/features/finance/presentation/transaction_form_page.dart';
import 'package:controle_ds/features/finance/presentation/transactions_notifier.dart';
import 'package:controle_ds/core/money/money.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class TransactionsPage extends ConsumerStatefulWidget {
  const TransactionsPage({super.key});

  @override
  ConsumerState<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends ConsumerState<TransactionsPage> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadWhenNearEnd);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_loadWhenNearEnd)
      ..dispose();
    super.dispose();
  }

  void _loadWhenNearEnd() {
    if (_scrollController.position.extentAfter < 300) {
      ref.read(transactionsNotifierProvider.notifier).loadMore();
    }
  }

  Future<void> _chooseDate({required bool start}) async {
    final current = ref.read(transactionsNotifierProvider).asData?.value;
    if (current == null) {
      return;
    }
    final filter = current.filter;
    final picked = await showDatePicker(
      context: context,
      initialDate: start
          ? filter.from ?? DateTime.now()
          : filter.to ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      await ref
          .read(transactionsNotifierProvider.notifier)
          .setFilter(
            start ? filter.copyWith(from: picked) : filter.copyWith(to: picked),
          );
    }
  }

  Future<void> _create() async {
    final categories = ref.read(categoriesNotifierProvider).asData?.value ?? [];
    if (!mounted) {
      return;
    }
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => TransactionFormPage(categories: categories),
      ),
    );
    if (saved == true && mounted) {
      await ref.read(transactionsNotifierProvider.notifier).refresh();
    }
  }

  Future<void> _edit(Transaction transaction) async {
    final categories = ref.read(categoriesNotifierProvider).asData?.value ?? [];
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => TransactionFormPage(
          categories: categories,
          transaction: transaction,
        ),
      ),
    );
    if (saved == true && mounted) {
      await ref.read(transactionsNotifierProvider.notifier).refresh();
    }
  }

  Future<void> _delete(Transaction transaction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir transação?'),
        content: Text('Deseja excluir "${transaction.description}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('confirm-delete-transaction'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    try {
      await ref
          .read(transactionsNotifierProvider.notifier)
          .delete(transaction.id);
    } on Object catch (error) {
      if (mounted) {
        _showError(error);
      }
    }
  }

  void _showError(Object error) {
    final source = error is DioException && error.error is Object
        ? error.error!
        : error;
    final message = source is ApiException
        ? messageForCode(source.code)
        : messageForCode('INTERNAL_ERROR');
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _setType(TransactionType? type) async {
    final current = ref.read(transactionsNotifierProvider).asData?.value;
    if (current == null) return;
    await ref
        .read(transactionsNotifierProvider.notifier)
        .setFilter(
          current.filter.copyWith(type: type, clearType: type == null),
        );
  }

  Future<void> _setCategory(String? id) async {
    final current = ref.read(transactionsNotifierProvider).asData?.value;
    if (current == null) return;
    await ref
        .read(transactionsNotifierProvider.notifier)
        .setFilter(
          current.filter.copyWith(categoryId: id, clearCategory: id == null),
        );
  }

  @override
  Widget build(BuildContext context) {
    final transactions = ref.watch(transactionsNotifierProvider);
    final categories = ref.watch(categoriesNotifierProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Transações')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add-transaction'),
        heroTag: 'add-transaction',
        onPressed: categories.isLoading ? null : _create,
        icon: const Icon(Icons.add),
        label: const Text('Nova'),
      ),
      body: transactions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Não foi possível carregar as transações.'),
              TextButton(
                onPressed: () =>
                    ref.read(transactionsNotifierProvider.notifier).refresh(),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
        data: (data) => Column(
          children: [
            _Filters(
              filter: data.filter,
              categories: categories.asData?.value ?? const [],
              onChooseDate: _chooseDate,
              onTypeChanged: _setType,
              onCategoryChanged: _setCategory,
              onClear: () => ref
                  .read(transactionsNotifierProvider.notifier)
                  .setFilter(const TransactionFilter()),
            ),
            Expanded(
              child: data.items.isEmpty
                  ? const Center(
                      key: Key('transactions-empty'),
                      child: Text('Nenhuma transação encontrada.'),
                    )
                  : RefreshIndicator(
                      onRefresh: () => ref
                          .read(transactionsNotifierProvider.notifier)
                          .refresh(),
                      child: ListView.builder(
                        key: const Key('transactions-list'),
                        controller: _scrollController,
                        itemCount:
                            data.items.length +
                            (data.nextCursor != null ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == data.items.length) {
                            return Center(
                              child: data.isLoadingMore
                                  ? const Padding(
                                      padding: EdgeInsets.all(16),
                                      child: CircularProgressIndicator(),
                                    )
                                  : TextButton(
                                      onPressed: () => ref
                                          .read(
                                            transactionsNotifierProvider
                                                .notifier,
                                          )
                                          .loadMore(),
                                      child: Text(
                                        data.loadMoreError == null
                                            ? 'Carregar mais'
                                            : 'Falha ao carregar. Tentar novamente',
                                      ),
                                    ),
                            );
                          }
                          final transaction = data.items[index];
                          return ListTile(
                            key: ValueKey('transaction-${transaction.id}'),
                            leading: Icon(
                              transaction.type == TransactionType.income
                                  ? Icons.south_west
                                  : Icons.north_east,
                            ),
                            title: Text(transaction.description),
                            subtitle: Text(
                              DateFormat.yMd('pt_BR').format(transaction.date),
                            ),
                            onTap: () => _edit(transaction),
                            onLongPress: () => _delete(transaction),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(formatBRL(transaction.amount)),
                                IconButton(
                                  tooltip: 'Excluir',
                                  onPressed: () => _delete(transaction),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.filter,
    required this.categories,
    required this.onChooseDate,
    required this.onTypeChanged,
    required this.onCategoryChanged,
    required this.onClear,
  });

  final TransactionFilter filter;
  final List<Category> categories;
  final Future<void> Function({required bool start}) onChooseDate;
  final ValueChanged<TransactionType?> onTypeChanged;
  final ValueChanged<String?> onCategoryChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => onChooseDate(start: true),
                icon: const Icon(Icons.event),
                label: Text(
                  filter.from == null
                      ? 'De'
                      : DateFormat.yMd('pt_BR').format(filter.from!),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => onChooseDate(start: false),
                icon: const Icon(Icons.event),
                label: Text(
                  filter.to == null
                      ? 'Até'
                      : DateFormat.yMd('pt_BR').format(filter.to!),
                ),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<TransactionType?>(
                key: const Key('transaction-type-filter'),
                initialValue: filter.type,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Todos')),
                  DropdownMenuItem(
                    value: TransactionType.income,
                    child: Text('Receitas'),
                  ),
                  DropdownMenuItem(
                    value: TransactionType.expense,
                    child: Text('Despesas'),
                  ),
                ],
                onChanged: onTypeChanged,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String?>(
                key: const Key('transaction-category-filter'),
                initialValue: filter.categoryId,
                decoration: const InputDecoration(labelText: 'Categoria'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todas')),
                  ...categories
                      .where((category) => !category.archived)
                      .map(
                        (category) => DropdownMenuItem(
                          value: category.id,
                          child: Text(category.name),
                        ),
                      ),
                ],
                onChanged: onCategoryChanged,
              ),
            ),
            IconButton(
              tooltip: 'Limpar filtros',
              onPressed: onClear,
              icon: const Icon(Icons.filter_alt_off),
            ),
          ],
        ),
      ],
    ),
  );
}
