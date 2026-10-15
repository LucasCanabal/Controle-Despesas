# Instruções para o Copilot: projeto ControleDs

Monorepo: `/backend` (FastAPI), `/mobile` (Flutter), `/docs`. Aqui você trabalha em `/mobile`.
Nome do pacote Dart: `controle_ds`. Imports sempre `package:controle_ds/...`.

## Stack (não troque)
- Flutter + Dart, estado com **flutter_riverpod** (`Notifier`/`AsyncNotifier`, SEM geradores de código).
- HTTP: **dio**. Rotas: **go_router**. Tokens: **flutter_secure_storage**.
- Dinheiro: **decimal** (`Decimal`). NUNCA `double` para valores monetários.
- Gráficos: **fl_chart**. Datas e moeda: **intl** (pt-BR). Biometria: **local_auth**.
- Testes: `flutter_test` + **mocktail**.
- NÃO usar: freezed, json_serializable, build_runner, riverpod_generator, GetX, Bloc, FutureBuilder junto com Riverpod.

## Arquitetura
- Por feature: `lib/features/<feature>/{data,domain,presentation}`. Código comum em `lib/core`.
- `domain`: modelos imutáveis (classes `final` com `const` constructor) e interfaces de repositório. Sem Flutter e sem Dio.
- `data`: `*Api` (chama Dio, devolve Map/JSON), `*RepositoryImpl` (converte JSON em modelos de domínio).
- `presentation`: providers Riverpod, páginas e widgets. Widgets não chamam Dio diretamente.
- Modelos escrevem `fromJson` e `toJson` à mão. Dinheiro vem como **string decimal** ("150.75") e vira `Decimal`.
- O app NÃO calcula regra financeira. Exibe o que a API retorna.

## Contrato da API (seção 10 do levantamento)
- Prefixo `/api/v1`. Autenticação por `Authorization: Bearer <token>` em tudo, exceto register, login, refresh, forgot-password, reset-password e health.
- Listas paginadas: `{ "items": [...], "next_cursor": "..." | null }`.
- Erro único: `{ "error": { "code", "message", "details": [{field, issue}], "request_id" } }`.
- Mensagens ao usuário em pt-BR, mapeadas a partir de `error.code`.
- Contrato é lei: não invente rotas, campos ou códigos. Se o contrato não definir algo que a tela precisa, PARE e pergunte.

## Regras de trabalho
1. Faça só o que a sessão pede. Não refatore sessões anteriores nem troque bibliotecas.
2. Antes de criar um arquivo, verifique se ele já existe. Reaproveite o que existe.
3. Testes junto com o código, cobrindo os critérios de aceite dos requisitos da sessão.
4. Nunca logar tokens, senhas, key ou secret. Nenhum segredo no repositório.
5. Nunca exibir o secret da corretora depois de salvo. Só o `key_hint`.
6. Ao terminar: rode `flutter test` e `dart analyze`, corrija o que for da sessão e atualize `docs/PROGRESS.md` (sessão, data, IDs atendidos, decisões, pendências).
7. Dúvida bloqueante (requisito em aberto, campo inexistente no contrato): pare e pergunte. Não assuma.
8. Código e nomes em inglês; textos da interface em pt-BR.
