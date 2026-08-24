# Plano de entregas — porte do backend (3 pessoas)

Este repo é o **protótipo de teste**. O trabalho semanal é **copiar** o código daqui para o **repo oficial**, conferir no HTTPie e marcar [`log_check_transactions.md`](./log_check_transactions.md). Não reimplementar do zero: abrir o tutorial em [`transacoes/`](./transacoes/00-GERAL.md), transcrever os **arquivos-chave**, ajustar só se o oficial divergir (pacote, porta, nome de pasta).

Front Angular **não** entra neste plano. Contratos JSON (request/response): [`00-JSON-CATALOG.md`](./00-JSON-CATALOG.md).

---

## Quantas entregas

| | |
|---|---|
| Primeira | terça **25/08/2026** (esta semana — fatia curta) |
| Ritmo | 1 entrega / semana, sempre na terça |
| Última | terça **10/11/2026** |
| **Total** | **12 entregas** |

De 25/08 a 10/11 inclusive, de 7 em 7 dias → 12 terças.

Ordem (não pular): **infra → Auth → Gateway/login → reboot → Cliente/Conta síncronos → composition → jobs/e-mail/SAGA → R9 → R13 → R15**. Sem reboot/login o testador para. Sem CQRS o saldo mente. Sem R9 o autocadastro não vira cliente.

---

## Como a equipe se divide

Os papéis **não mudam** de semana. Só muda o recorte.

| Papel | Foco permanente | Onde copiar |
|---|---|---|
| **A** | Gateway Fastify, Redis, ACL, proxy, jobs, composition | `backend/gateway/` |
| **B** | Microsserviço Kotlin da semana (HTTP + persistência) | `backend/services/<ms>/` + `shared/` |
| **C** | Compose, filas, seed, consumidores AMQP, HTTPie, marcar o log | `docker-compose.yml`, `db/`, `backend/services/saga`, `email`, `httpie/` |

Regra de ouro: A não inventa JSON; B não expõe porta 808x no host; C não fecha a semana sem marcar HTTPie **e** Código da transação no log.

Ao copiar: leia o tutorial da TX **antes**, cole no oficial, rode o HTTPie do recorte, marque o log.

