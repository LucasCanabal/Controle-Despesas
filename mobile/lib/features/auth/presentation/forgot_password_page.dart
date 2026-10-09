import 'package:controle_ds/features/auth/presentation/session_notifier.dart';
import 'package:controle_ds/features/auth/presentation/validators.dart';
import 'package:controle_ds/features/auth/presentation/auth_error_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _submitted = false;

  @override
  void dispose() {
    _emailController.dispose();
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
          .forgotPassword(_emailController.text.trim());
      if (mounted) {
        setState(() => _submitted = true);
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(authErrorMessage(error))));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Recuperar senha')),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: _submitted
              ? const Text(
                  'Se o e-mail estiver cadastrado, você receberá instruções '
                  'para redefinir sua senha.',
                  key: Key('forgot-success'),
                  textAlign: TextAlign.center,
                )
              : Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        key: const Key('forgot-email'),
                        controller: _emailController,
                        decoration: const InputDecoration(labelText: 'E-mail'),
                        keyboardType: TextInputType.emailAddress,
                        validator: validateEmail,
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        key: const Key('forgot-submit'),
                        onPressed: _isLoading ? null : _submit,
                        child: _isLoading
                            ? const CircularProgressIndicator()
                            : const Text('Enviar instruções'),
                      ),
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () => context.go('/login'),
                        child: const Text('Voltar para entrar'),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    ),
  );
}
