import 'package:controle_ds/features/portfolio/domain/portfolio.dart';

abstract interface class PortfolioRepository {
  Future<Portfolio> getPortfolio();

  Future<Portfolio> sync();
}
