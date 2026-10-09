import 'package:controle_ds/core/money/money.dart';
import 'package:decimal/decimal.dart';

final class Portfolio {
  const Portfolio({
    required this.totalValueUsdt,
    required this.totalValueDisplay,
    required this.displayCurrency,
    required this.totalPnl,
    required this.totalPnlPercent,
    required this.stale,
    required this.lastSyncedAt,
    required this.assets,
  });

  final Decimal totalValueUsdt;
  final Decimal totalValueDisplay;
  final String displayCurrency;
  final Decimal totalPnl;
  final Decimal? totalPnlPercent;
  final bool stale;
  final DateTime? lastSyncedAt;
  final List<PortfolioAsset> assets;

  factory Portfolio.fromJson(Map<String, Object?> json) {
    final totalValueUsdt = json['total_value_usdt'];
    final totalValueDisplay = json['total_value_display'];
    final displayCurrency = json['display_currency'];
    final totalPnl = json['total_pnl'];
    final totalPnlPercent = json['total_pnl_percent'];
    final stale = json['stale'];
    final lastSyncedAt = json['last_synced_at'];
    final rawAssets = json['assets'];
    if (totalValueUsdt is! String ||
        totalValueDisplay is! String ||
        displayCurrency is! String ||
        totalPnl is! String ||
        (totalPnlPercent != null && totalPnlPercent is! String) ||
        stale is! bool ||
        (lastSyncedAt != null && lastSyncedAt is! String) ||
        rawAssets is! List) {
      throw const FormatException('Formato de carteira inválido.');
    }
    return Portfolio(
      totalValueUsdt: parseMoney(totalValueUsdt),
      totalValueDisplay: parseMoney(totalValueDisplay),
      displayCurrency: displayCurrency,
      totalPnl: parseMoney(totalPnl),
      totalPnlPercent: totalPnlPercent == null
          ? null
          : parseMoney(totalPnlPercent as String),
      stale: stale,
      lastSyncedAt: lastSyncedAt == null
          ? null
          : DateTime.parse(lastSyncedAt as String),
      assets: rawAssets.map((item) => PortfolioAsset.fromJson(_asMap(item)))
          .toList(growable: false),
    );
  }
}

final class PortfolioAsset {
  const PortfolioAsset({
    required this.symbol,
    required this.quantity,
    required this.averagePrice,
    required this.currentPrice,
    required this.currentValue,
    required this.pnl,
    required this.pnlPercent,
  });

  final String symbol;
  final Decimal quantity;
  final Decimal averagePrice;
  final Decimal currentPrice;
  final Decimal currentValue;
  final Decimal pnl;
  final Decimal? pnlPercent;

  factory PortfolioAsset.fromJson(Map<String, Object?> json) {
    final symbol = json['symbol'];
    final quantity = json['quantity'];
    final averagePrice = json['average_price'];
    final currentPrice = json['current_price'];
    final currentValue = json['current_value'];
    final pnl = json['pnl'];
    final pnlPercent = json['pnl_percent'];
    if (symbol is! String ||
        quantity is! String ||
        averagePrice is! String ||
        currentPrice is! String ||
        currentValue is! String ||
        pnl is! String ||
        (pnlPercent != null && pnlPercent is! String)) {
      throw const FormatException('Formato de ativo da carteira inválido.');
    }
    return PortfolioAsset(
      symbol: symbol,
      quantity: parseMoney(quantity),
      averagePrice: parseMoney(averagePrice),
      currentPrice: parseMoney(currentPrice),
      currentValue: parseMoney(currentValue),
      pnl: parseMoney(pnl),
      pnlPercent: pnlPercent == null ? null : parseMoney(pnlPercent as String),
    );
  }
}

Map<String, Object?> _asMap(Object? value) {
  if (value is! Map) {
    throw const FormatException('O item da carteira deve ser um objeto.');
  }
  return {
    for (final entry in value.entries)
      if (entry.key is String) entry.key as String: entry.value,
  };
}
