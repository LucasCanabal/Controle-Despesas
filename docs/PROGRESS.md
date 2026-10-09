# Progresso

## S00 — Monorepo, Docker Compose e CI (partes 1, 2 e 3 de 4) (2026-10-08)
- Status: parcial
- Requisitos atendidos: parte de RNF-14 / D05 (estrutura do monorepo, backend mínimo e serviços locais no Compose); RNF-09 (`/health`)
- Decisões: app em `create_app()`; health em `app/modules/plat/router.py`; dependências mínimas por ora; imagens da API/worker usam Dockerfile inline (Compose v2.17.0+), evitando criar outro arquivo nesta parte.
- CI (parte 3): `.github/workflows/backend-ci.yml` roda ruff, ruff format, mypy e pytest com cobertura mínima de 80%. service container Postgres 15 já no CI (ainda sem testes que o usem; `DATABASE_URL` pronta para a S01); Redis entra quando for usado
- Compose (parte 2): `api`, `worker` placeholder, Postgres 15 e Redis 7; imagens da API/worker construídas com Dockerfile inline, dados persistidos em volumes nomeados e dependências aguardam healthchecks. Postgres usa autenticação `trust` apenas para desenvolvimento local e não publica porta no host; não usar esta configuração em ambiente compartilhado ou de produção.
- Validação: `docker compose config` passou após a instalação do Docker Desktop. `docker compose up --build` não foi executado: o Docker Engine não inicia enquanto a virtualização de hardware estiver desativada neste computador; a inicialização dos serviços e o healthcheck em `/api/v1/health` continuam pendentes.
- Problemas encontrados (não corrigidos): `backend/tests/test_health.py` espera que `GET /api/v1/` retorne 200, mas `backend/app/modules/plat/router.py` não registra uma rota `/`; não bloqueia o healthcheck do Compose, por isso ficou fora do escopo.
- Pendências para próximas sessões: validar o Compose com Docker e validar o workflow de CI no GitHub após push. A parte 4 (`flutter create`) foi concluída na M1, confirmada pelo commit `d428a89`.

## M1 — Criação do projeto mobile e dependências (2026-10-06)
- Status: concluída
- Entregas: projeto Flutter `mobile/` criado para Android, iOS e web; dependências base instaladas conforme o plano.
- Evidência no Git: commit `d428a89 chore(mobile): flutter create e dependencias (M1); remove pasta mnt`.
- Observação: este marco conclui a parte 4 de S00; Docker Compose e execução do CI continuam sendo pendências de S00.

## M2 — Núcleo do app (2026-10-06)
- Status: concluída
- Requisitos atendidos: MOB-11, D01 e RNF-11
- Decisões: Dio separado para refresh, refresh único compartilhado entre 401 simultâneos, tokens em `flutter_secure_storage`, dinheiro mantido em `Decimal`, rotas de negócio protegidas pelo estado de sessão autenticada. As páginas placeholder daquela etapa foram substituídas nas sessões M3–M6.
- Validação: `flutter test` passou; `dart analyze` sem problemas
- Pendências atuais: integração com as APIs reais quando os respectivos módulos do backend estiverem disponíveis; a ligação do roteador à sessão foi concluída em M3.

## M3 — Autenticação (2026-10-06)
- Status: concluída
- Requisitos atendidos: MOB-01 e MOB-02 (fluxos locais, validação, restauração e redirecionamento)
- Decisões: os exemplos de payload e respostas de AUTH foram adicionados à seção 10.3 do contrato; `AuthApi` e `AuthRepositoryImpl` implementam esses exemplos, o repository real tem provider alternativo e `FakeAuthRepository` continua como provider ativo até a S04 do backend. `SessionNotifier` coordena restauração, login, cadastro e logout; logout limpa tokens mesmo quando a chamada remota falha; mensagens usam `messageForCode`; esqueci a senha exibe sempre a mesma mensagem.
- Mudança de contrato: seção 10.3 agora especifica os corpos de register, login, refresh, logout, forgot-password e reset-password, incluindo `accepted_terms`, `terms_version` e status/respostas esperados.
- Validação: `flutter test` passou (36 testes); `dart analyze` sem problemas.
- Pendências: **trocar FakeAuthRepository pelo real quando a S04 do backend existir** e validar a integração contra o backend quando estiver disponível.
- Instruções: `.github/copilot-instructions.md` foi criado com o bloco da Seção 1, pois o arquivo não existia.

