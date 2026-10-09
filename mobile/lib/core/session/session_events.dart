import 'package:flutter_riverpod/flutter_riverpod.dart';

final sessionExpiredProvider = NotifierProvider<SessionExpiredNotifier, bool>(
  SessionExpiredNotifier.new,
);

class SessionExpiredNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void expire() => state = true;

  void reset() => state = false;
}
