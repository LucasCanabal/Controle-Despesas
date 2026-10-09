import 'package:controle_ds/core/money/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('money JSON round-trips without losing decimal precision', () {
    final value = parseMoney('150.75');

    expect(moneyToJson(value), '150.75');
    expect(parseMoney(moneyToJson(value)), value);
  });

  test('formats BRL using Brazilian separators', () {
    expect(formatBRL(parseMoney('1234.56')), 'R\$ 1.234,56');
  });

  test('formats USDT without binary floating-point conversion', () {
    expect(formatUSDT(parseMoney('1234.56789012')), '1,234.56789012 USDT');
  });
}
