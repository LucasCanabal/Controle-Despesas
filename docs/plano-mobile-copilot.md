# Plano de Implementação do App Flutter para o GitHub Copilot

**Onde salvar:** `docs/plano-mobile-copilot.md` (no monorepo `ControleDs`).
**Base:** `levantamento-de-requisitos-v2.md` (requisitos, D01–D11, seção 10) e `plano-de-implementacao-sessoes.md` (S07, S08, S09, S12, S17).

---

## 0. Como usar com o Copilot

1. Copie a **Seção 1** para `.github/copilot-instructions.md` (o Copilot lê esse arquivo em toda conversa).
2. No VS Code: abra o Copilot Chat, mude para **Agent** e escolha um modelo forte.
3. Execute **uma sessão por vez** (M1, M2...). Em cada sessão:
   - Anexe no chat: `#file:docs/plano-mobile-copilot.md`, `#file:docs/levantamento-de-requisitos-v2.md`, `#file:docs/PROGRESS.md`.
   - Cole o bloco **Prompt** da sessão.
   - Quando terminar, rode no terminal (dentro de `mobile/`): `flutter test` e `dart analyze`.
   - Só vá para a próxima sessão com os dois verdes. Faça commit a cada sessão.
4. Se o Copilot parar e fizer uma pergunta, responda. Isso é o comportamento desejado (regra 9).

---

## 1. Instruções permanentes (colar em `.github/copilot-instructions.md`)

```markdown
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
- Prefixo `/api/v1`. Bearer em tudo, exceto register, login, refresh, forgot-password, reset-password e health.
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
```

---

## 2. Mapa de sessões

| Sessão | Título | Requisitos | Depende de backend |
|---|---|---|---|
| M1 | Criar projeto e dependências | S00 parte 4 | não |
| M2 | Núcleo (config, erros, storage, Dio, tema, rotas, dinheiro) | MOB-11, D01, RNF-11 | não |
| M3 | Autenticação | MOB-01, MOB-02 | S04 (ou repositório fake) |
| M4 | Finanças | MOB-03, 04, 05 | S06 (ou fake) |
| M5 | Corretora, carteira, calculadora | MOB-06, 07, 10, 12 | S10, S11 (ou fake) |
| M6 | Robô: painel e histórico | MOB-08, 09, 12 | S15 (ou fake) |
| M7 | Validação final | RNF, segurança | todos |

> Enquanto o backend de uma sessão não existir, o Copilot implementa o **repositório fake** (classe `Fake<X>Repository` em memória) e o app roda com ele via provider. Quando o backend ficar pronto, troca-se só o provider.

---

## M1: Criar o projeto

**Faça no terminal (não no Copilot):**

```powershell
cd C:\Users\silve\Desktop\ControleDs
flutter create --org br.com.controleds --project-name controle_ds --platforms android,ios,web mobile
cd mobile
flutter pub add flutter_riverpod go_router dio flutter_secure_storage decimal fl_chart intl local_auth
flutter pub add --dev mocktail
flutter test
dart analyze
```

(`web` entra para você testar no Chrome enquanto o Android SDK não está pronto.)

**Pronto quando:** `flutter test` e `dart analyze` verdes e commit feito.

---

## M2: Núcleo do app

**Prompt:**

```
Implemente a sessão M2 do plano em #file:docs/plano-mobile-copilot.md.
Crie exatamente os arquivos e classes listados na seção M2, em /mobile/lib/core.
Não crie telas de negócio. Pode criar páginas placeholder só para o roteador.
Escreva os testes listados. Ao final rode flutter test e dart analyze e atualize docs/PROGRESS.md.
```

**Arquivos e classes**