| # | Data | Módulo | Transações no log | JSON (catálogo) |
|---|---|---|---|---|
| E01 | 25/08/2026 | Infra + health | TX-INFRA-01 | [req](json-catalog/TX-INFRA-01.md) · [resp](json-catalog/TX-INFRA-01.md) |
| E02 | 01/09/2026 | Shared + MS Auth | (base de TX-R2A) | [TX-R2A req](json-catalog/TX-R2A.md) · [resp](json-catalog/TX-R2A.md) · [erros 401](json-catalog/TX-R2A.md) |
| E03 | 08/09/2026 | Gateway JWT / login / logout | TX-R2A, TX-R2B | [R2A req](json-catalog/TX-R2A.md) · [resp](json-catalog/TX-R2A.md) · [R2B req](json-catalog/TX-R2B.md) · [resp 204](json-catalog/TX-R2B.md) |
| E04 | 15/09/2026 | Seed + `/reboot` | TX-INFRA-02 | [req](json-catalog/TX-INFRA-02.md) · [resp](json-catalog/TX-INFRA-02.md) · [login seed](json-catalog/TX-R2A.md) |
| E05 | 22/09/2026 | MS Cliente síncrono | TX-R1, TX-R8A, TX-R8B, TX-R10, TX-CAD-01 | [R1](json-catalog/TX-R1.md) · [R8A](json-catalog/TX-R8A.md) · [R8B](json-catalog/TX-R8B.md) · [R10](json-catalog/TX-R10.md) · [CAD-01](json-catalog/TX-CAD-01.md) |
| E06 | 29/09/2026 | MS Conta query | TX-R3A, TX-R3B, TX-R7 | [R3A](json-catalog/TX-R3A.md) · [R3B](json-catalog/TX-R3B.md) · [R7](json-catalog/TX-R7.md) |
| E07 | 06/10/2026 | MS Conta command | TX-R4, TX-R5, TX-R6 | [R4](json-catalog/TX-R4.md) · [R5](json-catalog/TX-R5.md) · [R6](json-catalog/TX-R6.md) |
| E08 | 13/10/2026 | MS Gerente + composition + cache | TX-R11, TX-R12, TX-CAD-02, TX-R14 | [R11](json-catalog/TX-R11.md) · [R12](json-catalog/TX-R12.md) · [CAD-02](json-catalog/TX-CAD-02.md) · [R14](json-catalog/TX-R14.md) |
| E09 | 20/10/2026 | Jobs + e-mail + SAGA esqueleto + R16 | TX-JOB-01, TX-JOB-02, TX-R16 | [JOB-01](json-catalog/TX-JOB-01.md) · [JOB-02](json-catalog/TX-JOB-02.md) · [R16](json-catalog/TX-R16.md) |
| E10 | 27/10/2026 | SAGA R9 | TX-R9 | [req](json-catalog/TX-R9.md) · [202](json-catalog/TX-R9.md) · [job OK](json-catalog/TX-R9.md) |
| E11 | 03/11/2026 | SAGA R13 | TX-R13 | [req](json-catalog/TX-R13.md) · [202](json-catalog/TX-R13.md) · [GET gerente](json-catalog/TX-R13.md) |
| E12 | 10/11/2026 | SAGA R15 + fecho | TX-R15 + convenções do log | [403](json-catalog/TX-R15.md) · [DELETE](json-catalog/TX-R15.md) · [202](json-catalog/TX-R15.md) · [result](json-catalog/TX-R15.md) |

---

## E01 — 25/08/2026 — Infra + health

Ler: [`00-GATEWAY.md`](transacoes/00-GATEWAY.md) · [`TX-INFRA-01`](transacoes/TX-INFRA-01-health.md)

**Contratos JSON:** [TX-INFRA-01 request](json-catalog/TX-INFRA-01.md) · [response 200](json-catalog/TX-INFRA-01.md)

### A — Gateway mínimo

- [x] Copiar `backend/gateway/` esqueleto: `app.ts`, `index.ts`, `config.ts`, CORS (`x-access-token`)
- [ ] `GET /health` público → `{ "status": "UP" }` **sem** `_links`
- [ ] ACL: `/health` na lista pública ([`acl.ts`](backend/gateway/src/auth/acl.ts))
- [ ] Dockerfile + healthcheck do serviço `gateway` (porta **3000** no host)

### B — MSs: só `/health`

- [ ] Cada MS Kotlin: `Application.kt` + `HealthController` `{ "status": "UP" }`
- [ ] `application.yml` com porta interna; **não** publicar 808x no compose
- [ ] Dockerfile de cada MS (`JAVA_TOOL_OPTIONS`, `mem_limit`)

### C — Compose e conferência

- [ ] `docker-compose.yml`: Postgres 16 (schemas `cliente`, `gerente`, `conta_command`, `conta_query`, collation `pt-BR-x-icu`), Mongo, Redis `noeviction`, RabbitMQ + `definitions.json` (filas podem nascer vazias nesta semana)
- [ ] Usuário Postgres **por schema**; `.env.example` sem segredo real
- [ ] `start.sh` / build um serviço por vez; `docker compose ps` healthy
- [ ] HTTPie [`TX-INFRA-01`](httpie/TX-INFRA-01-health.md) e marcar o log

**Aceite:** `GET http://localhost:3000/health` → 200; `localhost:8080` recusa.

---

## E02 — 01/09/2026 — Shared + MS Auth

Ler: trecho Auth de [`TX-R2A`](transacoes/TX-R2A-login.md)

