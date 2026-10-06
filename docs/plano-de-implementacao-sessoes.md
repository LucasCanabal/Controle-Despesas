# Plano de Implementação por Sessões

**Base:** `levantamento-de-requisitos-v2.md` (IDs de requisitos, decisões D01–D11, contrato da API na seção 10).
**Executor:** agente autônomo, uma sessão por vez.

---

## 1. Regras Gerais para o Agente (valem em toda sessão)

1. **Leia antes de agir:** o documento de requisitos, o `docs/PROGRESS.md` e apenas os arquivos dos módulos de que a sessão depende.
2. **Faça só o que a sessão pede.** Não refatore código de sessões anteriores, não troque bibliotecas e não corrija warnings ou lints fora do escopo. Se achar um erro real em código anterior, registre em `docs/PROGRESS.md` na seção "Problemas encontrados" e só corrija se ele bloquear a sessão.
3. **Respeite as decisões D01–D11.** Se uma decisão impedir a tarefa, pare e registre; não improvise alternativa.
4. **Contrato é lei.** Rotas, campos e códigos de erro seguem a seção 10 do requisitos. Mudança de contrato exige atualizar o documento na mesma sessão e registrar.
5. **Testes junto com o código.** Nenhuma sessão termina sem testes dos critérios de aceite dos requisitos cobertos.
6. **Segurança:** nunca logar segredos; nenhum segredo no repositório; `user_id` sempre vem do token.
7. **Sem rede real em testes.** Binance só via `FakeExchangeClient` ou Testnet em sessão explicitamente marcada.
8. **Ao terminar:** rodar a "Verificação padrão" (seção 2), atualizar `docs/PROGRESS.md` e listar quais IDs de requisitos foram atendidos.
9. **Dúvida bloqueante** (item em aberto Q1–Q9 que a sessão exige): parar e perguntar, sem assumir.

## 2. Verificação Padrão (Definition of Done comum)

- Backend: `pytest` verde, `ruff check`, `mypy` (ou pyright) sem erros novos, `alembic upgrade head` e `downgrade -1` funcionam.
- Mobile: `flutter test` verde e `dart analyze` sem erros (warnings pré-existentes não são escopo).
- Cada requisito coberto tem pelo menos um teste mapeado ao critério de aceite.
- `docs/PROGRESS.md` atualizado: sessão, data, IDs atendidos, decisões tomadas, pendências.

## 3. Mapa de Sessões

| Sessão | Módulo | Título | Depende de | Fase |
|---|---|---|---|---|
| S00 | PLAT | Monorepo, Docker Compose e CI | — | F0 |
| S01 | PLAT | Núcleo do backend (config, DB, erros, logs) | S00 | F0 |
| S02 | CALC | Biblioteca de cálculos | S00 | F2* |
| S03 | AUTH | Cadastro, login e access token | S01 | F1 |
| S04 | AUTH | Refresh, logout, brute force e senha | S03 | F1 |
| S05 | FIN | Categorias e transações | S03 | F1 |
| S06 | FIN | Dashboard mensal | S05 | F1 |
| S07 | MOB | Fundação do app Flutter | S00 | F1 |
| S08 | MOB | Telas de autenticação | S04, S07 | F1 |
| S09 | MOB | Telas de finanças | S06, S08 | F1 |
| S10 | EXCH | Interface, cripto e credenciais | S03 | F2 |
| S11 | PORT | Carteira e sincronização | S02, S10 | F2 |
| S12 | MOB | Corretora, carteira e calculadora | S09, S11 | F2 |
| S13 | BOT | Domínio puro (estratégia, guardrails, estados) | S02 | F3 |
| S14 | BOT | Persistência, configuração e controles | S10, S13 | F3 |
| S15 | BOT | Worker, execução PAPER e histórico | S11, S14 | F3 |
| S16 | BOT | Backtest e notificações (opcional) | S15 | F3 |
| S17 | MOB | Painel do robô e histórico | S12, S15 | F3 |
| S18 | PLAT | Hardening e revisão de segurança | S17 | F3 |
| S19 | BOT | Habilitar modo LIVE | S18 + Q6 | F4 |

