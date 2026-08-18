# BANTADS — Plano de Implementação do Backend

Documento para ser usado como **prompt de implementação**. Destinatário: Grok 4.6 (ou agente equivalente) implementando **somente o backend** do BANTADS (DS152 / DAC / UFPR).

Fontes canônicas (nesta ordem de precedência):

1. `docs/swagger_bantads.md` — contrato REST do API Gateway (OpenAPI 3.0.3, BANTADS API 2.0.0)
2. `docs/bantads.md` — enunciado (requisitos R1–R16, SAGAs, CQRS, seed, infra)
3. Este plano — decomposição em fases, decisões de engenharia e critérios de aceite

Se houver conflito entre este plano e o Swagger/enunciado, **Swagger + enunciado vencem**. Este plano não inventa endpoints, campos ou regras de negócio.

---

## 0. Prompt de sistema para o agente implementador

Você é um engenheiro sênior de backend. Sua missão é implementar o backend completo do BANTADS de forma **organizada, Clean Code, eficiente e moderna**, de modo que:

- o front-end e a aplicação de teste do professor falem **somente** com o API Gateway;
- todos os requisitos R1–R16 existam e estejam corretos;
- os padrões obrigatórios (Gateway, Database-per-Service / schema-per-service, CQRS, Event Sourcing, SAGA orquestrada, API Composition, HATEOAS Richardson nível 3) estejam realmente implementados, não simulados;
- a aplicação de teste do professor (pytest contra o Gateway, conforme enunciado) e a suíte de contrato BANTADS passem (ver seção 2).

### 0.1 Como trabalhar

- Implemente **uma fase por vez**, na ordem deste documento. Não pule fases. Não misture SAGA, CQRS e Gateway “tudo de uma vez”.
- Ao terminar uma fase, deixe o sistema **compilando, subindo no Docker e com testes daquela fase verdes** antes de avançar.
- Prefira código pequeno, explícito, tipado e testável. Evite magia, god-classes, duplicação de DTOs e atalhos que quebrem o contrato.
- Não invente campos JSON, não use `Double`/`Float` para dinheiro, não exponha entidades JPA, não deixe o front acessar microsserviços.
- Não commite segredos (JWT secret, senha de app Gmail, senhas de banco). Use variáveis de ambiente e `.env.example`.
- Nomes em português apenas onde o domínio exige (`solicitacao`, `gerente`, `saque`). Código, pacotes e identificadores técnicos em inglês (`service`, `repository`, `controller`). JSON da API segue o Swagger (português do domínio: `cpf`, `saldo`, `motivo`).
- Cada MS Spring: `Controller → Service → Repository → DB`. Controllers magros. Regras no service. Persistência no repository.
- Cada MS Fastify/Kotlin deve ter `/health` retornando `{ "status": "UP" }` com HTTP 200.
- Compilar **toda a frota** (MSs + gateway + frontend) **um app por vez** para poupar RAM: `compile-services.ps1` (Windows) ou `compile-services.sh` (Git Bash / WSL) na raiz do repositório. Use esses scripts sempre que for buildar todos de uma vez; nunca `./gradlew bootJar` / `npm run build` / `docker compose build` em paralelo na frota. Um módulo isolado pode continuar no Gradle/npm direto. Imagens Docker: `start.sh` constrói **um serviço por vez**. Flag `--test` roda os testes de cada módulo na mesma ordem sequencial.

### 0.2 Stack obrigatória (não negociar)

| Camada | Tecnologia |
|---|---|
| API Gateway | Node.js + **Fastify** + TypeScript |
| Microsserviços | **Kotlin** + Spring Boot 3.4+ + Java 21 |
| Persistência SQL | Spring Data JPA + Flyway + PostgreSQL 16 |
| Persistência Auth | Spring Data MongoDB + MongoDB 7 |
| Cache / sessão / jobs / SAGA state | Redis 7 |
| Mensageria | RabbitMQ 3 (management) |
| HATEOAS | Spring HATEOAS nos MSs; Gateway **reescreve** `href` |
| Senhas | **Argon2id** (nunca bcrypt/plain) |
| AuthN | JWT assinado **somente no Gateway** (`jwt.sign`), header `x-access-token` |
| Testes | JUnit 5 + MockK + Testcontainers (Kotlin); Vitest ou node:test (Gateway); contrato HTTP com pytest no estilo do professor |
| Execução | Docker + docker-compose; um contêiner por MS, um por banco, um RabbitMQ, um Redis |
| Script | `start.sh` (Git Bash / WSL) que faz `docker compose build` um serviço por vez e `up`; `compile-services.sh` / `.ps1` para compilação sequencial da frota |

Kotlin moderno: Gradle Kotlin DSL, `data class` para DTOs, `value class` só se não atrapalhar Jackson, coroutines **não** são necessárias (use threads do Web/AMQP). Jackson com `WRITE_BIGDECIMAL_AS_PLAIN` e serialização monetária como **string**.

### 0.3 O que NÃO fazer

- Não usar Local Storage / json-server como banco.
- Não deixar MS acessar schema/banco de outro MS.
- Não validar saldo no read model.
- Não fazer SAGA coreografada. Orquestrador central, filas `*.cmd` + `orquestrador.reply`.
- Não devolver saldo novo em depósito/saque/transferência.
- Não cachear dados do MS Conta.
- Não gravar senha em claro no Redis, logs ou bancos (exceto o instante do payload Auth→Orquestrador e Orquestrador→Email na SAGA R9).
- Não expor portas internas dos MSs no host (somente Gateway + consoles de infra na defesa).

---

## 1. Visão do sistema (mapa mental)

```
[Front Angular] [pytest professor]
        │  HTTP REST + x-access-token
        ▼
 [API Gateway Fastify :3000]
   │ REST (consultas, writes síncronos, composition)
   │ Redis (sessão, cache cadastral, jobs, tokens revogados)
   │ RabbitMQ saga.cmd (R9, R13, R15) e job R16
   ├──► MS Auth        (MongoDB)
   ├──► MS Cliente     (Postgres schema cliente)
   ├──► MS Gerente     (Postgres schema gerente)
   ├──► MS Conta       (Postgres schemas conta_command + conta_query)
   │         command ──ms.conta.events──► query
   ├──► MS Saga (só AMQP + Redis; HTTP só /health e /internal)
   └──► MS Email (só AMQP; SMTP Gmail; HTTP só /health)
```

Perfis: `CLIENTE` e `GERENTE`. Não existe ADMIN separado — gerentes fazem o CRUD de gerentes.

Identidade pública: **CPF (11 dígitos)**. Número de conta: **string de 4 dígitos**, pode ter zero à esquerda (`"0950"`). Contas novas: número **aleatório** único (o seed usa os 4 primeiros dígitos do CPF só por coincidência).

---

## 2. Testes e critérios de aceite

Implementar o backend **100% fiel ao Swagger 2.0.0 + enunciado**. O contrato da API é `docs/swagger_bantads.md`; não adicionar rotas, campos ou headers fora desse contrato.

Construir também `backend/contract-tests/` (pytest) no estilo da aplicação de teste do professor: `pytest -s -v`, `.env` com `URL`, cache/token em arquivo, reboot primeiro, polling de consistência eventual.

### 2.1 Ritual do testador (replicar)