**Contratos JSON (base):** [TX-R2A request](json-catalog/TX-R2A.md) · [response CLIENTE](json-catalog/TX-R2A.md) · [response GERENTE](json-catalog/TX-R2A.md) · [erros 401](json-catalog/TX-R2A.md)

### A — Tipos do Gateway

- [ ] Copiar `backend/gateway/src/types/` (envelopes, command types, schemas Zod de `{ email, senha }`, erros 401 `{ auth, message }`)
- [ ] Cliente HTTP interno para `POST /auth/verificar` ([`ms-client.ts`](backend/gateway/src/http/ms-client.ts)) — ainda sem JWT

### B — MS Auth (Mongo + Argon2id)

- [ ] Copiar `backend/services/auth/`: documento `usuarios`, unique cpf/login, `AuthService.verificar`
- [ ] `POST /auth/verificar` → `{ cpf, tipo }` ou 401; **nunca** devolver hash
- [ ] Consumidor `ms.auth.cmd` + inbox: `criar-cliente`, `criar-gerente`, `remover`/`desativar`/`reativar`
- [ ] `POST /internal/reboot` (estrutura; seed completo na E04)
- [ ] Testes: unique e-mail, inativo = inválido, hash ≠ senha

### C — Shared + filas Auth

- [ ] Copiar `backend/services/shared/`: Money string `^\d+\.\d{2}$`, envelopes AMQP, nomes de fila
- [ ] Filas `ms.auth.cmd` + DLQ no Rabbit `definitions.json`
- [ ] Mongo no compose; conferir ping; marcar no log o item **Código** do Auth em TX-R2A

**Aceite:** Testcontainers Auth verdes. Gateway ainda não precisa logar.

---

## E03 — 08/09/2026 — JWT, sessão, login, logout

Ler: [`00-JWT.md`](transacoes/00-JWT.md) · [`00-ACL.md`](transacoes/00-ACL.md) · [`TX-R2A`](transacoes/TX-R2A-login.md) · [`TX-R2B`](transacoes/TX-R2B-logout.md)

**Contratos JSON:** [TX-R2A request](json-catalog/TX-R2A.md) · [response](json-catalog/TX-R2A.md) · [TX-R2B request](json-catalog/TX-R2B.md) · [response 204](json-catalog/TX-R2B.md) · [pós-logout 401](json-catalog/TX-R2B.md)

### A — Pipeline do Gateway

- [ ] Copiar `auth/jwt.ts`, `auth/hook.ts`, `auth/acl.ts`, `redis/session.ts`
- [ ] Ordem: CORS → JWT `x-access-token` → sessão Redis → TTL 30 min sliding → ACL → `X-User-CPF` / `X-User-Tipo`
- [ ] JWT **só** no Gateway (`cpf`, `tipo`, `jti`, exp 8 h)
- [ ] Rotas públicas: `/health`, `/login`, `/reboot`, `/solicitacoes`
- [ ] Copiar [`login.ts`](backend/gateway/src/routes/login.ts) e [`logout.ts`](backend/gateway/src/routes/logout.ts)
- [ ] Mensagens exatas: `"Token não fornecido."` / `"Falha ao autenticar o token."` / `"Login inválido!"`

### B — Composition do `usuario` no login

- [ ] MS Cliente e Gerente: `GET /{cpf}` interno **mínimo** (nome + e-mail) para o login montar `usuario` — cadastro completo pode esperar E05/E08
- [ ] Auth já responde `verificar`; senha `tads` só existe depois do seed (E04) — use um usuário de teste se o reboot ainda não existir

### C — Redis sessão + HTTPie

- [ ] Redis no ar; chaves `sessao:{jti}`, `sessao:cpf:{cpf}`, `revogado:{jti}`
- [ ] HTTPie login/logout (seed se já houver; senão usuário de teste)
- [ ] Marcar TX-R2A e TX-R2B no log (o que ainda depender do seed fica para E04)

**Aceite:** 401 sem token / token lixo; logout 204; token reusado 401.

