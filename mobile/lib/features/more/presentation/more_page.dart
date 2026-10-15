import 'package:controle_ds/features/calculator/presentation/compound_interest_page.dart';
import 'package:controle_ds/features/bot/presentation/bot_orders_page.dart';
import 'package:controle_ds/features/exchange/presentation/exchange_page.dart';
import 'package:flutter/material.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Mais')),
    body: ListView(
      children: [
        ListTile(
          key: const Key('more-exchange'),
          leading: const Icon(Icons.currency_exchange),
          title: const Text('Corretora'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const ExchangePage())),
        ),
        ListTile(
          key: const Key('more-calculator'),
          leading: const Icon(Icons.calculate_outlined),
          title: const Text('Calculadora'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const CompoundInterestPage(),
            ),
          ),
        ),
        ListTile(
          key: const Key('more-bot-orders'),
          leading: const Icon(Icons.history),
          title: const Text('Histórico de ordens'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const BotOrdersPage()),
          ),
        ),
      ],
    ),
  );
}
