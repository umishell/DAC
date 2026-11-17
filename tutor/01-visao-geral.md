# 1. Visão geral da arquitetura Saga

[← Voltar ao índice](./README.md)

## 1.1 Componentes e responsabilidades

| Componente | Tecnologia | Papel na saga |
|------------|------------|----------------|
| **Gateway** | Node (Fastify) | API HTTP, autenticação, cria **job** no Redis, publica **uma** mensagem em `saga.cmd` |
| **ms-saga** | Spring Boot (Kotlin) | **Orquestrador**: estado da saga, sequência de passos, compensação, atualização do job |
| **ms-cliente / ms-gerente / ms-conta / ms-auth** | Spring Boot | Executam **um comando** por mensagem; respondem em `orquestrador.reply` |
| **ms-email** | Spring Boot | Comandos **sem resposta** (notificações) |
| **RabbitMQ** | Filas duráveis | Barramento assíncrono entre serviços |
| **Redis** | Chave-valor | Estado da saga, jobs, lock de compensação, senhas temporárias da saga |

O Gateway **não** fala com cliente/conta/auth diretamente na aprovação: ele só dispara a saga e expõe [`GET /jobs/:jobId/status`](../backend/gateway/src/routes/jobs.ts).

---

## 1.2 Filas RabbitMQ (nomes canônicos)

Fonte: [`QueueNames.kt`](../backend/services/shared/src/main/kotlin/br/ufpr/dac/bantads/shared/amqp/QueueNames.kt) e [`db/rabbitmq/definitions.json`](../db/rabbitmq/definitions.json).

| Fila | Quem consome | Quem publica |
|------|--------------|--------------|
| `saga.cmd` | ms-saga (`SagaCommandListener`) | Gateway |
| `orquestrador.reply` | ms-saga (`ReplyListener`) | ms-cliente, ms-gerente, ms-conta, ms-auth |
| `ms.cliente.cmd` | ms-cliente | ms-saga |
| `ms.gerente.cmd` | ms-gerente | ms-saga |
| `ms.conta.cmd` | ms-conta | ms-saga |
| `ms.auth.cmd` | ms-auth | ms-saga |
| `ms.email.cmd` | ms-email | ms-saga |
| `*.cmd.dlq` | ms-saga (`DlqListener`) | DLX após retries esgotados |

Filas de comando (exceto `saga.cmd` e `ms.email.cmd`) usam **dead-letter**: mensagem rejeitada/não confirmada vai para `*.cmd.wait` (TTL 5s, retry) e depois para `*.cmd.dlq`.

---

## 1.3 Contrato de mensagens

### Comando (ida)

[`MessageEnvelope`](../backend/services/shared/src/main/kotlin/br/ufpr/dac/bantads/shared/amqp/MessageEnvelope.kt):

- `sagaId` — igual ao `jobId` do Gateway (correlação ponta a ponta)
- `tipo` — comando atômico (ex.: `cliente.marcar-aprovada`) ou saga de alto nível (ex.: `aprovar-cliente` **só** na primeira mensagem)
- `timestamp`
- `payload` — mapa JSON acumulado ao longo da saga

Publicação no Gateway: [`publisher.ts`](../backend/gateway/src/amqp/publisher.ts) → fila `saga.cmd`.

### Resposta (volta)

[`ReplyEnvelope`](../backend/services/shared/src/main/kotlin/br/ufpr/dac/bantads/shared/amqp/ReplyEnvelope.kt):

- `sagaId`, `tipo` (o mesmo comando que foi executado)
- `status`: `SUCESSO` ou `FALHA`
- `erro` (se falhou)
- `payload` — **dados novos** que o orquestrador **soma** ao payload global

Padrão nos microserviços (exemplo cliente): [`ClienteCommandListener.kt`](../backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/saga/ClienteCommandListener.kt) — após `handler.handle`, se `sagaId != null`, envia reply para `orquestrador.reply`.

Catálogo de tipos: [`CommandTypes.kt`](../backend/services/shared/src/main/kotlin/br/ufpr/dac/bantads/shared/amqp/CommandTypes.kt).

---

## 1.4 Tipos de etapa (`StepKind`)

