import 'package:controle_ds/features/finance/data/fake_finance_repository.dart';
import 'package:controle_ds/features/finance/domain/category.dart';
import 'package:controle_ds/features/finance/domain/transaction.dart';
import 'package:controle_ds/features/finance/presentation/dashboard_page.dart';
import 'package:controle_ds/features/finance/presentation/home_shell.dart';
import 'package:controle_ds/features/finance/presentation/transaction_form_page.dart';
import 'package:controle_ds/core/errors/app_exception.dart';
import 'package:dio/dio.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  testWidgets('dashboard displays financial totals and distinct balances', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          financeRepositoryProvider.overrideWithValue(
            FakeFinanceRepository(now: () => DateTime(2026, 10, 6)),
          ),
        ],
        child: const MaterialApp(home: DashboardPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Receitas'), findsOneWidget);
    expect(find.text('Despesas'), findsOneWidget);
    expect(find.text('Saldo do mês'), findsOneWidget);
    expect(find.text('Saldo acumulado'), findsOneWidget);
    expect(find.text('Despesas por categoria'), findsOneWidget);
    await tester.drag(
      find.byKey(const Key('dashboard-content')),
      const Offset(0, -600),
    );
    await tester.pumpAndSettle();
    expect(find.text('Últimas transações'), findsOneWidget);
  });

  testWidgets('transaction form validates amount, description and category', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          financeRepositoryProvider.overrideWithValue(FakeFinanceRepository()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: TransactionFormPage(
              categories: const [
                Category(id: 'cat-1', name: 'Moradia', archived: false),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('transaction-amount')), '0');
    await tester.enterText(
      find.byKey(const Key('transaction-description')),
      'A',
    );
    await tester.tap(find.byKey(const Key('transaction-save')));
    await tester.pumpAndSettle();

    expect(find.text('O valor deve ser maior que zero.'), findsOneWidget);
    expect(find.text('Use de 2 a 100 caracteres.'), findsOneWidget);
    expect(find.text('Selecione uma categoria.'), findsOneWidget);
  });

  testWidgets('422 field details are shown on the matching input', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          financeRepositoryProvider.overrideWithValue(_InvalidRepository()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: TransactionFormPage(
              categories: const [
                Category(id: 'cat-1', name: 'Moradia', archived: false),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('transaction-amount')),
      '10.00',
    );
    await tester.enterText(
      find.byKey(const Key('transaction-description')),
      'Conta',
    );
    await tester.tap(find.byKey(const Key('transaction-category')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Moradia').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('transaction-save')));
    await tester.pumpAndSettle();

    expect(find.text('O valor deve ser maior que zero.'), findsOneWidget);
  });

  testWidgets('transaction delete always requires confirmation', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          financeRepositoryProvider.overrideWithValue(
            FakeFinanceRepository(now: () => DateTime(2026, 10, 6)),
          ),
        ],
        child: const MaterialApp(home: HomeShell()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transações').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('transaction-tx-income')), findsOneWidget);

    await tester.tap(find.byTooltip('Excluir').first);
    await tester.pumpAndSettle();

    expect(find.text('Excluir transação?'), findsOneWidget);
    expect(find.byKey(const Key('confirm-delete-transaction')), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('transaction-tx-income')), findsOneWidget);
  });
}

class _InvalidRepository extends FakeFinanceRepository {
  @override
  Future<Transaction> create(TransactionDraft draft) async {
    throw DioException(
      requestOptions: RequestOptions(path: '/transactions'),
      error: const ApiException(
        code: 'VALIDATION_ERROR',
        message: 'Confira os dados informados.',
        statusCode: 422,
        details: [
          {'field': 'amount', 'issue': 'must be greater than 0'},
        ],
      ),
    );
  }
}