---

## E04 — 15/09/2026 — Seed + `/reboot`

Ler: [`00-SEED.md`](transacoes/00-SEED.md) · [`TX-INFRA-02`](transacoes/TX-INFRA-02-reboot.md)

**Contratos JSON:** [TX-INFRA-02 request](json-catalog/TX-INFRA-02.md) · [response](json-catalog/TX-INFRA-02.md) · [TX-R2A login CLIENTE](json-catalog/TX-R2A.md) · [TX-R2A login GERENTE](json-catalog/TX-R2A.md)

### A — Gateway reboot

- [ ] Copiar [`reboot.ts`](backend/gateway/src/routes/reboot.ts): `POST /internal/reboot` em Auth, Cliente, Gerente, Conta em paralelo + `FLUSHDB`
- [ ] Resposta **exata** `{ "status": "ok", "clientes": 5, "gerentes": 4, "contas": 5 }` sem `_links`
- [ ] Timeout longo (HTTPie ≥ 90 s)

### B — Seed dos quatro MSs

- [ ] Copiar `RebootController` + dados do enunciado (5 clientes, 4 gerentes, senha `tads` Argon2id)
- [ ] Conta: popular **command e query** no reboot (não esperar Rabbit nesta chamada)
- [ ] Saldos query: `1291`=`"800.00"`, `0950`=`"10000.00"`, `8573`=`"200.00"`, `5887`=`"150000.00"`, `7617`=`"1500.00"`
- [ ] Movimentações históricas da Catharyna (7 linhas jan/2020)

### C — Conferência

- [ ] Segundo reboot = mesmo JSON
- [ ] Replay command Catharyna = `"800.00"` = query
- [ ] Tokens pré-reboot → 401
- [ ] Marcar TX-INFRA-02 no log; relogar TX-R2A/TX-R2B com seed real se faltou na E03

**Aceite:** T00 do contrato; login `cli1` / `ger1` com `tads`.

---

## E05 — 22/09/2026 — MS Cliente síncrono

Ler: [`TX-R1`](transacoes/TX-R1-autocadastro.md) · [`TX-R8A`](transacoes/TX-R8A-listar-solicitacoes.md) · [`TX-R8B`](transacoes/TX-R8B-consultar-solicitacao.md) · [`TX-R10`](transacoes/TX-R10-rejeitar-cliente.md) · [`TX-CAD-01`](transacoes/TX-CAD-01-consultar-cliente.md)

**Contratos JSON:**
- [TX-R1 request](json-catalog/TX-R1.md) · [response 201](json-catalog/TX-R1.md) · [409](json-catalog/TX-R1.md)
- [TX-R8A request](json-catalog/TX-R8A.md) · [response](json-catalog/TX-R8A.md)
- [TX-R8B request](json-catalog/TX-R8B.md) · [response PENDENTE](json-catalog/TX-R8B.md) · [response NAO_APROVADA](json-catalog/TX-R8B.md)
- [TX-R10 request](json-catalog/TX-R10.md) · [response](json-catalog/TX-R10.md)
- [TX-CAD-01 request](json-catalog/TX-CAD-01.md) · [response](json-catalog/TX-CAD-01.md)

### A — Proxy + cache cadastro

- [ ] Copiar proxy `POST/GET /solicitacoes`, rejeição, `GET /clientes/{cpf}`
- [ ] Cache-aside `cache:cliente:{cpf}` TTL 5 min **só** GET cadastro; **não** cachear 404 ([`00-REDIS-CACHE.md`](transacoes/00-REDIS-CACHE.md))
- [ ] Rewrite `_links` para `:3000`; `aprovacao`/`rejeicao` só se `PENDENTE`

### B — MS Cliente HTTP

