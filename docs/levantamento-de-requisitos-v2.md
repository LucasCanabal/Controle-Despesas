# Levantamento de Requisitos — App de Finanças Pessoais + Investimentos com Robô de Trade

**Versão:** 2.0 (revisão da v1)
**Status:** Rascunho para validação
**Público:** desenvolvedor e agente autônomo de implementação

> **Como ler este documento.** Cada requisito tem ID único, prioridade (MoSCoW) e critérios de aceite verificáveis. Cada módulo (seção 5) é uma unidade de implementação com fronteiras e dependências explícitas (seção 12). Itens marcados **[DECISÃO]** foram assumidos para destravar o projeto e podem ser trocados; itens em **[ABERTO]** (seção 13) precisam de resposta antes da fase indicada.

---

## 1. Visão e Escopo

### 1.1 Visão
Aplicativo mobile para gestão da vida financeira do usuário: controle de receitas/despesas mensais e acompanhamento de carteira de criptoativos, com um robô de trade que opera na corretora do usuário (Binance) dentro de limites de risco definidos por ele.

### 1.2 Dentro do escopo (MVP)
- Cadastro, login e sessão segura.
- CRUD de transações, categorias e dashboard mensal.
- Conexão de conta Binance (chaves de API somente com permissão de trade/leitura).
- Carteira sincronizada da corretora, com preço médio, ROI e projeção de juros compostos.
- Robô de trade com **modo simulado (paper)** e **modo real**, com limites e kill switch.
- Histórico de ordens e trilha de auditoria.

### 1.3 Fora do escopo (MVP)
- Outras corretoras além da Binance (a arquitetura deve permitir, mas não implementar).
- Ações, FIIs, renda fixa e importação de extratos bancários.
- Open Finance / conexão com bancos.
- Multiusuário compartilhado (contas familiares), web app, iOS e Android além do que o Flutter já entrega por padrão.
- Custódia: o sistema **nunca** guarda fundos nem executa saques.

### 1.4 Fases
| Fase | Conteúdo | Módulos |
|---|---|---|
| F0 | Fundação técnica | PLAT |
| F1 | Contas e finanças pessoais | AUTH, FIN |
| F2 | Corretora e carteira | EXCH, PORT, CALC |
| F3 | Robô em modo simulado | BOT (paper) |
| F4 | Robô em modo real (após validação) | BOT (live) |

---

## 2. Glossário

| Termo | Definição |
|---|---|
| Transação | Registro de receita (`INCOME`) ou despesa (`EXPENSE`) do usuário. |
| Credencial de corretora | Par API Key/Secret da Binance, armazenado criptografado. |
| Ativo | Criptomoeda mantida na corretora (ex.: BTC). |
| Estratégia | Componente que, dado o estado de mercado e da carteira, produz **sinais** (comprar/vender/nada). |
| Sinal | Decisão proposta por uma estratégia, ainda não executada. |
| Ordem | Instrução enviada à corretora a partir de um sinal aprovado pelos guardrails. |
| Guardrail | Verificação obrigatória (limite de capital, perda máxima etc.) entre sinal e ordem. |
| Paper trading | Execução simulada com preços reais e sem enviar ordens à corretora. |
| Kill switch | Parada imediata do robô de um usuário (manual ou automática). |
| Capital alocado | Valor máximo (em USDT) que o robô pode ter em posições para o usuário. |

---

## 3. Atores

| Ator | Descrição |
|---|---|
| Usuário | Pessoa autenticada que usa o app. |
| App Mobile (Flutter) | Cliente da API; não executa regra de negócio financeira. |
| API (FastAPI) | Camada HTTP; autentica, valida e orquestra. |
| Worker de Trade | Processo separado da API que roda o ciclo do robô. |
| Binance | Sistema externo (dados de mercado, saldos, ordens). |
| Serviço de e-mail | Sistema externo para recuperação de senha e alertas. |

---

## 4. Decisões de Arquitetura e Restrições

| ID | Decisão | Justificativa |
|---|---|---|
| D01 | Mobile em Flutter (Dart), estado com Riverpod, HTTP com Dio. | Stack já definida. |
| D02 | Back-end em **FastAPI** (descartar Django REST) com SQLAlchemy 2.x e Alembic. | Uma única opção evita ambiguidade para o agente. |
| D03 | PostgreSQL 15+. Valores monetários como `NUMERIC(20,8)`. | Precisão decimal. |
| D04 | Dinheiro trafega na API como **string decimal** (ex.: `"150.75"`), nunca `float`. Em Python usar `Decimal`; em Dart usar `Decimal` ou centavos inteiros. | Evita erro de arredondamento. |
| D05 | Monorepo: `/backend`, `/mobile`, `/docs`. | Facilita contexto para o agente. |
| D06 | Worker de trade em processo separado da API (ARQ ou Celery + Redis). | Isolamento de falhas e do event loop. |
| D07 | JWT com **PyJWT** (não `python-jose`); hash de senha com **argon2-cffi** (ou `bcrypt` direto, sem `passlib`). | Bibliotecas mantidas. |
| D08 | Acesso ao banco **assíncrono** (SQLAlchemy async + asyncpg). | Compatível com rotas `async`. |
| D09 | Segredos só por variáveis de ambiente / secret manager. Nenhum segredo no repositório. | Segurança. |
| D10 | Todas as datas em UTC no servidor; transações usam `date` (sem hora) na zona do usuário. | Consistência. |
| D11 | Idioma da API e mensagens ao usuário: pt-BR; códigos de erro em inglês (`UPPER_SNAKE`). | Padronização. |

