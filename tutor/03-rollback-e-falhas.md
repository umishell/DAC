# 3. Rollback, compensação e falhas

[← Voltar ao índice](./README.md) · [Fluxo R9](./02-fluxo-aprovar-cliente.md)

## 3.1 Modelo: Saga coreografada com compensações

Este projeto usa **saga orquestrada** (coordenador central no **ms-saga**), não coreografia pura entre pares.

- **Não há 2PC (two-phase commit)** entre bancos PostgreSQL de cada MS.
- Em falha, aplica-se **compensação**: comandos inversos **declarados na receita** (`compensationTipo` em cada `SagaStep`).
- Nem toda etapa compensa etapas anteriores sem efeito (ex.: `gerente.listar-ativos` é só leitura).

Lógica central: método **`compensate`** em [`SagaEngine.kt`](../backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/engine/SagaEngine.kt#L184-L238).

---

## 3.2 Quando a compensação dispara

| Gatilho | Origem | Erro típico |
|---------|--------|-------------|
| Reply com `status: FALHA` | Qualquer MS transactional | Regra de negócio (ex. e-mail duplicado) |
| Timeout de etapa | `TimeoutScanner` + `failTimedOutSteps` | Consumer lento ou parado |
| Mensagem na DLQ | `DlqListener` | Falha repetida / rejeição AMQP |

Todos chamam `compensate(state, definition, erro, failingTipo)`.

---

## 3.3 Algoritmo de compensação (passo a passo)

1. **`CompensationGuard`** ([`RedisCompensationGuard`](../backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/store/RedisCompensationGuard.kt)): lock Redis por `(sagaId, etapaAtual)` — evita **compensar duas vezes** se chegarem timeout **e** DLQ juntos (testes: `timeout with dead consumer compensates once even after DLQ`).

2. Percorre etapas **já executadas** (`definition.steps.take(etapaAtual)`), em **ordem reversa**.

3. Para cada etapa, só compensa se `step.tipo` está em **`succeededTipos`** (etapas que de fato completaram com sucesso).

4. Publica comando de compensação na fila configurada (mesmo padrão `MessageEnvelope` + `sagaId`).

5. Marca saga `FALHA`, limpa secrets, atualiza job com `erro`.

6. **Extra R9:** envia `email.falha-aprovacao` com `motivo` (fire-and-forget em `ms.email.cmd`).

**Importante:** compensações transactional são **publicadas**; o engine **não espera** reply delas neste fluxo (desfazimento assíncrono). Os MS executam o comando compensador como qualquer outro comando na fila.

---

## 3.4 Mapa de compensações no R9

| Etapa original | Comando compensador | Efeito de negócio |
|----------------|---------------------|-------------------|
| `cliente.marcar-aprovada` | `cliente.desmarcar-aprovada` | Volta solicitação (genérico) |
| `cliente.marcar-aprovada` | `cliente.marcar-nao-aprovada` | **Só** se falha foi e-mail duplicado no auth (ver abaixo) |
| `cliente.criar` | `cliente.remover` | Remove cadastro cliente |
| `auth.criar-cliente` | `auth.remover` | Remove usuário |
| `conta.criar` | `conta.remover` | Remove conta se criada na saga |

Etapas 1–2 (listar gerentes, escolher gerente) **não têm** compensação — não persistiram mudança que precise desfazer.

Etapa 6 (e-mail) é fire-and-forget: em falha **antes** dela, o e-mail de sucesso nem foi enviado.

---

## 3.5 Caso especial: “E-mail já cadastrado” no auth

Constante: [`SagaEngine.EMAIL_DUPLICADO`](../backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/engine/SagaEngine.kt#L497-L503).

Quando `auth.criar-cliente` falha com essa mensagem:

- A solicitação **não** deve voltar a “pendente” genérico.
- `compensationFor` troca compensação da etapa 0 para **`cliente.marcar-nao-aprovada`** em vez de `cliente.desmarcar-aprovada`.
- Compensa **`cliente.criar`** (`cliente.remover`) se já tiver rodado.
- **Não** chama `auth.remover` / `conta.remover` / `conta.criar` — auth/conta nem chegaram a concluir nesse cenário.

Teste que documenta: [`R9 email duplicado marks NAO_APROVADA...`](../backend/services/saga/src/test/kotlin/br/ufpr/dac/bantads/saga/engine/SagaEngineTest.kt#L131-L157).

---

## 3.6 Exemplo: falha na criação da conta (etapa 5)

Suponha que etapas 0–4 concluíram.

1. `conta.criar` retorna FALHA.
2. Compensação (reversa):
   - `auth.remover` (etapa 4 tinha sucesso)
   - `cliente.remover` (etapa 3)
   - `cliente.desmarcar-aprovada` (etapa 0) — ou `marcar-nao-aprovada` se regra de e-mail duplicado
3. Não compensa listar/escolher gerente.
4. `email.falha-aprovacao` notifica o gerente.
5. Job: `FALHA` com mensagem do erro da conta.

---

## 3.7 Timeout

- Ao publicar etapa transactional, grava `timeoutAtEpochMs = now + step-timeout` ([`application.yml`](../backend/services/saga/src/main/resources/application.yml)).
- [`TimeoutScanner`](../backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/engine/TimeoutScanner.kt) periódico chama `failTimedOutSteps`.
- Compensa com `erro = "timeout"` como se a etapa `waitingTipo` tivesse falhado.

Teste R9: [`R9 timeout compensates once and emails falha`](../backend/services/saga/src/test/kotlin/br/ufpr/dac/bantads/saga/engine/SagaEngineTest.kt#L159-L178).

---

## 3.8 Dead Letter Queue (RabbitMQ)

Configuração: [`definitions.json`](../db/rabbitmq/definitions.json) — filas `ms.*.cmd` com DLX `bantads.dlx` → wait (retry TTL) → `*.dlq`.

[`DlqListener`](../backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/amqp/DlqListener.kt) consome DLQs e chama `engine.onDlq` → mesma compensação com motivo `"DLQ"`.

---

## 3.9 O que **não** é rollback automático

- **E-mail já enviado** (`email.senha-cliente`) não tem compensação no registry — em teoria a saga só chega lá se tudo anterior passou; falha no SMTP não reverte conta (fire-and-forget).
- **Múltiplos bancos** não voltam atrás em uma transação única: consistência é **eventual** após compensações.
- **Gateway Redis job** criado antes do saga: em falha de publish, gateway marca FALHA localmente sem saga.

---

## 3.10 Comparar com outra saga (referência rápida)

**`inserir-gerente` (R13):** compensa `gerente.inserir` com `gerente.remover` se auth falhar; etapas de conta podem ser **puladas** se `semConta: true` no payload ([`skipIfTrue`](../backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/engine/SagaEngine.kt#L385-L392)). Fluxo completo: [13-fluxo-inserir-gerente.md](./13-fluxo-inserir-gerente.md).

**`remover-gerente` (R15):** inclui etapa **LOCAL** `saga.invalidar-sessao` e compensações de transferência de contas (`conta.reverter-transferencia-gerentes`). Fluxo completo: [14-fluxo-remover-gerente.md](./14-fluxo-remover-gerente.md).

**Matriz de modos assíncronos** (timeout, fire-and-forget, echo): [12-saga-tipos-assincronicidade.md](./12-saga-tipos-assincronicidade.md).

Mesmo motor, receitas diferentes em [`SagaRegistry.kt`](../backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/engine/SagaRegistry.kt).