- [ ] Tabelas `solicitacao` + `cliente`; unique CPF/e-mail
- [ ] Autocadastro 201 + `Location`; 409 nos três casos (CPF solicitação, e-mail, CPF já cliente)
- [ ] Listar/obter solicitações (GERENTE); rejeição síncrona 200 / 409 / 400
- [ ] Publicar `email.rejeicao` FF (consumidor na E09)
- [ ] `GET /clientes/{cpf}` sem `saldo`; posse `gerenteOrSelf`
- [ ] Assembler HATEOAS; consumidores AMQP de R9 podem ir como stub

### C — Conferência R1/R8/R10/CAD-01

- [ ] HTTPie dos quatro fluxos + 403 cliente na lista
- [ ] Marcar TX-R1, TX-R8A, TX-R8B, TX-R10, TX-CAD-01 no log

**Aceite:** T01, T01d, T08, T10.

---

## E06 — 29/09/2026 — MS Conta query (R3, R7)

Ler: [`TX-R3A`](transacoes/TX-R3A-consultar-conta-cpf.md) · [`TX-R3B`](transacoes/TX-R3B-consultar-conta-numero.md) · [`TX-R7`](transacoes/TX-R7-extrato.md)

**Contratos JSON:**
- [TX-R3A request](json-catalog/TX-R3A.md) · [response CLIENTE](json-catalog/TX-R3A.md) · [response GERENTE](json-catalog/TX-R3A.md)
- [TX-R3B request](json-catalog/TX-R3B.md) · [response](json-catalog/TX-R3B.md)
- [TX-R7 request](json-catalog/TX-R7.md) · [response jan/2020](json-catalog/TX-R7.md) · [response 30 dias](json-catalog/TX-R7.md)

### A — Proxy query + HATEOAS por perfil

- [ ] Proxy `GET /clientes/{cpf}/conta`, `GET /contas/{numero}`, `GET /contas/{numero}/extrato`
- [ ] **Não** cachear saldo
- [ ] Gerente: apagar rels `deposito|saque|transferencia|extrato`; extrato ACL só CLIENTE (403 gerente)
- [ ] Conta `"0950"` como string de 4 dígitos

### B — Read model + projector

- [ ] Copiar schema `conta_query`, `EventProjector`, `projecao_aplicada`
- [ ] Controllers query + `ExtratoRegras` (default 30 dias, 422 > 365 d, 422 fim < início)
- [ ] Internos `/internal/saldos` e `/internal/contagem-por-gerente` (usados na E08)
- [ ] Extrato jan/2020 Catharyna: abertura `"0.00"`, 7 movimentos

### C — Conferência R3/R7

- [ ] Consumidor `ms.conta.events` no ar (projeção; duplicata não soma duas vezes)
- [ ] HTTPie R3A/R3B/R7; marcar o log

**Aceite:** T03, T03p, T07.

---

## E07 — 06/10/2026 — MS Conta command (R4, R5, R6)

Ler: [`TX-R4`](transacoes/TX-R4-deposito.md) · [`TX-R5`](transacoes/TX-R5-saque.md) · [`TX-R6`](transacoes/TX-R6-transferencia.md)

**Contratos JSON:**
- [TX-R4 request](json-catalog/TX-R4.md) · [response 201](json-catalog/TX-R4.md)
- [TX-R5 request](json-catalog/TX-R5.md) · [response 201](json-catalog/TX-R5.md) · [422 saldo](json-catalog/TX-R5.md)
- [TX-R6 request](json-catalog/TX-R6.md) · [response 201](json-catalog/TX-R6.md) · [422 mesma conta](json-catalog/TX-R6.md)

### A — Gateway writes + enrich R6

- [ ] Proxy depósito/saque (só CLIENTE dono)
- [ ] R6: body do front `{ contaDestino, valor }`; Gateway valida origem=destino e destino inexistente (422); busca nomes; POST enriquecido no command
- [ ] 201 **sem** campo `saldo`; `_links.conta` e `_links.extrato`

### B — Event store

