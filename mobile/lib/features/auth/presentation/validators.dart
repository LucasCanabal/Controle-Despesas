String? validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) {
    return 'Informe seu e-mail.';
  }
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
    return 'Informe um e-mail válido.';
  }
  return null;
}

String? validatePassword(String? value) {
  if (value == null || value.length < 10) {
    return 'A senha deve ter pelo menos 10 caracteres.';
  }
  return null;
}

String? validateName(String? value) {
  final name = value?.trim() ?? '';
  if (name.isEmpty) {
    return 'Informe seu nome.';
  }
  return null;
}
