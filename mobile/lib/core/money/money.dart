import 'package:decimal/decimal.dart';
import 'package:decimal/intl.dart';
import 'package:intl/intl.dart';

Decimal parseMoney(String value) => Decimal.parse(value);

String formatBRL(Decimal amount) =>
    DecimalFormatter(NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$'))
        .format(amount);

String formatUSDT(Decimal amount) =>
    '${DecimalFormatter(NumberFormat('#,##0.########', 'en_US')).format(amount)} USDT';

String moneyToJson(Decimal amount) => amount.toString();