**Restrições:** HTTPS obrigatório fora de ambiente local; Binance Testnet obrigatória em dev/CI; nenhuma chamada real à Binance em testes automatizados.

---

## 5. Módulos

| Código | Módulo | Responsabilidade | Não é responsabilidade |
|---|---|---|---|
| PLAT | Plataforma | Config, logging, erros, DB, migrações, CI, healthcheck | Regra de negócio |
| AUTH | Autenticação | Cadastro, login, tokens, recuperação de senha, consentimentos | Dados financeiros |
| FIN | Finanças pessoais | Transações, categorias, dashboard mensal | Investimentos |
| EXCH | Corretora | Credenciais, validação de chave, cliente Binance (leitura/ordens) | Decisão de trade |
| PORT | Carteira | Saldos, posições, preço médio, sincronização | Execução de ordens |
| CALC | Cálculos | Funções puras de ROI, rentabilidade, juros compostos, preço médio | I/O, banco, rede |
| BOT | Robô de trade | Estratégias, guardrails, ciclo de execução, ordens, histórico | Armazenar chaves, UI |
| MOB | Aplicativo | Telas, navegação, estado, consumo da API | Regras financeiras |

---

## 6. Requisitos Funcionais

Prioridade: **M** = Must, **S** = Should, **C** = Could.

### 6.1 AUTH — Autenticação e Conta

| ID | Requisito | Prio. | Critérios de aceite |
|---|---|---|---|
| AUTH-01 | Cadastro com nome, e-mail e senha. | M | E-mail único (case-insensitive). Senha ≥ 10 caracteres. Resposta nunca contém hash. Cadastro duplicado retorna `EMAIL_ALREADY_REGISTERED` (409). |
| AUTH-02 | Login com e-mail e senha. | M | Credencial correta retorna access token + refresh token + dados básicos do usuário. Incorreta retorna `INVALID_CREDENTIALS` (401) com mensagem idêntica para e-mail inexistente e senha errada. |
| AUTH-03 | Proteção contra força bruta. | M | Após 5 falhas em 15 min por e-mail+IP, bloquear por 15 min (`TOO_MANY_ATTEMPTS`, 429). |
| AUTH-04 | Renovação de sessão por refresh token com rotação. | M | Refresh usado é invalidado e um novo é emitido. Reuso de refresh já usado revoga toda a família de tokens. |
| AUTH-05 | Logout. | M | Revoga o refresh token atual. Access token expira naturalmente (curto). |
| AUTH-06 | Recuperação de senha por e-mail. | S | Link de uso único, validade 30 min. Resposta de "esqueci a senha" é igual exista ou não o e-mail. Após redefinir, todos os refresh tokens do usuário são revogados. |
| AUTH-07 | Alterar senha autenticado. | S | Exige senha atual. Revoga demais sessões. |
| AUTH-08 | Registro de consentimentos versionados. | M | Aceite dos Termos/Política de Privacidade no cadastro (versão + timestamp). Consentimento do robô é separado (ver BOT-02). |
| AUTH-09 | Exclusão de conta e dados (LGPD). | S | Remove dados pessoais e credenciais; mantém apenas o mínimo exigido legalmente (auditoria anonimizada). |

### 6.2 FIN — Finanças Pessoais

| ID | Requisito | Prio. | Critérios de aceite |
|---|---|---|---|
| FIN-01 | Criar transação. | M | Campos: `type`, `amount` (> 0), `description` (2–100), `category_id`, `date`. `user_id` vem só do token. |
| FIN-02 | Listar transações com filtros e paginação. | M | Filtros: período, tipo, categoria. Paginação por cursor ou `page/page_size` (máx. 100). Ordenação por data desc. |
| FIN-03 | Editar transação. | M | Só o dono edita. Outro usuário recebe 404 (não revelar existência). |
| FIN-04 | Excluir transação (soft delete). | M | Registro some das listagens e do dashboard; permanece no banco com `deleted_at`. |
| FIN-05 | Categorias padrão e personalizadas. | M | Sistema semeia categorias padrão. Usuário cria/edita/arquiva as suas. Categoria com transações só pode ser arquivada, não apagada. |
| FIN-06 | Dashboard mensal. | M | Parâmetro `month=YYYY-MM` (padrão: mês atual). Retorna total de receitas, despesas, saldo do mês, total por categoria e últimas N transações. Somas calculadas no banco. |
| FIN-07 | Saldo acumulado. | S | Retorna também saldo acumulado (soma de todas as transações até o fim do mês consultado). Nomes distintos: `month_balance` e `cumulative_balance`. |
| FIN-08 | Transações recorrentes. | C | Regra mensal que gera transações automaticamente. |

### 6.3 EXCH — Corretora