- [ ] Copiar `conta_command.evento`, replay, optimistic lock
- [ ] `writeMoney` depósito/saque; saldo **só** do replay; 422 insuficiente **antes** do append
- [ ] Transferência: dois eventos na **mesma** TX local; publicar `ms.conta.events` depois do commit
- [ ] AMQP de SAGA (`criar`, R13/R15) pode ir como stub se ainda não usado

### C — Conferência R4/R5/R6

- [ ] Poll GET conta 2–5 s após write
- [ ] Marcar TX-R4, TX-R5, TX-R6 no log (incluindo 400 valor number e 403 conta alheia)

**Aceite:** T04, T05, T06.

---

## E08 — 13/10/2026 — Gerente síncrono + R11/R12 + cache

Ler: [`TX-R11`](transacoes/TX-R11-consultar-clientes.md) · [`TX-R12`](transacoes/TX-R12-listar-gerentes.md) · [`TX-CAD-02`](transacoes/TX-CAD-02-consultar-gerente.md) · [`TX-R14`](transacoes/TX-R14-atualizar-gerente.md) · [`00-REDIS-CACHE.md`](transacoes/00-REDIS-CACHE.md)

**Contratos JSON:**
- [TX-R11 request](json-catalog/TX-R11.md) · [response filtro](json-catalog/TX-R11.md) · [response todos](json-catalog/TX-R11.md)
- [TX-R12 request](json-catalog/TX-R12.md) · [response](json-catalog/TX-R12.md)
- [TX-CAD-02 request](json-catalog/TX-CAD-02.md) · [response próprio](json-catalog/TX-CAD-02.md) · [response outro](json-catalog/TX-CAD-02.md)
- [TX-R14 request](json-catalog/TX-R14.md) · [response](json-catalog/TX-R14.md)

### A — Composition + cache gerente

- [ ] Copiar [`composition.ts`](backend/gateway/src/routes/composition.ts): R11 (cliente + saldos, sort `pt-BR`, **não** cachear); R12 (gerentes + contagem)
- [ ] Cache `cache:gerente:{cpf}` TTL 5 min; `DEL` no PUT 200
- [ ] HATEOAS: lista com `criacao`; sem `remocao` no próprio CPF; `busca=Cat` → Catharyna, Catianna

### B — MS Gerente

- [ ] CRUD HTTP: listar ativos, GET por CPF, PUT só nome/telefone (e-mail/CPF diferentes → 400)
- [ ] Assembler; `quantidadeClientes` nula no GET unitário é ok
- [ ] AMQP `inserir`/`inativar`/`listar-ativos` (usados E11–E12)

### C — Conferência

- [ ] Quantidades seed: Geniéve 2, Godophredo 2, Gyândula 1, Gadamântio 0
- [ ] Marcar TX-R11, TX-R12, TX-CAD-02, TX-R14 no log

**Aceite:** T11, T12, T14.

---

## E09 — 20/10/2026 — Jobs + e-mail + esqueleto SAGA + R16

Ler: [`TX-JOB-01`](transacoes/TX-JOB-01-status.md) · [`TX-JOB-02`](transacoes/TX-JOB-02-result.md) · [`TX-R16`](transacoes/TX-R16-relatorio-clientes.md)

**Contratos JSON:**
- [TX-JOB-01 request](json-catalog/TX-JOB-01.md) · [PENDENTE](json-catalog/TX-JOB-01.md) · [CONCLUIDO resource](json-catalog/TX-JOB-01.md) · [CONCLUIDO inline](json-catalog/TX-JOB-01.md) · [FALHA](json-catalog/TX-JOB-01.md)
- [TX-JOB-02 request](json-catalog/TX-JOB-02.md) · [result R15](json-catalog/TX-JOB-02.md) · [result R16](json-catalog/TX-JOB-02.md)
- [TX-R16 request](json-catalog/TX-R16.md) · [202](json-catalog/TX-R16.md) · [result](json-catalog/TX-R16.md)

