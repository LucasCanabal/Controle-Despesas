import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

final localAuthNavigatorKey = GlobalKey<NavigatorState>();

abstract interface class LocalAuthService {
  Future<bool> confirm(String reason);
}

final localAuthProvider = Provider<LocalAuthService>(
  (ref) => DeviceLocalAuthService(LocalAuthentication(), localAuthNavigatorKey),
);

final class DeviceLocalAuthService implements LocalAuthService {
  const DeviceLocalAuthService(this._authentication, this._navigatorKey);

  final LocalAuthentication _authentication;
  final GlobalKey<NavigatorState> _navigatorKey;

  @override
  Future<bool> confirm(String reason) async {
    // Web, Linux, and Fuchsia do not have a supported local_auth integration.
    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.fuchsia) {
      return _showExplicitConfirmation(reason);
    }

    if (!await _authentication.isDeviceSupported()) {
      return _showExplicitConfirmation(reason);
    }

    return _authentication.authenticate(localizedReason: reason);
  }

  Future<bool> _showExplicitConfirmation(String reason) async {
    final context = _navigatorKey.currentContext;
    if (context == null) {
      throw StateError('Não foi possível abrir a confirmação de segurança.');
    }
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirmar ação sensível'),
            content: Text(
              '$reason\n\nEste dispositivo não oferece biometria ou PIN '
              'integrado ao app. Confirme explicitamente para continuar.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                key: const Key('confirm-local-fallback'),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Confirmar'),
              ),
            ],
          ),
        ) ??
        false;
  }
}