| ID | Requisito | Prio. | Critérios de aceite |
|---|---|---|---|
| EXCH-01 | Cadastrar credencial Binance. | M | Ao salvar, o servidor valida a chave consultando a Binance. Chave inválida: `EXCHANGE_KEY_INVALID` (422), nada é salvo. |
| EXCH-02 | Rejeitar chaves inseguras. | M | Se a chave tiver permissão de **saque**, recusar com `EXCHANGE_KEY_WITHDRAW_ENABLED`. Exibir orientação de IP whitelist. |
| EXCH-03 | Armazenamento criptografado. | M | Key e secret criptografados com chave mestra fora do banco, com suporte a rotação. Nunca retornados em nenhuma resposta; só os 4 últimos caracteres da key (`key_hint`). |
| EXCH-04 | Substituir e remover credencial. | M | Remover credencial desativa o robô e cancela ordens abertas do robô. |
| EXCH-05 | Status da conexão. | S | Retorna `CONNECTED`, `INVALID`, `RATE_LIMITED` ou `UNREACHABLE`, com última verificação. |
| EXCH-06 | Camada de abstração de corretora. | M | Interface `ExchangeClient` (saldos, preços, ordens, cancelamento). Binance é uma implementação. BOT e PORT dependem só da interface. |

### 6.4 PORT — Carteira

| ID | Requisito | Prio. | Critérios de aceite |
|---|---|---|---|
| PORT-01 | Sincronizar saldos da Binance. | M | Job periódico (padrão 5 min) e sincronização manual (limite 1/min por usuário). Falha na corretora mantém último estado com flag `stale=true` e `last_synced_at`. |
| PORT-02 | Listar ativos e posições. | M | Para cada ativo: quantidade, preço médio, preço atual, valor atual, lucro/prejuízo absoluto e %. |
| PORT-03 | Preço médio. | M | Calculado a partir de ordens executadas (histórico da corretora + ordens do robô) pelo método de preço médio ponderado. Ver CALC-01. |
| PORT-04 | Valor total da carteira. | M | Soma em USDT e na moeda de exibição do usuário. |
| PORT-05 | Aportes manuais / ativos fora da corretora. | C | Fora do MVP. |

### 6.5 CALC — Cálculos (funções puras)

| ID | Requisito | Prio. | Fórmula / critério |
|---|---|---|---|
| CALC-01 | Preço médio ponderado | M | `Σ(qtd_i × preço_i) / Σ(qtd_i)` nas compras; venda reduz quantidade sem alterar o preço médio. |
| CALC-02 | ROI | M | `(valor_atual − custo_total) / custo_total`. Custo zero retorna `null`, nunca erro. |
| CALC-03 | Rentabilidade do período | S | Retorno entre duas datas, considerando aportes/retiradas (método do retorno ponderado pelo tempo ou simples — ver ABERTO Q5). |
| CALC-04 | Projeção de juros compostos | S | `VF = VP·(1+i)^n + PMT·((1+i)^n − 1)/i`. Entradas: valor inicial, aporte mensal, taxa, meses. Taxa 0 tratada sem divisão por zero. |
| CALC-05 | Todas as funções com testes unitários de casos de borda | M | Zero, valores negativos inválidos, precisão decimal, entradas muito grandes. |

### 6.6 BOT — Robô de Trade

| ID | Requisito | Prio. | Critérios de aceite |
|---|---|---|---|
| BOT-01 | Configurar o robô. | M | Campos: `mode` (`PAPER`/`LIVE`), `max_capital_allocation` (USDT), `risk_level`, `strategy_id`, pares permitidos. Salvar configuração **não** exige reenviar credenciais. |
| BOT-02 | Consentimento explícito para modo LIVE. | M | Ativar LIVE exige aceitar aviso de risco versionado, registrado com timestamp e versão. Mudança de versão do aviso exige novo aceite. |
| BOT-03 | Ativar/desativar. | M | Ativar só é permitido com credencial `CONNECTED`, consentimento vigente e capital > 0. Desativar impede novos sinais imediatamente. |
| BOT-04 | Modo PAPER. | M | Mesma lógica do LIVE, mas ordens são simuladas contra preços reais e gravadas com `is_simulated=true`. **LIVE só pode ser habilitado após ≥ 7 dias em PAPER** **[DECISÃO]**. |
| BOT-05 | Guardrails obrigatórios. | M | Antes de qualquer ordem: (a) exposição total ≤ `max_capital_allocation`; (b) tamanho máximo por ordem; (c) perda diária máxima; (d) apenas pares permitidos; (e) saldo suficiente. Violação bloqueia a ordem e registra motivo. |
| BOT-06 | Stop-loss e perda máxima. | M | Atingir a perda máxima diária ou total desativa o robô automaticamente (`STOPPED_BY_RISK`) e notifica o usuário. |
| BOT-07 | Kill switch. | M | Ação de um toque no app. Cancela ordens abertas do robô, desativa o robô; não vende posições automaticamente (comportamento configurável — ver ABERTO Q4). |
| BOT-08 | Estados do robô. | M | `INACTIVE`, `STARTING`, `RUNNING`, `PAUSED`, `STOPPED_BY_RISK`, `ERROR`. Transições válidas definidas em 9.2. |
| BOT-09 | Idempotência de ordens. | M | Cada ordem usa `client_order_id` determinístico. Reexecução do mesmo ciclo nunca duplica ordens. |
| BOT-10 | Reconciliação. | M | A cada ciclo e após reinício, comparar ordens locais com as da corretora e corrigir estado local. |
| BOT-11 | Interface de estratégia plugável. | M | `Strategy.evaluate(market_state, portfolio_state) -> list[Signal]`, sem acesso a rede ou banco. Permite backtest e testes. |
| BOT-12 | Estratégia MVP. | M | **[DECISÃO]** DCA com limites (compra periódica de valor fixo dentro do capital alocado) até a "IA" ser definida (ABERTO Q1). |
| BOT-13 | Monitoramento. | M | Endpoint de status: estado, última execução, próximo ciclo, ordens abertas, P&L do dia e último erro. |
| BOT-14 | Histórico de ordens. | M | Listagem paginada: par, lado, quantidade, preço médio de execução, taxa, status, simulada/real, `exchange_order_id`, estratégia, motivo do sinal. |
| BOT-15 | Backtest. | S | Executar estratégia sobre dados históricos e reportar resultado. Pré-requisito para qualquer estratégia além do DCA. |
| BOT-16 | Notificações. | S | Push/e-mail em: parada por risco, erro, chave inválida, ordem executada (opcional). |
| BOT-17 | Auditoria. | M | Toda mudança de configuração, ativação, consentimento e ordem gera evento imutável (quem, quando, o quê). |

