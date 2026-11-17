# Índice de arquivos (Saga)

[← Voltar ao índice](./README.md)

Caminhos relativos à raiz do repositório (`DAC/`).

## Orquestração (ms-saga)

Tutoriais por pasta: [05-pastas-ms-saga.md](./05-pastas-ms-saga.md) · fluxos por saga: [12](./12-saga-tipos-assincronicidade.md)–[15](./15-fluxo-echo.md)

| Arquivo | Descrição |
|---------|-----------|
| [`backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/engine/SagaRegistry.kt`](../backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/engine/SagaRegistry.kt) | Receitas das sagas (passos, filas, compensações) |
| [`backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/engine/SagaEngine.kt`](../backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/engine/SagaEngine.kt) | `start`, `advance`, `onReply`, `compensate`, `complete` |
| [`backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/engine/SagaStep.kt`](../backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/engine/SagaStep.kt) | Modelo de uma etapa |
| [`backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/engine/StepKind.kt`](../backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/engine/StepKind.kt) | LOCAL / TRANSACTIONAL / FIRE_AND_FORGET |
| [`backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/engine/SagaState.kt`](../backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/engine/SagaState.kt) | Estado persistido da instância |
| [`backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/engine/TimeoutScanner.kt`](../backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/engine/TimeoutScanner.kt) | Job agendado de timeout |
| [`backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/amqp/SagaCommandListener.kt`](../backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/amqp/SagaCommandListener.kt) | Consome `saga.cmd` |
| [`backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/amqp/ReplyListener.kt`](../backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/amqp/ReplyListener.kt) | Consome `orquestrador.reply` |
| [`backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/amqp/DlqListener.kt`](../backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/amqp/DlqListener.kt) | Consome DLQs |
| [`backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/amqp/RabbitCommandBus.kt`](../backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/amqp/RabbitCommandBus.kt) | Publica em `ms.*.cmd` |
| [`backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/store/RedisCompensationGuard.kt`](../backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/store/RedisCompensationGuard.kt) | Lock de compensação |
| [`backend/services/saga/src/main/resources/application.yml`](../backend/services/saga/src/main/resources/application.yml) | Timeout, TTL Redis |

## Gateway

Tutoriais por pasta: [06-pastas-gateway.md](./06-pastas-gateway.md) · fluxos AMQP: [07-fluxos-e-formatos.md](./07-fluxos-e-formatos.md) · Gateway transversal: [08](./08-gateway-tipos-de-fluxo.md)–[11](./11-gateway-catalogo-funcionalidades.md)

| Arquivo | Descrição |
|---------|-----------|
| [`backend/gateway/src/routes/aprovacao.ts`](../backend/gateway/src/routes/aprovacao.ts) | POST aprovação → saga R9 |
| [`backend/gateway/src/routes/inserir-gerente.ts`](../backend/gateway/src/routes/inserir-gerente.ts) | POST gerente → saga R13 |
| [`backend/gateway/src/routes/remover-gerente.ts`](../backend/gateway/src/routes/remover-gerente.ts) | DELETE gerente → saga R15 |
| [`backend/gateway/src/routes/jobs.ts`](../backend/gateway/src/routes/jobs.ts) | Status/resultado do job |
| [`backend/gateway/src/amqp/publisher.ts`](../backend/gateway/src/amqp/publisher.ts) | Publica em `saga.cmd` |

## Shared (contratos)

| Arquivo | Descrição |
|---------|-----------|
| [`backend/services/shared/src/main/kotlin/br/ufpr/dac/bantads/shared/amqp/CommandTypes.kt`](../backend/services/shared/src/main/kotlin/br/ufpr/dac/bantads/shared/amqp/CommandTypes.kt) | Constantes de tipos |
| [`backend/services/shared/src/main/kotlin/br/ufpr/dac/bantads/shared/amqp/QueueNames.kt`](../backend/services/shared/src/main/kotlin/br/ufpr/dac/bantads/shared/amqp/QueueNames.kt) | Nomes de filas |
| [`backend/services/shared/src/main/kotlin/br/ufpr/dac/bantads/shared/amqp/MessageEnvelope.kt`](../backend/services/shared/src/main/kotlin/br/ufpr/dac/bantads/shared/amqp/MessageEnvelope.kt) | Envelope de comando |
| [`backend/services/shared/src/main/kotlin/br/ufpr/dac/bantads/shared/amqp/ReplyEnvelope.kt`](../backend/services/shared/src/main/kotlin/br/ufpr/dac/bantads/shared/amqp/ReplyEnvelope.kt) | Envelope de resposta |
| [`backend/services/shared/src/main/kotlin/br/ufpr/dac/bantads/shared/domain/SagaType.kt`](../backend/services/shared/src/main/kotlin/br/ufpr/dac/bantads/shared/domain/SagaType.kt) | Enum de sagas de alto nível |

