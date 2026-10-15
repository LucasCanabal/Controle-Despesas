import 'package:controle_ds/core/errors/app_exception.dart';
import 'package:controle_ds/core/errors/error_messages.dart';
import 'package:controle_ds/core/money/money.dart';
import 'package:controle_ds/features/finance/domain/category.dart';
import 'package:controle_ds/features/finance/domain/transaction.dart';
import 'package:controle_ds/features/finance/presentation/transactions_notifier.dart';
import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class TransactionFormPage extends ConsumerStatefulWidget {
  const TransactionFormPage({
    required this.categories,
    this.transaction,
    super.key,
  });

  final List<Category> categories;
  final Transaction? transaction;

  @override
  ConsumerState<TransactionFormPage> createState() =>
      _TransactionFormPageState();
}

class _TransactionFormPageState extends ConsumerState<TransactionFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;
  late TransactionType _type;
  late DateTime _date;
  String? _categoryId;
  bool _isSaving = false;
  final Map<String, String> _serverErrors = {};

  bool get _isEditing => widget.transaction != null;

  @override
  void initState() {
    super.initState();
    final transaction = widget.transaction;
    _amountController = TextEditingController(
      text: transaction == null ? '' : moneyToJson(transaction.amount),
    );
    _descriptionController = TextEditingController(
      text: transaction?.description ?? '',
    );
    _type = transaction?.type ?? TransactionType.expense;
    _date = transaction?.date ?? DateTime.now();
    _categoryId = transaction?.categoryId;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _chooseDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected != null) {
      setState(() => _date = selected);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isSaving = true;
      _serverErrors.clear();
    });
    try {
      final amountText = _amountController.text.trim().replaceAll(',', '.');
      final draft = TransactionDraft(
        type: _type,
        amount: parseMoney(amountText),
        description: _descriptionController.text.trim(),
        categoryId: _categoryId!,
        date: _date,
      );
      final notifier = ref.read(transactionsNotifierProvider.notifier);
      if (_isEditing) {
        await notifier.saveUpdate(widget.transaction!.id, draft);
      } else {
        await notifier.saveCreate(draft);
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      final apiError = _apiException(error);
      if (apiError?.statusCode == 422 && apiError!.details.isNotEmpty) {
        for (final detail in apiError.details) {
          final field = detail['field'];
          if (field is String) {
            _serverErrors[_fieldName(field)] = _localizedFieldIssue(
              detail['issue'],
            );
          }
        }
        setState(() {});
      } else {
        final code = apiError?.code ?? 'INTERNAL_ERROR';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(messageForCode(code))));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  ApiException? _apiException(Object error) {
    if (error is ApiException) {
      return error;
    }
    if (error is DioException && error.error is ApiException) {
      return error.error as ApiException;
    }
    return null;
  }

  String _fieldName(String field) => switch (field) {
    'amount' => 'amount',
    'description' => 'description',
    'category_id' => 'category',
    'date' => 'date',
    'type' => 'type',
    _ => 'form',
  };

  String _localizedFieldIssue(Object? issue) {
    final text = issue is String ? issue.toLowerCase() : '';
    if (text.contains('greater than 0') || text.contains('positive')) {
      return 'O valor deve ser maior que zero.';
    }
    if (text.contains('2') && text.contains('100')) {
      return 'A descrição deve ter de 2 a 100 caracteres.';
    }
    return 'Confira este campo.';
  }

  String? _validateAmount(String? value) {
    final amount = value?.trim().replaceAll(',', '.') ?? '';
    if (amount.isEmpty) {
      return 'Informe o valor.';
    }
    try {
      if (Decimal.parse(amount) <= Decimal.zero) {
        return 'O valor deve ser maior que zero.';
      }
    } on FormatException {
      return 'Informe um valor válido.';
    }
    return _serverErrors['amount'];
  }

  String? _validateDescription(String? value) {
    final length = value?.trim().length ?? 0;
    if (length < 2 || length > 100) {
      return 'Use de 2 a 100 caracteres.';
    }
    return _serverErrors['description'];
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_isEditing ? 'Editar transação' : 'Nova transação'),
    ),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          DropdownButtonFormField<TransactionType>(
            key: const Key('transaction-type'),
            initialValue: _type,
            decoration: InputDecoration(
              labelText: 'Tipo',
              errorText: _serverErrors['type'],
            ),
            items: const [
              DropdownMenuItem(
                value: TransactionType.income,
                child: Text('Receita'),
              ),
              DropdownMenuItem(
                value: TransactionType.expense,
                child: Text('Despesa'),
              ),
            ],
            onChanged: _isSaving
                ? null
                : (value) {
                    if (value != null) {
                      setState(() => _type = value);
                    }
                  },
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const Key('transaction-amount'),
            controller: _amountController,
            decoration: InputDecoration(
              labelText: 'Valor',
              prefixText: 'R\$ ',
              errorText: _serverErrors['amount'],
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d,.]')),
            ],
            validator: _validateAmount,
            enabled: !_isSaving,
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const Key('transaction-description'),
            controller: _descriptionController,
            decoration: InputDecoration(
              labelText: 'Descrição',
              errorText: _serverErrors['description'],
            ),
            maxLength: 100,
            validator: _validateDescription,
            enabled: !_isSaving,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: const Key('transaction-category'),
            initialValue: _categoryId,
            decoration: InputDecoration(
              labelText: 'Categoria',
              errorText:
                  _serverErrors['category'] ?? _serverErrors['category_id'],
            ),
            items: widget.categories
                .map(
                  (category) => DropdownMenuItem(
                    value: category.id,
                    child: Text(category.name),
                  ),
                )
                .toList(growable: false),
            onChanged: _isSaving
                ? null
                : (value) => setState(() => _categoryId = value),
            validator: (value) =>
                value == null ? 'Selecione uma categoria.' : null,
          ),
          if (_serverErrors['form'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _serverErrors['form']!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            key: const Key('transaction-date'),
            onPressed: _isSaving ? null : _chooseDate,
            icon: const Icon(Icons.calendar_month),
            label: Text(DateFormat.yMd('pt_BR').format(_date)),
          ),
          if (_serverErrors['date'] != null)
            Text(
              _serverErrors['date']!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('transaction-save'),
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const CircularProgressIndicator()
                : const Text('Salvar'),
          ),
        ],
      ),
    ),
  );
}