### 6.7 MOB — Aplicativo

| ID | Requisito | Prio. | Critérios de aceite |
|---|---|---|---|
| MOB-01 | Splash com restauração de sessão. | M | Lê tokens do `flutter_secure_storage`; tenta refresh; destino: Dashboard ou Login. |
| MOB-02 | Telas de login, cadastro e recuperação de senha. | M | Validação local espelhando regras da API; erros do servidor exibidos por código. |
| MOB-03 | Dashboard financeiro. | M | Seletor de mês, cards de receitas/despesas/saldo, gráfico por categoria, últimas transações. |
| MOB-04 | Lista e formulário de transações. | M | Paginação infinita, filtros, criar/editar/excluir com confirmação. |
| MOB-05 | Gestão de categorias. | S | Criar, editar, arquivar. |
| MOB-06 | Tela de carteira. | M | Ativos, valor total, P&L, indicação de dados desatualizados. |
| MOB-07 | Tela de conexão com corretora. | M | Entrada de chaves com orientações de segurança (sem saque, IP whitelist); campo secret mascarado; nunca exibir o valor salvo. |
| MOB-08 | Painel do robô. | M | Estado, modo PAPER/LIVE, capital alocado, switch, kill switch destacado, aviso de risco. |
| MOB-09 | Histórico de ordens do robô. | M | Lista com filtros (simulada/real, par, período). |
| MOB-10 | Calculadora de projeção. | S | Entradas e resultado de CALC-04. |
| MOB-11 | Tratamento global de erros. | M | Interceptor Dio mapeia códigos de erro para mensagens; 401 tenta refresh uma vez, depois vai para o login. |
| MOB-12 | Bloqueio do app (biometria/PIN) antes de ações sensíveis. | S | Ativar LIVE, salvar credencial e kill switch exigem confirmação. |

---

## 7. Regras de Negócio

| ID | Regra |
|---|---|
| RN-01 | O robô só opera em LIVE com credencial válida e sem permissão de saque, consentimento de risco vigente, modo PAPER prévio cumprido e capital > 0. |
| RN-02 | Isolamento de dados: toda consulta de dados do usuário filtra por `user_id` do token. Acesso a recurso de outro usuário retorna 404. |
| RN-03 | O capital alocado é o teto da **exposição total** do robô (posições abertas + ordens pendentes), medida em USDT. |
| RN-04 | O robô opera apenas com ativos/pares da lista permitida pelo usuário, e somente com saldo da própria conta; nunca usa margem ou derivativos no MVP. |
| RN-05 | Perda diária máxima (padrão 5% do capital alocado) e perda total máxima (padrão 20%) disparam parada automática. **[DECISÃO]** valores padrão editáveis. |
| RN-06 | Excluir transação é lógico; relatórios ignoram registros com `deleted_at`. |
| RN-07 | Preço exibido mais antigo que 60 s é marcado como desatualizado. |
| RN-08 | O sistema nunca executa saques, transferências ou conversões fora dos pares permitidos. |
| RN-09 | Credenciais removidas ou inválidas desativam o robô. |
| RN-10 | Alterações em limites de risco só valem para ciclos seguintes; não alteram ordens já enviadas. |

---

## 8. Requisitos Não Funcionais

