import 'package:controle_ds/core/errors/app_exception.dart';
import 'package:controle_ds/core/errors/error_messages.dart';
import 'package:controle_ds/core/money/money.dart';
import 'package:controle_ds/features/bot/domain/bot_order.dart';
import 'package:controle_ds/features/bot/domain/bot_order_filter.dart';
import 'package:controle_ds/features/bot/presentation/bot_orders_notifier.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class BotOrdersPage extends ConsumerStatefulWidget {
  const BotOrdersPage({super.key});

  @override
  ConsumerState<BotOrdersPage> createState() => _BotOrdersPageState();
}

class _BotOrdersPageState extends ConsumerState<BotOrdersPage> {
  final _pairController = TextEditingController();
  bool? _simulated;
  String? _pair;
  DateTime? _from;
  DateTime? _to;

  @override
  void dispose() {
    _pairController.dispose();
    super.dispose();
  }

  BotOrderFilter get _filter =>
      BotOrderFilter(simulated: _simulated, pair: _pair, from: _from, to: _to);

  Future<void> _selectDate({required bool from}) async {
    final date = await showDatePicker(
      context: context,
      initialDate: from ? _from ?? DateTime.now() : _to ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    setState(() {
      if (from) {
        _from = date;
      } else {
        _to = date;
      }
    });
    await ref.read(botOrdersNotifierProvider.notifier).setFilter(_filter);
  }

  Future<void> _setFilter(BotOrderFilter filter) async {
    setState(() {
      _simulated = filter.simulated;
      _pair = filter.pair;
      _pairController.text = filter.pair ?? '';
      _from = filter.from;
      _to = filter.to;
    });
    await ref.read(botOrdersNotifierProvider.notifier).setFilter(filter);
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(botOrdersNotifierProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Histórico de ordens')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DropdownButton<bool?>(
                  key: const Key('bot-orders-simulated-filter'),
                  value: _simulated,
                  hint: const Text('Tipo'),
                  items: const [
                    DropdownMenuItem<bool?>(value: null, child: Text('Todas')),
                    DropdownMenuItem<bool?>(
                      value: true,
                      child: Text('Simuladas'),
                    ),
                    DropdownMenuItem<bool?>(value: false, child: Text('Reais')),
                  ],
                  onChanged: (value) => _setFilter(
                    BotOrderFilter(
                      simulated: value,
                      pair: _pair,
                      from: _from,
                      to: _to,
                    ),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: TextField(
                    key: const Key('bot-orders-pair-filter'),
                    controller: _pairController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Par',
                      hintText: 'BTC/USDT',
                    ),
                    onSubmitted: (value) => _setFilter(
                      BotOrderFilter(
                        simulated: _simulated,
                        pair: value.trim().isEmpty
                            ? null
                            : value.trim().toUpperCase(),
                        from: _from,
                        to: _to,
                      ),
                    ),
                  ),
                ),
                OutlinedButton(
                  key: const Key('bot-orders-from-date'),
                  onPressed: () => _selectDate(from: true),
                  child: Text(
                    _from == null
                        ? 'De'
                        : DateFormat('dd/MM/yyyy').format(_from!),
                  ),
                ),
                OutlinedButton(
                  key: const Key('bot-orders-to-date'),
                  onPressed: () => _selectDate(from: false),
                  child: Text(
                    _to == null ? 'Até' : DateFormat('dd/MM/yyyy').format(_to!),
                  ),
                ),
                TextButton(
                  key: const Key('bot-orders-clear-filters'),
                  onPressed: () => _setFilter(const BotOrderFilter()),
                  child: const Text('Limpar'),
                ),
              ],
            ),
          ),
          Expanded(
            child: orders.when(
              loading: () => const Center(
                key: Key('bot-orders-loading'),
                child: CircularProgressIndicator(),
              ),
              error: (error, stackTrace) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(messageForCode(_apiCode(error))),
                    TextButton(
                      onPressed: () => ref
                          .read(botOrdersNotifierProvider.notifier)
                          .refresh(),
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
              data: (page) {
                if (page.items.isEmpty) {
                  return const Center(
                    key: Key('bot-orders-empty'),
                    child: Text('Nenhuma ordem encontrada.'),
                  );
                }
                return ListView(
                  key: const Key('bot-orders-list'),
                  children: [
                    ...page.items.map((order) => _OrderTile(order: order)),
                    if (page.nextCursor != null)
                      Center(
                        child: TextButton(
                          key: const Key('bot-orders-load-more'),
                          onPressed:
                              ref
                                  .read(botOrdersNotifierProvider.notifier)
                                  .isLoadingMore
                              ? null
                              : () => _loadMore(context),
                          child: const Text('Carregar mais'),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadMore(BuildContext context) async {
    try {
      await ref.read(botOrdersNotifierProvider.notifier).loadMore();
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(messageForCode(_apiCode(error)))),
        );
      }
    }
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.order});

  final BotOrder order;

  @override
  Widget build(BuildContext context) => Card(
    key: ValueKey('bot-order-${order.id}'),
    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    child: ListTile(
      title: Row(
        children: [
          Expanded(
            child: Text(
              '${order.pair} · ${order.side == BotOrderSide.buy ? 'Compra' : 'Venda'}',
            ),
          ),
          if (order.isSimulated)
            const Chip(
              key: Key('simulated-order-label'),
              label: Text('Simulada'),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${order.status.name.toUpperCase()} · ${order.quantity} · '
            '${formatUSDT(order.averagePrice)} · Taxa: ${formatUSDT(order.fee)} · '
            '${DateFormat('dd/MM/yyyy HH:mm').format(order.createdAt.toLocal())}',
          ),
          Text('Estratégia: ${order.strategyId} · ${order.signalReason}'),
          if (order.exchangeOrderId != null)
            Text('ID na corretora: ${order.exchangeOrderId}'),
        ],
      ),
      isThreeLine: true,
    ),
  );
}

String _apiCode(Object error) {
  if (error is ApiException) return error.code;
  if (error is DioException && error.error is ApiException) {
    return (error.error as ApiException).code;
  }
  return 'INTERNAL_ERROR';
}
