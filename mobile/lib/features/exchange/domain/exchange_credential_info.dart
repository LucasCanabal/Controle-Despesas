import 'package:controle_ds/features/exchange/domain/exchange_status.dart';

final class ExchangeCredentialInfo {
  const ExchangeCredentialInfo({
    required this.status,
    required this.keyHint,
    required this.lastCheckedAt,
  });

  final ExchangeStatus status;
  final String keyHint;
  final DateTime? lastCheckedAt;

  factory ExchangeCredentialInfo.fromJson(Map<String, Object?> json) {
    final keyHint = json['key_hint'];
    final checkedAt = json['last_checked_at'];
    if (keyHint is! String ||
        (checkedAt != null && checkedAt is! String)) {
      throw const FormatException(
        'Formato de metadados da credencial inválido.',
      );
    }
    return ExchangeCredentialInfo(
      status: ExchangeStatus.fromJson(json['status']),
      keyHint: keyHint,
      lastCheckedAt: checkedAt == null
          ? null
          : DateTime.parse(checkedAt as String),
    );
  }
}