[`StepKind.kt`](../backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/engine/StepKind.kt)

| Kind | Comportamento |
|------|----------------|
| `TRANSACTIONAL` | Publica na fila do MS, **para e espera** reply. Timeout configurável (`saga.step-timeout`, padrão 30s). Sem reply a tempo → compensação. |
| `FIRE_AND_FORGET` | Publica (ex.: e-mail) e **avança imediatamente** sem esperar confirmação. |
| `LOCAL` | Executado **dentro do ms-saga** (ex.: invalidar sessão no Redis, passos do `echo`). |

Cada etapa na receita é um [`SagaStep`](../backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/engine/SagaStep.kt): `tipo`, `kind`, `queue`, opcionalmente `compensationTipo` / `compensationQueue`, e `skipIfTrue` (pula etapa se flag no payload, ex. `semConta`).

---

## 1.5 Estado e jobs (Redis)

O ms-saga persiste:

- **`SagaState`** — etapa atual, payload mesclado, status, qual comando está aguardando, timeout, lista `succeededTipos` ([`SagaState.kt`](../backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/engine/SagaState.kt))
- **Job** — espelho do que o cliente consulta (`PENDENTE` → `CONCLUIDO` / `FALHA`) via [`JobStore`](../backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/store/JobStore.kt)

O Gateway grava o job inicial em Redis ao aceitar a requisição; o saga **atualiza** o mesmo `jobId` ao concluir ou falhar (`SagaEngine.complete` / `failJob`).

Configuração: [`application.yml`](../backend/services/saga/src/main/resources/application.yml) (`step-timeout`, `timeout-scan-ms`, TTLs).

---

## 1.6 Idempotência nos participantes (Saga Inbox)

Cada comando transactional pode ser redeliverado pelo RabbitMQ. Os handlers consultam tabela **inbox** `(sagaId, tipo)` e devolvem a mesma resposta já gravada, sem reexecutar efeito colateral.

- Cliente: [`ClienteCommandHandler.handle`](../backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/saga/ClienteCommandHandler.kt)
- Auth: padrão similar com reserva de inbox — [`AuthCommandHandler`](../backend/services/auth/src/main/kotlin/br/ufpr/dac/bantads/auth/saga/AuthCommandHandler.kt)
- Conta / Gerente: mesmo padrão nos respectivos `*CommandHandler.kt`

Isso é importante na apresentação: **compensação não “desfaz” inbox**, mas **reexecução do mesmo comando** na ida é segura.

---

## 1.7 Pontos de entrada no ms-saga

| Listener | Arquivo | Fila |
|----------|---------|------|
| Início de saga | [`SagaCommandListener.kt`](../backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/amqp/SagaCommandListener.kt) | `saga.cmd` |
| Respostas | [`ReplyListener.kt`](../backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/amqp/ReplyListener.kt) | `orquestrador.reply` |
| Falha infra | [`DlqListener.kt`](../backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/amqp/DlqListener.kt) | `*.cmd.dlq` |
| Publicação de comandos | [`RabbitCommandBus.kt`](../backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/amqp/RabbitCommandBus.kt) | filas `ms.*.cmd` |

Varredura de timeout: [`TimeoutScanner.kt`](../backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/engine/TimeoutScanner.kt) chama `engine.failTimedOutSteps()` a cada ~1s.

---

## 1.8 Frontend (contexto de negócio)

O gerente aprova autocadastro na tela de solicitações, que chama o Gateway:

- UI: [`frontend/src/app/gerente/solicitacoes/solicitacoes.ts`](../frontend/src/app/gerente/solicitacoes/solicitacoes.ts)
- HTTP: `SolicitacaoService` → `POST .../solicitacoes/{cpf}/aprovacao` e polling do job

A **rejeição** de solicitação **não** usa saga (fluxo síncrono no ms-cliente); só a **aprovação** dispara R9.

**Outras sagas e modos assíncronos:** o material até o doc 03 detalha sobretudo R9; para R13, R15, `echo` e a matriz `TRANSACTIONAL` / `LOCAL` / `FIRE_AND_FORGET`, ver [12](./12-saga-tipos-assincronicidade.md)–[15](./15-fluxo-echo.md).