1. `.env`: `URL` **sem barra final** (ex.: `http://localhost:3000`).
2. Primeira chamada: **`POST /reboot`** para estado conhecido do seed.
3. Testes **sequenciais e stateful**: compartilham token em arquivo e cache JSON.
4. Sem token → **401**. Token inválido → **401**. Login inválido → **401**.
5. Duplicidade de cadastro → **409**. Recurso inexistente → **404**.
6. Requisição malformada → **400**; regra de negócio síncrona → **422**; conflito de estado → **409**.
7. Após escrita CQRS (R4/R5/R6), saldo/extrato pode demorar instantes. Implemente projeção rápida; nos testes internos, retry com 2s + até 3 tentativas com intervalo de 5s.
8. Autocadastro (R1) não gera senha imediata. Fluxo de teste: autocadastro → login gerente seed → aprovar (R9) → poll job → senha via e-mail (`MAIL_DEV` / outbox).

Autenticação conforme Swagger: header **`x-access-token`**; login com `{ email, senha }`; resposta `{ auth, token, tipo, usuario }`.

### 2.2 Matriz de aceite BANTADS

Construa `backend/contract-tests/` (pytest) espelhando o estilo do professor, contra o Gateway, nesta ordem. Cada item é critério de Done da fase correspondente.

| ID | Fluxo | Asserts mínimos |
|---|---|---|
| T00 | `POST /reboot` | 200, `{ status: "ok", clientes: 5, gerentes: 4, contas: 5 }` |
| T00b | `GET /health` | 200, `{ status: "UP" }` |
| T01 | `POST /solicitacoes` público | 201, `Location: /solicitacoes/{cpf}`, body com `status=PENDENTE`, `_links.self/aprovacao/rejeicao` |
| T01d | mesmo CPF ou e-mail de outra solicitação | 409 |
| T02a | `GET /clientes/{cpf}` sem token | 401 `{ auth: false, message: "Token não fornecido." }` |
| T02b | token inválido | 401 `{ auth: false, message: "Falha ao autenticar o token." }` |
| T02c | login senha/e-mail errados ou inativo | 401 `{ auth: false, message: "Login inválido!" }` |
| T02d | login seed `cli1@bantads.com.br` / `tads` | 200, `tipo=CLIENTE`, `usuario.cpf=12912861012` |
| T02e | login `ger1@bantads.com.br` / `tads` | 200, `tipo=GERENTE` |
| T02f | logout | 204; reuse do token → 401 |
| T03 | cliente logado `GET /clientes/{cpf}/conta` | 200, `numero=1291`, `saldo="800.00"` (seed), links de operação |
| T03p | cliente A acessa conta de B | 403 |
| T04 | `POST /contas/1291/deposito` `{ valor: "10.00" }` | 201, **sem saldo**; poll conta até saldo `"810.00"` |
| T05 | saque maior que saldo | 422; saque válido 201 e saldo desce |
| T06 | transferência para `"0950"` | 201 com `destino`; origem desce, destino sobe; própria conta → 422; destino inexistente → 422 |
| T07 | `GET .../extrato` sem datas | 200, últimos 30 dias, `saldoAbertura` + `movimentacoes`; intervalo > 365d → 422 |
| T08 | gerente `GET /solicitacoes` | 200, lista com pendente do T01 e links de ação só em `PENDENTE` |
| T09 | `POST /solicitacoes/{cpf}/aprovacao` | 202 + `Location: /jobs/{id}/status`; poll até `CONCLUIDO` `resultType=resource` `dominio=clientes`; `GET /clientes/{cpf}` 200; login do novo cliente funciona |
| T09f | aprovar de novo / CPF inexistente | 202 depois job `FALHA` (Gateway **não** pré-valida estado) |
| T10 | rejeição síncrona | 200, `NAO_APROVADA`, `motivo` preenchido; 409 se não `PENDENTE` |
| T11 | `GET /clientes?busca=Cat` | 200, composition, ordenado pt-BR, itens com `saldo` |
| T12 | `GET /gerentes` | 200, só ativos, `quantidadeClientes` preenchida, ordem pt-BR |
| T13 | `POST /gerentes` | 202; job `resource` `dominio=gerentes`; GET gerente; e-mail duplicado → job `FALHA` |
| T14 | `PUT /gerentes/{cpf}` só nome/telefone | 200; e-mail/CPF diferentes no body → 400 |
| T15 | `DELETE /gerentes/{próprio cpf}` | 403 **síncrono**; último ativo → 202 + job `FALHA`; sucesso → job `inline` + GET result |
| T16 | `GET /relatorios/clientes` | 202; job inline; result com 5 linhas seed, ordem pt-BR |
| T$ | dinheiro | todo valor JSON casa com `^\d+\.\d{2}$` |
| T# | HATEOAS | todo DTO de recurso/lista tem `_links`; login/jobs/health/reboot **não** têm |

Seed que os testes vão cravar (seção 4 do enunciado) — **dados exatos**:

**Clientes / Auth (senha `tads`):**

| cpf | nome | email | salário | conta | saldo | gerente | criação |
|---|---|---|---|---|---|---|---|
| 12912861012 | Catharyna | cli1@bantads.com.br | 10000.00 | 1291 | 800.00 | Geniéve | 2000-01-01 |
| 09506382000 | Cleuddônio | cli2@bantads.com.br | 20000.00 | 0950 | 10000.00 | Godophredo | 1990-10-10 |
| 85733854057 | Catianna | cli3@bantads.com.br | 3000.00 | 8573 | 200.00 | Gyândula | 2012-12-12 |
| 58872160006 | Cutardo | cli4@bantads.com.br | 500.00 | 5887 | 150000.00 | Geniéve | 2022-02-22 |
| 76179646090 | Coândrya | cli5@bantads.com.br | 1500.00 | 7617 | 1500.00 | Godophredo | 2025-01-01 |

**Gerentes / Auth (senha `tads`):**

| cpf | nome | email |
|---|---|---|
| 98574307084 | Geniéve | ger1@bantads.com.br |
| 64065268052 | Godophredo | ger2@bantads.com.br |
| 23862179060 | Gyândula | ger3@bantads.com.br |
| 40501740066 | Gadamântio | ger4@bantads.com.br |

Contagem de clientes no seed: Geniéve=2, Godophredo=2, Gyândula=1, Gadamântio=0.

Movimentações históricas (devem existir no event store **e** no histórico query; replay do command **reproduz exatamente** os saldos acima):

Catharyna 1291 (Criado saldo 0 → 800):

- 2020-01-01T10:00:00 Depósito 1000.00
- 2020-01-01T11:00:00 Depósito 900.00
- 2020-01-01T12:00:00 Saque 550.00
- 2020-01-01T13:00:00 Saque 350.00
- 2020-01-10T15:00:00 Depósito 2000.00
- 2020-01-15T08:00:00 Saque 500.00
- 2020-01-20T12:00:00 TransferênciaOrigem → Cleuddônio 1700.00

Cleuddônio 0950 (inclui TransferênciaDestino 1700.00 em 2020-01-20T12:00:00 + depósitos/saques 2025 → 10000.00):

- 2025-01-01T12:00:00 Depósito 1000.00
- 2025-01-02T10:00:00 Depósito 5000.00
- 2025-01-10T10:00:00 Saque 200.00
- 2025-02-05T10:00:00 Depósito 7000.00
- 2025-03-06T11:00:00 Saque 4500.00

Catianna 8573: 2025-05-05T10:00:00 Dep 1000.00; 2025-05-06T10:00:00 Saque 800.00 → 200.00

Cutardo 5887: 2025-06-01T10:00:00 Dep 150000.00 → 150000.00

Coândrya 7617: 2025-07-01T10:00:00 Dep 1500.00 → 1500.00

Endereços e telefones do seed: a equipe escolhe, mas **fixos e estáveis** no reboot (mesmo valor sempre). Use Curitiba/PR para todos, CEP 8 dígitos, telefone só dígitos.

---

## 3. Convenções transversais (aplicar em todas as fases)

### 3.1 Dinheiro