\* S02 pode rodar a qualquer momento após S00.

**Paralelismo possível:** S02 e S07 em paralelo com S01/S03; S13 em paralelo com S10–S12.

**Itens em aberto que bloqueiam:** Q7 antes de S00 (só se quiser deploy; Compose local não depende), Q2 e Q5 antes de S11/S02, Q1 antes de S13 (sem resposta, usar o DCA já decidido), Q4 antes de S14, Q8 antes de S16, Q6 antes de S19.

---

## 4. Sessões

### S00 — Monorepo, Docker Compose e CI
**Requisitos:** RNF-14, D05
**Entregas**
- Estrutura `/backend`, `/mobile`, `/docs`, `README.md`, `.gitignore`, `.env.example`.
- `docker-compose.yml` com `api`, `worker` (placeholder), `postgres`, `redis`.
- `backend/` com `pyproject.toml` (FastAPI, SQLAlchemy 2 async, asyncpg, Alembic, pydantic-settings, PyJWT, argon2-cffi, cryptography, pytest, pytest-asyncio, httpx, ruff, mypy).
- `mobile/` criado com `flutter create`, sem telas.
- CI (GitHub Actions) rodando lint, type-check e testes do backend e `flutter test`.
- `docs/PROGRESS.md` com template.
**Pronto quando:** `docker compose up` sobe API com `GET /api/v1/health` retornando 200; CI verde.

### S01 — Núcleo do Backend
**Requisitos:** RNF-04, RNF-05 (parcial), RNF-09, RNF-13, contrato de erros (10.1)
**Entregas**
- Estrutura em camadas: `app/core`, `app/modules/<modulo>/{router,service,repository,schemas,models}.py`.
- Config via env (`Settings`); falha na inicialização se segredo obrigatório faltar.
- Engine/sessão async, `Base`, mixin com `id` UUID, `created_at`, `updated_at`; Alembic configurado.
- Exception handlers para `HTTPException`, `RequestValidationError` e exceção genérica, todos no formato `{"error": {code, message, details, request_id}}`.
- Middleware de `request_id`; logging estruturado com filtro que mascara padrões sensíveis.
- Fixtures de teste: banco de teste, cliente HTTP, rollback por teste.
**Testes:** formato de erro em 404, 422 e 500; mascaramento de segredo nos logs; health.
**Pronto quando:** todos os erros saem no formato único.

### S02 — Biblioteca de Cálculos (CALC)
**Requisitos:** CALC-01…05
**Entregas**
- Pacote puro `app/modules/calc/` (sem I/O, sem import de banco/HTTP), usando `Decimal`.
- Funções: `weighted_average_price`, `roi`, `period_return` (conforme Q5; se não respondido, implementar retorno simples e deixar ponto de extensão), `compound_interest_future_value`.
- Endpoint `POST /api/v1/calculations/compound-interest` (usa a função).
**Testes:** valores conhecidos, zero, taxa 0, custo 0 (`roi` retorna `None`), negativos inválidos, grandes valores, precisão decimal.
**Pronto quando:** cobertura de CALC ≥ 95%.

### S03 — AUTH: Cadastro, Login e Access Token
**Requisitos:** AUTH-01, AUTH-02, AUTH-08 (cadastro), RNF-02 (senha), RNF-03 (access)
**Entregas**
- Models/migração: `users`, `consents`.
- Serviço de hash (argon2) e serviço de JWT (PyJWT, claims `sub`, `iat`, `exp`, `jti`, access 15 min).
- Rotas `POST /auth/register` e `POST /auth/login` (corpo JSON).
- Dependência `get_current_user_id` (lê Bearer, valida, retorna UUID); `GET /me`.
- Aceite de TERMS e PRIVACY registrado no cadastro.
- `EmailStr`; e-mail normalizado em minúsculas.
**Testes:** cadastro duplicado (409), senha curta (422), login ok/errado/e-mail inexistente com mensagem idêntica, token expirado, token adulterado, ausência de `password_hash` em qualquer resposta.
**Pronto quando:** rota protegida de teste retorna 401 sem token e 200 com token.