## M4 — Finanças (2026-10-06)
- Status: concluída
- Requisitos atendidos: FIN-01 a FIN-07; MOB-03, MOB-04 e MOB-05
- Decisões: `Decimal` permanece no domínio e no tráfego JSON; para o fl_chart, os valores são normalizados em proporções adimensionais antes da conversão exigida pelo widget. `FakeFinanceRepository` é o provider ativo e `FinanceRepositoryImpl` está disponível via provider alternativo. Providers de dashboard, transações e categorias usam `AsyncNotifier`. HomeShell substitui o placeholder e as datas/material UI usam localização pt-BR.
- Mudança de contrato: seção 10.3 agora descreve filtros/paginação de transações, respostas de transação, criação/edição/exclusão e CRUD/arquivamento de categorias, conforme campos autorizados para M4.
- Validação: `flutter test` passou (46 testes); `dart analyze` sem problemas.
- Pendências: **trocar o provider fake pelo `FinanceRepositoryImpl` quando as sessões S05/S06 do backend existirem** e validar a integração contra a API real.

## M5 — Corretora, carteira e calculadora (2026-10-06)
- Status: concluída
- Requisitos atendidos: EXCH-01 a EXCH-05, PORT-01 a PORT-04, CALC-04; MOB-06, MOB-07, MOB-10 e MOB-12
- Decisões: respostas e campos autorizados foram registrados na seção 10.3; valores monetários e quantidades são `Decimal`; a key e o secret permanecem apenas nos controllers locais, nunca são armazenados em Riverpod/modelos/logs/mensagens, e os campos são limpos no `finally`; confirmação local precede salvar/remover; as APIs reais usam Dio, mas os providers ativos usam fakes; o fake de juros compostos é demonstrativo e arredonda cada mês para 2 casas; web/Linux/Fuchsia usa diálogo explícito de confirmação quando não há autenticação do dispositivo.
- Validação: `flutter test` passou (60 testes); `dart analyze` sem problemas.
- Pendências: trocar os providers fake por `ExchangeRepositoryImpl` e `PortfolioRepositoryImpl` quando S10/S11 do backend existirem (e o repositório real da calculadora quando o endpoint S11 existir); validar integração com backend; os ajustes nativos de `local_auth` (Android/iOS) não puderam ser validados em aparelho.

## M6 — Robô: painel e histórico (2026-10-06)
- Status: concluída
- Requisitos atendidos: BOT-01, BOT-03, BOT-04, BOT-07, BOT-08, BOT-13, BOT-14; MOB-08, MOB-09 e MOB-12
- Decisões: contratos autorizados para configurações, estado e histórico foram registrados na seção 10.3; o modo enviado é sempre `PAPER` e LIVE permanece desabilitado; ações usam somente os endpoints start/stop/kill existentes e respeitam os estados de 9.2; kill exige confirmação no diálogo e autenticação local; consentimento versionado fica no modelo/API mas seu fluxo visual fica para S19; polling de 10 s só roda com a aba/painel visível e é injetável em teste; histórico usa páginas de 5 itens e deduplica por ID; providers ativos usam FakeBotRepository.
- Validação: `flutter test` passou (78 testes); `dart analyze` sem problemas.
- Pendências: trocar `FakeBotRepository` pelo `BotRepositoryImpl` quando S15 do backend existir; modo LIVE e fluxo de consentimento de risco (BOT-02) ficam para S19.

## M7 — Validação final (2026-10-06)
- Status: concluída, com integração real pendente por indisponibilidade do backend.
- Comparação com o código e o Git: S00 permanece parcial por Docker Compose e execução do CI; M1 existe e está registrada pelo commit `d428a89`; M2–M6 têm suas features e requisitos presentes no código. As quantidades de testes em M3–M6 são os resultados históricos de cada marco; o total corrente é 78. O `HEAD` está em `41e83a6` (M5); M6 e M7 estão no working tree, ainda sem commit.
- Auditoria:

