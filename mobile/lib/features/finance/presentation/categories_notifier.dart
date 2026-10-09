import 'package:controle_ds/features/finance/data/fake_finance_repository.dart';
import 'package:controle_ds/features/finance/domain/category.dart';
import 'package:controle_ds/features/finance/domain/finance_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final categoriesNotifierProvider =
    AsyncNotifierProvider<CategoriesNotifier, List<Category>>(
      CategoriesNotifier.new,
    );

class CategoriesNotifier extends AsyncNotifier<List<Category>> {
  late FinanceRepository _repository;

  @override
  Future<List<Category>> build() {
    _repository = ref.watch(financeRepositoryProvider);
    return _repository.listCategories();
  }

  Future<void> create(String name) async {
    await _runMutation(() async {
      await _repository.createCategory(name);
    });
  }

  Future<void> updateCategory(Category category) async {
    await _runMutation(() async {
      await _repository.updateCategory(category);
    });
  }

  Future<void> archive(String id) async {
    await _runMutation(() async {
      await _repository.archiveCategory(id);
    });
  }

  Future<void> refresh() async {
    state = const AsyncLoading<List<Category>>();
    state = await AsyncValue.guard(_repository.listCategories);
  }

  Future<void> _runMutation(Future<void> Function() action) async {
    try {
      await action();
      state = AsyncData(await _repository.listCategories());
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}
