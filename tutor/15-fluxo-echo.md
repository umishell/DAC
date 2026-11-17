# 15. Fluxo: saga `echo` (motor assíncrono mínimo)

[← Voltar ao índice](./README.md) · [Tipos assíncronos](./12-saga-tipos-assincronicidade.md) · [Rollback timeout](./03-rollback-e-falhas.md)

A saga **`echo`** não tem rota HTTP no Gateway. Ela existe para **testes** do `SagaEngine` e integração (`SagaIT`, `SagaEngineTest`): validar LOCAL, TRANSACTIONAL, compensação local, timeout e DLQ.

Receita: [`SagaRegistry.echo()`](../backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/engine/SagaRegistry.kt#L15-L32)

---

## 15.1 Etapas

| # | `tipo` | Kind | Fila | Compensação |
|---|--------|------|------|-------------|
| 0 | `echo.setup` | **LOCAL** | — | `echo.undo` (LOCAL) |
| 1 | `echo.ping` | **TRANSACTIONAL** | `ms.auth.cmd` | — |

**Entrada:** mensagem em `saga.cmd` com `tipo: "echo"` (não confundir com `echo.ping`, que é comando da etapa 1).

```json
{
  "sagaId": "echo-ok",
  "tipo": "echo",
  "payload": { "nome": "Ada", "senha": "secret" }
}
```

`senha` vai para secrets e sai do estado persistido, como nas sagas de negócio.

---

## 15.2 Caminho feliz

1. `start` → `echo.setup` (LOCAL, avança sem AMQP).
2. `echo.ping` publicado em `ms.auth.cmd`.
3. Auth (ou test harness) responde `ReplyEnvelope` SUCESSO.
4. `complete` → job `CONCLUIDO`, `resultType: inline`, `resultado: { "mensagem": "pong" }`.

Teste: [`echo success completes job with pong`](../backend/services/saga/src/test/kotlin/br/ufpr/dac/bantads/saga/engine/SagaEngineTest.kt#L32-L53).

---

## 15.3 Timeout + compensação LOCAL

Cenário `echo-to` (consumer morto, `autoReply = false`):

1. Para em `echo.ping` com `waitingTipo` setado.
2. `failTimedOutSteps` → `compensate` com `erro: timeout`.
3. Compensação do passo 0: `echo.undo` (LOCAL) → `compensacoes++` no `SagaState`.
4. Job `FALHA`.

Se **depois** chegar `onDlq` para o mesmo comando, o **guard** impede segunda compensação (contador e job permanecem).

**Por quê importa?** Demonstra que falha assíncrona por **timeout** e por **DLQ** não duplicam rollback.

---

## 15.4 O que o echo **não** testa

- Compensação TRANSACTIONAL em MS (só LOCAL undo).
- `skipIfTrue`, e-mail fire-and-forget, merge grande de payload.
- Para isso, use R9/R13/R15 nos testes [`SagaEngineTest`](../backend/services/saga/src/test/kotlin/br/ufpr/dac/bantads/saga/engine/SagaEngineTest.kt).

---

## 15.5 Como disparar manualmente (dev)

1. Subir Rabbit + ms-saga + ms-auth.
2. Publicar JSON na fila `saga.cmd` (management UI ou script).
3. Poll job se tiver criado job no Redis, ou inspecionar `SagaIT`.

O Gateway **não** expõe `echo`; contratos de produto usam as três sagas com rotas HTTP.

---

## 15.6 Resumo: echo vs sagas de negócio

| | echo | R9 / R13 / R15 |
|---|------|----------------|
| Origem HTTP | não | Gateway 202 |
| Etapas MS | 1 ping | muitas |
| LOCAL | setup + undo | só R15 invalidar sessão |
| Job sucesso | mensagem pong | resource ou inline negócio |
| Uso | testes motor | produção |