import 'package:controle_ds/core/network/dio_client.dart';
import 'package:controle_ds/core/pagination/page.dart';
import 'package:controle_ds/features/bot/domain/bot_order.dart';
import 'package:controle_ds/features/bot/domain/bot_order_filter.dart';
import 'package:controle_ds/features/bot/domain/bot_settings.dart';
import 'package:controle_ds/features/bot/domain/bot_state.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final botApiProvider = Provider<BotApi>((ref) => BotApi(ref.watch(dioProvider)));

final class BotApi {
  const BotApi(this._dio);

  final Dio _dio;

  Future<Map<String, Object?>> getSettings() async =>
      _objectResponse(await _dio.get<Object?>('/bot/settings'));

  Future<Map<String, Object?>> saveSettings(BotSettings settings) async =>
      _objectResponse(
        await _dio.put<Object?>('/bot/settings', data: settings.toJson()),
      );

  Future<Map<String, Object?>> getStatus() async =>
      _objectResponse(await _dio.get<Object?>('/bot/status'));

  Future<Map<String, Object?>> start() async =>
      _objectResponse(await _dio.post<Object?>('/bot/start'));

  Future<Map<String, Object?>> stop() async =>
      _objectResponse(await _dio.post<Object?>('/bot/stop'));

  Future<Map<String, Object?>> kill() async =>
      _objectResponse(await _dio.post<Object?>('/bot/kill'));

  Future<void> acceptConsent(String version) async {
    await _dio.post<void>('/bot/consent', data: {'version': version});
  }

  Future<Map<String, Object?>> listOrders(
    BotOrderFilter filter, {
    String? cursor,
    int limit = 20,
  }) async {
    if (limit < 1 || limit > 100) {
      throw RangeError.range(limit, 1, 100, 'limit');
    }
    final query = <String, Object?>{'limit': limit};
    if (filter.simulated != null) {
      query['simulated'] = filter.simulated;
    }
    if (filter.pair != null && filter.pair!.isNotEmpty) {
      query['pair'] = filter.pair;
    }
    if (filter.from != null) {
      query['from'] = _dateOnly(filter.from!);
    }
    if (filter.to != null) {
      query['to'] = _dateOnly(filter.to!);
    }
    if (cursor != null) {
      query['cursor'] = cursor;
    }
    return _objectResponse(
      await _dio.get<Object?>('/bot/orders', queryParameters: query),
    );
  }

  BotSettings parseSettings(Map<String, Object?> json) =>
      BotSettings.fromJson(json);

  BotStatus parseStatus(Map<String, Object?> json) => BotStatus.fromJson(json);

  Page<BotOrder> parseOrders(Map<String, Object?> json) =>
      Page<BotOrder>.fromJson(json, BotOrder.fromJson);

  Map<String, Object?> _objectResponse(Response<Object?> response) {
    final value = response.data;
    if (value is! Map) {
      throw const FormatException('A resposta da API deve ser um objeto.');
    }
    return {
      for (final entry in value.entries)
        if (entry.key is String) entry.key as String: entry.value,
    };
  }
}

String _dateOnly(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