| Arquivo | Classe / função | Responsabilidade |
|---|---|---|
| `core/config/app_config.dart` | `AppConfig` (`env`, `baseUrl`); `appConfigProvider` | Lê `--dart-define=API_BASE_URL` e `APP_ENV`. Padrão dev Android: `http://10.0.2.2:8000/api/v1`. Web/desktop: `http://localhost:8000/api/v1`. |
| `core/errors/app_exception.dart` | `sealed class AppException` e subclasses `ApiException(code, message, statusCode, details, requestId)`, `NetworkException`, `UnauthorizedException` | Erro tipado de toda a camada de dados. |
| `core/errors/error_messages.dart` | `String messageForCode(String code)` | Mapa pt-BR dos códigos da seção 10.1 (`INVALID_CREDENTIALS`, `TOO_MANY_ATTEMPTS`, `EXCHANGE_KEY_INVALID`, `EXCHANGE_KEY_WITHDRAW_ENABLED`, `CONSENT_REQUIRED`, `PAPER_PERIOD_NOT_MET`...). Código desconhecido devolve mensagem genérica. |
| `core/storage/token_storage.dart` | `AuthTokens(accessToken, refreshToken)`; `TokenStorage` com `read()`, `save(AuthTokens)`, `clear()`; `tokenStorageProvider` | Persistência com `flutter_secure_storage`. Recebe o storage por construtor (para mock). |
| `core/network/dio_client.dart` | `dioProvider`, `refreshDioProvider` | Dio principal com interceptors e Dio separado (sem interceptors) só para `/auth/refresh`. |
| `core/network/auth_interceptor.dart` | `AuthInterceptor` | Injeta `Authorization: Bearer`. Em 401: faz **um** refresh (fila única para chamadas simultâneas), repete a requisição; se falhar, limpa tokens e emite evento de sessão expirada. |
| `core/network/error_interceptor.dart` | `ErrorInterceptor` | Converte resposta `{error:{...}}` em `ApiException`; falha de conexão e timeout em `NetworkException`. |
| `core/session/session_events.dart` | `sessionExpiredProvider` (stream ou `Notifier`) | Avisa o roteador para ir ao login. |
| `core/money/money.dart` | `Decimal parseMoney(String)`; `String formatBRL(Decimal)`; `String formatUSDT(Decimal)`; `String moneyToJson(Decimal)` | Única porta de entrada e saída de dinheiro. |
| `core/pagination/page.dart` | `Page<T>(items, nextCursor)` e `Page.fromJson(json, itemParser)` | Formato de lista paginada. |
| `core/theme/app_theme.dart` | `AppTheme.light`, `AppTheme.dark` | Tema Material 3. |
| `core/router/app_router.dart` | `routerProvider` (`GoRouter`) | Rotas `/splash`, `/login`, `/register`, `/forgot-password`, `/reset-password`, `/home`. `redirect` baseado na sessão. |
| `main.dart` e `app.dart` | `ProviderScope`, `MaterialApp.router` | Ponto de entrada. |

**Testes (Dio mockado, sem rede)**
- `auth_interceptor_test.dart`: injeta header; em 401 faz refresh uma vez e repete; refresh falha então limpa tokens e sinaliza expiração; dois 401 simultâneos geram um único refresh.
- `error_interceptor_test.dart`: JSON de erro vira `ApiException` com `code`; timeout vira `NetworkException`.
- `error_messages_test.dart`: todos os códigos da tabela 10.1 têm mensagem.
- `money_test.dart`: `"150.75"` ida e volta sem perda; formatação pt-BR; nunca usa `double`.
- `token_storage_test.dart`: salvar, ler e limpar.

**Pronto quando:** testes verdes, `dart analyze` limpo e o app abre (no Chrome) na tela de splash placeholder.

---

## M3: Autenticação

**Prompt:**

```
Implemente a sessão M3 do plano em #file:docs/plano-mobile-copilot.md (requisitos MOB-01 e MOB-02).
Use o núcleo criado na M2. Crie lib/features/auth conforme a seção M3.
Se o backend ainda não estiver disponível, implemente também FakeAuthRepository e deixe o provider apontando para ele, com um comentário TODO claro.
Escreva os testes de widget e de provider listados. Ao final rode flutter test e dart analyze e atualize docs/PROGRESS.md.
```

**Arquivos e classes** (em `lib/features/auth/`)

