import 'package:controle_ds/core/errors/app_exception.dart';
import 'package:controle_ds/core/errors/error_messages.dart';
import 'package:controle_ds/core/security/local_auth_service.dart';
import 'package:controle_ds/features/exchange/data/fake_exchange_repository.dart';
import 'package:controle_ds/features/exchange/domain/exchange_credential_info.dart';
import 'package:controle_ds/features/exchange/domain/exchange_status.dart';
import 'package:controle_ds/features/exchange/presentation/exchange_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class ExchangePage extends ConsumerStatefulWidget {
  const ExchangePage({super.key});

  @override
  ConsumerState<ExchangePage> createState() => _ExchangePageState();
}

class _ExchangePageState extends ConsumerState<ExchangePage> {
  final _keyController = TextEditingController();
  final _secretController = TextEditingController();
  bool _busy = false;
  bool _hasLocalInfo = false;
  ExchangeCredentialInfo? _localInfo;

  @override
  void dispose() {
    _keyController.dispose();
    _secretController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final apiKey = _keyController.text;
    final apiSecret = _secretController.text;
    setState(() => _busy = true);
    try {
      if (apiKey.trim().isEmpty || apiSecret.isEmpty) {
        _showMessage('Informe a chave e o secret da corretora.');
        return;
      }
      final confirmed = await ref
          .read(localAuthProvider)
          .confirm('Confirme para salvar a credencial da Binance.');
      if (!confirmed) return;

      final info = await ref
          .read(exchangeRepositoryProvider)
          .saveCredentials(apiKey, apiSecret);
      if (mounted) {
        setState(() {
          _localInfo = info;
          _hasLocalInfo = true;
        });
      }
      _showMessage('Credencial salva com segurança.');
    } on Object catch (error) {
      final code = _apiCode(error);
      var message = messageForCode(code ?? 'INTERNAL_ERROR');
      if (code == 'EXCHANGE_KEY_WITHDRAW_ENABLED') {
        message =
            '$message Configure também a lista de IPs permitidos '
            '(IP whitelist) na Binance.';
      }
      _showMessage(message);
    } finally {
      if (mounted) {
        _keyController.clear();
        _secretController.clear();
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _remove() async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover credencial?'),
        content: const Text(
          'A credencial será removida, o robô será desativado e as ordens '
          'abertas do robô serão canceladas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('confirm-remove-exchange'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted || _busy) return;
    setState(() => _busy = true);
    try {
      final confirmed = await ref
          .read(localAuthProvider)
          .confirm('Confirme para remover a credencial da Binance.');
      if (!confirmed) return;
      await ref.read(exchangeRepositoryProvider).remove();
      if (mounted) {
        setState(() {
          _localInfo = null;
          _hasLocalInfo = true;
        });
      }
      _showMessage('Credencial removida.');
    } on Object catch (error) {
      _showMessage(messageForCode(_apiCode(error) ?? 'INTERNAL_ERROR'));
    } finally {
      if (mounted) {
        _keyController.clear();
        _secretController.clear();
        setState(() => _busy = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final info = ref.watch(exchangeInfoProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Corretora')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Crie uma chave de API sem permissão de saque e restrinja o acesso '
            'por IP (whitelist) nas configurações da Binance.',
          ),
          const SizedBox(height: 20),
          TextField(
            key: const Key('exchange-api-key'),
            controller: _keyController,
            enabled: !_busy,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Chave da API'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('exchange-api-secret'),
            controller: _secretController,
            enabled: !_busy,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(labelText: 'Secret da API'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('save-exchange-credentials'),
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Salvar credencial'),
          ),
          const SizedBox(height: 20),
          if (_hasLocalInfo)
            _CredentialDetails(
              info: _localInfo,
              onRemove: _localInfo == null || _busy ? null : _remove,
            )
          else
            info.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => const Text(
                'Não foi possível carregar o status da corretora.',
              ),
              data: (credential) => _CredentialDetails(
                info: credential,
                onRemove: credential == null || _busy ? null : _remove,
              ),
            ),
        ],
      ),
    );
  }
}

class _CredentialDetails extends StatelessWidget {
  const _CredentialDetails({required this.info, required this.onRemove});

  final ExchangeCredentialInfo? info;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    if (info == null) {
      return const ListTile(
        key: Key('exchange-no-credential'),
        title: Text('Nenhuma credencial conectada.'),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: ${_statusLabel(info!.status)}'),
            const SizedBox(height: 4),
            Text('Chave: ${info!.keyHint}'),
            if (info!.lastCheckedAt != null)
              Text(
                'Última verificação: '
                '${DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(info!.lastCheckedAt!.toLocal())}',
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: const Key('remove-exchange-credentials'),
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remover credencial'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _statusLabel(ExchangeStatus status) => switch (status) {
  ExchangeStatus.connected => 'Conectada',
  ExchangeStatus.invalid => 'Inválida',
  ExchangeStatus.rateLimited => 'Limite de requisições',
  ExchangeStatus.unreachable => 'Indisponível',
};

String? _apiCode(Object error) {
  if (error is ApiException) return error.code;
  if (error is DioException && error.error is ApiException) {
    return (error.error as ApiException).code;
  }
  return null;
}
