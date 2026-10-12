# Cronograma resumido do projeto

## Situação para alinhamento

O projeto tem o aplicativo mobile implementado contra repositórios fake e a fundação inicial do backend (S01). **Ainda não existe um banco PostgreSQL operacional para desenvolvimento local nem tabelas/migrações de negócio.** A principal dependência imediata é destravar Docker/virtualização ou disponibilizar um PostgreSQL de desenvolvimento acessível.

Este cronograma agrupa as sessões técnicas em cinco marcos para facilitar o acompanhamento. É uma sequência de entregas, não um compromisso de datas: ainda não foram definidos disponibilidade da equipe, responsáveis nem capacidade semanal.

| Ordem | Marco | Escopo agrupado | Critério de saída |
|---|---|---|---|
| 1 | Destravar ambiente e fechar fundação (S00/S01) | Disponibilizar Docker/WSL 2 ou PostgreSQL de desenvolvimento; subir Compose; validar healthcheck e CI; manter S01 como base do backend. | API, PostgreSQL e Redis sobem no ambiente de desenvolvimento; healthcheck responde; CI passa. |
| 2 | Implementar cálculos puros (S02) | Funções financeiras com `Decimal`, testes de precisão e endpoint contratado. Pode ser desenvolvido em paralelo ao marco 1; resolver Q2/Q5 se forem necessários para fechar comportamento. | Testes de cálculo passam e cobertura de CALC atinge o critério do plano. |
| 3 | Entregar contas e finanças (S03–S06) | Autenticação, sessão, categorias, transações e dashboard; criar as primeiras migrações de negócio; conectar as telas mobile e retirar os fakes dessas áreas. | Fluxos AUTH/FIN funcionam contra PostgreSQL local e passam os testes de contrato/integração. |
| 4 | Entregar corretora e carteira (S10–S12, com CALC) | Credenciais protegidas, sincronização da carteira, integração do cálculo e conexão das telas mobile; resolver decisões de produto pendentes que afetem carteira/cálculo. | EXCH/PORT/CALC integrados à API; testes cobrem persistência, segurança de credenciais e contrato mobile. |
| 5 | Entregar robô PAPER e validar MVP (S13–S18) | Domínio e limites de risco, configuração, worker, execução simulada, histórico, integração mobile e hardening/revisão de segurança. | Fluxo PAPER validado ponta a ponta; revisão S18 concluída. |

**Fora do cronograma imediato:** S19/F4 (modo LIVE). Só começa após S18, decisão jurídica Q6 e resolução dos bloqueios de segurança/regulatórios. Backtest/notificações (S16) é opcional conforme o plano.

## O que a documentação diz sobre o banco

Sim. O [levantamento de requisitos, seção 9](./levantamento-de-requisitos-v2.md#9-modelo-de-dados-conceitual) define um **modelo conceitual** com 12 tabelas: `users`, `consents`, `refresh_tokens`, `password_reset_tokens`, `categories`, `transactions`, `exchange_credentials`, `portfolio_positions`, `bot_settings`, `bot_orders`, `bot_run_logs` e `audit_events`.

O mesmo levantamento define PostgreSQL 15+, SQLAlchemy assíncrono com `asyncpg`, Alembic para migrações, UUIDs, timestamps, valores monetários `NUMERIC(20,8)`, chaves estrangeiras e constraints. O Compose já declara serviços PostgreSQL 15 e Redis 7.

**O que ainda não temos:** servidor PostgreSQL local iniciado e acessível; modelos SQLAlchemy de negócio; migrações Alembic criando as tabelas; nem testes de integração contra PostgreSQL local. S01 adicionou a infraestrutura e migrações vazias. Os testes atuais usam SQLite assíncrono localmente e exercitam um modelo temporário de teste; isso valida a infraestrutura, mas não substitui PostgreSQL nem constitui o schema do produto. O serviço PostgreSQL do CI também não significa que exista um banco de desenvolvimento disponível para a equipe.

## Dependências e decisões

- O marco 1 está bloqueado neste computador pela virtualização indisponível para o Docker Desktop. Uma alternativa é solicitar à equipe um PostgreSQL de desenvolvimento acessível, sem esperar pela configuração local.
- AUTH/FIN dependem do núcleo S01; EXCH depende de AUTH; PORT depende de EXCH e CALC; o robô depende dessas bases.
- O mobile já tem telas e contratos planejados, mas usa fakes. Integração real é parte dos marcos 3–5.
- Decisões em aberto no levantamento incluem Q2/Q5 para cálculo e apresentação financeira, Q9 para ativos externos à Binance, Q1/Q4 para o robô, e Q6 antes de LIVE. Confirmar cada questão antes do marco que ela bloqueia.

## Próxima ação

Confirmar com a equipe como obter um PostgreSQL de desenvolvimento (Docker local após habilitar virtualização, ou instância compartilhada aprovada). Assim que houver conexão, validar Compose/healthcheck e iniciar S03 (AUTH); S02 pode seguir em paralelo.
