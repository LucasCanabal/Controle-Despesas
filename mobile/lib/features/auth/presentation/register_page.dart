import 'package:controle_ds/features/auth/presentation/auth_error_message.dart';
import 'package:controle_ds/features/auth/presentation/session_notifier.dart';
import 'package:controle_ds/features/auth/presentation/validators.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _acceptedTerms = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || !_acceptedTerms) {
      return;
    }
    await ref
        .read(sessionNotifierProvider.notifier)
        .register(
          _nameController.text.trim(),
          _emailController.text.trim(),
          _passwordController.text,
          _acceptedTerms,
        );
    if (!mounted) {
      return;
    }
    final session = ref.read(sessionNotifierProvider);
    if (session.hasError) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(authErrorMessage(session.error!))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(sessionNotifierProvider).isLoading;
    return Scaffold(
      appBar: AppBar(title: const Text('Criar conta')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    key: const Key('register-name'),
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Nome'),
                    textCapitalization: TextCapitalization.words,
                    validator: validateName,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('register-email'),
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'E-mail'),
                    keyboardType: TextInputType.emailAddress,
                    validator: validateEmail,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('register-password'),
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: 'Senha'),
                    obscureText: true,
                    validator: validatePassword,
                  ),
                  CheckboxListTile(
                    key: const Key('register-terms'),
                    contentPadding: EdgeInsets.zero,
                    value: _acceptedTerms,
                    onChanged: isLoading
                        ? null
                        : (accepted) => setState(
                            () => _acceptedTerms = accepted ?? false,
                          ),
                    title: const Text(
                      'Aceito os termos e a política de privacidade',
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    key: const Key('register-submit'),
                    onPressed: isLoading || !_acceptedTerms ? null : _submit,
                    child: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Criar conta'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
