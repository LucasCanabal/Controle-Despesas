import 'package:controle_ds/features/bot/data/fake_bot_repository.dart';
import 'package:controle_ds/features/bot/presentation/bot_panel_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('polling refreshes on interval and stops when focus leaves', () async {
    final repository = FakeBotRepository();
    final container = ProviderContainer(
      overrides: [
        botRepositoryProvider.overrideWithValue(repository),
        botPollingIntervalProvider.overrideWithValue(
          const Duration(seconds: 2),
        ),
      ],
    );
    final subscription = container.listen(botPanelNotifierProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);
    final notifier = container.read(botPanelNotifierProvider.notifier);
    expect(repository.getStatusCalls, 1);

    notifier.setFocused(true);
    await Future<void>.delayed(const Duration(milliseconds: 25));
    expect(notifier.isPolling, isTrue);
    await Future<void>.delayed(const Duration(seconds: 2));
    expect(repository.getStatusCalls, 2);

    notifier.setFocused(false);
    expect(notifier.isPolling, isFalse);
    await Future<void>.delayed(const Duration(seconds: 3));
    expect(repository.getStatusCalls, 2);

    subscription.close();
    container.dispose();
    await Future<void>.delayed(const Duration(seconds: 3));
    expect(repository.getStatusCalls, 2);
  });
}
