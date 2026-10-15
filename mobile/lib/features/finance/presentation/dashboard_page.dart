import 'package:controle_ds/core/money/money.dart';
import 'package:controle_ds/features/finance/presentation/dashboard_notifier.dart';
import 'package:controle_ds/features/finance/domain/dashboard_summary.dart';
import 'package:controle_ds/features/finance/domain/transaction.dart';
import 'package:decimal/decimal.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  Future<void> _chooseMonth(BuildContext context, WidgetRef ref) async {
    final selected = DateTime.parse('${ref.read(selectedMonthProvider)}-01');
    final picked = await showDatePicker(
      context: context,
      initialDate: selected,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Selecione um mês',
    );
    if (picked != null) {
      ref
          .read(selectedMonthProvider.notifier)
          .select(
            '${picked.year.toString().padLeft(4, '0')}-'
            '${picked.month.toString().padLeft(2, '0')}',
          );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(dashboardNotifierProvider);
    final month = ref.watch(selectedMonthProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resumo financeiro'),
        actions: [
          IconButton(
            key: const Key('dashboard-select-month'),
            tooltip: 'Selecionar mês',
            onPressed: () => _chooseMonth(context, ref),
            icon: const Icon(Icons.calendar_month),
          ),
        ],
      ),
      body: summary.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _ErrorView(
          onRetry: () => ref.read(dashboardNotifierProvider.notifier).refresh(),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () =>
              ref.read(dashboardNotifierProvider.notifier).refresh(),
          child: ListView(
            key: const Key('dashboard-content'),
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: Text(
                  DateFormat(
                    'MMMM yyyy',
                    'pt_BR',
                  ).format(DateTime.parse('$month-01')),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 16),
              _SummaryCards(summary: data),
              const SizedBox(height: 24),
              Text(
                'Despesas por categoria',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              _CategoryChart(summary: data),
              const SizedBox(height: 24),
              Text(
                'Últimas transações',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              if (data.recentTransactions.isEmpty)
                const ListTile(
                  key: Key('dashboard-empty-transactions'),
                  title: Text('Nenhuma transação neste mês.'),
                )
              else
                ...data.recentTransactions.map(
                  (transaction) =>
                      _RecentTransactionTile(transaction: transaction),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 12,
    children: [
      _SummaryCard(
        label: 'Receitas',
        value: formatBRL(summary.totalIncome),
        icon: Icons.south_west,
      ),
      _SummaryCard(
        label: 'Despesas',
        value: formatBRL(summary.totalExpense),
        icon: Icons.north_east,
      ),
      _SummaryCard(
        label: 'Saldo do mês',
        value: formatBRL(summary.monthBalance),
        icon: Icons.calendar_view_month,
      ),
      _SummaryCard(
        label: 'Saldo acumulado',
        value: formatBRL(summary.cumulativeBalance),
        icon: Icons.account_balance_wallet_outlined,
      ),
    ],
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 164,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 10),
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    ),
  );
}

class _CategoryChart extends StatelessWidget {
  const _CategoryChart({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    if (summary.byCategory.isEmpty) {
      return const SizedBox(
        height: 120,
        child: Center(child: Text('Sem dados de categorias neste mês.')),
      );
    }
    final total = summary.byCategory.fold(
      Decimal.zero,
      (sum, category) => sum + category.total,
    );
    final palette = [
      Theme.of(context).colorScheme.primary,
      Theme.of(context).colorScheme.tertiary,
      Theme.of(context).colorScheme.secondary,
      Theme.of(context).colorScheme.error,
      Theme.of(context).colorScheme.primaryContainer,
    ];
    return Column(
      children: [
        SizedBox(
          height: 190,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 35,
              sections: [
                for (var index = 0; index < summary.byCategory.length; index++)
                  PieChartSectionData(
                    value: total == Decimal.zero
                        ? 1
                        : (summary.byCategory[index].total / total).toDouble(),
                    color: palette[index % palette.length],
                    title: '',
                    radius: 62,
                  ),
              ],
            ),
          ),
        ),
        ...summary.byCategory.indexed.map((entry) {
          final category = entry.$2;
          return ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 7,
              backgroundColor: palette[entry.$1 % palette.length],
            ),
            title: Text(category.name),
            trailing: Text(formatBRL(category.total)),
          );
        }),
      ],
    );
  }
}

class _RecentTransactionTile extends StatelessWidget {
  const _RecentTransactionTile({required this.transaction});

  final Transaction transaction;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(
      transaction.type == TransactionType.income
          ? Icons.south_west
          : Icons.north_east,
    ),
    title: Text(transaction.description),
    subtitle: Text(DateFormat.yMd('pt_BR').format(transaction.date)),
    trailing: Text(formatBRL(transaction.amount)),
  );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Não foi possível carregar o resumo financeiro.'),
        const SizedBox(height: 12),
        FilledButton(onPressed: onRetry, child: const Text('Tentar novamente')),
      ],
    ),
  );
}