- JSON (Swagger `Dinheiro`): string `^\d+\.\d{2}$` — `"1500.00"`. Nunca number.
- PostgreSQL: `NUMERIC(19,4)`.
- Payload de evento: string com 2 casas.
- Kotlin: `BigDecimal` + scale 2 `HALF_EVEN` na borda da API; internamente 4 casas ok. Nunca `Double`.
- Helper único `Money` no módulo compartilhado: `parse`, `format`, `add`, `subtract`, `isPositive`, `gte`.
- Saque/transferência exigem `valor > 0`. Zero ou negativo → 400.

### 3.2 Datas

- JSON data/hora: ISO 8601 **sem offset** `2026-04-30T10:00:00` (timezone de negócio America/Sao_Paulo, gravar local naive ou gravar timestamptz e formatar sem offset).
- Query de data: `YYYY-MM-DD`.
- `dataCriacao` da conta: `date` (`2000-01-01`).

### 3.3 CPF e conta

- CPF path/body: `^\d{11}$`. Com pontuação → 400.
- Conta path: `^\d{4}$`. Sempre 4 chars, pad left com zero na geração.

### 3.4 Erros

Corpo padrão (exceto auth 401):

```json
{ "status": 422, "erro": "Unprocessable Entity", "mensagem": "Saldo insuficiente para a operação" }
```

401 de token/login: `{ "auth": false, "message": "..." }` — **exatamente** as três mensagens do Swagger.

| Situação | HTTP |
|---|---|
| JSON inválido, campo ausente, CPF/conta malformados, valor não casa com Dinheiro | 400 |
| Sem token / token ruim / sessão morta / login inválido | 401 |
| Perfil errado, posse de outro usuário, gerente remove a si mesmo | 403 |
| Recurso inexistente, job expirado | 404 |
| Conflito de estado (CPF já tem solicitação, rejeitar não-PENDENTE) | 409 |
| Regra de negócio síncrona (saldo, intervalo extrato, transferência inválida) | 422 |

Falhas **dentro** de SAGA não viram 4xx do POST inicial: sempre **202** + job `FALHA` + `erro`.

### 3.5 HATEOAS

- MSs geram `_links` com URLs **internas**.
- Gateway reescreve host/porta para o Gateway público (`http://localhost:3000` em dev; `GATEWAY_PUBLIC_URL` em prod).
- Estilo HAL: `{ "rel": { "href": "..." } }`.
- Links **dependem de estado + perfil**. Não despejar todos os rels sempre.
- Sem `_links`: login, 202/job status/result, `/health`, `/reboot`.

Matriz de links (Gateway, após rewrite):

**Solicitação** (`GERENTE`):

- sempre `self` → `/solicitacoes/{cpf}`
- se `PENDENTE`: `aprovacao`, `rejeicao`

**Lista solicitações**: `self` → `/solicitacoes`

**Cliente**: `self` → `/clientes/{cpf}`; `conta` → `/clientes/{cpf}/conta`

**ClienteResumo (R11)**: `self` → `/clientes/{cpf}`; `conta` → `/clientes/{cpf}/conta`

**Conta para o CLIENTE dono**: `self` `/contas/{n}`, `cliente`, `deposito`, `saque`, `transferencia`, `extrato`

**Conta para GERENTE**: `self`, `cliente` (sem rels de escrita)

**OperacaoRealizada**: `conta`, `extrato`

**Extrato**: `self`, `conta`

**Gerente**: `self`; se ativo: `atualizacao` (PUT), `remocao` (DELETE). Não incluir `remocao` se o CPF do gerente autenticado = recurso (HATEOAS dirige a UI: não mostrar botão de se auto-remover).

**Lista gerentes**: `self` `/gerentes`; `criacao` POST `/gerentes`

**Listas** (`clientes`, `solicitacoes`): `self` com a querystring usada.

### 3.6 Ordenação

Listas por nome: collation **pt-BR**, case-insensitive, acentos = letra base.

- Postgres: `ORDER BY nome COLLATE "pt-BR-x-icu"` (imagem deve ter locale ICU).
- Gateway composition: `Intl.Collator('pt-BR', { sensitivity: 'base' })`.
- Nunca `ORDER BY nome` ASCII-only.

### 3.7 Identidade interna

Após auth, Gateway injeta:

- `X-User-CPF`
- `X-User-Tipo` = `CLIENTE` | `GERENTE`

MSs **não** revalidam JWT. MSs **exigem** esses headers em rotas protegidas e validam posse (ex.: conta.cpfCliente == X-User-CPF para R4/R5/R6). Rede Docker interna; não publicar portas dos MSs.

### 3.8 Envelope RabbitMQ

Comando:

```json
{
  "sagaId": "uuid-ou-ausente",
  "tipo": "cliente.marcar-aprovada",
  "timestamp": "2026-04-30T10:00:00",
  "payload": {}
}
```

Reply:

```json
{
  "sagaId": "uuid",
  "tipo": "cliente.marcar-aprovada",
  "timestamp": "2026-04-30T10:00:00",
  "status": "SUCESSO",
  "erro": null,
  "payload": {}
}
```

- Fora de SAGA: omitir `sagaId`.
- Fire-and-forget (e-mail): sem reply.
- Consumidores `*.cmd`: **idempotentes** na chave `(sagaId, tipo)` — tabela `saga_inbox` por MS.
- Default exchange, filas nomeadas.

Filas:

| Fila | Produtor | Consumidor |
|---|---|---|
| saga.cmd | Gateway | Orquestrador |
| ms.cliente.cmd | Orquestrador | MS Cliente |
| ms.conta.cmd | Orquestrador | MS Conta |
| ms.gerente.cmd | Orquestrador | MS Gerente |
| ms.auth.cmd | Orquestrador | MS Auth |
| ms.email.cmd | Orquestrador / MSs | MS Email |
| orquestrador.reply | MSs | Orquestrador |
| ms.conta.events | Conta command | Conta query |

DLQ (retry 3× / 5s, depois DLQ): `ms.cliente.cmd.dlq`, `ms.conta.cmd.dlq`, `ms.gerente.cmd.dlq`, `ms.auth.cmd.dlq`, `ms.conta.events.dlq`.

- DLQ de `*.cmd`: Orquestrador consome e dispara compensação **idempotente por passo**.
- Timeout de passo transacional: **30s**. Passo de e-mail: sem timeout, não-crítico.
- Um passo pode falhar duas vezes (DLQ ~15–20s **e** timeout 30s). Compensar **uma** vez (`sagaId` + `etapa`).
- DLQ de `ms.conta.events`: **não** compensar; reprocessamento **manual** no console (defesa). Projeção idempotente.

### 3.9 Redis

| Chave | TTL | Uso |
|---|---|---|
| `sessao:{jti}` | 30 min sliding | `{ cpf, tipo, expJwt }` |
| `sessao:cpf:{cpf}` | 30 min sliding | jti atual |
| `revogado:{jti}` | restante do JWT | logout |
| `cache:cliente:{cpf}` | 5 min | GET cliente; DEL no R9 |
| `cache:gerente:{cpf}` | 5 min | GET gerente; DEL em R13/R14/R15 |
| `job:{jobId}` | 5 min | jobs 202 |
| `saga:{sagaId}` | 1 h | estado da orquestração |

Política Redis: `noeviction`. Não cachear saldo/extrato/quantidadeClientes.

JWT: vida absoluta **8h** (`exp`). `jti` = UUID. Payload: `{ cpf, tipo, jti }`. SECRET só no Gateway. Sliding window **não** renova `exp`.

### 3.10 Jobs

`jobId` das SAGAs = `sagaId` (UUID gerado no Gateway).

Estados: `PENDENTE` | `CONCLUIDO` | `FALHA`.

