import 'package:controle_ds/features/finance/data/fake_finance_repository.dart';
import 'package:controle_ds/features/finance/domain/finance_repository.dart';
import 'package:controle_ds/features/finance/domain/transaction.dart';
import 'package:controle_ds/features/finance/domain/transaction_filter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final transactionsNotifierProvider =
    AsyncNotifierProvider<TransactionsNotifier, TransactionsState>(
      TransactionsNotifier.new,
    );

final class TransactionsState {
  const TransactionsState({
    required this.items,
    required this.filter,
    required this.nextCursor,
    this.isLoadingMore = false,
    this.loadMoreError,
  });

  final List<Transaction> items;
  final TransactionFilter filter;
  final String? nextCursor;
  final bool isLoadingMore;
  final Object? loadMoreError;

  TransactionsState copyWith({
    List<Transaction>? items,
    TransactionFilter? filter,
    String? nextCursor,
    bool clearCursor = false,
    bool? isLoadingMore,
    Object? loadMoreError,
    bool clearLoadMoreError = false,
  }) => TransactionsState(
    items: items ?? this.items,
    filter: filter ?? this.filter,
    nextCursor: clearCursor ? null : nextCursor ?? this.nextCursor,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    loadMoreError: clearLoadMoreError
        ? null
        : loadMoreError ?? this.loadMoreError,
  );
}

class TransactionsNotifier extends AsyncNotifier<TransactionsState> {
  late FinanceRepository _repository;
  int _requestGeneration = 0;

  @override
  Future<TransactionsState> build() async {
    _repository = ref.watch(financeRepositoryProvider);
    const filter = TransactionFilter();
    final page = await _repository.listTransactions(filter);
    return TransactionsState(
      items: page.items,
      filter: filter,
      nextCursor: page.nextCursor,
    );
  }

  Future<void> loadMore() async {
    final current = state.asData?.value;
    if (current == null ||
        current.nextCursor == null ||
        current.isLoadingMore) {
      return;
    }
    final generation = _requestGeneration;
    state = AsyncData(
      current.copyWith(isLoadingMore: true, clearLoadMoreError: true),
    );
    try {
      final page = await _repository.listTransactions(
        current.filter,
        cursor: current.nextCursor,
      );
      if (generation != _requestGeneration) {
        return;
      }
      final byId = <String, Transaction>{
        for (final item in current.items) item.id: item,
        for (final item in page.items) item.id: item,
      };
      state = AsyncData(
        current.copyWith(
          items: byId.values.toList(growable: false),
          nextCursor: page.nextCursor,
          clearCursor: page.nextCursor == null,
          isLoadingMore: false,
          clearLoadMoreError: true,
        ),
      );
    } on Object catch (error) {
      if (generation != _requestGeneration) {
        return;
      }
      state = AsyncData(
        current.copyWith(isLoadingMore: false, loadMoreError: error),
      );
    }
  }

  Future<void> setFilter(TransactionFilter filter) async {
    _requestGeneration++;
    state = const AsyncLoading<TransactionsState>();
    state = await AsyncValue.guard(() async {
      final page = await _repository.listTransactions(filter);
      return TransactionsState(
        items: page.items,
        filter: filter,
        nextCursor: page.nextCursor,
      );
    });
  }

  Future<void> refresh() async {
    _requestGeneration++;
    final current = state.asData?.value;
    final filter = current?.filter ?? const TransactionFilter();
    state = const AsyncLoading<TransactionsState>();
    state = await AsyncValue.guard(() async {
      final page = await _repository.listTransactions(filter);
      return TransactionsState(
        items: page.items,
        filter: filter,
        nextCursor: page.nextCursor,
      );
    });
  }

  Future<void> delete(String id) async {
    await _repository.delete(id);
    await refresh();
  }

  Future<Transaction> saveCreate(TransactionDraft draft) async {
    return _repository.create(draft);
  }

  Future<Transaction> saveUpdate(String id, TransactionDraft draft) async {
    return _repository.update(id, draft);
  }
}
