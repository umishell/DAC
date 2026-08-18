---
name: bantads-ms-saga
description: Orquestrador SAGA BANTADS — RabbitMQ orquestrado, Redis estado, timeout 30s, compensação idempotente, jobs. Use em services/saga, filas *.cmd, R9/R13/R15.
---

# Agente — Orquestrador SAGA

Só AMQP + Redis. HTTP: `/health` e o mínimo interno. **Nunca** coreografia (MS não chama MS).

## Filas

`saga.cmd` → você. Você publica `ms.*.cmd`. MSs respondem `orquestrador.reply`. E-mail em `ms.email.cmd` (FF, sem reply, sem timeout, não aborta SAGA).

DLQ `ms.{cliente,conta,gerente,auth}.cmd.dlq`: compensar **uma vez** por `(sagaId, etapa)` — DLQ e timeout 30s podem chegar os dois.

## Estado Redis `saga:{id}` TTL 1h

`{ sagaId, tipo, etapaAtual, status, payload, timestamp }` — payload **sem senha**.

Job Redis `job:{id}` (mesmo UUID): você atualiza `PENDENTE|CONCLUIDO|FALHA`.

## R9 Aprovar Cliente (`aprovar-cliente`)

1. `cliente.marcar-aprovada` → compensar PENDENTE
2. `gerente.listar-ativos`
3. `conta.escolher-gerente-menos-clientes`
4. `cliente.criar` → remover cliente
5. `auth.criar-cliente` → remover auth (senha clara só neste reply → passo email)
6. `conta.criar` → remover conta
7. `email.senha-cliente` FF

Falha transacional: compensar inversa + `email.falha-aprovacao`.

**E-mail duplicado no Auth:** não voltar solicitação a PENDENTE; `cliente.marcar-nao-aprovada` motivo automático. Job `FALHA`.

Sucesso: `resultType=resource`, `dominio=clientes`, `resourceId=cpf`. DEL `cache:cliente:{cpf}`.

## R13 Inserir Gerente (`inserir-gerente`)

1. `gerente.inserir` → delete
2. `auth.criar-gerente` → delete auth
3. `conta.identificar-conta-para-novo-gerente`
4–6. Se houver conta: atribuir, obter cliente, `email.troca-gerente`. Se `semConta`: pular e **sucesso**.

Job resource `dominio=gerentes`. Unique e-mail = job FALHA (202 já foi). DEL cache gerente.

## R15 Remover Gerente (`remover-gerente`)

Pré-condição 403 é no **Gateway**. Aqui:

1. `gerente.inativar` (último ativo → FALHA)
2. `auth.desativar`
3. Você DEL `sessao:cpf:{cpf}` e `sessao:{jti}` (sem compensação)
4. listar ativos
5. transferir contas
6. obter clientes
7. e-mails FF

Sucesso inline `{ mensagem }`. DEL cache gerente.

## Relatório R16

Pode ser tipo `relatorio-clientes` sem compensação: composition e grava `resultado` no job inline.

## Idempotência

Reentrega Rabbit = at-least-once. Inbox nos MSs. Compensação por passo uma vez. Timeout 30s só passos transacionais (Cliente, Gerente, Conta, Auth).