| Operação | resultType | Pós-sucesso |
|---|---|---|
| R9 aprovação | resource | `dominio=clientes`, `resourceId=cpf` |
| R13 inserção gerente | resource | `dominio=gerentes`, `resourceId=cpf` |
| R15 remoção | inline | `GET /jobs/{id}/result` → `{ mensagem }` |
| R16 relatório | inline | `{ clientes: [...] }` |

`GET /jobs/{id}/result`: 409 se não `CONCLUIDO` ou não `inline`; 404 se expirado.

Polling: o testador vai bater status em loop. Status deve atualizar em segundos (passos de SAGA são locais).

---

## 4. Estrutura do repositório

```
DAC/
  backend_plan.md
  docs/
  docker-compose.yml
  start.sh
  compile-services.sh      # frota um a um (Git Bash / WSL)
  compile-services.ps1     # frota um a um (Windows)
  .env.example
  gateway/                 # Node Fastify TS
  services/
    shared/                # Kotlin lib: Money, envelopes, erros
    auth/
    cliente/
    gerente/
    conta/
    saga/
    email/
  db/
    postgres/init/         # cria schemas + extensões
    mongo/                 # não commitar senhas em claro
    seeds/                 # SQL + JS mongo, usados pelo reboot
  backend/contract-tests/  # pytest BANTADS
```

Um Gradle multi-module:

```
services/settings.gradle.kts
  include("shared", "auth", "cliente", "gerente", "conta", "saga", "email")
```

Cada MS: Dockerfile próprio, `./gradlew :conta:bootJar`. Imagens `eclipse-temurin:21-jre-alpine` (ou distroless). Instalar `curl` para healthcheck.

Gateway: multi-stage `node:22-alpine` → `node dist/index.js`. `wget` para healthcheck.

---

## 5. Portas, rede, memória

Rede: `bantads`. Publicar no host:

- Gateway `3000`
- Postgres `5432` (DBeaver na defesa)
- Mongo `27017`
- Redis `6379`
- RabbitMQ `5672` + management `15672`

Não publicar 808x dos MSs.

`mem_limit` (coluna 8 GB do enunciado; soma com folga para SO/IDE/Firefox):

| Serviço | mem_limit | Extra |
|---|---|---|
| gateway | 256m | `NODE_OPTIONS=--max-old-space-size=192` |
| cada MS Java | 512m | `JAVA_TOOL_OPTIONS=-XX:MaxRAMPercentage=60 -XX:+UseSerialGC` |
| postgres | 384m | `shared_buffers=128MB` |
| mongo | 384m | `--wiredTigerCacheSizeGB 0.25` |
| redis | 128m | `--maxmemory 100mb --maxmemory-policy noeviction` |
| rabbitmq | 512m | `RABBITMQ_VM_MEMORY_HIGH_WATERMARK=0.6` |

MS Conta = **um** JVM com dois datasources (command + query) e consumidor/produtor Rabbit internos. Pacotes `command` e `query` isolados. Motivo: 7 JVMs estouram máquina de 8 GB na defesa.

Compilação local da frota também estoura RAM se for em paralelo. Sempre `compile-services.ps1` / `compile-services.sh` (seção 0.1).

`depends_on` com `condition: service_healthy`. Spring Boot `start_period: 40s`.

---

## FASE 0 — Bootstrap do monorepo e qualidade

**Objetivo:** esqueleto compilável, lint, Dockerfiles vazios mas válidos, CI local.

Passos:

1. Criar Gradle wrapper, Java 21, Kotlin 2.x, Spring Boot 3.4 BOM.
2. Módulo `shared`: ainda sem lógica, só `Money` + testes unitários de parse/format.
3. Cada MS: `Application.kt` + `GET /health` + `application.yml` com `server.port`.
4. Gateway: Fastify hello + `GET /health`.
5. `.editorconfig`, ktlint (Gradle) / prettier (Gateway).
6. `.env.example` com: `JWT_SECRET`, `GMAIL_USER`, `GMAIL_APP_PASSWORD`, `GATEWAY_PUBLIC_URL`, URLs internas, `POSTGRES_*`, `MONGO_*`, `REDIS_*`, `RABBIT_*`.
7. `start.sh`: `docker compose build && docker compose up -d`.

Aceite: `docker compose up` sobe health do gateway. `./gradlew test` no shared verde.

Não implemente regras de negócio nesta fase.

---

## FASE 1 — Infra Docker e bancos

**Objetivo:** Postgres com schemas e ICU, Mongo, Redis, RabbitMQ com filas/DLQ.

Passos:

1. `docker-compose.yml` completo (serviços de app podem ser stubs).
2. Init Postgres (`docker-entrypoint-initdb.d`):

```sql
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE DATABASE bantads;
-- no DB bantads:
CREATE SCHEMA cliente;
CREATE SCHEMA gerente;
CREATE SCHEMA conta_command;
CREATE SCHEMA conta_query;
```

Garanta locale ICU (`pt-BR-x-icu`). Se a imagem oficial não tiver, use `postgres:16` e crie collation:

```sql
CREATE COLLATION IF NOT EXISTS "pt-BR-x-icu" (provider = icu, locale = 'pt-BR');
```

3. RabbitMQ: `definitions.json` importado no container (filas, DLXs, TTL retry). Padrão retry: mensagem falha → wait queue TTL 5s → volta à fila principal; após 3 deaths (`x-death`) → DLQ.
4. Redis com `noeviction`.
5. Usuários de banco **por schema** (privilégio só no próprio schema). Cada MS usa user próprio.

Aceite: `pg_isready`, `mongosh ping`, `redis-cli ping`, `rabbitmq-diagnostics ping`, filas visíveis em `:15672`.

---

## FASE 2 — Contrato compartilhado

**Objetivo:** um único lugar para envelope AMQP, erros HTTP, Money, tipos de evento.

Em `shared` (Kotlin) + `gateway/src/types` (TS) **espelhados**:

- `MessageEnvelope`, `ReplyEnvelope`
- `SagaType`: `APROVAR_CLIENTE`, `INSERIR_GERENTE`, `REMOVER_GERENTE`
- `EventType`: `Criado`, `Saque`, `Depósito`, `TransferênciaOrigem`, `TransferênciaDestino`, `GerenteAlterado`
- `JobStatus`, `ResultType`
- `ErroBody`
- `CommandTypes` (strings estáveis, copiar seção 8 deste plano)

Jackson: `FAIL_ON_UNKNOWN_PROPERTIES=false` nos MSs (evolução), mas o Gateway valida input com Zod **estrito** no que o Swagger marca required.

Aceite: testes de serialização Money e envelope.

---

## FASE 3 — MS Auth (MongoDB)

**Objetivo:** fonte da verdade de login único + Argon2 + ativo/inativo.

Documento `usuarios`:

```
{
  cpf: string,          // unique
  login: string,        // email, unique, índice unique
  senhaHash: string,    // argon2id
  tipo: "CLIENTE" | "GERENTE",
  ativo: boolean
}
```

API HTTP interna (não pública):

- `POST /auth/verificar` `{ email, senha }` → 200 `{ cpf, tipo }` ou 401 (inválido/inativo). Nunca devolver hash.
- `GET /auth/health`
- `POST /internal/reboot`
- Consumidor `ms.auth.cmd`:
  - `auth.criar-cliente` — gera senha aleatória (8 chars alfanum), grava hash, **devolve senha em claro só no reply payload**. Unique login: se duplicado, `status=FALHA` `erro="E-mail já cadastrado"`.
  - `auth.criar-gerente` — senha vem no payload (já em claro do form R13), hash Argon2.
  - `auth.remover` / `auth.desativar` / `auth.reativar` (compensações).
  - Inbox idempotente `(sagaId, tipo)`.

