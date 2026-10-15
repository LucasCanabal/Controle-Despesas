import 'package:controle_ds/features/auth/presentation/auth_error_message.dart';
import 'package:controle_ds/features/auth/presentation/session_notifier.dart';
import 'package:controle_ds/features/auth/presentation/validators.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ResetPasswordPage extends ConsumerStatefulWidget {
  const ResetPasswordPage({required this.token, super.key});

  final String token;

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _isLoading = false;
  bool _completed = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isLoading = true);
    try {
      await ref
          .read(sessionNotifierProvider.notifier)
          .resetPassword(widget.token, _passwordController.text);
      if (mounted) {
        setState(() => _completed = true);
      }
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(authErrorMessage(error))));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Redefinir senha')),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: _completed
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Senha redefinida com sucesso.'),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('Ir para entrar'),
                    ),
                  ],
                )
              : Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        key: const Key('reset-password'),
                        controller: _passwordController,
                        decoration: const InputDecoration(
                          labelText: 'Nova senha',
                        ),
                        obscureText: true,
                        validator: validatePassword,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const Key('reset-password-confirm'),
                        controller: _confirmationController,
                        decoration: const InputDecoration(
                          labelText: 'Confirme a nova senha',
                        ),
                        obscureText: true,
                        validator: (value) => value != _passwordController.text
                            ? 'As senhas não coincidem.'
                            : null,
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        key: const Key('reset-submit'),
                        onPressed: _isLoading ? null : _submit,
                        child: _isLoading
                            ? const CircularProgressIndicator()
                            : const Text('Redefinir senha'),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    ),
  );
}