| ID | Categoria | Requisito (mensurável) |
|---|---|---|
| RNF-01 | Segurança — transporte | HTTPS/TLS 1.2+ em tudo fora de `localhost`. HSTS ativo. |
| RNF-02 | Segurança — dados | Criptografia aplicada **somente a credenciais de corretora** (AEAD, chave mestra fora do banco, rotação com `MultiFernet` ou equivalente). Senhas com hash adaptativo. Demais dados protegidos por criptografia de disco/backup do banco; valores de transações **não** são criptografados em nível de campo (necessário para agregações). |
| RNF-03 | Segurança — sessão | Access token 15 min; refresh 30 dias com rotação; `iat`, `exp`, `jti` e `sub` presentes. |
| RNF-04 | Segurança — logs | Proibido logar senhas, tokens, chaves e secrets. Teste automatizado que falha se padrões sensíveis aparecerem nos logs. |
| RNF-05 | Segurança — API | Rate limit por IP e por usuário; CORS restritivo; validação com Pydantic em todas as entradas. |
| RNF-06 | Desempenho | p95 < 300 ms para endpoints de leitura (sem chamadas externas); dashboard < 500 ms com 50 mil transações. |
| RNF-07 | Disponibilidade do robô | Ciclo do worker independente da API; queda da API não interrompe o robô; queda do worker gera alerta em ≤ 2 min. |
| RNF-08 | Resiliência | Chamadas à Binance com timeout, retry com backoff e respeito a rate limit; circuit breaker em falha contínua. |
| RNF-09 | Observabilidade | Logs estruturados com `request_id`; métricas de ciclo do robô, latência e erros; healthcheck `/health`. |
| RNF-10 | Qualidade | Cobertura ≥ 80% em CALC, AUTH e guardrails do BOT (≥ 95% em CALC e guardrails). Lint, type-check (mypy/pyright; `dart analyze`) e testes no CI. |
| RNF-11 | Compatibilidade | Android 8+ e iOS 14+. |
| RNF-12 | Conformidade | LGPD: base legal, consentimento, exportação e exclusão de dados, retenção definida. Aviso de que o app não é consultoria de investimento e que há risco de perda total. |
| RNF-13 | Manutenibilidade | Camadas separadas (router → service → repository). Regras de negócio fora dos routers. Funções de CALC e `Strategy` puras. |
| RNF-14 | Reprodutibilidade | Ambiente local via `docker compose` (API, worker, Postgres, Redis). Migrações versionadas e reversíveis. |

---

## 9. Modelo de Dados (Conceitual)

Convenções: PK `id` UUID; `created_at`/`updated_at` em todas as tabelas; valores monetários `NUMERIC(20,8)`; FKs com índice.

### 9.1 Tabelas

| Tabela | Campos principais | Constraints / notas |
|---|---|---|
| `users` | `name`, `email`, `password_hash`, `is_active` | `email` único (índice em `lower(email)`). |
| `consents` | `user_id`, `type` (`TERMS`, `PRIVACY`, `BOT_RISK`), `version`, `accepted_at`, `ip` | Imutável (só insere). |
| `refresh_tokens` | `user_id`, `family_id`, `token_hash`, `expires_at`, `revoked_at`, `replaced_by` | Guardar apenas hash do token. |
| `password_reset_tokens` | `user_id`, `token_hash`, `expires_at`, `used_at` | Uso único. |
| `categories` | `user_id` (null = padrão do sistema), `name`, `type`, `archived_at` | Único `(user_id, name, type)`. |
| `transactions` | `user_id`, `type`, `amount`, `description`, `category_id`, `date`, `deleted_at` | `CHECK amount > 0`; índice `(user_id, date)`. |
| `exchange_credentials` | `user_id`, `exchange`, `api_key_enc`, `api_secret_enc`, `key_hint`, `key_version`, `status`, `last_checked_at` | Único `(user_id, exchange)`. |
| `portfolio_positions` | `user_id`, `asset_symbol`, `quantity`, `average_buy_price`, `last_synced_at` | Único `(user_id, asset_symbol)`. |
| `bot_settings` | `user_id` (único), `mode`, `state`, `strategy_id`, `strategy_params` (JSONB), `max_capital_allocation`, `max_order_size`, `max_daily_loss`, `max_total_loss`, `allowed_pairs`, `paper_started_at` | `CHECK max_capital_allocation >= 0`. |
| `bot_orders` | `user_id`, `pair`, `side`, `quantity`, `price`, `fee`, `fee_asset`, `status`, `client_order_id`, `exchange_order_id`, `is_simulated`, `signal_reason`, `strategy_id`, `executed_at` | Único `client_order_id`; índice `(user_id, executed_at)`. |
| `bot_run_logs` | `user_id`, `cycle_at`, `outcome`, `details` (JSONB) | Retenção limitada. |
| `audit_events` | `user_id`, `actor`, `event_type`, `payload` (JSONB), `created_at` | Imutável. |

### 9.2 Máquina de estados do robô

| De | Para | Gatilho |
|---|---|---|
| `INACTIVE` | `STARTING` | Usuário ativa (RN-01 satisfeita) |
| `STARTING` | `RUNNING` | Reconciliação concluída |
| `STARTING` | `ERROR` | Falha ao iniciar |
| `RUNNING` | `PAUSED` | Usuário pausa ou corretora indisponível |
| `PAUSED` | `RUNNING` | Usuário retoma / corretora volta |
| `RUNNING` | `STOPPED_BY_RISK` | Guardrail de perda (BOT-06) |
| `RUNNING`/`PAUSED`/`ERROR` | `INACTIVE` | Usuário desativa ou kill switch |
| `STOPPED_BY_RISK` | `INACTIVE` | Usuário reconhece e desativa; reativação exige confirmação |

---

## 10. Contrato da API