Argon2id: memory 19–32 MiB, iterations 2+, parallelism 1 (cabe no mem_limit). Use `de.mkammerer:argon2-jvm` ou Spring Security Crypto.

Aceite: testes Testcontainers Mongo: unique login, inativo não autentica, hash ≠ senha, idempotência do criar.

---

## FASE 4 — MS Cliente (Postgres schema `cliente`)

Tabelas:

`solicitacao` (PK cpf): nome, email (unique), telefone, salario NUMERIC(19,4), logradouro, numero, complemento, cep, cidade, uf, status (`PENDENTE|APROVADA|NAO_APROVADA`), motivo, data_hora_processamento.

`cliente` (PK cpf): mesmos dados cadastrais (sem status). Só existe após aprovação.

Índices: unique email em ambas (solicitação: unique email). Unique cpf.

HTTP interna:

- `POST /solicitacoes` → 201 + entity HATEOAS. 409 se CPF já tem solicitação **em qualquer estado** ou email já usado em outra solicitação. Também 409 se já existe cliente com aquele CPF (defesa em profundidade; o enunciado fala em solicitação por CPF).
- `GET /solicitacoes?status=`
- `GET /solicitacoes/{cpf}`
- `POST /solicitacoes/{cpf}/rejeicao` `{ motivo }` síncrono: se não PENDENTE → 409; senão NAO_APROVADA + timestamp. Publicar `ms.email.cmd` fire-and-forget (rejeição).
- `GET /clientes/{cpf}`
- `GET /clientes?busca=` (filtra cpf **ou** nome, trecho `ILIKE`, unaccent/collation). Sem composition de saldo aqui — devolve cadastro; o Gateway junta saldo. Alternativa: Gateway busca todos e filtra. Prefira filtro no MS Cliente + Gateway busca saldos em lote.
- `GET /clientes/{cpf}/nomes?cpfs=` batch para composition/transferência (interno).
- `POST /internal/reboot`

AMQP:

- `cliente.marcar-aprovada` — se não PENDENTE → FALHA. Senão APROVADA + timestamp; reply com dados da solicitação (nome, email, telefone, salario, endereco). Compensação padrão: volta PENDENTE (limpa motivo/timestamp).
- `cliente.marcar-nao-aprovada` — caso especial e-mail duplicado: NAO_APROVADA + motivo automático `"E-mail já cadastrado"`.
- `cliente.criar` — copia solicitação → tabela cliente. Compensação: DELETE cliente.
- `cliente.obter-por-cpfs` — consulta para e-mails da SAGA.

HATEOAS gerado aqui; Gateway reescreve.

Aceite: testes de unique CPF/email, rejeição 409, collation busca `Cat` acha Catharyna e Catianna.

---

## FASE 5 — MS Gerente (Postgres schema `gerente`)

Tabela `gerente`: cpf PK, nome, email unique, telefone, ativo boolean.

HTTP:

- `GET /gerentes` — **todos** (Gateway filtra ativos na listagem R12, ou o MS já filtra `ativo=true` para R12 e um interno lista todos). Para R12: só ativos.
- `GET /gerentes/{cpf}`
- `PUT /gerentes/{cpf}` — somente nome e telefone. Se body trouxer email/cpf diferentes → 400. Imutáveis.
- `POST /internal/reboot`

AMQP:

- `gerente.inserir` — insert ativo=true. Unique email/cpf → FALHA. Compensação: DELETE (não inativar — a inserção ainda não “existiu” para o negócio).
- `gerente.inativar` — se não existe → FALHA; se último ativo → FALHA `"Não é permitido remover o último gerente ativo"`. Compensação: `ativo=true`.
- `gerente.listar-ativos` — consulta.

Aceite: último ativo não inativa; PUT não muda email; collation pt-BR.

---

## FASE 6 — MS Conta command (Event Sourcing)

Mesmo artefato `services/conta`, pacote `command`.

Tabela `conta_command.evento`:

- `id` UUID PK
- `objeto_id` VARCHAR(4)  -- número da conta
- `tipo` VARCHAR
- `payload` JSONB  -- valores monetários como string
- `versao` INT
- `timestamp` TIMESTAMP
- UNIQUE (`objeto_id`, `versao`)

Inbox SAGA: `conta_command.saga_inbox (saga_id, tipo) UNIQUE`.

Projeção de concorrência: **optimistic locking** via unique versão. Fluxo de write:

1. `SELECT MAX(versao) FROM evento WHERE objeto_id=?`
2. Replay ordenado por versao → estado `{ saldo, cpfCliente, cpfGerente, existe }`
3. Validar regra (saldo, posse, destino)
4. INSERT próxima versao; se unique violation → retry replay (até N vezes)

Evento `Criado` payload mínimo:

```json
{
  "cpfCliente": "...",
  "cpfGerente": "...",
  "saldoInicial": "0.00",
  "dataCriacao": "2026-04-30"
}
```

Número da conta em R9: sortear 4 dígitos, checar existência no event store, repetir até livre. **Não** usar 4 primeiros dígitos do CPF.

`Saque`/`Depósito` payload: `{ "valor": "10.00" }`

Transferência: **uma transação local** grava `TransferênciaOrigem` (conta A, versao+1) e `TransferênciaDestino` (conta B, versao+1). Payload de cada um inclui origem/destino com `{ numeroConta, cpf, nome }` (já enriquecido pelo Gateway). Transferência **não** é SAGA.

HTTP command (Gateway roteia writes):

- `POST /contas/{numero}/deposito`
- `POST /contas/{numero}/saque`
- `POST /contas/{numero}/transferencia` body já enriquecido: `{ valor, destino: { numeroConta, cpf, nome }, origem: { numeroConta, cpf, nome } }`
- Posse: `X-User-Tipo=CLIENTE` e replay.cpfCliente == `X-User-CPF`. Senão 403. Gerente não deposita/saca.

Após persistir, publicar **o evento** em `ms.conta.events` (não o envelope de SAGA). Para transferência, publicar os dois eventos (ordem origem depois destino).

AMQP command:

- `conta.escolher-gerente-menos-clientes` — payload: lista de gerentes ativos. Conta clientes por `cpfGerente` no estado atual (replay ou tabela auxiliar de snapshot **derivada só do event store**, nunca do read model). Gerente sem contas = 0. Empate: qualquer. Reply `{ cpfGerente }`. Sem compensação.
- `conta.criar` — gera número, evento Criado. Compensação: evento de remoção **não existe no enunciado**. Compensar com evento interno `ContaRemovida` **ou** tombstone no stream + ignorar no replay. Prefira marcar stream com evento `Removido` só para compensação de SAGA (não aparece no extrato). Documente no PDF de premissas. Alternativa aceitável: compensação deleta eventos daquela conta **somente se** a conta foi criada nesta SAGA (versao máxima = Criado). Mais simples e alinhado a “remove a conta”.
- `conta.identificar-conta-para-novo-gerente` — regra R13 (abaixo). Reply `{ semConta: true }` ou `{ numero, cpfCliente, cpfGerenteOrigem }`.
- `conta.atribuir-gerente` — evento `GerenteAlterado`. Compensação: `GerenteAlterado` de volta ao original.
- `conta.transferir-contas-do-gerente` — R15: todas as contas do removido → gerente ativo com menos clientes (≠ removido). Reply lista de `cpfCliente`. Compensação: reassocia ao original.

**Regra R13 (cravar em teste unitário puro, sem Spring):**