### S04 — AUTH: Sessão e Senha
**Requisitos:** AUTH-03, 04, 05, 06, 07, 09, RNF-03 (refresh)
**Entregas**
- Models/migração: `refresh_tokens`, `password_reset_tokens`.
- Login passa a emitir refresh token (guardar só hash); `POST /auth/refresh` com rotação e detecção de reuso (revoga a família).
- `POST /auth/logout`.
- Limite de tentativas (Redis ou tabela) por e-mail+IP: 5 falhas/15 min.
- `forgot-password` (resposta idêntica exista ou não o e-mail), `reset-password` (uso único, 30 min, revoga sessões), `change-password`.
- Interface `EmailSender` com implementação de log/console (envio real fica para depois).
- `DELETE /me` com remoção/anonimização conforme AUTH-09.
**Testes:** rotação, reuso revoga família, bloqueio e liberação após janela, token de reset reutilizado, sessões revogadas após troca de senha.

### S05 — FIN: Categorias e Transações
**Requisitos:** FIN-01…05, RN-02, RN-06
**Entregas**
- Models/migração: `categories`, `transactions` (com `CHECK amount > 0`, índice `(user_id, date)`).
- Seed de categorias padrão (migração de dados).
- Rotas de categorias e de transações (criar, listar com filtros e paginação por cursor, obter, editar, excluir com soft delete).
- Dinheiro como string decimal nas respostas.
**Testes:** isolamento (usuário B recebe 404 em recurso do A, em todas as rotas), validações, soft delete some das listagens, categoria com transações só arquiva, filtros e paginação.

### S06 — FIN: Dashboard
**Requisitos:** FIN-06, FIN-07
**Entregas**
- `GET /dashboard/summary?month=YYYY-MM` com totais, `month_balance`, `cumulative_balance`, `by_category` e últimas N transações; somas feitas em SQL.
- Mês inválido retorna 422.
**Testes:** dados conhecidos, mês sem dados (zeros), exclusão de soft deleted, isolamento entre usuários, desempenho com volume grande (seed de 50 mil linhas; meta RNF-06).

### S07 — MOB: Fundação do App
**Requisitos:** MOB-11, D01, RNF-11
**Entregas**
- Estrutura por feature: `lib/core` (config, dio, erros, tema, rotas), `lib/features/<feature>/{data,domain,presentation}`.
- Riverpod, `go_router`, Dio com interceptors: injeta Bearer, mapeia `error.code` para mensagens, 401 tenta refresh uma vez e depois redireciona ao login.
- `TokenStorage` sobre `flutter_secure_storage`.
- Modelos de dinheiro com `Decimal`.
- Ambientes (dev/prod) via `--dart-define`.
**Testes:** interceptor (injeção de header, fluxo de refresh, mapeamento de erro) com Dio mockado.

### S08 — MOB: Autenticação
**Requisitos:** MOB-01, MOB-02
**Entregas:** splash com restauração de sessão, login, cadastro (com aceite de termos), esqueci/redefinir senha; validações espelhando a API; estados de carregando/erro.
**Testes:** widget tests dos formulários e do redirecionamento por sessão.

### S09 — MOB: Finanças
**Requisitos:** MOB-03, MOB-04, MOB-05
**Entregas:** navegação inferior; dashboard (seletor de mês, cards, gráfico por categoria com `fl_chart`, últimas transações); lista de transações com paginação infinita e filtros; formulário criar/editar; excluir com confirmação; categorias.
**Observação:** usar `AsyncNotifier`/`AsyncValue` do Riverpod para estados (sem `FutureBuilder` junto).
**Testes:** providers com repositório fake; widget tests das telas principais.