### 10.1 Convenções
- Prefixo `/api/v1`. Autenticação por `Authorization: Bearer <access_token>` em tudo, exceto `register`, `login`, `refresh`, `forgot-password`, `reset-password` e `health`.
- Dinheiro como string decimal; datas ISO 8601 (`YYYY-MM-DD` para datas, UTC com `Z` para timestamps).
- Listas paginadas: `{ "items": [...], "next_cursor": "..." | null }`.
- Ações mutáveis sensíveis aceitam `Idempotency-Key`.
- **Formato único de erro** (via exception handlers para `HTTPException`, `RequestValidationError` e exceções não tratadas):

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Dados inválidos.",
    "details": [{ "field": "amount", "issue": "must be greater than 0" }],
    "request_id": "c1f2..."
  }
}
```

| HTTP | Códigos de erro |
|---|---|
| 400 | `BAD_REQUEST` |
| 401 | `UNAUTHORIZED`, `INVALID_CREDENTIALS`, `TOKEN_EXPIRED`, `TOKEN_REUSED` |
| 403 | `FORBIDDEN`, `CONSENT_REQUIRED`, `PAPER_PERIOD_NOT_MET` |
| 404 | `NOT_FOUND` |
| 409 | `EMAIL_ALREADY_REGISTERED`, `BOT_INVALID_STATE` |
| 422 | `VALIDATION_ERROR`, `EXCHANGE_KEY_INVALID`, `EXCHANGE_KEY_WITHDRAW_ENABLED` |
| 429 | `TOO_MANY_ATTEMPTS`, `RATE_LIMITED` |
| 500 | `INTERNAL_ERROR` |
| 502/503 | `EXCHANGE_UNAVAILABLE` |

### 10.2 Endpoints

| Módulo | Método e rota | Req. |
|---|---|---|
| AUTH | `POST /auth/register` | AUTH-01, 08 |
| AUTH | `POST /auth/login` | AUTH-02, 03 |
| AUTH | `POST /auth/refresh` | AUTH-04 |
| AUTH | `POST /auth/logout` | AUTH-05 |
| AUTH | `POST /auth/forgot-password`, `POST /auth/reset-password` | AUTH-06 |
| AUTH | `POST /auth/change-password` | AUTH-07 |
| AUTH | `GET /me`, `DELETE /me` | AUTH-09 |
| FIN | `GET/POST /transactions`, `GET/PATCH/DELETE /transactions/{id}` | FIN-01…04 |
| FIN | `GET/POST /categories`, `PATCH/DELETE /categories/{id}` | FIN-05 |
| FIN | `GET /dashboard/summary?month=YYYY-MM` | FIN-06, 07 |
| EXCH | `PUT /exchange/credentials`, `GET /exchange/credentials` (só metadados), `DELETE /exchange/credentials` | EXCH-01…05 |
| PORT | `GET /portfolio`, `POST /portfolio/sync` | PORT-01…04 |
| CALC | `POST /calculations/compound-interest` | CALC-04 |
| BOT | `GET/PUT /bot/settings` | BOT-01 |
| BOT | `POST /bot/consent`, `POST /bot/start`, `POST /bot/stop`, `POST /bot/kill` | BOT-02, 03, 07 |
| BOT | `GET /bot/status` | BOT-13 |
| BOT | `GET /bot/orders` | BOT-14 |
| BOT | `POST /bot/backtests`, `GET /bot/backtests/{id}` | BOT-15 |
| PLAT | `GET /health` | RNF-09 |

### 10.3 Exemplos

**Cadastro — request**
```json
{
  "name": "Nome do Usuário",
  "email": "usuario@example.com",
  "password": "senha-com-10-caracteres",
  "accepted_terms": true,
  "terms_version": "2026-10"
}
```
Resposta `201`: igual à resposta de login abaixo.

**Login — request**
```json
{ "email": "usuario@example.com", "password": "senha-com-10-caracteres" }
```

**Login — resposta 200**
```json
{
  "access_token": "eyJ...",
  "refresh_token": "d3f...",
  "token_type": "bearer",
  "expires_in": 900,
  "user": { "id": "a1b2c3d4-...", "name": "Nome do Usuário" }
}
```

**Refresh — request**
```json
{ "refresh_token": "d3f..." }
```
Resposta `200`: igual à resposta de login acima.

**Logout — request**
```json
{ "refresh_token": "d3f..." }
```
Resposta `204` sem corpo.

**Esqueci a senha — request**
```json
{ "email": "usuario@example.com" }
```
Resposta `202`: sempre igual, exista ou não o e-mail.

**Redefinir senha — request**
```json
{ "token": "token-de-uso-unico", "new_password": "nova-senha-com-10" }
```
Resposta `204` sem corpo.

**Criar transação — request**
```json
{
  "type": "EXPENSE",
  "amount": "150.75",
  "description": "Conta de Luz",
  "category_id": "9b1c...",
  "date": "2026-10-05"
}
```

**Listar transações — request**
```http
GET /api/v1/transactions?from=2026-10-01&to=2026-10-31&type=EXPENSE&category_id=9b1c...&cursor=cursor-1&limit=50
```
Todos os filtros são opcionais. `type` aceita `INCOME` ou `EXPENSE`; `limit` é no máximo 100.

**Listar transações — resposta**
```json
{
  "items": [
    {
      "id": "f8e9...",
      "type": "EXPENSE",
      "amount": "150.75",
      "description": "Conta de Luz",
      "category_id": "9b1c...",
      "date": "2026-10-05"
    }
  ],
  "next_cursor": null
}
```

**Criar/editar transação — resposta**
Resposta com o objeto da transação no formato listado acima. `PATCH` usa `/api/v1/transactions/{id}` e o mesmo corpo do exemplo de criação.

**Excluir transação**
`DELETE /api/v1/transactions/{id}` responde `204` sem corpo.

**Listar categorias — resposta**
```json
{
  "items": [
    { "id": "9b1c...", "name": "Moradia", "archived": false }
  ]
}
```

**Criar categoria — request**
```json
{ "name": "Moradia" }
```

**Editar categoria — request**
`PATCH /api/v1/categories/{id}`; campos opcionais:
```json
{ "name": "Casa", "archived": false }
```

**Arquivar categoria**
`DELETE /api/v1/categories/{id}` responde `204` sem corpo. Categorias com transações são arquivadas, não removidas.

**Dashboard — resposta**
```json
{
  "month": "2026-10",
  "total_income": "5000.00",
  "total_expense": "3250.50",
  "month_balance": "1749.50",
  "cumulative_balance": "8920.10",
  "by_category": [{ "category_id": "9b1c...", "name": "Moradia", "total": "1200.00" }],
  "recent_transactions": [
    { "id": "f8e9...", "type": "EXPENSE", "amount": "150.75", "description": "Conta de Luz", "date": "2026-10-05" }
  ]
}
```

**Credencial da corretora — request** (separada da configuração do robô)
```json
{ "exchange": "BINANCE", "api_key": "…", "api_secret": "…" }
```
Resposta: `{ "status": "CONNECTED", "key_hint": "…a9F2", "last_checked_at": "2026-10-05T14:00:00Z" }`

**Credencial da corretora — respostas**
`GET /api/v1/exchange/credentials` retorna os mesmos metadados da resposta de `PUT`.
Se não houver credencial salva, responde `404` com o código `NOT_FOUND`. `status`
aceita `CONNECTED`, `INVALID`, `RATE_LIMITED` ou `UNREACHABLE`; `key_hint` é
string; `last_checked_at` é timestamp UTC ISO 8601 ou `null`. A resposta nunca
inclui `api_key` nem `api_secret`. `DELETE /api/v1/exchange/credentials` responde
`204` sem corpo.

**Carteira — resposta**
`GET /api/v1/portfolio` e `POST /api/v1/portfolio/sync` (sem corpo) retornam:
```json
{
  "total_value_usdt": "3775.00",
  "total_value_display": "3775.00",
  "display_currency": "USDT",
  "total_pnl": "75.00",
  "total_pnl_percent": "2.02",
  "stale": false,
  "last_synced_at": "2026-10-06T13:00:00Z",
  "assets": [
    {
      "symbol": "BTC",
      "quantity": "0.025",
      "average_price": "60000.00",
      "current_price": "65000.00",
      "current_value": "1625.00",
      "pnl": "125.00",
      "pnl_percent": "8.33"
    }
  ]
}
```
Todos os campos monetários, inclusive quantidade, são strings decimais.
`total_pnl_percent` e `pnl_percent` são strings decimais ou `null`;
`last_synced_at` é timestamp UTC ISO 8601 ou `null`. `stale` é booleano.
Sincronização manual acima de uma vez por minuto responde `429 RATE_LIMITED`.

**Juros compostos — request**
`POST /api/v1/calculations/compound-interest`:
```json
{
  "initial_amount": "1000.00",
  "monthly_contribution": "100.00",
  "monthly_rate": "1.00",
  "months": 12
}
```
`monthly_rate` é o percentual ao mês (`"1.00"` representa 1%); taxa zero é
válida. `months` é inteiro maior ou igual a 1. A resposta contém
`final_value`, `total_invested` e `total_interest`, todos strings decimais.

**Configuração do robô — request**
```json
{
  "mode": "PAPER",
  "strategy_id": "dca_v1",
  "strategy_params": { "order_amount": "50.00", "interval_hours": 24 },
  "max_capital_allocation": "1000.00",
  "max_order_size": "100.00",
  "max_daily_loss": "50.00",
  "max_total_loss": "200.00",
  "allowed_pairs": ["BTC/USDT", "ETH/USDT"]
}
```

**Configuração do robô — resposta**
`GET /api/v1/bot/settings` retorna os campos do exemplo de configuração acima,
mais `risk_level` (`LOW`, `MEDIUM` ou `HIGH`) e
`consent: { "accepted": boolean, "version": string | null }`.
Sem configuração salva, responde `404 NOT_FOUND`. `PUT /api/v1/bot/settings`
recebe o exemplo acima acrescido de `risk_level` e responde com o mesmo formato
do GET. Valores monetários são strings decimais; `mode` viaja em maiúsculas.

**Status do robô — resposta**
`GET /api/v1/bot/status`, `POST /api/v1/bot/start`, `POST /api/v1/bot/stop` e
`POST /api/v1/bot/kill` (os POSTs sem corpo) retornam:
```json
{
  "state": "INACTIVE",
  "mode": "PAPER",
  "max_capital_allocation": "1000.00",
  "last_run_at": null,
  "next_run_at": null,
  "open_orders": 0,
  "pnl_today": "0.00",
  "last_error": null,
  "paper_days_completed": 0,
  "live_allowed": false
}
```
`state`: `INACTIVE`, `STARTING`, `RUNNING`, `PAUSED`, `STOPPED_BY_RISK` ou
`ERROR`; `mode`: `PAPER` ou `LIVE`; timestamps são UTC ISO 8601 ou `null`.
`last_error`, quando presente, contém `code`, `message` e `occurred_at`.
`POST /api/v1/bot/consent` recebe `{ "version": "2026-10" }` e responde `204`.
Erros de início podem ser `409 BOT_INVALID_STATE`, `403 CONSENT_REQUIRED` ou
`403 PAPER_PERIOD_NOT_MET`.

**Histórico de ordens — request e resposta**
`GET /api/v1/bot/orders` aceita filtros opcionais `simulated` (boolean),
`pair`, `from`, `to`, `cursor` e `limit`. Datas usam `YYYY-MM-DD`.
Resposta paginada:
```json
{
  "items": [
    {
      "id": "order-1",
      "pair": "BTC/USDT",
      "side": "BUY",
      "quantity": "0.010",
      "avg_price": "65000.00",
      "fee": "0.10",
      "status": "FILLED",
      "is_simulated": true,
      "exchange_order_id": null,
      "strategy_id": "dca_v1",
      "signal_reason": "Compra periódica DCA",
      "created_at": "2026-10-06T13:00:00Z"
    }
  ],
  "next_cursor": null
}
```
`side`: `BUY` ou `SELL`; `status`: `OPEN`, `FILLED`, `CANCELED` ou
`REJECTED`; todos os valores monetários e quantidades são strings decimais;
`exchange_order_id` é string ou `null`.

---

## 11. Segurança e Conformidade (resumo de controles)

| Ameaça | Controle |
|---|---|
| Vazamento do banco | Credenciais criptografadas; senhas com hash forte; tokens guardados só como hash. |
| Vazamento da chave mestra | Fora do banco e do repositório; versão de chave por registro; procedimento de rotação documentado. |
| Roubo de chave Binance | Recusar permissão de saque; orientar IP whitelist; nunca devolver o secret. |
| Roubo de sessão | Access curto; refresh com rotação e detecção de reuso; armazenamento seguro no dispositivo. |
| Acesso a dados de outro usuário (IDOR) | `user_id` sempre do token; testes automatizados de isolamento por endpoint. |
| Robô fora de controle | Guardrails, perda máxima, kill switch, idempotência, reconciliação, período PAPER obrigatório. |
| Abuso da API | Rate limit, bloqueio por tentativas, validação estrita. |
| Dependências vulneráveis | Auditoria no CI (`pip-audit`, `dart pub outdated`); dependências fixadas. |
| Responsabilidade regulatória | Termos e aviso de risco; análise jurídica antes do modo LIVE (ABERTO Q6). |

---

## 12. Dependências entre Módulos (para planejamento)

```
PLAT ──► AUTH ──► FIN
          │
          └────► EXCH ──► PORT ──► (CALC é usado por PORT e MOB)
                   │
                   └────► BOT  (depende de EXCH, PORT, CALC, AUTH)
