import 'dart:async';

import 'package:controle_ds/features/bot/data/fake_bot_repository.dart';
import 'package:controle_ds/features/bot/domain/bot_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final botPollingIntervalProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 10),
);

final botPanelNotifierProvider =
    AsyncNotifierProvider<BotPanelNotifier, BotStatus>(BotPanelNotifier.new);

class BotPanelNotifier extends AsyncNotifier<BotStatus> {
  Timer? _timer;
  bool _focused = false;

  bool get isPolling => _timer?.isActive ?? false;

  @override
  Future<BotStatus> build() {
    ref.onDispose(_cancelPolling);
    return ref.watch(botRepositoryProvider).getStatus();
  }

  void setFocused(bool focused) {
    if (_focused == focused) return;
    _focused = focused;
    if (focused) {
      final interval = ref.read(botPollingIntervalProvider);
      _timer = Timer.periodic(interval, (_) => _poll());
    } else {
      _cancelPolling();
    }
  }

  Future<void> refresh() async {
    final status = await ref.read(botRepositoryProvider).getStatus();
    state = AsyncData(status);
  }

  Future<BotStatus> start() async {
    final status = await ref.read(botRepositoryProvider).start();
    state = AsyncData(status);
    return status;
  }

  Future<BotStatus> stop() async {
    final status = await ref.read(botRepositoryProvider).stop();
    state = AsyncData(status);
    return status;
  }

  Future<BotStatus> kill() async {
    final status = await ref.read(botRepositoryProvider).kill();
    state = AsyncData(status);
    return status;
  }

  void setStatus(BotStatus status) {
    state = AsyncData(status);
  }

  Future<void> _poll() async {
    try {
      final status = await ref.read(botRepositoryProvider).getStatus();
      if (_focused) state = AsyncData(status);
    } on Object catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  void _cancelPolling() {
    _timer?.cancel();
    _timer = null;
  }
}
