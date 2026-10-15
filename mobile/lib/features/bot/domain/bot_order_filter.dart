final class BotOrderFilter {
  const BotOrderFilter({
    this.simulated,
    this.pair,
    this.from,
    this.to,
  });

  final bool? simulated;
  final String? pair;
  final DateTime? from;
  final DateTime? to;

  @override
  bool operator ==(Object other) =>
      other is BotOrderFilter &&
      other.simulated == simulated &&
      other.pair == pair &&
      _sameDate(other.from, from) &&
      _sameDate(other.to, to);

  @override
  int get hashCode => Object.hash(
    simulated,
    pair,
    from?.year,
    from?.month,
    from?.day,
    to?.year,
    to?.month,
    to?.day,
  );
}

bool _sameDate(DateTime? left, DateTime? right) =>
    left == null
        ? right == null
        : right != null &&
            left.year == right.year &&
            left.month == right.month &&
            left.day == right.day;
