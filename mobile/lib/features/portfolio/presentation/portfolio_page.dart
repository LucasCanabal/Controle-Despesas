import 'package:controle_ds/core/errors/app_exception.dart';
import 'package:controle_ds/core/errors/error_messages.dart';
import 'package:controle_ds/core/money/money.dart';
import 'package:controle_ds/features/portfolio/domain/portfolio.dart';
import 'package:controle_ds/features/portfolio/presentation/portfolio_notifier.dart';
import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PortfolioPage extends ConsumerWidget {
  const PortfolioPage({super.key});

  Future<void> _sync(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(portfolioNotifierProvider.notifier).sync();
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(messageForCode(_apiCode(error) ?? 'INTERNAL_ERROR')),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final portfolio = ref.watch(portfolioNotifierProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Carteira')),
      body: portfolio.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Não foi possível carregar a carteira.'),
              TextButton(
                onPressed: () => ref.invalidate(portfolioNotifierProvider),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
        data: (data) => RefreshIndicator(
          key: const Key('portfolio-refresh'),
          onRefresh: () => _sync(context, ref),
          child: _PortfolioContent(portfolio: data),
        ),
      ),
    );
  }
}

class _PortfolioContent extends StatelessWidget {
  const _PortfolioContent({required this.portfolio});

  final Portfolio portfolio;

  @override
  Widget build(BuildContext context) => ListView(
    key: const Key('portfolio-content'),
    padding: const EdgeInsets.all(16),
    children: [
      if (portfolio.stale)
        const MaterialBanner(
          key: Key('portfolio-stale-warning'),
          content: Text(
            'Os dados da carteira estão desatualizados. '
            'Puxe a tela para atualizar.',
          ),
          leading: Icon(Icons.warning_amber),
          actions: [SizedBox.shrink()],
        ),
      Text('Valor total', style: Theme.of(context).textTheme.titleMedium),
      Text(
        '${_formatDisplay(portfolio.totalValueDisplay, portfolio.displayCurrency)}'
        ' (${formatUSDT(portfolio.totalValueUsdt)})',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 8),
      _PnlRow(
        label: 'P&L total',
        value: portfolio.totalPnl,
        percent: portfolio.totalPnlPercent,
        currency: portfolio.displayCurrency,
      ),
      const SizedBox(height: 16),
      Text('Ativos', style: Theme.of(context).textTheme.titleLarge),
      if (portfolio.assets.isEmpty)
        const ListTile(title: Text('Nenhum ativo na carteira.'))
      else
        ...portfolio.assets.map(
          (asset) => Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(asset.symbol, style: Theme.of(context).textTheme.titleMedium),
                  Text('Quantidade: ${asset.quantity}'),
                  Text('Preço médio: ${formatUSDT(asset.averagePrice)}'),
                  Text('Preço atual: ${formatUSDT(asset.currentPrice)}'),
                  Text('Valor atual: ${formatUSDT(asset.currentValue)}'),
                  _PnlRow(
                    label: 'P&L',
                    value: asset.pnl,
                    percent: asset.pnlPercent,
                    currency: 'USDT',
                  ),
                ],
              ),
            ),
          ),
        ),
    ],
  );
}

class _PnlRow extends StatelessWidget {
  const _PnlRow({
    required this.label,
    required this.value,
    required this.percent,
    required this.currency,
  });

  final String label;
  final Decimal value;
  final Decimal? percent;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final positive = value >= Decimal.zero;
    final color = positive ? Colors.green.shade700 : Theme.of(context).colorScheme.error;
    return Row(
      children: [
        Icon(
          positive ? Icons.trending_up : Icons.trending_down,
          color: color,
          size: 20,
        ),
        const SizedBox(width: 6),
        Text(
          '$label: ${_formatDisplay(value, currency)} '
          '(${percent == null ? '-' : '${percent!.toString()}%'})',
          style: TextStyle(color: color),
        ),
      ],
    );
  }
}

String _formatDisplay(Decimal value, String currency) =>
    '${value.toStringAsFixed(2)} $currency';

String? _apiCode(Object error) {
  if (error is ApiException) return error.code;
  if (error is DioException && error.error is ApiException) {
    return (error.error as ApiException).code;
  }
  return null;
}