| Camada | Arquivo | Classe | Responsabilidade |
|---|---|---|---|
| domain | `domain/user.dart` | `User(id, name)` | Dados básicos do login. |
| domain | `domain/auth_repository.dart` | `abstract class AuthRepository` | `login(email, password)`, `register(name, email, password, acceptedTerms)`, `refresh(refreshToken)`, `logout()`, `forgotPassword(email)`, `resetPassword(token, newPassword)`. |
| data | `data/auth_api.dart` | `AuthApi` | `POST /auth/login`, `/register`, `/refresh`, `/logout`, `/forgot-password`, `/reset-password`. |
| data | `data/auth_repository_impl.dart` | `AuthRepositoryImpl` | Converte resposta (`access_token`, `refresh_token`, `expires_in`, `user`) e salva tokens no `TokenStorage`. |
| data | `data/fake_auth_repository.dart` | `FakeAuthRepository` | Em memória, para desenvolver sem backend. |
| presentation | `presentation/session_notifier.dart` | `SessionState` (`unknown`, `authenticated(user)`, `unauthenticated`); `SessionNotifier extends AsyncNotifier<SessionState>` | Restaura sessão (lê tokens, tenta refresh), faz login, logout e reage a `sessionExpiredProvider`. |
| presentation | `presentation/validators.dart` | `validateEmail`, `validatePassword` (mínimo 10), `validateName` | Espelham as regras da API (AUTH-01). |
| presentation | `presentation/splash_page.dart` | `SplashPage` | MOB-01: restaura a sessão e vai ao Dashboard ou Login. |
| presentation | `presentation/login_page.dart` | `LoginPage` | Formulário, estado carregando/erro, mensagem por `error.code`. |
| presentation | `presentation/register_page.dart` | `RegisterPage` | Nome, e-mail, senha, checkbox de aceite dos termos (obrigatório). |
| presentation | `presentation/forgot_password_page.dart`, `reset_password_page.dart` | `ForgotPasswordPage`, `ResetPasswordPage` | Mostra sempre a mesma mensagem de sucesso, exista ou não o e-mail (AUTH-06). |

**Comportamentos obrigatórios**
- `INVALID_CREDENTIALS`, `TOO_MANY_ATTEMPTS`, `EMAIL_ALREADY_REGISTERED` aparecem com a mensagem mapeada.
- Logout limpa os tokens mesmo se a chamada à API falhar.
- Sem token válido, qualquer rota protegida redireciona ao login.

**Testes**
- `session_notifier_test.dart`: sem token então `unauthenticated`; token + refresh ok então `authenticated`; refresh falha então `unauthenticated`.
- Widget tests: validação dos formulários; botão desabilitado enquanto carrega; cadastro bloqueado sem aceitar termos; redirecionamento por sessão.

---

## M4: Finanças

**Prompt:**

```
Implemente a sessão M4 do plano em #file:docs/plano-mobile-copilot.md (requisitos MOB-03, MOB-04 e MOB-05).
Crie lib/features/finance conforme a seção M4, usando AsyncNotifier/AsyncValue para estados.
Use FakeFinanceRepository se o backend ainda não estiver pronto.
Todo valor monetário é Decimal vindo de string. Escreva os testes listados. Ao final rode flutter test e dart analyze e atualize docs/PROGRESS.md.
```

**Arquivos e classes** (em `lib/features/finance/`)

| Camada | Arquivo | Classe | Responsabilidade |
|---|---|---|---|
| domain | `domain/transaction.dart` | `TransactionType` (`income`, `expense` ↔ `INCOME`/`EXPENSE`); `Transaction(id, type, amount: Decimal, description, categoryId, date)`; `TransactionDraft` | Criar e editar. |
| domain | `domain/category.dart` | `Category(id, name, archived)` | Categorias. |
| domain | `domain/dashboard_summary.dart` | `DashboardSummary(month, totalIncome, totalExpense, monthBalance, cumulativeBalance, byCategory, recentTransactions)`; `CategoryTotal` | Resposta de `GET /dashboard/summary`. |
| domain | `domain/transaction_filter.dart` | `TransactionFilter(from, to, type, categoryId)` | Filtros de FIN-02. |
| domain | `domain/finance_repository.dart` | `abstract class FinanceRepository` | `getSummary(month)`, `listTransactions(filter, cursor)` → `Page<Transaction>`, `create`, `update`, `delete`, `listCategories`, `createCategory`, `updateCategory`, `archiveCategory`. |
| data | `data/finance_api.dart` | `FinanceApi` | Rotas `/transactions`, `/categories`, `/dashboard/summary?month=YYYY-MM`. |
| data | `data/finance_repository_impl.dart`, `fake_finance_repository.dart` | `FinanceRepositoryImpl`, `FakeFinanceRepository` | Implementação real e fake. |
| presentation | `presentation/dashboard_notifier.dart` | `DashboardNotifier extends AsyncNotifier<DashboardSummary>` (+ `selectedMonthProvider`) | Mês atual por padrão. |
| presentation | `presentation/transactions_notifier.dart` | `TransactionsNotifier` com `loadMore()`, `setFilter()`, `refresh()` | Paginação infinita por cursor. |
| presentation | `presentation/categories_notifier.dart` | `CategoriesNotifier` | CRUD de categorias. |
| presentation | `presentation/home_shell.dart` | `HomeShell` | Navegação inferior (Dashboard, Transações, Categorias, mais as abas das próximas sessões como placeholder). |
| presentation | `presentation/dashboard_page.dart` | `DashboardPage` | Seletor de mês, cards (receitas, despesas, saldo do mês, saldo acumulado), gráfico `fl_chart` por categoria, últimas transações. |
| presentation | `presentation/transactions_page.dart` | `TransactionsPage` | Lista com scroll infinito e filtros. |
| presentation | `presentation/transaction_form_page.dart` | `TransactionFormPage` | Criar/editar. Valor > 0, descrição 2–100 caracteres. |
| presentation | `presentation/categories_page.dart` | `CategoriesPage` | Criar, editar, arquivar. |

