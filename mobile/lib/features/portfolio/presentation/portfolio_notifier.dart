import 'package:controle_ds/features/portfolio/data/fake_portfolio_repository.dart';
import 'package:controle_ds/features/portfolio/domain/portfolio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final portfolioNotifierProvider =
    AsyncNotifierProvider<PortfolioNotifier, Portfolio>(
      PortfolioNotifier.new,
    );

class PortfolioNotifier extends AsyncNotifier<Portfolio> {
  @override
  Future<Portfolio> build() =>
      ref.watch(portfolioRepositoryProvider).getPortfolio();

  Future<void> sync() async {
    final portfolio = await ref.read(portfolioRepositoryProvider).sync();
    state = AsyncData(portfolio);
  }
}
