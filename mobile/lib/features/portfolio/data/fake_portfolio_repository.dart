import 'package:controle_ds/core/errors/app_exception.dart';
import 'package:controle_ds/core/money/money.dart';
import 'package:controle_ds/features/portfolio/domain/portfolio.dart';
import 'package:controle_ds/features/portfolio/domain/portfolio_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final portfolioRepositoryProvider = Provider<PortfolioRepository>((ref) {
  // TODO: switch to portfolioRepositoryImplProvider when backend S11 exists.
  return FakePortfolioRepository();
});

final class FakePortfolioRepository implements PortfolioRepository {
  FakePortfolioRepository({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  DateTime? _lastSync;
  bool _stale = true;

  @override
  Future<Portfolio> getPortfolio() async => _portfolio();

  @override
  Future<Portfolio> sync() async {
    final current = _now().toUtc();
    if (_lastSync != null &&
        current.difference(_lastSync!) < const Duration(minutes: 1)) {
      throw const ApiException(
        code: 'RATE_LIMITED',
        message: 'Limite de sincronização atingido.',
        statusCode: 429,
      );
    }
    _lastSync = current;
    _stale = false;
    return _portfolio();
  }

  Portfolio _portfolio() {
    final assets = [
      PortfolioAsset(
        symbol: 'BTC',
        quantity: parseMoney('0.025'),
        averagePrice: parseMoney('60000'),
        currentPrice: parseMoney('65000'),
        currentValue: parseMoney('1625'),
        pnl: parseMoney('125'),
        pnlPercent: parseMoney('8.33'),
      ),
      PortfolioAsset(
        symbol: 'ETH',
        quantity: parseMoney('0.50'),
        averagePrice: parseMoney('3000'),
        currentPrice: parseMoney('2800'),
        currentValue: parseMoney('1400'),
        pnl: parseMoney('-100'),
        pnlPercent: parseMoney('-6.67'),
      ),
      PortfolioAsset(
        symbol: 'SOL',
        quantity: parseMoney('5'),
        averagePrice: parseMoney('140'),
        currentPrice: parseMoney('150'),
        currentValue: parseMoney('750'),
        pnl: parseMoney('50'),
        pnlPercent: null,
      ),
    ];
    return Portfolio(
      totalValueUsdt: parseMoney('3775'),
      totalValueDisplay: parseMoney('3775'),
      displayCurrency: 'USDT',
      totalPnl: parseMoney('75'),
      totalPnlPercent: parseMoney('2.02'),
      stale: _stale,
      lastSyncedAt: _lastSync,
      assets: assets,
    );
  }
}
