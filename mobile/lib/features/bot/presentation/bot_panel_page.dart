import 'package:controle_ds/core/errors/app_exception.dart';
import 'package:controle_ds/core/errors/error_messages.dart';
import 'package:controle_ds/core/money/money.dart';
import 'package:controle_ds/features/bot/presentation/bot_orders_page.dart';
import 'package:controle_ds/features/bot/domain/bot_settings.dart';
import 'package:controle_ds/features/bot/domain/bot_state.dart';
import 'package:controle_ds/features/bot/presentation/bot_panel_notifier.dart';
import 'package:controle_ds/features/bot/presentation/bot_settings_page.dart';
import 'package:controle_ds/features/bot/presentation/kill_switch_button.dart';
import 'package:controle_ds/features/exchange/data/fake_exchange_repository.dart';
import 'package:controle_ds/features/exchange/domain/exchange_status.dart';
import 'package:dio/dio.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class BotPanelPage extends ConsumerWidget {
  const BotPanelPage({super.key});

  Future<void> _openScreen(
    BuildContext context,
    WidgetRef ref,
    Widget page,
  ) async {
    ref.read(botPanelNotifierProvider.notifier).setFocused(false);
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
    if (context.mounted) {
      ref.read(botPanelNotifierProvider.notifier).setFocused(true);
    }
  }

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    BotStatus status,
    bool enabled,
  ) async {
    try {
      final notifier = ref.read(botPanelNotifierProvider.notifier);
      if (enabled) {
        final info = await ref.read(exchangeRepositoryProvider).getInfo();
        if (!context.mounted) return;
        if (info?.status != ExchangeStatus.connected) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Conecte uma corretora com credencial válida antes de ativar o robô.',
              ),
            ),
          );
          return;
        }
        if (status.state == BotState.inactive ||
            status.state == BotState.paused) {
          await notifier.start();
        }
      } else if (status.state == BotState.running ||
          status.state == BotState.paused) {
        await notifier.stop();
      }
    } on Object catch (error) {
      if (context.mounted) _showError(context, _apiCode(error));
    }
  }

  Future<void> _acknowledge(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(botPanelNotifierProvider.notifier).stop();
    } on Object catch (error) {
      if (context.mounted) _showError(context, _apiCode(error));
    }
  }

  void _showError(BuildContext context, String code) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(messageForCode(code))));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(botPanelNotifierProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Robô'),
        actions: [
          IconButton(
            key: const Key('bot-settings'),
            tooltip: 'Configurações',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _openScreen(context, ref, const BotSettingsPage()),
          ),
        ],
      ),
      body: status.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(messageForCode(_apiCode(error))),
              TextButton(
                onPressed: () =>
                    ref.read(botPanelNotifierProvider.notifier).refresh(),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
        data: (data) => ListView(
          key: const Key('bot-panel-content'),
          padding: const EdgeInsets.all(16),
          children: [
            const MaterialBanner(
              key: Key('bot-risk-warning'),
              leading: Icon(Icons.warning_amber),
              content: Text(
                'Robôs podem gerar perdas. O modo PAPER é uma simulação e '
                'não envia ordens reais.',
              ),
              actions: [SizedBox.shrink()],
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estado: ${_stateLabel(data.state)}',
                      key: const Key('bot-state'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<BotMode>(
                      key: const Key('bot-mode'),
                      initialValue: BotMode.paper,
                      decoration: const InputDecoration(labelText: 'Modo'),
                      items: const [
                        DropdownMenuItem(
                          value: BotMode.paper,
                          child: Text('PAPER — simulação'),
                        ),
                        DropdownMenuItem(
                          value: BotMode.live,
                          enabled: false,
                          child: Text('LIVE — indisponível nesta fase'),
                        ),
                      ],
                      onChanged: (value) {},
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Capital alocado: '
                      '${formatUSDT(data.maxCapitalAllocation)}',
                    ),
                    Text('Ordens abertas: ${data.openOrders}'),
                    if (data.lastRunAt != null)
                      Text('Última execução: ${_formatDate(data.lastRunAt!)}'),
                    if (data.nextRunAt != null)
                      Text('Próxima execução: ${_formatDate(data.nextRunAt!)}'),
                    _PnlToday(value: data.pnlToday),
                    if (data.lastError != null && data.state == BotState.error)
                      ListTile(
                        key: const Key('bot-last-error'),
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.error_outline),
                        title: Text(messageForCode(data.lastError!.code)),
                      ),
                    SwitchListTile(
                      key: const Key('bot-enable-switch'),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Ativar robô'),
                      value: {
                        BotState.running,
                        BotState.starting,
                        BotState.paused,
                      }.contains(data.state),
                      onChanged: _canToggle(data.state)
                          ? (value) => _toggle(context, ref, data, value)
                          : null,
                    ),
                    if (data.state == BotState.error ||
                        data.state == BotState.stoppedByRisk)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          key: const Key('bot-acknowledge-stop'),
                          onPressed: () => _acknowledge(context, ref),
                          child: const Text('Reconhecer e desativar'),
                        ),
                      ),
                    if (data.state == BotState.paused)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          key: const Key('bot-resume'),
                          onPressed: () => _toggle(context, ref, data, true),
                          child: const Text('Retomar'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                KillSwitchButton(
                  enabled: {
                    BotState.running,
                    BotState.paused,
                    BotState.error,
                    BotState.stoppedByRisk,
                  }.contains(data.state),
                ),
                OutlinedButton.icon(
                  key: const Key('bot-open-orders'),
                  onPressed: () =>
                      _openScreen(context, ref, const BotOrdersPage()),
                  icon: const Icon(Icons.history),
                  label: const Text('Histórico de ordens'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PnlToday extends StatelessWidget {
  const _PnlToday({required this.value});

  final Decimal value;

  @override
  Widget build(BuildContext context) {
    final positive = value >= Decimal.zero;
    final color = positive
        ? Colors.green.shade700
        : Theme.of(context).colorScheme.error;
    return Row(
      children: [
        Icon(positive ? Icons.trending_up : Icons.trending_down, color: color),
        const SizedBox(width: 6),
        Text(
          'P&L de hoje: ${formatUSDT(value)}',
          key: const Key('bot-pnl-today'),
          style: TextStyle(color: color),
        ),
      ],
    );
  }
}

bool _canToggle(BotState state) => switch (state) {
  BotState.inactive || BotState.running || BotState.paused => true,
  BotState.starting || BotState.stoppedByRisk || BotState.error => false,
};

String _stateLabel(BotState state) => switch (state) {
  BotState.inactive => 'Inativo',
  BotState.starting => 'Iniciando',
  BotState.running => 'Em execução',
  BotState.paused => 'Pausado',
  BotState.stoppedByRisk => 'Parado por risco',
  BotState.error => 'Erro',
};

String _apiCode(Object error) {
  if (error is ApiException) return error.code;
  if (error is DioException && error.error is ApiException) {
    return (error.error as ApiException).code;
  }
  return 'INTERNAL_ERROR';
}

String _formatDate(DateTime value) =>
    DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(value.toLocal());