**Comportamentos obrigatórios**
- Excluir sempre pede confirmação (diálogo).
- Mês sem dados mostra zeros, sem erro.
- `month_balance` e `cumulative_balance` têm rótulos distintos na tela.
- Erro 422 (`details`) aparece no campo correspondente.

**Testes**
- Providers com `FakeFinanceRepository`: carga do dashboard, troca de mês, paginação (`loadMore` não duplica itens), filtro reinicia a lista.
- Widget tests: dashboard, formulário (validações), confirmação de exclusão.

---

## M5: Corretora, carteira e calculadora

**Prompt:**

```
Implemente a sessão M5 do plano em #file:docs/plano-mobile-copilot.md (requisitos MOB-06, MOB-07, MOB-10 e MOB-12).
Crie as features exchange, portfolio e calculator conforme a seção M5.
O contrato de GET /portfolio e GET /exchange/credentials só está definido parcialmente. Para qualquer campo não definido, PARE e pergunte; não invente.
Escreva os testes listados. Ao final rode flutter test e dart analyze e atualize docs/PROGRESS.md.
```

**Arquivos e classes**

| Feature | Arquivo | Classe | Responsabilidade |
|---|---|---|---|
| core | `core/security/local_auth_service.dart` | `LocalAuthService.confirm(reason)`; `localAuthProvider` | MOB-12: biometria/PIN do aparelho. Interface mockável. |
| exchange | `domain/exchange_status.dart` | `ExchangeStatus` (`connected`, `invalid`, `rateLimited`, `unreachable`); `ExchangeCredentialInfo(status, keyHint, lastCheckedAt)` | Só metadados. Nunca guarda a key nem o secret. |
| exchange | `domain/exchange_repository.dart` | `abstract class ExchangeRepository` | `saveCredentials(apiKey, apiSecret)` (`PUT /exchange/credentials`), `getInfo()`, `remove()`. |
| exchange | `presentation/exchange_page.dart` | `ExchangePage` | Orientações (sem permissão de saque, IP whitelist), campo secret mascarado, confirmação biométrica antes de salvar. Depois de salvar, limpa os campos e mostra só `key_hint`. |
| portfolio | `domain/portfolio.dart` | `Portfolio`, `PortfolioAsset`, `stale`, `lastSyncedAt` | Ativos, valor total, P&L absoluto e %. Campos exatos conforme resposta de `GET /portfolio`. |
| portfolio | `presentation/portfolio_page.dart` | `PortfolioPage` | Lista, total, pull-to-refresh (`POST /portfolio/sync`), faixa de aviso quando `stale=true`. |
| calculator | `presentation/compound_interest_page.dart` | `CompoundInterestPage` | Entradas: valor inicial, aporte mensal, taxa, meses. Resultado vem de `POST /calculations/compound-interest` (o app não calcula). |

**Testes**
- O secret nunca aparece na tela depois de salvar e os campos são limpos.
- `EXCHANGE_KEY_WITHDRAW_ENABLED` mostra a orientação de IP whitelist.
- Salvar credencial sem biometria confirmada não chama a API.
- `stale=true` mostra o aviso na carteira.
- Calculadora: taxa 0 aceita; valores inválidos bloqueiam o envio.