### S10 — EXCH: Interface, Criptografia e Credenciais
**Requisitos:** EXCH-01…06, RNF-02, RNF-08
**Entregas**
- Interface `ExchangeClient` (saldos, preços, permissões da chave, ordens, cancelamento, consulta de ordem) e `FakeExchangeClient` em memória configurável.
- `BinanceClient` com timeout, retry/backoff e respeito a rate limit; sem uso em testes automáticos.
- `CredentialCipher` com `MultiFernet` (chave mestra por env, versão da chave por registro).
- Models/migração: `exchange_credentials`.
- Rotas `PUT/GET/DELETE /exchange/credentials`; validação da chave na Binance antes de salvar; recusa se houver permissão de saque; resposta só com `key_hint`.
- Remover credencial emite evento para desativar o robô (hook; BOT ainda não existe).
**Testes:** com fake: chave inválida não salva, saque habilitado recusa, secret nunca aparece em resposta nem em log, rotação de chave descriptografa registros antigos.

### S11 — PORT: Carteira e Sincronização
**Requisitos:** PORT-01…04, RN-07
**Entregas**
- Models/migração: `portfolio_positions`.
- Serviço de sincronização (saldos + preços) usando `ExchangeClient`; job periódico (ARQ/Celery) e `POST /portfolio/sync` com limite 1/min.
- Preço médio via CALC-01 a partir de ordens executadas; ROI e P&L via CALC.
- `GET /portfolio` com flag `stale` e `last_synced_at`.
**Testes:** com fake: sincronização, falha da corretora mantém estado antigo com `stale=true`, limite do sync manual, cálculo de P&L.

### S12 — MOB: Corretora, Carteira e Calculadora
**Requisitos:** MOB-06, MOB-07, MOB-10
**Entregas:** tela de conexão com orientações (sem saque, IP whitelist) e campo secret mascarado; tela de carteira com indicador de desatualizado e pull-to-refresh; calculadora de juros compostos.
**Testes:** widget tests; garantir que o secret nunca é exibido após salvar.

### S13 — BOT: Domínio Puro
**Requisitos:** BOT-05, BOT-06, BOT-08, BOT-11, BOT-12, RN-03…05, RN-10
**Entregas** (sem banco, sem rede)
- Tipos: `Signal`, `MarketState`, `PortfolioState`, `BotConfig`, `OrderIntent`.
- `Strategy` (interface) e `DcaStrategy`.
- `GuardrailEngine`: exposição total, tamanho máximo, perda diária/total, pares permitidos, saldo; retorna decisão com motivo.
- `BotStateMachine` conforme tabela 9.2.
- `client_order_id` determinístico (usuário + estratégia + janela de tempo + par + lado).
**Testes:** cobertura ≥ 95% dos guardrails; tabela completa de transições (válidas e inválidas); determinismo do `client_order_id`; DCA com limites.

### S14 — BOT: Persistência, Configuração e Controles
**Requisitos:** BOT-01…04, BOT-07, BOT-17, RN-01, RN-09
**Dependência:** Q4 respondida (comportamento do kill switch).
**Entregas**
- Models/migração: `bot_settings`, `bot_orders`, `bot_run_logs`, `audit_events`.
- Rotas: `GET/PUT /bot/settings`, `POST /bot/consent`, `/bot/start`, `/bot/stop`, `/bot/kill`, `GET /bot/status`.
- Regras: ativar exige credencial `CONNECTED`, consentimento vigente (para LIVE), capital > 0; LIVE bloqueado antes de 7 dias em PAPER (`PAPER_PERIOD_NOT_MET`); remover credencial desativa o robô.
- Eventos de auditoria em toda mudança relevante.
**Testes:** cada pré-condição de ativação, transições inválidas retornam `BOT_INVALID_STATE`, consentimento versionado, auditoria gerada, isolamento entre usuários.

