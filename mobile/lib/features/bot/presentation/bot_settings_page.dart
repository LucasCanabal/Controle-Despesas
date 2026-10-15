import 'package:controle_ds/core/errors/app_exception.dart';
import 'package:controle_ds/core/errors/error_messages.dart';
import 'package:controle_ds/core/money/money.dart';
import 'package:controle_ds/features/bot/data/fake_bot_repository.dart';
import 'package:controle_ds/features/bot/domain/bot_settings.dart';
import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final botSettingsProvider = FutureProvider<BotSettings?>((ref) async {
  try {
    return await ref.watch(botRepositoryProvider).getSettings();
  } on Object catch (error) {
    if (_apiCode(error) == 'NOT_FOUND') return null;
    rethrow;
  }
});

class BotSettingsPage extends ConsumerStatefulWidget {
  const BotSettingsPage({super.key});

  @override
  ConsumerState<BotSettingsPage> createState() => _BotSettingsPageState();
}

class _BotSettingsPageState extends ConsumerState<BotSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _capital = TextEditingController();
  final _orderAmount = TextEditingController();
  final _intervalHours = TextEditingController();
  final _maxOrder = TextEditingController();
  final _dailyLoss = TextEditingController();
  final _totalLoss = TextEditingController();
  final _pairs = TextEditingController();
  BotRiskLevel _riskLevel = BotRiskLevel.medium;
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _capital.dispose();
    _orderAmount.dispose();
    _intervalHours.dispose();
    _maxOrder.dispose();
    _dailyLoss.dispose();
    _totalLoss.dispose();
    _pairs.dispose();
    super.dispose();
  }

  void _populate(BotSettings? settings) {
    if (_initialized) return;
    _initialized = true;
    final value = settings ??
        BotSettings(
          mode: BotMode.paper,
          strategyId: 'dca_v1',
          orderAmount: parseMoney('50.00'),
          intervalHours: 24,
          maxCapitalAllocation: parseMoney('1000.00'),
          maxOrderSize: parseMoney('100.00'),
          maxDailyLoss: parseMoney('50.00'),
          maxTotalLoss: parseMoney('200.00'),
          riskLevel: BotRiskLevel.medium,
          allowedPairs: const ['BTC/USDT', 'ETH/USDT'],
          consent: const BotConsent(accepted: false, version: null),
        );
    _capital.text = value.maxCapitalAllocation.toString();
    _orderAmount.text = value.orderAmount.toString();
    _intervalHours.text = value.intervalHours.toString();
    _maxOrder.text = value.maxOrderSize.toString();
    _dailyLoss.text = value.maxDailyLoss.toString();
    _totalLoss.text = value.maxTotalLoss.toString();
    _pairs.text = value.allowedPairs.join(', ');
    _riskLevel = value.riskLevel;
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    final pairs = _pairs.text
        .split(',')
        .map((pair) => pair.trim())
        .where((pair) => pair.isNotEmpty)
        .toList(growable: false);
    setState(() => _saving = true);
    try {
      await ref.read(botRepositoryProvider).saveSettings(
        BotSettings(
          mode: BotMode.paper,
          strategyId: 'dca_v1',
          orderAmount: _parseDecimal(_orderAmount.text),
          intervalHours: int.parse(_intervalHours.text.trim()),
          maxCapitalAllocation: _parseDecimal(_capital.text),
          maxOrderSize: _parseDecimal(_maxOrder.text),
          maxDailyLoss: _parseDecimal(_dailyLoss.text),
          maxTotalLoss: _parseDecimal(_totalLoss.text),
          riskLevel: _riskLevel,
          allowedPairs: pairs,
          consent: const BotConsent(accepted: false, version: null),
        ),
      );
      ref.invalidate(botSettingsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configuração salva em modo PAPER.')),
        );
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(messageForCode(_apiCode(error)))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(botSettingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações do robô')),
      body: settings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(messageForCode(_apiCode(error))),
              TextButton(
                onPressed: () => ref.invalidate(botSettingsProvider),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
        data: (value) {
          _populate(value);
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                DropdownButtonFormField<BotMode>(
                  key: const Key('bot-settings-mode'),
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
                      child: Text('LIVE — será liberado em fase futura'),
                    ),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) {
                          if (value == BotMode.paper) {
                            setState(() {});
                          }
                        },
                ),
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.info_outline),
                  title: Text(
                    'O modo real (LIVE) será liberado em uma fase futura.',
                  ),
                ),
                _positiveDecimalField(
                  key: const Key('bot-capital'),
                  controller: _capital,
                  label: 'Capital máximo alocado (USDT)',
                ),
                _positiveDecimalField(
                  key: const Key('bot-order-amount'),
                  controller: _orderAmount,
                  label: 'Valor da ordem DCA (USDT)',
                ),
                TextFormField(
                  key: const Key('bot-interval-hours'),
                  controller: _intervalHours,
                  enabled: !_saving,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Intervalo entre ordens (horas)',
                  ),
                  validator: (value) {
                    final interval = int.tryParse(value?.trim() ?? '');
                    return interval == null || interval < 1
                        ? 'Informe pelo menos 1 hora.'
                        : null;
                  },
                ),
                _positiveDecimalField(
                  key: const Key('bot-max-order'),
                  controller: _maxOrder,
                  label: 'Tamanho máximo da ordem (USDT)',
                ),
                _positiveDecimalField(
                  key: const Key('bot-max-daily-loss'),
                  controller: _dailyLoss,
                  label: 'Perda diária máxima (USDT)',
                ),
                _positiveDecimalField(
                  key: const Key('bot-max-total-loss'),
                  controller: _totalLoss,
                  label: 'Perda total máxima (USDT)',
                ),
                DropdownButtonFormField<BotRiskLevel>(
                  key: const Key('bot-risk-level'),
                  initialValue: _riskLevel,
                  decoration: const InputDecoration(labelText: 'Nível de risco'),
                  items: const [
                    DropdownMenuItem(
                      value: BotRiskLevel.low,
                      child: Text('Baixo'),
                    ),
                    DropdownMenuItem(
                      value: BotRiskLevel.medium,
                      child: Text('Médio'),
                    ),
                    DropdownMenuItem(
                      value: BotRiskLevel.high,
                      child: Text('Alto'),
                    ),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) {
                          if (value != null) setState(() => _riskLevel = value);
                        },
                ),
                TextFormField(
                  key: const Key('bot-allowed-pairs'),
                  controller: _pairs,
                  enabled: !_saving,
                  decoration: const InputDecoration(
                    labelText: 'Pares permitidos',
                    helperText: 'Separe os pares por vírgula.',
                  ),
                  validator: (value) {
                    final pairs = value
                        ?.split(',')
                        .map((pair) => pair.trim())
                        .where((pair) => pair.isNotEmpty)
                        .toList();
                    if (pairs == null || pairs.isEmpty) {
                      return 'Informe pelo menos um par.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                FilledButton(
                  key: const Key('save-bot-settings'),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const CircularProgressIndicator()
                      : const Text('Salvar configuração'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  TextFormField _positiveDecimalField({
    required Key key,
    required TextEditingController controller,
    required String label,
  }) => TextFormField(
    key: key,
    controller: controller,
    enabled: !_saving,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(labelText: label),
    validator: (value) {
      final raw = value?.trim().replaceAll(',', '.') ?? '';
      if (raw.isEmpty) return 'Informe um valor.';
      try {
        if (_parseDecimal(raw) <= Decimal.zero) {
          return 'O valor deve ser maior que zero.';
        }
      } on FormatException {
        return 'Informe um número válido.';
      }
      return null;
    },
  );
}

Decimal _parseDecimal(String value) =>
    Decimal.parse(value.trim().replaceAll(',', '.'));

String _apiCode(Object error) {
  if (error is ApiException) return error.code;
  if (error is DioException && error.error is ApiException) {
    return (error.error as ApiException).code;
  }
  return 'INTERNAL_ERROR';
}