MOB consome a API de cada módulo, depois que o respectivo contrato (seção 10) estiver implementado.
```

Regras de segmentação sugeridas para o plano do agente:
1. Cada sessão implementa **um módulo (ou parte) com seus testes** e só depende de módulos anteriores já concluídos.
2. **CALC** e **Strategy** são puros e podem ser feitos em paralelo a qualquer outro módulo.
3. O contrato da API (seção 10) é a fronteira entre `backend` e `mobile`; o mobile pode ser desenvolvido contra mocks do contrato.
4. `ExchangeClient` tem implementação **fake** em memória para testes de PORT e BOT.
5. Cada sessão termina com: testes passando, lint/type-check limpos, migração criada e requisitos atendidos listados.

---

## 13. Questões em Aberto

| ID | Pergunta | Necessária antes de |
|---|---|---|
| Q1 | O que é a "IA" do robô? (regras técnicas, modelo de ML, LLM?) Fonte de dados e horizonte de operação (spot, intervalo dos ciclos)? | F3 |
| Q2 | Moeda de exibição principal (BRL?) e fonte de cotação USDT→BRL. | F2 |
| Q3 | O app será distribuído publicamente ou é de uso pessoal/fechado? (impacta LGPD, termos e regulação) | F1 |
| Q4 | Ao acionar o kill switch, o robô deve apenas parar ou também liquidar posições? | F3 |
| Q5 | Rentabilidade do período: retorno simples ou ponderado pelo tempo? | F2 |
| Q6 | Haverá parecer jurídico sobre operar por conta do usuário (CVM/BCB) antes do modo LIVE? | F4 |
| Q7 | Hospedagem alvo (VPS, cloud gerenciada) e orçamento? | F0 |
| Q8 | Notificações: push (FCM) ou apenas e-mail no MVP? | F3 |
| Q9 | A carteira deve incluir ativos comprados fora da Binance (PORT-05)? | F2 |

---

## 14. Rastreabilidade (v1 → v2)

| v1 | v2 |
|---|---|
| RF01 | AUTH-01…09 |
| RF02, RF03 | FIN-01…08, MOB-03/04 |
| RF04 | PORT-01…04, MOB-06 |
| RF05 | CALC-01…05, MOB-10 |
| RF06 | EXCH-01…06, MOB-07 |
| RF07 | BOT-01…13, MOB-08 |
| RF08 | BOT-14, MOB-09 |
| RNF02 | RNF-02, EXCH-03 (escopo corrigido: só credenciais) |
| RNF03, RNF04 | RNF-01, RNF-03 |
| RNF05 | D06, RNF-07 |
| RN01 | RN-01, BOT-02/03/04 |
| RN02 | RN-02, RNF-05 |
| RN03 | RN-03, BOT-05 |