1. Entre gerentes **ativos** já existentes, ache o(s) com **maior** quantidade de contas.
2. Se essa quantidade máxima é **≤ 1**, nenhuma conta é transferida (nunca deixar existente com 0 contas; primeiro gerente também cai aqui).
3. Se vários empatam na quantidade máxima, escolha o de **menor soma de saldos** (saldo do gerente = soma dos saldos das contas, via replay).
4. Desse gerente, transfira a conta de **menor saldo**. Empate de saldo: qualquer.

No seed, inserir um 5º gerente: max qtd = 2 (Geniéve e Godophredo). Soma Geniéve = 800+150000=150800; Godophredo=10000+1500=11500 → escolhe Godophredo → menor saldo Coândrya `7617`.

HTTP não devolve saldo novo. Resposta `OperacaoRealizada` montada no MS (sem `_links` internos corretos do Gateway — Gateway adiciona/reescreve).

Aceite: teste de corrida de dois saques (um deve 422 ou retry); transferência atômica (se destino falhar, origem não persiste); replay Catharyna = 800.00.

---

## FASE 7 — MS Conta query (CQRS read model)

Pacote `query`, schema `conta_query`, **desnormalizado**.

Tabelas:

`conta` (PK numero): cpf_cliente, cpf_gerente, saldo NUMERIC(19,4), data_criacao DATE.

`movimentacao`: id, numero_conta, data_hora, tipo (`DEPOSITO|SAQUE|TRANSFERENCIA`), valor, origem_numero/cpf/nome, destino_numero/cpf/nome. Origem/destino null em dep/saque.

`projecao_aplicada (evento_id PK)` para idempotência.

Consumidor `ms.conta.events`:

- Já aplicado → ack e ignore.
- `Criado` → insert conta saldo 0 (ou saldoInicial).
- `Depósito` → saldo += valor; insert movimentacao DEPOSITO.
- `Saque` → saldo -=; SAQUE.
- `TransferênciaOrigem` → saldo origem -=; movimentacao TRANSFERENCIA na origem (com origem/destino).
- `TransferênciaDestino` → saldo destino +=; movimentacao TRANSFERENCIA no destino.
- `GerenteAlterado` → update cpf_gerente. Sem linha de extrato.

HTTP query:

- `GET /contas/{numero}`
- `GET /clientes/{cpf}/conta` (lookup por cpf_cliente)
- `GET /contas/{numero}/extrato?inicio&fim`
  - default: hoje-30d .. hoje (America/Sao_Paulo)
  - se fim < inicio ou (fim-inicio) > 365 dias → 422
  - `saldoAbertura` = saldo consolidado **antes** de `inicio` (soma de movimentações da conta com data_hora < inicio 00:00:00, partindo de 0, **ou** saldo atual menos movimentações do período — as duas têm de coincidir)
  - `movimentacoes` do período, ordem cronológica
- Interno composition:
  - `GET /internal/saldos` → mapa cpfCliente → { saldo, numero, cpfGerente }
  - `GET /internal/contagem-por-gerente` → mapa cpfGerente → quantidade

**Não cachear** no Gateway.

Aceite: após seed, GET conta 1291 saldo `"800.00"`; extrato Catharyna em jan/2020 devolve abertura e as 7 movimentações; evento duplicado não duplica saldo.

---

## FASE 8 — MS Email

Só consome `ms.email.cmd`. SMTP Gmail (senha de app em env). Logar `message-id` sem senha.

Tipos:

- `email.senha-cliente` — aprovação OK
- `email.falha-aprovacao` — SAGA R9 falhou após compensar
- `email.rejeicao` — R10
- `email.troca-gerente` — R13/R15 (um ou N destinatários)

Modo `MAIL_DEV=true`: não envia SMTP; grava em arquivo `/tmp/outbox/{to}.txt` e log. **Necessário para testes e para o `input()` da senha na defesa.** Expor senha gerada nesse outbox.

HTTP: só `/health`.

Aceite: teste com GreenMail ou outbox file.

---

## FASE 9 — Orquestrador SAGA (esqueleto)

MS sem REST de negócio. Redis `saga:{id}`. Consome `saga.cmd` e `orquestrador.reply` e `*.cmd.dlq`.

Máquina de estados genérica:

```
carregar definição da SAGA
enquanto houver passo:
  se passo fire-and-forget: publish e continue
  senão: publish cmd, espera reply 30s OU DLQ
  se FALHA: compensar passos transacionais já SUCESSO em ordem inversa (idempotente)
  atualizar job no Redis
```

Não execute as SAGAs de negócio ainda — só um `ping` de teste (`saga.tipo=echo` → reply). Prove timeout e idempotência de compensação.

Estado Redis (enunciado):

```json
{
  "sagaId": "abc-123",
  "tipo": "aprovar-cliente",
  "etapaAtual": 3,
  "status": "EM_ANDAMENTO",
  "payload": { "cpf": "12912861012" },
  "timestamp": "2026-04-30T10:00:00"
}
```

Payload da SAGA **nunca** contém senha em claro.

Aceite: teste de timeout 30s com consumer morto dispara compensação uma vez só mesmo com DLQ depois.

---

## FASE 10 — API Gateway (Fastify) — esqueleto de auth e proxy

Ordem de hooks (enunciado 5.3):

`CORS → JWT verify (x-access-token) → Redis sessão → sliding TTL → role → injeta X-User-* → handler`

Rotas públicas: `POST /login`, `POST /reboot`, `GET /health`, `POST /solicitacoes` (autocadastro).

`POST /login`:

1. Validar body (`email` ou `login` + `senha`).
2. REST `POST ms-auth/auth/verificar`.
3. Se CLIENTE: GET ms-cliente `/clientes/{cpf}`; se GERENTE: GET ms-gerente `/gerentes/{cpf}`. Composition do `usuario`.
4. `jwt.sign({ cpf, tipo, jti }, SECRET, { expiresIn: '8h' })`.
5. SET `sessao:{jti}`, `sessao:cpf:{cpf}` TTL 30min.
6. Resposta conforme Swagger (`auth`, `token`, `tipo`, `usuario`). Sem `_links`.

`POST /logout` (CLIENTE|GERENTE): DEL sessões; SET `revogado:{jti}` com TTL = exp-now; 204.

Proxy: undici, timeout 5s para sync. Reescrever `_links` recursivamente (qualquer objeto com `href` começando em URL interna).

Papéis:

- Só GERENTE: solicitações GET/aprovação/rejeição, GET /clientes lista, gerentes, relatório.
- CLIENTE dono **ou** GERENTE: GET cliente, GET conta.
- Só CLIENTE dono: depósito, saque, transferência, extrato.

404/403 padronizados.

Aceite: T02a–T02f da matriz. CORS `origin` do Angular + métodos/headers incluindo `x-access-token`.

---

## FASE 11 — Seed e `/reboot`

**A primeira chamada da app de teste.** Tem que ser determinística.

Gateway `POST /reboot` (público):

1. Chama `POST /internal/reboot` em Auth, Cliente, Gerente, Conta (command+query no mesmo MS).
2. Flush Redis (jobs, sessões, cache, sagas) — `FLUSHDB` no DB lógico do BANTADS, não em Redis compartilhado indevido.
3. Não precisa reboot do Email.
4. Resposta `{ status: "ok", clientes: 5, gerentes: 4, contas: 5 }`.

Cada MS reboot:

- TRUNCATE / delete all
- Insere seed
- Conta: **command primeiro** (eventos com versao e timestamps das movimentações) **depois** query (contas + movimentacoes equivalentes). Ou: command insere eventos e publica para query; reboot do query espera projeções **ou** insere read model na mesma transação de reboot para ficar instantâneo. **Recomendado no reboot:** popular os dois lados direto (sem esperar Rabbit), para T00 ser síncrono. Em runtime normal, query só via eventos.

