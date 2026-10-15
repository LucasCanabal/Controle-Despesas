import 'package:controle_ds/core/pagination/page.dart';
import 'package:controle_ds/features/bot/domain/bot_order.dart';
import 'package:controle_ds/features/bot/domain/bot_order_filter.dart';
import 'package:controle_ds/features/bot/domain/bot_settings.dart';
import 'package:controle_ds/features/bot/domain/bot_state.dart';

abstract interface class BotRepository {
  Future<BotSettings> getSettings();

  Future<BotSettings> saveSettings(BotSettings settings);

  Future<BotStatus> getStatus();

  Future<BotStatus> start();

  Future<BotStatus> stop();

  Future<BotStatus> kill();

  Future<void> acceptConsent(String version);

  Future<Page<BotOrder>> listOrders(
    BotOrderFilter filter, {
    String? cursor,
    int limit = 20,
  });
}
