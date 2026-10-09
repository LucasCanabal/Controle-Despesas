import 'package:controle_ds/features/finance/data/fake_finance_repository.dart';
import 'package:controle_ds/features/finance/domain/dashboard_summary.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

String _currentMonth() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}';
}

final selectedMonthProvider = NotifierProvider<SelectedMonthNotifier, String>(
  SelectedMonthNotifier.new,
);

class SelectedMonthNotifier extends Notifier<String> {
  @override
  String build() => _currentMonth();

  void select(String month) {
    if (!RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(month)) {
      throw FormatException('Mês inválido: $month');
    }
    state = month;
  }
}

final dashboardNotifierProvider =
    AsyncNotifierProvider<DashboardNotifier, DashboardSummary>(
      DashboardNotifier.new,
    );

class DashboardNotifier extends AsyncNotifier<DashboardSummary> {
  @override
  Future<DashboardSummary> build() {
    final month = ref.watch(selectedMonthProvider);
    return ref.watch(financeRepositoryProvider).getSummary(month);
  }

  Future<void> refresh() async {
    state = const AsyncLoading<DashboardSummary>();
    state = await AsyncValue.guard(
      () => ref
          .read(financeRepositoryProvider)
          .getSummary(ref.read(selectedMonthProvider)),
    );
  }
}
