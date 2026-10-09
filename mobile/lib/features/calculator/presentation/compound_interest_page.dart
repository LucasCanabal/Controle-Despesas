import 'package:controle_ds/core/errors/app_exception.dart';
import 'package:controle_ds/core/errors/error_messages.dart';
import 'package:controle_ds/core/money/money.dart';
import 'package:controle_ds/features/calculator/data/fake_compound_interest_repository.dart';
import 'package:controle_ds/features/calculator/domain/compound_interest_result.dart';
import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CompoundInterestPage extends ConsumerStatefulWidget {
  const CompoundInterestPage({super.key});

  @override
  ConsumerState<CompoundInterestPage> createState() =>
      _CompoundInterestPageState();
}

class _CompoundInterestPageState extends ConsumerState<CompoundInterestPage> {
  final _formKey = GlobalKey<FormState>();
  final _initialController = TextEditingController();
  final _contributionController = TextEditingController();
  final _rateController = TextEditingController();
  final _monthsController = TextEditingController();
  CompoundInterestResult? _result;
  bool _busy = false;

  @override
  void dispose() {
    _initialController.dispose();
    _contributionController.dispose();
    _rateController.dispose();
    _monthsController.dispose();
    super.dispose();
  }

  Future<void> _calculate() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _result = null;
    });
    try {
      final result = await ref
          .read(compoundInterestRepositoryProvider)
          .calculate(
            initialAmount: _decimal(_initialController.text),
            monthlyContribution: _decimal(_contributionController.text),
            monthlyRate: _decimal(_rateController.text),
            months: int.parse(_monthsController.text.trim()),
          );
      if (mounted) setState(() => _result = result);
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(messageForCode(_apiCode(error) ?? 'INTERNAL_ERROR')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Calculadora')),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _decimalField(
            key: const Key('calc-initial-amount'),
            controller: _initialController,
            label: 'Valor inicial',
          ),
          _decimalField(
            key: const Key('calc-monthly-contribution'),
            controller: _contributionController,
            label: 'Aporte mensal',
          ),
          _decimalField(
            key: const Key('calc-monthly-rate'),
            controller: _rateController,
            label: 'Taxa ao mês (%)',
          ),
          TextFormField(
            key: const Key('calc-months'),
            controller: _monthsController,
            enabled: !_busy,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Meses'),
            validator: (value) {
              final months = int.tryParse(value?.trim() ?? '');
              if (months == null || months < 1) {
                return 'Informe pelo menos 1 mês.';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('calculate-compound-interest'),
            onPressed: _busy ? null : _calculate,
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Calcular'),
          ),
          if (_result case final result?) ...[
            const SizedBox(height: 24),
            Text('Resultado', style: Theme.of(context).textTheme.titleLarge),
            ListTile(
              title: const Text('Valor final'),
              trailing: Text(formatBRL(result.finalValue)),
            ),
            ListTile(
              title: const Text('Total investido'),
              trailing: Text(formatBRL(result.totalInvested)),
            ),
            ListTile(
              title: const Text('Total em juros'),
              trailing: Text(formatBRL(result.totalInterest)),
            ),
          ],
        ],
      ),
    ),
  );

  TextFormField _decimalField({
    required Key key,
    required TextEditingController controller,
    required String label,
  }) => TextFormField(
    key: key,
    controller: controller,
    enabled: !_busy,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(labelText: label),
    validator: (value) {
      final raw = value?.trim().replaceAll(',', '.') ?? '';
      if (raw.isEmpty) return 'Informe um valor.';
      try {
        if (_decimal(raw) < Decimal.zero) {
          return 'O valor deve ser maior ou igual a zero.';
        }
      } on FormatException {
        return 'Informe um número válido.';
      }
      return null;
    },
  );
}

Decimal _decimal(String value) => Decimal.parse(value.trim().replaceAll(',', '.'));

String? _apiCode(Object error) {
  if (error is ApiException) return error.code;
  if (error is DioException && error.error is ApiException) {
    return (error.error as ApiException).code;
  }
  return null;
}
