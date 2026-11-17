# 4. Roteiro para apresentação ao professor

[← Voltar ao índice](./README.md)

Use este roteiro como **fala de 8–12 minutos**. Aprofunde nos links do [tutorial completo](./02-fluxo-aprovar-cliente.md) se perguntarem detalhes.

---

## Slide 1 — Problema

- Operação **“aprovar autocadastro”** toca **quatro bounded contexts**: solicitação (cliente), gerente, conta, autenticação, mais notificação por e-mail.
- Cada um tem **seu PostgreSQL**. Não dá para uma transação SQL única.
- **Solução:** padrão **Saga** — sequência de transações locais + **compensações** se algo falhar.

---

## Slide 2 — Quem é o orquestrador

- **ms-saga** (`SagaEngine` + `SagaRegistry`) é o cérebro.
- **Gateway** só inicia: HTTP 202 + job assíncrono + uma mensagem RabbitMQ.
- Participantes **não** conhecem a saga inteira; só executam **comandos** tipados (`cliente.criar`, `conta.criar`, …).

Código: [`SagaRegistry.kt`](../backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/engine/SagaRegistry.kt), [`SagaEngine.kt`](../backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/engine/SagaEngine.kt).

---

## Slide 3 — Logística (mensageria)

Desenhe três setas:

1. **Gateway → `saga.cmd` → ms-saga**
2. **ms-saga → `ms.*.cmd` → microserviço X**
3. **microserviço X → `orquestrador.reply` → ms-saga**

Envelopes: `MessageEnvelope` (ida) e `ReplyEnvelope` (volta) — [`shared/amqp`](../backend/services/shared/src/main/kotlin/br/ufpr/dac/bantads/shared/amqp/).

Correlação: **`sagaId` = `jobId`**.

---

## Slide 4 — Fluxo R9 em linguagem natural

1. Marcar solicitação aprovada e **copiar dados** para o payload da saga.
2. Listar gerentes ativos; escolher quem tem **menos clientes**.
3. Criar cliente, criar login, abrir conta.
4. Mandar e-mail com senha (sem travar a saga).

Mostre o diagrama do [`README.md`](./README.md#diagrama-do-caminho-feliz-r9).

---

## Slide 5 — Como o payload “cresce”

- Cada reply **adiciona** campos (`cpfGerente`, `numero`, `email`, …).
- O saga **mescla** maps: não precisa reenviar tudo manualmente do Gateway.
- Senha: tratada em **`SagaSecrets`**, injetada só no comando de e-mail — não fica no Redis do estado.

Isso responde “como remodelam e reenviam”: **remodelagem = merge no orquestrador + handlers que leem chaves convencionadas** (ver `ContaCommandHandler`, `extrasFor` no `SagaEngine`).

---

## Slide 6 — Tipos de passo

| Tipo | Uso no R9 |
|------|-----------|
| TRANSACTIONAL | Quase tudo; espera reply |
| FIRE_AND_FORGET | E-mail final |
| LOCAL | Outras sagas (ex. invalidar sessão) |

Timeout 30s por passo; scanner dispara compensação.

---

## Slide 7 — Falha e rollback

- **Não é rollback de banco global** — são **comandos compensadores** na ordem inversa.
- Só etapas em `succeededTipos` são desfeitas.
- **Lock Redis** evita compensação duplicada (timeout + DLQ).
- Caso de negócio: e-mail já existe → marca solicitação **não aprovada** em vez de só desmarcar.

Testes como prova: [`SagaEngineTest.kt`](../backend/services/saga/src/test/kotlin/br/ufpr/dac/bantads/saga/engine/SagaEngineTest.kt).

---

## Slide 8 — Resiliência

- **Saga Inbox** nos MS: reentrega AMQP não duplica efeito.
- **DLQ + retry** nas filas de comando ([`definitions.json`](../db/rabbitmq/definitions.json)).
- Job HTTP consultável: padrão **outbox assíncrono** do ponto de vista do usuário.

---

## Perguntas frequentes (cola)

| Pergunta | Resposta curta |
|----------|----------------|
| Por que RabbitMQ e não REST entre MS? | Desacoplamento, filas duráveis, DLQ, consumo no ritmo de cada serviço. |
| Onde está a “transação distribuída”? | Não existe; existe **consistência saga** com compensações. |
| Quem define a ordem dos passos? | `SagaRegistry` — mudança de processo = mudar a receita + testes. |
| E se o e-mail falhar? | R9 já concluiu; e-mail é best-effort (`FIRE_AND_FORGET`). |
| Como o front sabe que terminou? | Polling em `/jobs/{id}/status`. |

---

## Demonstração ao vivo (opcional)

1. Subir stack (`docker-compose`).
2. Aprovar solicitação como gerente (UI ou `bantads.py` testes).
3. Mostrar logs `saga.cmd`, `cliente cmd`, `orquestrador.reply` nos containers.
4. Arquivo de senha em `outbox/` ou `senhasTeste/senha_recente.txt` se `MAIL_DEV=true`.