---

## M6: Robô (painel e histórico)

**Prompt:**

```
Implemente a sessão M6 do plano em #file:docs/plano-mobile-copilot.md (requisitos MOB-08, MOB-09 e MOB-12).
Crie lib/features/bot conforme a seção M6.
O modo LIVE NÃO está liberado nesta fase: a interface deve permitir apenas PAPER, mostrando LIVE desabilitado com explicação.
Campos e rotas só os do contrato. Para qualquer dúvida, pare e pergunte.
Escreva os testes listados. Ao final rode flutter test e dart analyze e atualize docs/PROGRESS.md.
```

**Arquivos e classes** (em `lib/features/bot/`)

| Camada | Arquivo | Classe | Responsabilidade |
|---|---|---|---|
| domain | `bot_state.dart` | `BotState` (`inactive`, `starting`, `running`, `paused`, `stoppedByRisk`, `error`); `BotStatus` | Resposta de `GET /bot/status` (BOT-13). |
| domain | `bot_settings.dart` | `BotMode` (`paper`, `live`); `BotSettings(mode, strategyId, strategyParams, maxCapitalAllocation, maxOrderSize, maxDailyLoss, maxTotalLoss, allowedPairs)` | `GET/PUT /bot/settings`. Valores monetários em `Decimal`. |
| domain | `bot_order.dart`, `bot_order_filter.dart` | `BotOrder`, `BotOrderFilter(simulated, pair, from, to)` | Histórico (BOT-14). |
| domain | `bot_repository.dart` | `abstract class BotRepository` | `getSettings`, `saveSettings`, `getStatus`, `start`, `stop`, `kill`, `acceptConsent`, `listOrders(filter, cursor)`. |
| presentation | `bot_panel_notifier.dart` | `BotPanelNotifier` | Atualiza o status por polling (intervalo configurável, para quando a aba sai de foco). |
| presentation | `bot_panel_page.dart` | `BotPanelPage` | Estado, modo, capital alocado, switch ligar/desligar, P&L do dia, último erro, aviso de risco. |
| presentation | `kill_switch_button.dart` | `KillSwitchButton` | Botão destacado; exige confirmação do usuário **e** biometria/PIN (`LocalAuthService`). |
| presentation | `bot_settings_page.dart` | `BotSettingsPage` | Formulário de BOT-01. |
| presentation | `bot_orders_page.dart` | `BotOrdersPage` | Lista paginada com filtros simulada/real, par e período. |

**Comportamentos obrigatórios**
- Ações que retornam `BOT_INVALID_STATE`, `CONSENT_REQUIRED` ou `PAPER_PERIOD_NOT_MET` mostram a mensagem mapeada, sem travar a tela.
- Ordens simuladas ficam visualmente marcadas.
- O switch fica desabilitado quando o estado não permitir a ação.
- Aviso de risco sempre visível no painel.

**Testes**
- Widget tests de cada estado do robô (`inactive`, `running`, `stoppedByRisk`, `error`).
- Kill switch só chama a API após confirmação e biometria.
- Filtros do histórico reiniciam a lista.

---

## M7: Validação final

**Prompt:**

```
Execute a sessão M7 do plano em #file:docs/plano-mobile-copilot.md.
Não crie funcionalidades novas. Faça a revisão listada e corrija apenas o que falhar.
Reporte o resultado em docs/PROGRESS.md.
```

**Checklist**
- `flutter test` verde e `dart analyze` sem erros.
- Busca no código por `double` em valores monetários: nenhuma ocorrência.
- Busca por `print(`/`debugPrint(` com token, senha, key ou secret: nenhuma ocorrência.
- Nenhum segredo, URL de produção ou chave no repositório.
- Todas as rotas protegidas redirecionam ao login sem sessão.
- Teste de integração rodando o app contra a API local (backend no ar).
- Todas as telas tratam: carregando, erro, vazio.

---

## Regras para você, humano

- Uma sessão por vez, com commit ao final.
- Se o Copilot inventar rota ou campo que não está na seção 10 do levantamento, rejeite e peça para seguir o contrato.
- Se o Copilot quiser trocar biblioteca (ex.: GetX, freezed), recuse. Isso está proibido nas instruções.
- Se um teste falhar fora do escopo da sessão, registre em `docs/PROGRESS.md` em "Problemas encontrados" e continue.
