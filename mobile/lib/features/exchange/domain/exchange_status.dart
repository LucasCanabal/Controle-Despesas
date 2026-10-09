enum ExchangeStatus {
  connected,
  invalid,
  rateLimited,
  unreachable;

  factory ExchangeStatus.fromJson(Object? value) => switch (value) {
    'CONNECTED' => ExchangeStatus.connected,
    'INVALID' => ExchangeStatus.invalid,
    'RATE_LIMITED' => ExchangeStatus.rateLimited,
    'UNREACHABLE' => ExchangeStatus.unreachable,
    _ => throw const FormatException('Status da corretora inválido.'),
  };

  String toJson() => switch (this) {
    ExchangeStatus.connected => 'CONNECTED',
    ExchangeStatus.invalid => 'INVALID',
    ExchangeStatus.rateLimited => 'RATE_LIMITED',
    ExchangeStatus.unreachable => 'UNREACHABLE',
  };
}
