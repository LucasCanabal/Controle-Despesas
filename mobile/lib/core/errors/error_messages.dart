const _messagesByCode = <String, String>{
  'BAD_REQUEST':
      'A solicitação é inválida. Confira os dados e tente novamente.',
  'UNAUTHORIZED': 'Sua sessão expirou. Entre novamente.',
  'INVALID_CREDENTIALS': 'E-mail ou senha inválidos.',
  'TOKEN_EXPIRED': 'Sua sessão expirou. Entre novamente.',
  'TOKEN_REUSED': 'Sua sessão foi invalidada. Entre novamente.',
  'FORBIDDEN': 'Você não tem permissão para realizar esta ação.',
  'CONSENT_REQUIRED': 'É necessário aceitar o consentimento para continuar.',
  'PAPER_PERIOD_NOT_MET':
      'O período mínimo de operação em modo PAPER ainda não foi concluído.',
  'NOT_FOUND': 'O item solicitado não foi encontrado.',
  'EMAIL_ALREADY_REGISTERED': 'Este e-mail já está cadastrado.',
  'BOT_INVALID_STATE':
      'Esta ação não está disponível no estado atual do robô.',
  'VALIDATION_ERROR': 'Confira os dados informados.',
  'EXCHANGE_KEY_INVALID': 'A chave da corretora é inválida.',
  'EXCHANGE_KEY_WITHDRAW_ENABLED':
      'Desative a permissão de saque da chave da corretora.',
  'TOO_MANY_ATTEMPTS':
      'Muitas tentativas. Aguarde um pouco antes de tentar novamente.',
  'RATE_LIMITED': 'Muitas solicitações. Aguarde um pouco e tente novamente.',
  'INTERNAL_ERROR': 'Ocorreu um erro inesperado. Tente novamente.',
  'EXCHANGE_UNAVAILABLE': 'A corretora está indisponível no momento.',
};

String messageForCode(String code) =>
    _messagesByCode[code] ??
    'Não foi possível concluir a solicitação. Tente novamente.';
