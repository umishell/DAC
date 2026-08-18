---
name: bantads-ms-conta
description: MS Conta BANTADS — CQRS, Event Sourcing, depósito/saque/transferência/extrato, vínculo de gerente. Use em services/conta, event store, read model, R3–R7, passos conta das SAGAs.
---

# Agente — MS Conta (CQRS + Event Sourcing)

Um JVM, dois datasources/schemas: `conta_command` e `conta_query`. Pacotes isolados. Sync **somente** via fila `ms.conta.events`.

## Command (event store)

Tabela `evento`: `id`, `objeto_id` (conta 4 dígitos), `tipo`, `payload` JSONB (dinheiro string), `versao`, `timestamp`. UNIQUE `(objeto_id, versao)`.

Tipos **exatos**: `Criado`, `Saque`, `Depósito`, `TransferênciaOrigem`, `TransferênciaDestino`, `GerenteAlterado`.

Write: `MAX(versao)` → **replay** ordenado → validar (saldo, posse, destino) → INSERT próxima versão. Unique violation → retry replay. **Nunca** validar saldo no read model.

- Posse R4/R5/R6: `X-User-Tipo=CLIENTE` e `cpfCliente == X-User-CPF` senão 403
- Valor > 0; malformado 400; saldo insuficiente / destino inexistente / mesma conta → 422
- Transferência: **uma transação local** grava origem e destino. Não é SAGA. Payload já vem enriquecido (nomes/CPFs) pelo Gateway
- Conta nova (R9): 4 dígitos **aleatórios** únicos — não usar prefixo do CPF
- Resposta R4/R5/R6: `OperacaoRealizada` **sem o novo saldo**

`Criado` payload inclui `cpfGerente`. Troca de gerente → `GerenteAlterado`.

Compensação “remover conta”: só streams criados na SAGA atual (tombstone/delete controlado). Documentar premissa.

## Query (read model desnormalizado)

`conta`: numero, cpf_cliente, cpf_gerente, saldo NUMERIC(19,4), data_criacao.

`movimentacao`: tipo `DEPOSITO|SAQUE|TRANSFERENCIA`, origem/destino só em transferência.

Projeção **idempotente** (`evento_id`). DLQ de events: reprocessamento **manual**, sem compensação SAGA.

HTTP query: `GET /contas/{numero}`, `GET /clientes/{cpf}/conta` (não cachear no Gateway), extrato:

- default últimos 30 dias; máx 365; fim < início → 422
- `saldoAbertura` = consolidado **antes** de inicio; `movimentacoes` do período

Interno: batch saldos; contagem de clientes por gerente.

## AMQP command (SAGA)

- `conta.escolher-gerente-menos-clientes` — 0 contas = 0; empate qualquer; **via replay/snapshot do command**, não query
- `conta.criar` / `conta.remover`
- `conta.identificar-conta-para-novo-gerente` — regra R13
- `conta.atribuir-gerente` / reassocia
- `conta.transferir-contas-do-gerente` — R15 para o ativo com menos clientes ≠ removido

### Regra R13 (teste unitário puro)

1. Entre ativos existentes, maior quantidade de contas
2. Se essa máxima é ≤ 1 → **nenhuma** conta transfere (nunca zerar um gerente existente)
3. Empate de quantidade → menor **soma de saldos**
4. Desse, a conta de **menor saldo**

Seed: inserir 5º gerente transfere `7617` (Godophredo, menor saldo).

## Seed

Popular **command e query** de forma consistente. Replay Catharyna `1291` = `"800.00"`. Movimentações e datas exatamente da seção 4. Reboot pode inserir os dois lados direto (sem esperar Rabbit) para T00 ser síncrono.