| # | Resultado | Evidência / constatação |
|---|---|---|
| 1 | PASSOU | `flutter test`: 78 testes passaram (`+77: All tests passed!`); `dart analyze`: `No issues found!`. Reexecutados após as correções. |
| 2 | CORRIGIDO | Em `mobile/lib/features/finance/presentation/dashboard_page.dart:182`, os montantes continuam `Decimal`; o gráfico recebe somente a proporção adimensional `total/total`, convertida na borda visual. Não há `double`/`num` em modelos nem cálculos monetários. |
| 3 | PASSOU | Busca em `mobile/lib` não encontrou `print`, `debugPrint`, `developer.log` ou `Logger`; nenhum log de token, senha, key ou secret. |
| 4 | PASSOU | Busca no mobile e arquivos versionados não encontrou segredo real, chave privada ou URL de produção. URLs encontradas são locais (`10.0.2.2`, `localhost`) ou o host reservado `example.test` dos testes mockados; `.env.example` contém somente comentários e está intencionalmente vazio. Strings de autenticação/chaves nos testes e fakes são fixtures não reais. |
| 5 | PASSOU | `mobile/lib/features/exchange/presentation/exchange_page.dart:21` mantém key/secret somente nos controllers; o secret usa `obscureText`, os campos são limpos em sucesso/erro e o estado guarda apenas metadados. `ExchangeCredentialInfo` contém `key_hint`, status e data, sem key/secret; erros são mapeados por código. O transporte recebe os argumentos apenas para enviar a requisição contratada. |
| 6 | CORRIGIDO | `mobile/test/auth_pages_test.dart:152` percorre as rotas registradas do roteador sem sessão: as rotas públicas permanecem acessíveis, `/splash` vai para `/login` e a rota protegida `/home` redireciona para `/login`. As telas de negócio estão sob o `HomeShell` protegido. |
| 7 | PASSOU | Dashboard, transações, categorias, carteira, corretora e histórico têm estados de carregamento, erro e vazio apropriados. O painel do robô tem carregamento/erro; vazio não se aplica ao recurso singular `/bot/status`, cujo estado inicial é `INACTIVE`. Não há estado faltante. |
| 8 | PASSOU | Providers ativos em fake estão listados na tabela “Fakes ativos” abaixo, com o provider real alternativo e a sessão de backend para troca. |
| 9 | PASSOU | Controllers de tela/dialog e ScrollController são descartados; `BotPanelNotifier` cancela o Timer ao perder foco e em `onDispose`; Dio/router/listenable também são fechados. |
| 10 | PASSOU | Não há `freezed`, `build_runner`, `json_serializable`, `riverpod_generator`, GetX ou Bloc no `pubspec.yaml`. Dependência direta não usada: `cupertino_icons` (restante das dependências diretas é usado pelo app, análise ou testes). |
| 11 | CORRIGIDO | `mobile/android/app/src/main/AndroidManifest.xml:2` declara INTERNET e `:3` declara USE_BIOMETRIC; `MainActivity` é `FlutterFragmentActivity`. HTTP em claro está habilitado somente em `src/debug/AndroidManifest.xml:2`, não em `main`/release. |
| 12 | FALHOU — PENDENTE | Não foi possível executar integração real: o backend disponível contém somente `plat`; os módulos AUTH/FIN/EXCH/PORT/BOT ainda precisam das sessões S03–S06, S10–S11 e S13–S15. Os testes de API existentes são mockados. Não foi inventada API nem integração. |
| 13 | PASSOU | Rotas, campos e códigos usados pelas implementações Dio estão documentados nas seções 10.2, 10.3 e 10.1 do levantamento; não foi encontrado endpoint, campo ou código de erro usado pelo app sem documentação. |

- Validação final: `flutter test` — 78 testes passaram; `dart analyze` — sem problemas.
- Correções desta sessão: normalização decimal do gráfico; teste percorrendo as rotas sem sessão; permissão INTERNET no manifesto principal e HTTP em claro restrito ao manifesto debug.
- Pendência de integração registrada: aguardar S03/S04 (AUTH), S05/S06 (FIN), S10 (EXCH), S11 (PORT e endpoint de cálculo), S13/S14 (domínio/configuração/controles BOT) e S15 (execução PAPER e histórico); depois substituir os providers fake e testar os contratos contra o backend real.

## Estado atual do mobile

### Features
- **Auth:** cadastro, login, restauração/expiração de sessão e recuperação de senha; implementação Dio disponível e provider fake ativo.
- **Finanças:** dashboard mensal, transações paginadas com filtros e categorias; API/repositório Dio disponíveis e provider fake ativo.
- **Corretora:** credencial Binance com confirmação local, campos sensíveis mascarados/limpos e exibição apenas de metadados; fake ativo.
- **Carteira:** ativos, P&L, aviso de dados stale e sincronização por pull-to-refresh; fake ativo.
- **Calculadora:** juros compostos com validação e entrada/saída Decimal; cálculo demonstrativo no fake, API/repositório real disponíveis.
- **Robô:** painel de status, configurações em PAPER, LIVE desabilitado, aviso de risco, ações e kill switch com confirmação/autenticação; fake ativo.
- **Histórico:** filtros, paginação com deduplicação e etiqueta de ordem simulada; provider compartilhado com o fake do robô.

