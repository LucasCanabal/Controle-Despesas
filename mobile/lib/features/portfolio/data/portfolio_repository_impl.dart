import 'package:controle_ds/features/portfolio/data/portfolio_api.dart';
import 'package:controle_ds/features/portfolio/domain/portfolio.dart';
import 'package:controle_ds/features/portfolio/domain/portfolio_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final portfolioRepositoryImplProvider = Provider<PortfolioRepository>(
  (ref) => PortfolioRepositoryImpl(ref.watch(portfolioApiProvider)),
);

final class PortfolioRepositoryImpl implements PortfolioRepository {
  const PortfolioRepositoryImpl(this._api);

  final PortfolioApi _api;

  @override
  Future<Portfolio> getPortfolio() async =>
      Portfolio.fromJson(await _api.getPortfolio());

  @override
  Future<Portfolio> sync() async => Portfolio.fromJson(await _api.sync());
}
