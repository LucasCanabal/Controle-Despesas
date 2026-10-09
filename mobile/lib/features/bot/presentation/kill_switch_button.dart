import 'package:controle_ds/core/errors/app_exception.dart';
import 'package:controle_ds/core/errors/error_messages.dart';
import 'package:controle_ds/core/security/local_auth_service.dart';
import 'package:controle_ds/features/bot/presentation/bot_panel_notifier.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class KillSwitchButton extends ConsumerStatefulWidget {
  const KillSwitchButton({super.key, this.enabled = true});

  final bool enabled;

  @override
  ConsumerState<KillSwitchButton> createState() => _KillSwitchButtonState();
}

class _KillSwitchButtonState extends ConsumerState<KillSwitchButton> {
  bool _busy = false;

  Future<void> _kill() async {
    if (_busy || !widget.enabled) return;
    final confirmedByDialog = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Acionar kill switch?'),
        content: const Text(
          'Esta ação cancela ordens abertas e desativa o robô. '
          'Nenhuma posição será vendida.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('confirm-bot-kill'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirmedByDialog != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final confirmedByDevice = await ref
          .read(localAuthProvider)
          .confirm('Confirme para cancelar ordens abertas e desativar o robô.');
      if (!confirmedByDevice) return;
      await ref.read(botPanelNotifierProvider.notifier).kill();
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(messageForCode(_apiCode(error)))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    key: const Key('bot-kill-switch'),
    onPressed: _busy || !widget.enabled ? null : _kill,
    style: FilledButton.styleFrom(
      backgroundColor: Theme.of(context).colorScheme.error,
      foregroundColor: Theme.of(context).colorScheme.onError,
    ),
    icon: const Icon(Icons.power_settings_new),
    label: Text(_busy ? 'Aguarde…' : 'Kill switch'),
  );
}

String _apiCode(Object error) {
  if (error is ApiException) return error.code;
  if (error is DioException && error.error is ApiException) {
    return (error.error as ApiException).code;
  }
  return 'INTERNAL_ERROR';
}