Auth seed: 5 clientes + 4 gerentes, Argon2 de `tads`, todos `ativo=true`.

Flyway `V1__schema.sql` + `V2` não precisa do seed (seed é reboot). Opcional `data.sql` só para dev local.

Aceite: reboot duas vezes seguidas = mesmo estado. Replay command Catharyna = 800.00 = query.

---

## FASE 12 — Fluxos síncronos R1, R3–R8, R10, R14

Implementar ponta a ponta via Gateway.

**R1** `POST /solicitacoes` → MS Cliente. 201 + Location.

**R3** `GET /clientes/{cpf}/conta` e `GET /contas/{numero}` → query. Não cachear.

**R4–R6** Gateway:

- valida JWT + posse (CLIENTE).
- R6: 1) GET query conta destino por número (404/422 se não existe); 2) GET nomes origem+destino no MS Cliente; 3) POST command transferência enriquecida; 4) mesma conta origem=destino → 422 **antes** de chamar o MS.

**R7** extrato → query.

**R8** `GET /solicitacoes` GERENTE.

**R10** rejeição síncrona + e-mail FF.

**R14** PUT gerente; Gateway DEL `cache:gerente:{cpf}`.

Aceite: T01, T01d, T03, T03p, T04–T07, T08, T10, T14. Poll de saldo nos testes de T04–T06 (2s + 3 retries / 5s).

---

## FASE 13 — API Composition R11, R12, Login (já na F10)

**R11** `GET /clientes?busca=` GERENTE:

1. MS Cliente lista filtrada (cpf/nome parcial).
2. MS Conta query `internal/saldos` (ou N GETs — volume didático, mas prefira batch).
3. Join por cpf. Cliente sem conta (não deve ocorrer pós-aprovação) → omitir ou saldo nulo; seed sempre tem conta.
4. Sort `Intl.Collator('pt-BR')`.
5. Envelope `{ clientes, _links }`.

**R12** `GET /gerentes`:

1. MS Gerente ativos.
2. MS Conta `internal/contagem-por-gerente`.
3. `quantidadeClientes` (Gadamântio = 0).
4. Sort pt-BR.
5. `{ gerentes, _links }`.

`GET /gerentes/{cpf}`: só MS Gerente; `quantidadeClientes` pode ser `null`. Cache-aside 5 min.

Aceite: T11, T12. `busca=Cat` retorna Catharyna e Catianna, não Cleuddônio. Ordem nomes com acento (Catianna, Catharyna, Cleuddônio, Coândrya, Cutardo).

---

## FASE 14 — SAGA R9 Aprovar Cliente

Gateway `POST /solicitacoes/{cpf}/aprovacao` GERENTE:

