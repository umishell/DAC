# 2. Fluxo completo: `aprovar-cliente` (R9)

[← Voltar ao índice](./README.md) · [Rollback e falhas](./03-rollback-e-falhas.md)

## 2.1 Gatilho HTTP

**Rota:** `POST /solicitacoes/:cpf/aprovacao`  
**Arquivo:** [`backend/gateway/src/routes/aprovacao.ts`](../backend/gateway/src/routes/aprovacao.ts)

1. Gera `jobId` (UUID) = `sagaId`.
2. Salva job `{ jobId, status: PENDENTE, cpf: usuário logado }` no Redis.
3. Publica em `saga.cmd`:

```json
{
  "sagaId": "<jobId>",
  "tipo": "aprovar-cliente",
  "timestamp": "...",
  "payload": {
    "cpf": "<cpf do solicitante>",
    "solicitadoPorCpf": "<cpf do gerente>"
  }
}
```

4. Responde **202 Accepted** com `Location: /jobs/{jobId}/status`.

Se o publish falhar, o job vira `FALHA` com erro “Falha ao publicar SAGA”.

---

## 2.2 Receita registrada (7 etapas)

**Arquivo:** [`SagaRegistry.aprovarCliente()`](../backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/engine/SagaRegistry.kt#L34-L87)

| # | `tipo` do comando | MS / fila | Kind | Compensação (se houver) |
|---|-------------------|-----------|------|-------------------------|
| 0 | `cliente.marcar-aprovada` | cliente / `ms.cliente.cmd` | TRANSACTIONAL | `cliente.desmarcar-aprovada` |
| 1 | `gerente.listar-ativos` | gerente / `ms.gerente.cmd` | TRANSACTIONAL | — |
| 2 | `conta.escolher-gerente-menos-clientes` | conta / `ms.conta.cmd` | TRANSACTIONAL | — |
| 3 | `cliente.criar` | cliente / `ms.cliente.cmd` | TRANSACTIONAL | `cliente.remover` |
| 4 | `auth.criar-cliente` | auth / `ms.auth.cmd` | TRANSACTIONAL | `auth.remover` |
| 5 | `conta.criar` | conta / `ms.conta.cmd` | TRANSACTIONAL | `conta.remover` |
| 6 | `email.senha-cliente` | email / `ms.email.cmd` | FIRE_AND_FORGET | — |

**Por que essa ordem?**

1. Marcar solicitação como aprovada **antes** de criar entidades definitivas (estado intermediário visível no domínio cliente).
2. Descobrir gerente e conta **depende** de listas/quantidades em outros serviços (gerente + conta).
3. Criar **cliente** (cadastro) com dados da solicitação já no payload.
4. Criar **credencial** no auth (e-mail da solicitação); senha gerada volta na reply.
5. Abrir **conta bancária** ligada ao cliente e ao gerente escolhido.
6. E-mail com senha — melhor esforço, sem bloquear conclusão da saga.

---

## 2.3 O que o `SagaEngine` faz em cada transição

**Arquivo:** [`SagaEngine.kt`](../backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/engine/SagaEngine.kt)

### `start(envelope)` (mensagem `aprovar-cliente`)

- Valida `sagaId`; busca definição no registry.
- Cria `SagaState` (`EM_ANDAMENTO`, `etapaAtual = 0`, payload inicial).
- Chama `advance`.

### `advance(state, definition)`

- Se acabaram os passos → `complete`.
- Se `skipIfTrue` no payload → pula etapa (não usado no R9).
- `TRANSACTIONAL`: `publish` + grava `waitingTipo` e deadline de timeout.
- Ao receber reply em `onReply`:
  - **FALHA** → `compensate` (ver doc 03).
  - **SUCESSO** → `succeededTipos += reply.tipo`; **`payload = payload + reply.payload`** (merge); `etapaAtual++`; `advance` de novo.

**Remodelagem do payload:** cada microserviço devolve apenas **campos novos**; o orquestrador **não descarta** o que já tinha. Ex.: após marcar aprovada, o cliente devolve nome, e-mail, endereço, salário — necessários para `auth.criar-cliente` e e-mail depois.

### Enriquecimento antes de publicar (`extrasFor`)

O saga **injeta** campos que o payload ainda não tem, sem o MS precisar conhecer toda a história:

| Ao publicar | Campo extra | Motivo |
|-------------|-------------|--------|
| `email.senha-cliente` | `senha` | Vem de `SagaSecrets` (Redis/memória), nunca fica no payload persistido |
| `conta.criar` | usa `cpf` e `cpfGerente` já no payload | Handler conta lê [`ContaCommandHandler`](../backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/saga/ContaCommandHandler.kt) |

Senha: após `auth.criar-cliente` com sucesso, `capturePassword` guarda em secrets; removida do payload em sanitização [`withoutPassword()`](../backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/engine/PayloadSanitize.kt).

---

## 2.4 Etapa a etapa: quem faz o quê

### Etapa 0 — `cliente.marcar-aprovada`

- **Handler:** [`ClienteCommandHandler`](../backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/saga/ClienteCommandHandler.kt) → `solicitacoes.marcarAprovada(cpf)`.
- **Reply payload:** dados completos da solicitação (`nome`, `email`, `telefone`, `salario`, `endereco`, …).
- **Por quê:** congela o snapshot usado nas etapas seguintes.

### Etapa 1 — `gerente.listar-ativos`

- **Handler:** [`GerenteCommandHandler`](../backend/services/gerente/src/main/kotlin/br/ufpr/dac/bantads/gerente/saga/GerenteCommandHandler.kt).
- **Reply payload:** `{ "gerentes": [ { cpf, nome, ... }, ... ] }`.
- **Por quê:** política de balanceamento precisa da lista de CPFs ativos.

### Etapa 2 — `conta.escolher-gerente-menos-clientes`

- **Handler:** [`ContaCommandHandler`](../backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/saga/ContaCommandHandler.kt) → `commands.escolherGerenteMenosClientes(cpfs)`.
- **Reply payload:** `{ "cpfGerente": "..." }`.
- **Por quê:** regra de negócio R9 — gerente com menos clientes recebe o novo cliente.

### Etapa 3 — `cliente.criar`

- Cria registro de **cliente** a partir da solicitação aprovada.
- **Compensação futura:** `cliente.remover` se algo depois falhar.

### Etapa 4 — `auth.criar-cliente`

- **Handler:** [`AuthCommandHandler.criarCliente`](../backend/services/auth/src/main/kotlin/br/ufpr/dac/bantads/auth/saga/AuthCommandHandler.kt) — usa `cpf` e `email` do payload.
- Gera senha; reply pode conter `senha` (saga guarda em secrets, não no estado durável).
- Falha comum: **“E-mail já cadastrado”** → caso especial de compensação (doc 03).

### Etapa 5 — `conta.criar`

- Cria conta para `cpf` + `cpfGerente`.
- **Reply:** `numero`, `cpfCliente`.
- **Compensação:** `conta.remover` se só foi criada na saga (`removerSeSoCriado`).

### Etapa 6 — `email.senha-cliente`

- **Listener:** [`EmailCommandListener`](../backend/services/email/src/main/kotlin/br/ufpr/dac/bantads/email/amqp/EmailCommandListener.kt) — **não** envia reply.
- Saga marca etapa como sucesso localmente e **conclui**.

---

## 2.5 Conclusão da saga

[`SagaEngine.complete`](../backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/engine/SagaEngine.kt) para `APROVAR_CLIENTE`:

- Job → `CONCLUIDO`, `resultType: resource`, `dominio: clientes`, `resourceId: cpf`.
- `cache.deleteCliente(cpf)` — invalida cache HTTP do gateway para o novo cliente.

Ordem exata de comandos publicados no caminho feliz (teste automatizado):  
[`SagaEngineTest` — `R9 success completes resource job...`](../backend/services/saga/src/test/kotlin/br/ufpr/dac/bantads/saga/engine/SagaEngineTest.kt#L88-L129).

---

## 2.6 Acompanhamento pelo cliente da API

1. `POST /solicitacoes/{cpf}/aprovacao` → `jobId`
2. Poll `GET /jobs/{jobId}/status` até `CONCLUIDO` ou `FALHA`
3. Se concluído com `resultType: resource`, o HATEOAS pode apontar para o cliente criado (gateway).

Implementação status: [`jobs.ts`](../backend/gateway/src/routes/jobs.ts).