## Participantes — Cliente

| Arquivo | Descrição |
|---------|-----------|
| [`backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/saga/ClienteCommandListener.kt`](../backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/saga/ClienteCommandListener.kt) | AMQP in/out |
| [`backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/saga/ClienteCommandHandler.kt`](../backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/saga/ClienteCommandHandler.kt) | Lógica R9 no domínio cliente |

## Participantes — Gerente

| Arquivo | Descrição |
|---------|-----------|
| [`backend/services/gerente/src/main/kotlin/br/ufpr/dac/bantads/gerente/saga/GerenteCommandListener.kt`](../backend/services/gerente/src/main/kotlin/br/ufpr/dac/bantads/gerente/saga/GerenteCommandListener.kt) | AMQP |
| [`backend/services/gerente/src/main/kotlin/br/ufpr/dac/bantads/gerente/saga/GerenteCommandHandler.kt`](../backend/services/gerente/src/main/kotlin/br/ufpr/dac/bantads/gerente/saga/GerenteCommandHandler.kt) | Listar/inserir gerentes |

## Participantes — Conta

| Arquivo | Descrição |
|---------|-----------|
| [`backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/saga/ContaCommandListener.kt`](../backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/saga/ContaCommandListener.kt) | AMQP |
| [`backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/saga/ContaCommandHandler.kt`](../backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/saga/ContaCommandHandler.kt) | Escolher gerente, criar/remover conta |

## Participantes — Auth

| Arquivo | Descrição |
|---------|-----------|
| [`backend/services/auth/src/main/kotlin/br/ufpr/dac/bantads/auth/saga/AuthCommandListener.kt`](../backend/services/auth/src/main/kotlin/br/ufpr/dac/bantads/auth/saga/AuthCommandListener.kt) | AMQP |
| [`backend/services/auth/src/main/kotlin/br/ufpr/dac/bantads/auth/saga/AuthCommandHandler.kt`](../backend/services/auth/src/main/kotlin/br/ufpr/dac/bantads/auth/saga/AuthCommandHandler.kt) | Criar cliente/gerente, remover |

## Participantes — Email

| Arquivo | Descrição |
|---------|-----------|
| [`backend/services/email/src/main/kotlin/br/ufpr/dac/bantads/email/amqp/EmailCommandListener.kt`](../backend/services/email/src/main/kotlin/br/ufpr/dac/bantads/email/amqp/EmailCommandListener.kt) | Consome `ms.email.cmd` (sem reply) |

## Infraestrutura

| Arquivo | Descrição |
|---------|-----------|
| [`db/rabbitmq/definitions.json`](../db/rabbitmq/definitions.json) | Filas, DLX, bindings |
| [`docker-compose.yml`](../docker-compose.yml) | Serviço `saga`, Redis, RabbitMQ |

## Testes (especificação executável)

| Arquivo | Descrição |
|---------|-----------|
| [`backend/services/saga/src/test/kotlin/br/ufpr/dac/bantads/saga/engine/SagaEngineTest.kt`](../backend/services/saga/src/test/kotlin/br/ufpr/dac/bantads/saga/engine/SagaEngineTest.kt) | R9, R13, R15, timeout, DLQ |
| [`backend/services/saga/src/test/kotlin/br/ufpr/dac/bantads/saga/SagaIT.kt`](../backend/services/saga/src/test/kotlin/br/ufpr/dac/bantads/saga/SagaIT.kt) | Integração |
| [`backend/contract-tests/test_z_catalog_async_rabbit.py`](../backend/contract-tests/test_z_catalog_async_rabbit.py) | Contrato filas AMQP |

## Frontend

| Arquivo | Descrição |
|---------|-----------|
| [`frontend/src/app/gerente/solicitacoes/solicitacoes.ts`](../frontend/src/app/gerente/solicitacoes/solicitacoes.ts) | UI que dispara aprovação |
| [`frontend/src/app/services/solicitacao.service.ts`](../frontend/src/app/services/solicitacao.service.ts) | Chamada HTTP + job |