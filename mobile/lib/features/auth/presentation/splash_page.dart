import 'package:controle_ds/features/auth/presentation/session_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SplashPage extends ConsumerWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionNotifierProvider);
    return Scaffold(
      body: Center(
        child: session.when(
          loading: () => const CircularProgressIndicator(),
          error: (error, stackTrace) => const Text(
            'Não foi possível restaurar sua sessão. Tente novamente.',
          ),
          data: (_) => const CircularProgressIndicator(),
        ),
      ),
    );
  }
}
