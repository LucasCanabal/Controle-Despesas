import 'package:controle_ds/core/pagination/page.dart';
import 'package:controle_ds/features/bot/data/bot_api.dart';
import 'package:controle_ds/features/bot/domain/bot_order.dart';
import 'package:controle_ds/features/bot/domain/bot_order_filter.dart';
import 'package:controle_ds/features/bot/domain/bot_repository.dart';
import 'package:controle_ds/features/bot/domain/bot_settings.dart';
import 'package:controle_ds/features/bot/domain/bot_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final botRepositoryImplProvider = Provider<BotRepository>(
  (ref) => BotRepositoryImpl(ref.watch(botApiProvider)),
);

final class BotRepositoryImpl implements BotRepository {
  const BotRepositoryImpl(this._api);

  final BotApi _api;

  @override
  Future<BotSettings> getSettings() async =>
      _api.parseSettings(await _api.getSettings());

  @override
  Future<BotSettings> saveSettings(BotSettings settings) async =>
      _api.parseSettings(await _api.saveSettings(settings));

  @override
  Future<BotStatus> getStatus() async =>
      _api.parseStatus(await _api.getStatus());

  @override
  Future<BotStatus> start() async => _api.parseStatus(await _api.start());

  @override
  Future<BotStatus> stop() async => _api.parseStatus(await _api.stop());

  @override
  Future<BotStatus> kill() async => _api.parseStatus(await _api.kill());

  @override
  Future<void> acceptConsent(String version) => _api.acceptConsent(version);

  @override
  Future<Page<BotOrder>> listOrders(
    BotOrderFilter filter, {
    String? cursor,
    int limit = 20,
  }) async => _api.parseOrders(
    await _api.listOrders(filter, cursor: cursor, limit: limit),
  );
}