### A — Jobs HTTP + relatório

- [ ] Copiar [`jobs.ts`](backend/gateway/src/routes/jobs.ts), [`redis/jobs.ts`](backend/gateway/src/redis/jobs.ts)
- [ ] Status: dono do job; PENDENTE/CONCLUIDO/FALHA; TTL 5 min; **sem** `_links`
- [ ] Result só `CONCLUIDO` + `inline`; senão 409
- [ ] Copiar [`relatorio.ts`](backend/gateway/src/routes/relatorio.ts): GET 202, composition **async** (não `saga.cmd`), result `{ clientes: [...] }` sem `_links`

### B — MS Email

- [ ] Copiar `backend/services/email/`: consome `ms.email.cmd`; HTTP só `/health`
- [ ] `MAIL_DEV=true` → `outbox/{email}.txt`; SMTP só via env
- [ ] Tipos: senha cliente, falha aprovação, rejeição, troca gerente
- [ ] FF: **sem** reply; SMTP falho **não** compensa SAGA

### C — Orquestrador esqueleto + conferência

- [ ] Copiar `SagaEngine` + Redis `saga:{id}` **sem** senha; timeout 30 s; compensação idempotente
- [ ] SAGA `echo`/ping: timeout e DLQ compensam **uma** vez
- [ ] Filas `saga.cmd`, `orquestrador.reply`, `*.cmd.dlq`
- [ ] HTTPie JOB-01/02 via R16; marcar TX-JOB-01, TX-JOB-02, TX-R16 no log

**Aceite:** T16; poll < 5 s no seed.

---

## E10 — 27/10/2026 — SAGA R9 (aprovar cliente)

Ler: [`TX-R9`](transacoes/TX-R9-aprovar-cliente.md)

**Contratos JSON:** [TX-R9 request](json-catalog/TX-R9.md) · [202](json-catalog/TX-R9.md) · [job CONCLUIDO](json-catalog/TX-R9.md) · [job FALHA](json-catalog/TX-R9.md) · [job FALHA e-mail](json-catalog/TX-R9.md) · [TX-CAD-01 pós-aprovação](json-catalog/TX-CAD-01.md)

### A — Gateway aprovação

- [ ] Copiar [`aprovacao.ts`](backend/gateway/src/routes/aprovacao.ts): 202 **sem** pré-validar PENDENTE; `jobId = sagaId`
- [ ] `DEL cache:cliente:{cpf}` no sucesso (orquestrador já faz; conferir)

### B — Passos nos MSs

- [ ] Cliente: marcar aprovada / criar / marcar não-aprovada / compensações
- [ ] Auth: `criar-cliente` senha aleatória **só no reply AMQP**
- [ ] Conta: escolher gerente com menos contas; criar número **aleatório** 4 dígitos (≠ 4 primeiros do CPF)
- [ ] E-mail senha FF

### C — Registry R9 + conferência

- [ ] Copiar `SagaRegistry.aprovarCliente` + caso e-mail duplicado → `NAO_APROVADA` (não volta a PENDENTE)
- [ ] HTTPie caminho feliz + 202/FALHA (CPF inexistente, e-mail de gerente)
- [ ] Marcar TX-R9 no log; senha no `outbox/`; login do novo cliente

**Aceite:** T09, T09f.

---

## E11 — 03/11/2026 — SAGA R13 (inserir gerente)

Ler: [`TX-R13`](transacoes/TX-R13-inserir-gerente.md)

**Contratos JSON:** [TX-R13 request](json-catalog/TX-R13.md) · [202](json-catalog/TX-R13.md) · [job CONCLUIDO](json-catalog/TX-R13.md) · [GET gerente criado](json-catalog/TX-R13.md) · [job FALHA e-mail](json-catalog/TX-R13.md) · [400 síncrono](json-catalog/TX-R13.md)

### A — Gateway POST `/gerentes`

