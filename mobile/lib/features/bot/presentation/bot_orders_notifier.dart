import 'package:controle_ds/core/pagination/page.dart';
import 'package:controle_ds/features/bot/data/fake_bot_repository.dart';
import 'package:controle_ds/features/bot/domain/bot_order.dart';
import 'package:controle_ds/features/bot/domain/bot_order_filter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _ordersPageSize = 5;

final botOrdersNotifierProvider =
    AsyncNotifierProvider<BotOrdersNotifier, Page<BotOrder>>(
      BotOrdersNotifier.new,
    );

class BotOrdersNotifier extends AsyncNotifier<Page<BotOrder>> {
  BotOrderFilter _filter = const BotOrderFilter();
  bool _loadingMore = false;
  String? get nextCursor => state.asData?.value.nextCursor;
  bool get isLoadingMore => _loadingMore;

  @override
  Future<Page<BotOrder>> build() =>
      ref.watch(botRepositoryProvider).listOrders(
        _filter,
        limit: _ordersPageSize,
      );

  Future<void> setFilter(BotOrderFilter filter) async {
    if (_filter == filter) return;
    _filter = filter;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(botRepositoryProvider)
          .listOrders(_filter, limit: _ordersPageSize),
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(botRepositoryProvider)
          .listOrders(_filter, limit: _ordersPageSize),
    );
  }

  Future<void> loadMore() async {
    final cursor = nextCursor;
    if (cursor == null || _loadingMore || state.asData == null) return;
    _loadingMore = true;
    try {
      final next = await ref
          .read(botRepositoryProvider)
          .listOrders(_filter, cursor: cursor, limit: _ordersPageSize);
      final current = state.requireValue;
      final knownIds = current.items.map((order) => order.id).toSet();
      final appended = [
        ...current.items,
        ...next.items.where((order) => knownIds.add(order.id)),
      ];
      state = AsyncData(Page(items: appended, nextCursor: next.nextCursor));
    } finally {
      _loadingMore = false;
    }
  }
}
