import 'package:controle_ds/core/errors/error_messages.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all API error codes have a Portuguese message', () {
    const codes = [
      'BAD_REQUEST',
      'UNAUTHORIZED',
      'INVALID_CREDENTIALS',
      'TOKEN_EXPIRED',
      'TOKEN_REUSED',
      'FORBIDDEN',
      'CONSENT_REQUIRED',
      'PAPER_PERIOD_NOT_MET',
      'NOT_FOUND',
      'EMAIL_ALREADY_REGISTERED',
      'BOT_INVALID_STATE',
      'VALIDATION_ERROR',
      'EXCHANGE_KEY_INVALID',
      'EXCHANGE_KEY_WITHDRAW_ENABLED',
      'TOO_MANY_ATTEMPTS',
      'RATE_LIMITED',
      'INTERNAL_ERROR',
      'EXCHANGE_UNAVAILABLE',
    ];

    for (final code in codes) {
      expect(messageForCode(code), isNotEmpty, reason: code);
      expect(
        messageForCode(code),
        isNot(contains('Não foi possível concluir')),
        reason: code,
      );
    }
  });

  test('unknown codes return the generic Portuguese message', () {
    expect(messageForCode('UNKNOWN'), contains('Não foi possível'));
  });
}
