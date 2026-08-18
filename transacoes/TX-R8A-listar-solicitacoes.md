# TX-R8A — Listar solicitações (R8)

**ID:** `TX-R8A`  
**HTTPie:** [`../httpie/TX-R8A-listar-solicitacoes.md`](../httpie/TX-R8A-listar-solicitacoes.md)

Home do gerente: todas as solicitações. Botões Aprovar/Recusar **só** se o item tiver `_links.aprovacao` / `rejeicao`.

## Diagrama de sequência

```mermaid
sequenceDiagram
    actor Front
    participant GW as Gateway
    participant Cli as MS Cliente
    participant PG as Postgres solicitacao
    Front->>GW: GET /solicitacoes?status opcional
    GW->>Cli: GET + X-User-Tipo GERENTE
    Cli->>PG: listByStatus
    Cli-->>GW: lista HAL
    GW-->>Front: 200; PENDENTE tem aprovacao/rejeicao
```

## O que acontece

### 1. Front

Após login GERENTE, a tabela itera `solicitacoes`. Não hardcoda botões: lê HATEOAS ([agente frontend](../.cursor/agents/frontend-angular.md)).

### 2. Gateway

ACL `gerente`. Proxy [`GET /solicitacoes`](../backend/gateway/src/routes/proxy.ts). `applyListSelf` em [`hateoas.ts`](../backend/gateway/src/http/hateoas.ts) coloca `_links.self` da lista (inclui query `status=`).

### 3. MS + Postgres

[`SolicitacaoController.listar`](../backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/solicitacao/SolicitacaoController.kt) exige gerente → [`listar`](../backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/solicitacao/SolicitacaoService.kt) na tabela `solicitacao`. [`ClienteAssembler`](../backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/hateoas/ClienteAssembler.kt) só adiciona rels de ação se `PENDENTE`.

### 4. Reply

O front segue `aprovacao` → [TX-R9](./TX-R9-aprovar-cliente.md) ou `rejeicao` → [TX-R10](./TX-R10-rejeitar-cliente.md).

## Arquivos-chave

- [`SolicitacaoController.kt`](../backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/solicitacao/SolicitacaoController.kt)  
- [`ClienteAssembler.kt`](../backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/hateoas/ClienteAssembler.kt)