- [ ] Copiar [`inserir-gerente.ts`](backend/gateway/src/routes/inserir-gerente.ts): valida body (senha obrigatória); **não** checa e-mail único; 202
- [ ] Senha **não** vai para Redis da SAGA nem volta no job/GET

### B — R13 no MS Conta + Gerente/Auth

- [ ] Copiar [`R13Selecao`](backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/command/r13/R13Selecao.kt) + testes unitários
- [ ] `gerente.inserir` / `auth.criar-gerente` / atribuir `GerenteAlterado`
- [ ] `semConta`: pula atribuir/e-mail; sucesso com 0 clientes
- [ ] Nunca zerar gerente que só tem 1 conta

### C — Registry R13 + conferência

- [ ] Copiar `SagaRegistry.inserirGerente` (`skipIfTrue = semConta`)
- [ ] Seed puro: 1ª inserção pega `7617` (Coândrya)
- [ ] E-mail duplicado → 202 depois FALHA + GET 404 (compensou)
- [ ] Body incompleto → 400 síncrono
- [ ] Marcar TX-R13 no log; login com a senha do form

**Aceite:** T13.

---

## E12 — 10/11/2026 — SAGA R15 + HATEOAS fino + aceite total

Ler: [`TX-R15`](transacoes/TX-R15-remover-gerente.md) · [`00-HATEOAS.md`](transacoes/00-HATEOAS.md)

**Contratos JSON:** [403 auto-remoção](json-catalog/TX-R15.md) · [DELETE request](json-catalog/TX-R15.md) · [202](json-catalog/TX-R15.md) · [job CONCLUIDO inline](json-catalog/TX-R15.md) · [result](json-catalog/TX-R15.md) · [login removido 401](json-catalog/TX-R15.md) · [job FALHA](json-catalog/TX-R15.md)

### A — Gateway DELETE + rewrite final

- [ ] Copiar [`remover-gerente.ts`](backend/gateway/src/routes/remover-gerente.ts): auto-CPF → **403 síncrono** sem job
- [ ] Rewrite recursivo de `href`; nenhum `_links` aponta para `:808x`
- [ ] Sem `_links`: login, 202/status/result, `/health`, `/reboot`, linhas do relatório

### B — Passos R15 nos MSs

- [ ] `gerente.inativar` (último ativo → FALHA); `auth.desativar`
- [ ] Transferir contas ao ativo com **menos** clientes ≠ removido; evento `GerenteAlterado`
- [ ] Compensações reativar / reassociar

### C — Registry R15 + fecho do log

- [ ] Copiar `SagaRegistry.removerGerente` (passo **LOCAL** `SAGA_INVALIDAR_SESSAO`)
- [ ] Job sucesso `inline` `{ mensagem: "Gerente removido; N contas transferidas para {Nome}" }`
- [ ] HTTPie: 403 em si; Gadamântio 202 + result; login removido 401; DELETE de novo 202+FALHA; result de FALHA → 409
- [ ] Marcar TX-R15, revalidar TX-JOB-01/02 no fluxo inline, **convenções transversais** do log
- [ ] `pytest` contrato T00–T16 se a suíte estiver no oficial; `compile-services` da frota

**Aceite:** T15; log inteiro marcado; dinheiro string; dois envelopes de erro; 3 SAGAs orquestradas.

---

## Definition of Done (oficial, E12)

- [ ] R1–R16 conforme Swagger
- [ ] 7 processos: gateway, auth, cliente, gerente, conta, saga, email
- [ ] Schema-per-service; CQRS + event store reais
- [ ] 3 SAGAs orquestradas (30 s, compensação, DLQ, idempotência)
- [ ] Composition: login, R11, R12, R16
- [ ] JWT só no Gateway + Redis sessão 30 min + logout revoga
- [ ] Argon2id; HATEOAS nível 3 com rewrite
- [ ] `/health` + `/reboot` determinístico
- [ ] Sem segredos no git; front/testes só `:3000`