### Fakes ativos

| Feature | Provider ativo | Arquivo fake | Troca pelo provider real | Backend |
|---|---|---|---|---|
| Auth | `authRepositoryProvider` | `mobile/lib/features/auth/data/fake_auth_repository.dart` | `authRepositoryImplProvider` em `mobile/lib/features/auth/data/auth_repository_impl.dart` | S03–S04 |
| Finanças (dashboard, transações, categorias) | `financeRepositoryProvider` | `mobile/lib/features/finance/data/fake_finance_repository.dart` | `financeRepositoryImplProvider` em `mobile/lib/features/finance/data/finance_repository_impl.dart` | S05–S06 |
| Corretora | `exchangeRepositoryProvider` | `mobile/lib/features/exchange/data/fake_exchange_repository.dart` | `exchangeRepositoryImplProvider` em `mobile/lib/features/exchange/data/exchange_repository_impl.dart` | S10 |
| Carteira | `portfolioRepositoryProvider` | `mobile/lib/features/portfolio/data/fake_portfolio_repository.dart` | `portfolioRepositoryImplProvider` em `mobile/lib/features/portfolio/data/portfolio_repository_impl.dart` | S11 |
| Calculadora | `compoundInterestRepositoryProvider` | `mobile/lib/features/calculator/data/fake_compound_interest_repository.dart` | `compoundInterestRepositoryImplProvider` em `mobile/lib/features/calculator/data/compound_interest_repository_impl.dart` | S11 |
| Robô e histórico | `botRepositoryProvider` | `mobile/lib/features/bot/data/fake_bot_repository.dart` | `botRepositoryImplProvider` em `mobile/lib/features/bot/data/bot_repository_impl.dart` | S13–S15 (trocar após S15) |

### Contrato adicionado pelo mobile na seção 10.3
- AUTH: payloads de register/login/refresh/logout/forgot-password/reset-password, aceite/versionamento de termos, respostas e status HTTP.
- FIN: filtros e paginação de transações, payloads e respostas CRUD, categorias e resumo mensal/dashboard.
- EXCH: request BINANCE com `api_key`/`api_secret`; resposta somente com status, `key_hint` e `last_checked_at`; `GET` sem credencial como `404 NOT_FOUND`; remoção `204`.
- PORT: estrutura de carteira/ativos, valores decimais em string, percentuais anuláveis, timestamps UTC, `stale` e `429 RATE_LIMITED` na sincronização.
- CALC: request de juros compostos, taxa percentual mensal e meses mínimos, resposta decimal em string.
- BOT: settings e consentimento versionado, status e estados/modos, respostas de start/stop/kill, erros de início e filtros/campos de ordem paginada.
- Auditoria M7 não encontrou rota, campo ou código adicional consumido sem documentação; backend deve obedecer a esses exemplos e convenções.

### Pendências consolidadas
- Implementar os módulos de backend S03–S06, S10–S11 e S13–S15; enquanto isso, não há integração real nem teste de integração possível. Testes Dio mockados estão verdes.
- Após esses módulos, trocar os seis providers fake conforme a tabela e validar contratos/integrar o app contra a API local.
- Validar `local_auth` e permissões/descrições nativas em aparelho Android/iOS; a auditoria estática não substitui essa validação.
- Executar a revisão de segurança S18 antes de qualquer preparação para LIVE.
- Manter modo LIVE e fluxo visual de consentimento de risco BOT-02 bloqueados até S19 e as condições de segurança/regulatórias correspondentes.
- Fora do mobile: Docker Compose (parte 2 de S00) e execução confirmada do workflow CI no GitHub continuam pendentes.

### Próximos passos recomendados
1. Completar S03–S06 (AUTH e FIN) e integrar essas features.
2. Completar S10–S11 (EXCH, PORT e cálculo) e integrar corretora, carteira e calculadora.
3. Completar S13–S15 (BOT PAPER/configuração/histórico) e integrar o robô.
4. Executar testes de integração locais por contrato e validar `local_auth` em dispositivos Android/iOS.
5. Completar Compose/CI pendentes de S00 e realizar S18 (hardening/revisão de segurança).
6. Só após S18 e resolução dos bloqueios regulatórios, iniciar S19 para consentimento BOT-02 e modo LIVE.