### S15 — BOT: Worker, Execução PAPER e Histórico
**Requisitos:** BOT-09, BOT-10, BOT-13, BOT-14, RNF-07, RNF-08
**Entregas**
- Worker (processo separado) com ciclo por usuário ativo: obter estado → estratégia → guardrails → executar → registrar.
- `PaperExecutor` (simulado, com `is_simulated=true`, taxa simulada) e `LiveExecutor` implementado atrás de interface, **desabilitado por feature flag** até S19.
- Idempotência: reexecutar o mesmo ciclo não duplica ordens.
- Reconciliação no início e a cada ciclo.
- Parada automática por risco (`STOPPED_BY_RISK`) com evento de auditoria.
- `GET /bot/orders` (paginado, filtros) e campos de status completos.
- Heartbeat do worker e métrica de ciclo.
**Testes:** com fake: ciclo completo, reexecução idempotente, falha no meio do ciclo e retomada, reconciliação corrige divergência, perda máxima para o robô, queda da corretora leva a `PAUSED`.

### S16 — BOT: Backtest e Notificações (opcional)
**Requisitos:** BOT-15, BOT-16
**Dependência:** Q8 (canal de notificação).
**Entregas:** executor de backtest reutilizando `Strategy` e guardrails sobre candles históricos (fonte via `ExchangeClient`); rotas `POST/GET /bot/backtests`; interface `Notifier` com implementação de e-mail (e push se Q8 definir) acionada em parada por risco, erro e chave inválida.
**Testes:** backtest determinístico com dados fixos; notificações disparadas nos eventos corretos.

### S17 — MOB: Painel do Robô
**Requisitos:** MOB-08, MOB-09, MOB-12
**Entregas:** painel (estado, modo, capital, switch, kill switch destacado, P&L do dia, último erro); fluxo de consentimento de risco para LIVE; histórico de ordens com filtros; confirmação biométrica/PIN para ações sensíveis.
**Testes:** widget tests dos estados do robô; kill switch exige confirmação.

### S18 — Hardening e Revisão de Segurança
**Requisitos:** RNF-01, RNF-05, RNF-06, RNF-09, RNF-10, RNF-12, seção 11
**Entregas**
- Suíte automatizada de isolamento (IDOR) cobrindo **todas** as rotas com dados de usuário.
- Rate limit global por IP e usuário; CORS restritivo; cabeçalhos de segurança.
- Teste que varre logs em busca de segredos.
- `pip-audit` e checagem de dependências no CI.
- Teste de carga do dashboard (meta RNF-06).
- Rotinas de exportação de dados do usuário (LGPD).
- Documentos: procedimento de rotação da chave mestra, runbook do robô (kill switch, falhas), checklist de deploy.
**Pronto quando:** checklist da seção 11 do requisitos marcado item a item, com evidência (teste ou documento).

### S19 — BOT: Habilitar Modo LIVE
**Requisitos:** RN-01, RN-08, F4
**Dependência:** S18 concluída **e** Q6 respondida (parecer jurídico).
**Entregas**
- Ativar `LiveExecutor` atrás de flag por ambiente.
- Teste ponta a ponta na **Binance Testnet** (sessão manual supervisionada, fora do CI).
- Limites iniciais conservadores por padrão e checklist de ativação por usuário.
**Pronto quando:** ciclo completo na Testnet com ordens reais de teste, reconciliação e kill switch validados.

---

## 5. Modelo de Prompt por Sessão

Use este texto para iniciar cada sessão:

```
Sessão: <Sxx — título>
Leia: docs/levantamento-de-requisitos-v2.md, docs/PLANO.md (seção da sessão), docs/PROGRESS.md.
Implemente somente o que está na sessão. Siga as Regras Gerais (seção 1).
Ao terminar: rode a Verificação Padrão, atualize docs/PROGRESS.md e responda com:
1) IDs de requisitos atendidos; 2) arquivos criados/alterados; 3) decisões tomadas;
4) pendências e problemas encontrados.
```

## 6. Template de `docs/PROGRESS.md`

```
## Sxx — título (data)
- Status: concluída | parcial | bloqueada
- Requisitos atendidos: ...
- Decisões: ...
- Problemas encontrados (não corrigidos): ...
- Pendências para próximas sessões: ...
```