1. **Não** validar existência/PENDENTE.
2. UUID `jobId=sagaId`, job Redis PENDENTE, 202 + Location `/jobs/{id}/status`.
3. Publish `saga.cmd` tipo `aprovar-cliente` payload `{ cpf, solicitadoPorCpf }`.
4. DEL `cache:cliente:{cpf}` no sucesso (Orquestrador ou Gateway ouvindo término — Orquestrador já atualiza job; Gateway pode DEL cache ao servir GET miss. Obrigatório invalidar na escrita: Orquestrador publica evento interno ou o Gateway DEL ao receber... **mais simples:** MS Cliente no `cliente.criar` ok; Gateway DEL cache no GET miss é insuficiente se cacheou 404. Então: Orquestrador, ao concluir R9, `DEL cache:cliente:{cpf}` (Orquestrador já acessa Redis).

Passos transacionais (timeout 30s) e compensações:

| # | Comando | Compensação |
|---|---|---|
| 1 | `cliente.marcar-aprovada` | `cliente.desmarcar-aprovada` → PENDENTE (exceto caso especial) |
| 2 | `gerente.listar-ativos` | — |
| 3 | `conta.escolher-gerente-menos-clientes` | — |
| 4 | `cliente.criar` | `cliente.remover` |
| 5 | `auth.criar-cliente` | `auth.remover` |
| 6 | `conta.criar` | `conta.remover` |
| 7 | `email.senha-cliente` | — FF, senha só neste payload e no reply do passo 5 (não persistir no Redis) |

Falha transacional: compensar inversa, depois `email.falha-aprovacao`.

Caso especial passo 5 `E-mail já cadastrado`: compensar 4 e 6 se já rodaram; passo 1 **não** volta a PENDENTE — `cliente.marcar-nao-aprovada`. Job `FALHA`.

Sucesso: job `CONCLUIDO` resource `clientes` + cpf.

Aceite: T09, T09f. Aprovar seed duplicando email de gerente na solicitação → NAO_APROVADA. Número de conta nova ≠ 4 dígitos do CPF (assert estatístico: gerar 20 contas em teste unitário do gerador). Qualquer gerente pode aprovar; dono da conta = quem tem menos clientes **no momento**.

---

## FASE 15 — SAGA R13 Inserir Gerente

Gateway `POST /gerentes` GERENTE, body `GerenteInput` (inclui senha). 202 imediato. Unique e-mail **não** é checado no Gateway (job FALHA).

Passos:

| # | Comando | Compensação / nota |
|---|---|---|
| 1 | `gerente.inserir` | delete gerente |
| 2 | `auth.criar-gerente` | delete auth |
| 3 | `conta.identificar-conta-para-novo-gerente` | — |
| 4 | se houver conta: `conta.atribuir-gerente` | reassocia original |
| 5 | se houver conta: `cliente.obter-por-cpfs` | — |
| 6 | se houver conta: `email.troca-gerente` | FF |

Se passo 3 `semConta`: pular 4–6, sucesso. Gerente fica com 0 contas.

Sucesso: job resource `gerentes`. DEL `cache:gerente:{cpf}`.

Aceite: T13. Inserir no estado seed transfere `7617`. Segundo insert (todos com ≤2, max ainda 2...) recalcular. E-mail `ger1@bantads.com.br` → job FALHA, sem gerente órfão (compensou).

---

## FASE 16 — SAGA R15 Remover Gerente

Gateway: se `X-User-CPF` == path cpf → **403 síncrono**, sem SAGA.

Senão 202 + SAGA `remover-gerente`.

Passos:

| # | Comando | Compensação / nota |
|---|---|---|
| 1 | `gerente.inativar` (falha se inexistente ou último ativo) | reativar |
| 2 | `auth.desativar` | reativar auth |
| 3 | Orquestrador DEL `sessao:cpf:{cpf}` e `sessao:{jti}` | sem compensação (login de novo se SAGA falhar) |
| 4 | `gerente.listar-ativos` | — |
| 5 | `conta.transferir-contas-do-gerente` | reassocia original |
| 6 | `cliente.obter-por-cpfs` | — |
| 7 | `email.troca-gerente` para cada cliente | FF |

Sucesso: job inline `{ mensagem: "Gerente removido; N contas transferidas para {nome}" }`. DEL cache gerente.

Aceite: T15. Remover a si 403. Remover Gadamântio (0 contas) ok, mensagem 0 contas. Remover até restar 1 → próximo DELETE job FALHA. Gerente inativo não loga (T02c).

---

## FASE 17 — Jobs HTTP + R16 Relatório

Gateway:

- `GET /jobs/{jobId}/status` — dono do job (guardar `cpf` no job Redis). 404 TTL.
- `GET /jobs/{jobId}/result` — só inline concluído.

**R16** `GET /relatorios/clientes` GERENTE:

Não é SAGA. Gateway gera jobId, 202, dispara composition **assíncrona** (worker no próprio Gateway ou mensagem `saga.cmd` tipo `relatorio-clientes` tratada pelo Orquestrador sem compensação).

Composition: MS Cliente todos + MS Conta saldos/números/gerente + MS Gerente nomes. Ordenar pt-BR. Gravar resultado no job `resultado`. `resultType=inline`.

Aceite: T16. Poll status até CONCLUIDO < 5s no seed.

---

## FASE 18 — HATEOAS fino + cache-aside

- Centralizar rewrite no Gateway (`walk(obj)`).
- Links condicionais (seção 3.5).
- Cache GET `/clientes/{cpf}` e `/gerentes/{cpf}`: HIT Redis; MISS → MS → SET 5 min. Invalidar conforme fases 14–16 e R14.
- GET cliente 404 não cachear (ou cachear negativo curto) para não esconder aprovação.

Aceite: T# e T$. Snapshot JSON dos recursos seed comparado a exemplos do Swagger (campos required).

---

## FASE 19 — Testes (unitários, integração, contrato)

Pirâmide:

1. **Unitário Kotlin** (sem Spring): Money, replay event store, regra R13, saldo abertura do extrato, collator.
2. **Integração Testcontainers**: cada MS (Postgres/Mongo/Rabbit/Redis).
3. **Contrato pytest** `backend/contract-tests/` — matriz seção 2.2, `pytest -s -v`, `.env URL=http://localhost:3000`, retry CQRS conforme seção 2.1.
4. **Gateway** testes de verifyJWT (token ausente/inválido/revogado/inatividade mockando Redis).

Não dependa de e-mail real nos testes: `MAIL_DEV=true` + ler senha do outbox no T09.

Aceite da fase: `./gradlew test` verde; `pytest -s -v` da suíte BANTADS verde após `start.sh`.

---

## FASE 20 — Endurecimento, defesa, Definition of Done

1. `start.sh` idempotente; `docker compose` healthchecks; mem_limit em **todos**.
2. Logs estruturados JSON; **nunca** logar senha, JWT, Argon2.
3. README de backend: como subir, `.env.example`, usuário Rabbit/DBeaver, URL Gateway `http://localhost:3000`, como rodar pytest BANTADS.
4. Premissas em PDF (enunciado 5): timezone naive, evento `Removido` só compensação, MAIL_DEV.
5. Console RabbitMQ acessível na defesa; filas e uma mensagem de SAGA visíveis.
6. Reboot + login seed + depósito + aprovação + insert gerente demonstráveis só pelo Gateway (Postman collection opcional, não substitui pytest).
7. Zip sem `node_modules`, sem `build/`, sem secrets, < 50 MB.

### Definition of Done (backend)

- [ ] R1–R16 implementados conforme Swagger 2.0.0
- [ ] 6 processos de app: gateway, auth, cliente, gerente, conta, saga; email (7º) ou fundido no saga **somente** se 8 GB obrigar — prefira separado
- [ ] Database-per-service / schema-per-service respeitado
- [ ] CQRS + Event Sourcing reais (event store ≠ read model; sync via `ms.conta.events`)
- [ ] 3 SAGAs orquestradas com compensação, timeout 30s, idempotência, DLQ
- [ ] API Composition: login, R11, R12, R16
- [ ] JWT + Redis sessão sliding 30 min + exp 8h + logout revoga
- [ ] Argon2id; e-mail único no Auth
- [ ] HATEOAS nível 3 com rewrite no Gateway
- [ ] Dinheiro string 2 casas; NUMERIC(19,4)
- [ ] `/health` e `/reboot` (GET+POST)
- [ ] Seed seção 4 reproduzível; replay = saldos
- [ ] Suíte contrato BANTADS verde
- [ ] mem_limit + JAVA_TOOL_OPTIONS + NODE_OPTIONS
- [ ] Sem segredos no git

---

## 8. Catálogo de `tipo` nas mensagens (não divergir)

SAGA start (`saga.cmd`): `aprovar-cliente` | `inserir-gerente` | `remover-gerente` | `relatorio-clientes`

Cliente: `cliente.marcar-aprovada`, `cliente.desmarcar-aprovada`, `cliente.marcar-nao-aprovada`, `cliente.criar`, `cliente.remover`, `cliente.obter-por-cpfs`

Gerente: `gerente.inserir`, `gerente.remover`, `gerente.inativar`, `gerente.reativar`, `gerente.listar-ativos`

Conta: `conta.escolher-gerente-menos-clientes`, `conta.criar`, `conta.remover`, `conta.identificar-conta-para-novo-gerente`, `conta.atribuir-gerente`, `conta.reatribuir-gerente`, `conta.transferir-contas-do-gerente`, `conta.reverter-transferencia-gerentes`

Auth: `auth.criar-cliente`, `auth.criar-gerente`, `auth.remover`, `auth.desativar`, `auth.reativar`

Email: `email.senha-cliente`, `email.falha-aprovacao`, `email.rejeicao`, `email.troca-gerente`

Eventos CQRS: usar os nomes **exatos** do enunciado com acento: `Criado`, `Saque`, `Depósito`, `TransferênciaOrigem`, `TransferênciaDestino`, `GerenteAlterado`.

---

## 9. Ordem de implementação resumida (checklist do agente)

```
F0 bootstrap → F1 infra → F2 shared → F3 auth → F4 cliente → F5 gerente
→ F6 conta command → F7 conta query → F8 email → F9 saga skeleton
→ F10 gateway auth/proxy → F11 seed/reboot
→ F12 sync R1/R3–R8/R10/R14 → F13 composition R11/R12
→ F14 SAGA R9 → F15 SAGA R13 → F16 SAGA R15
→ F17 jobs + R16 → F18 HATEOAS/cache → F19 testes → F20 defesa
```

Se o tempo apertar, a ordem de valor para a defesa/teste é: **F11 reboot + F10 login + F12 contas + F14 R9**. Sem reboot/login o testador para no começo. Sem SAGA R9 o autocadastro não vira cliente. Sem CQRS o saldo mente.

---

## 10. Armadilhas conhecidas (ler antes de cada fase de contas/SAGA)

1. **Float em JSON** — o testador compara `"800.00"` literal. `800` ou `800.0` falha.
2. **Conta como number** — `"0950"` vira `950` em JSON number. Sempre string.
3. **Validar saldo no query** — saque passa e o command depois recusa, ou o contrário. Replay no command.
4. **Transferência em duas transações** — origem debitada e destino não. Uma TX local.
5. **SAGA coreografada** — MS Conta não chama MS Auth. Só o orquestrador publica `*.cmd`.
6. **Cache de saldo** — proibido. Esconde consistência eventual e quebra o poll do teste.
7. **JWT sem sessão Redis** — enunciado exige os dois. Token válido com sessão apagada = 401 `"Falha ao autenticar o token."`
8. **R9 pré-validada no Gateway** — Swagger: solicitação inexistente vira job FALHA, não 404.
9. **Auto-remoção no Orquestrador** — tarde demais; 403 no Gateway.
10. **R13 tirar a única conta de alguém** — proibido. Se max contas ≤ 1, novo gerente nasce zerado.
11. **Seed só no query** — replay não fecha 800.00. Defesa pergunta Event Sourcing.
12. **HATEOAS apontando para `:8081`** — front/teste saem do Gateway. Rewrite obrigatório.
13. **Collation ASCII** — `Coândrya` vai para o fim. Usar pt-BR.
14. **Senha da R9 no Redis da SAGA** — vazamento. Só AMQP Auth reply → Email cmd.
15. **Idempotência ausente** — Rabbit reentrega, duas contas criadas, teste de unique quebra.
16. **Heap da JVM sem MaxRAMPercentage** — OOM na defesa com 6 Spring Boots.

---

Fim do plano. Implementar a Fase 0 em seguida, salvo instrução em contrário.
