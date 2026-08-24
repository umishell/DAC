# Plano de entregas — por serviço (arquivos inteiros)

Este plano é complementar ao [`plano-entregas-backend.md`](./plano-entregas-backend.md).

**Regra principal:** copiar **arquivos inteiros** para o repo oficial — nunca trechos de código. Quando todos os arquivos de um serviço estiverem colados, compilados, testados e funcionando, parte-se para o próximo serviço. Não há motivo para voltar a um serviço já fechado.

**O que NÃO copiar:** `docs/`, `httpie/`, `json-catalog/`, `transacoes/`, `log_check_transactions.md`, `.cursor/`, `plano-entregas-backend.md`, `plano-entregas-frontend.md`, `00-JSON-CATALOG.md` — são arquivos de tutorial e referência deste protótipo, não pertencem ao oficial.

---

## Calendário

| # | Data | Serviço / Módulo | Aceite mínimo |
|---|---|---|---|
| E01 | ter **25/08/2026** | Infra + Gateway (todos os arquivos) | `GET /health` → 200 |
| E02 | ter **01/09/2026** | Shared + MS Auth | `POST /login` → 200 com token |
| E03 | ter **08/09/2026** | MS Cliente | `POST /solicitacoes` → 201; `GET /clientes/{cpf}` → 200 |
| E04 | ter **15/09/2026** | MS Conta command (CQRS write) | `POST /reboot` parcial OK; depósito → 201 |
| E05 | ter **22/09/2026** | MS Conta query (CQRS read) | `GET /conta` → saldo; extrato Catharyna; reboot completo |
| E06 | ter **29/09/2026** | MS Gerente + composition R11/R12 | `GET /gerentes` com `quantidadeClientes`; reboot 5/4/5 |
| E07 | ter **06/10/2026** | MS Saga (engine + R9) | SAGA R9 → 202 + job `CONCLUIDO`; login do novo cliente |
| E08 | ter **13/10/2026** | MS Email + SAGA R13/R15 | R13/R15 → 202 + job OK; e-mail em `outbox/` |
| E09 | ter **20/10/2026** | Contract tests (pytest T00–T16) | `pytest -v` verde na suíte completa |
| E10 | ter **27/10/2026** | Integração frontend Angular | Todas as telas funcionando com backend real |
| E11 | ter **03/11/2026** | Ajustes pós-integração + R16 + jobs inline | R16 no front; jobs CONCLUIDO/FALHA corretos |
| E12 | ter **10/11/2026** | Aceite final e fecho | T00–T16 verde; log fechado; money string em tudo |

---

## Como a equipe se divide

Papéis **fixos** — só muda o recorte da semana.

| Papel | Foco permanente | Destino no oficial |
|---|---|---|
| **A** | Gateway/Node/TS, Redis, ACL, proxy, jobs, AMQP | `backend/gateway/` |
| **B** | Kotlin MS da semana, JPA, HATEOAS, seed, testes | `backend/services/<ms>/` + `shared/` |
| **C** | Compose, filas, scripts, contract tests, conferência | `docker-compose.yml`, `db/`, `backend/contract-tests/` |

Regra de ouro: A não inventa JSON; B não publica porta `808x` no host; C não fecha a semana sem `docker compose ps` healthy **e** aceite marcado.

---

## E01 — 25/08/2026 — Infra + Gateway

**Sumário:** copiar toda a pasta `backend/gateway/` e os arquivos de infra raiz. O Gateway sobe com `/health`, CORS e Redis. Rotas que dependem de MSs ainda retornam 502 — isso é esperado; serão desbloqueadas semana a semana.

**Aceite E01:** `GET http://localhost:3000/health` → `{ "status": "UP" }`; `localhost:8081` recusa conexão; `npm test` (tipos + auth unitário com mock) passa.

---

### A — Gateway: todos os arquivos

#### Raiz do projeto gateway

- [x] umi [`backend/gateway/package.json`](backend/gateway/package.json)
- [ ] [`backend/gateway/package-lock.json`](backend/gateway/package-lock.json)
- [ ] [`backend/gateway/tsconfig.json`](backend/gateway/tsconfig.json)
- [ ] [`backend/gateway/.prettierrc.json`](backend/gateway/.prettierrc.json)
- [ ] [`backend/gateway/Dockerfile`](backend/gateway/Dockerfile)

#### `src/`

- [ ] [`backend/gateway/src/app.ts`](backend/gateway/src/app.ts)
- [ ] [`backend/gateway/src/index.ts`](backend/gateway/src/index.ts)
- [ ] [`backend/gateway/src/config.ts`](backend/gateway/src/config.ts)

#### `src/auth/`

- [ ] [`backend/gateway/src/auth/acl.ts`](backend/gateway/src/auth/acl.ts)
- [ ] [`backend/gateway/src/auth/hook.ts`](backend/gateway/src/auth/hook.ts)
- [ ] [`backend/gateway/src/auth/jwt.ts`](backend/gateway/src/auth/jwt.ts)

#### `src/http/`

- [ ] [`backend/gateway/src/http/dates.ts`](backend/gateway/src/http/dates.ts)
- [ ] [`backend/gateway/src/http/errors.ts`](backend/gateway/src/http/errors.ts)
- [ ] [`backend/gateway/src/http/hateoas.ts`](backend/gateway/src/http/hateoas.ts)
- [ ] [`backend/gateway/src/http/ms-client.ts`](backend/gateway/src/http/ms-client.ts)
- [ ] [`backend/gateway/src/http/pt-br.ts`](backend/gateway/src/http/pt-br.ts)

#### `src/redis/`

- [ ] [`backend/gateway/src/redis/cache.ts`](backend/gateway/src/redis/cache.ts)
- [ ] [`backend/gateway/src/redis/jobs.ts`](backend/gateway/src/redis/jobs.ts)
- [ ] [`backend/gateway/src/redis/redis-store.ts`](backend/gateway/src/redis/redis-store.ts)
- [ ] [`backend/gateway/src/redis/session.ts`](backend/gateway/src/redis/session.ts)
- [ ] [`backend/gateway/src/redis/store.ts`](backend/gateway/src/redis/store.ts)

#### `src/amqp/`

- [ ] [`backend/gateway/src/amqp/publisher.ts`](backend/gateway/src/amqp/publisher.ts)

#### `src/routes/`

- [ ] [`backend/gateway/src/routes/aprovacao.ts`](backend/gateway/src/routes/aprovacao.ts)
- [ ] [`backend/gateway/src/routes/composition.ts`](backend/gateway/src/routes/composition.ts)
- [ ] [`backend/gateway/src/routes/inserir-gerente.ts`](backend/gateway/src/routes/inserir-gerente.ts)
- [ ] [`backend/gateway/src/routes/jobs.ts`](backend/gateway/src/routes/jobs.ts)
- [ ] [`backend/gateway/src/routes/login.ts`](backend/gateway/src/routes/login.ts)
- [ ] [`backend/gateway/src/routes/logout.ts`](backend/gateway/src/routes/logout.ts)
- [ ] [`backend/gateway/src/routes/proxy.ts`](backend/gateway/src/routes/proxy.ts)
- [ ] [`backend/gateway/src/routes/reboot.ts`](backend/gateway/src/routes/reboot.ts)
- [ ] [`backend/gateway/src/routes/relatorio.ts`](backend/gateway/src/routes/relatorio.ts)
- [ ] [`backend/gateway/src/routes/remover-gerente.ts`](backend/gateway/src/routes/remover-gerente.ts)

#### `src/types/`

- [ ] [`backend/gateway/src/types/command-types.ts`](backend/gateway/src/types/command-types.ts)
- [ ] [`backend/gateway/src/types/enums.ts`](backend/gateway/src/types/enums.ts)
- [ ] [`backend/gateway/src/types/envelopes.ts`](backend/gateway/src/types/envelopes.ts)
- [ ] [`backend/gateway/src/types/fastify.ts`](backend/gateway/src/types/fastify.ts)
- [ ] [`backend/gateway/src/types/index.ts`](backend/gateway/src/types/index.ts)
- [ ] [`backend/gateway/src/types/patterns.ts`](backend/gateway/src/types/patterns.ts)
- [ ] [`backend/gateway/src/types/queues.ts`](backend/gateway/src/types/queues.ts)
- [ ] [`backend/gateway/src/types/schemas.ts`](backend/gateway/src/types/schemas.ts)

#### `test/`

- [ ] [`backend/gateway/test/auth.test.ts`](backend/gateway/test/auth.test.ts)
- [ ] [`backend/gateway/test/composition.test.ts`](backend/gateway/test/composition.test.ts)
- [ ] [`backend/gateway/test/hateoas.test.ts`](backend/gateway/test/hateoas.test.ts)
- [ ] [`backend/gateway/test/jobs.test.ts`](backend/gateway/test/jobs.test.ts)
- [ ] [`backend/gateway/test/memory-store.ts`](backend/gateway/test/memory-store.ts)
- [ ] [`backend/gateway/test/reboot.test.ts`](backend/gateway/test/reboot.test.ts)
- [ ] [`backend/gateway/test/relatorio.test.ts`](backend/gateway/test/relatorio.test.ts)
- [ ] [`backend/gateway/test/sync.test.ts`](backend/gateway/test/sync.test.ts)
- [ ] [`backend/gateway/test/types.test.ts`](backend/gateway/test/types.test.ts)

---

### B — Infra raiz

- [ ] [`docker-compose.yml`](docker-compose.yml)
- [ ] [`.env.example`](.env.example)
- [ ] [`start.sh`](start.sh)
- [ ] [`compile-services.ps1`](compile-services.ps1)
- [ ] [`compile-services.sh`](compile-services.sh)

#### `db/`

- [ ] [`db/postgres/init/01-extensions-schemas.sql`](db/postgres/init/01-extensions-schemas.sql)
- [ ] [`db/postgres/init/02-users.sh`](db/postgres/init/02-users.sh)
- [ ] [`db/rabbitmq/definitions.json`](db/rabbitmq/definitions.json) _(filas podem nascer vazias aqui; serão populadas em E02–E07)_
- [ ] [`db/rabbitmq/rabbitmq.conf`](db/rabbitmq/rabbitmq.conf)

---

### C — Conferência E01

- [ ] `docker compose ps` → serviços `gateway`, `postgres`, `mongo`, `redis`, `rabbit` todos `healthy`
- [ ] `GET http://localhost:3000/health` → `{ "status": "UP" }`
- [ ] `GET http://localhost:8081/health` recusa (MS não publicado no host)
- [ ] `cd backend/gateway && npm ci && npm test` → `types.test` e `auth.test` passam (mocks internos, sem MS real)

---

## E02 — 01/09/2026 — Shared + MS Auth

**Sumário:** copiar o módulo `shared` (Money string, envelopes AMQP, nomes de fila, enums) e o MS Auth (MongoDB, Argon2id, verificar, consumidor AMQP, reboot). Com Auth no ar, `POST /login` no Gateway começa a funcionar.

**Aceite E02:** `POST /login` com credencial de teste → 200 `{ auth, token, tipo, usuario }`; `POST /login` com senha errada → 401 `"Login inválido!"`; `AuthIT` verde.

---

### A — Gateway: verificar env de Auth

- [ ] Confirmar variável `AUTH_URL` no `.env` / `docker-compose.yml` aponta para o container `auth`
- [ ] CORS ainda retorna `Access-Control-Allow-Headers: x-access-token` no OPTIONS
- [ ] `POST /login` → 200 com usuário de teste criado manualmente no Mongo (seed completo na E06)

---

### B — Shared + MS Auth

#### Raiz dos serviços Kotlin _(copiar uma única vez nesta semana)_

- [ ] [`backend/services/settings.gradle.kts`](backend/services/settings.gradle.kts)
- [ ] [`backend/services/build.gradle.kts`](backend/services/build.gradle.kts)
- [ ] [`backend/services/gradle.properties`](backend/services/gradle.properties)
- [ ] [`backend/services/gradlew`](backend/services/gradlew)
- [ ] [`backend/services/gradlew.bat`](backend/services/gradlew.bat)
- [ ] [`backend/services/gradle/docker-java.properties`](backend/services/gradle/docker-java.properties)
- [ ] [`backend/services/gradle/wrapper/gradle-wrapper.properties`](backend/services/gradle/wrapper/gradle-wrapper.properties)

#### `shared/`

- [ ] [`backend/services/shared/build.gradle.kts`](backend/services/shared/build.gradle.kts)
- [ ] [`backend/services/shared/src/main/kotlin/br/ufpr/dac/bantads/shared/amqp/CommandTypes.kt`](backend/services/shared/src/main/kotlin/br/ufpr/dac/bantads/shared/amqp/CommandTypes.kt)
- [ ] [`backend/services/shared/src/main/kotlin/br/ufpr/dac/bantads/shared/amqp/MessageEnvelope.kt`](backend/services/shared/src/main/kotlin/br/ufpr/dac/bantads/shared/amqp/MessageEnvelope.kt)
- [ ] [`backend/services/shared/src/main/kotlin/br/ufpr/dac/bantads/shared/amqp/QueueNames.kt`](backend/services/shared/src/main/kotlin/br/ufpr/dac/bantads/shared/amqp/QueueNames.kt)
- [ ] [`backend/services/shared/src/main/kotlin/br/ufpr/dac/bantads/shared/amqp/ReplyEnvelope.kt`](backend/services/shared/src/main/kotlin/br/ufpr/dac/bantads/shared/amqp/ReplyEnvelope.kt)
- [ ] [`backend/services/shared/src/main/kotlin/br/ufpr/dac/bantads/shared/amqp/ReplyStatus.kt`](backend/services/shared/src/main/kotlin/br/ufpr/dac/bantads/shared/amqp/ReplyStatus.kt)
- [ ] [`backend/services/shared/src/main/kotlin/br/ufpr/dac/bantads/shared/domain/EventType.kt`](backend/services/shared/src/main/kotlin/br/ufpr/dac/bantads/shared/domain/EventType.kt)
- [ ] [`backend/services/shared/src/main/kotlin/br/ufpr/dac/bantads/shared/domain/JobStatus.kt`](backend/services/shared/src/main/kotlin/br/ufpr/dac/bantads/shared/domain/JobStatus.kt)
- [ ] [`backend/services/shared/src/main/kotlin/br/ufpr/dac/bantads/shared/domain/Perfil.kt`](backend/services/shared/src/main/kotlin/br/ufpr/dac/bantads/shared/domain/Perfil.kt)
- [ ] [`backend/services/shared/src/main/kotlin/br/ufpr/dac/bantads/shared/domain/ResultType.kt`](backend/services/shared/src/main/kotlin/br/ufpr/dac/bantads/shared/domain/ResultType.kt)
- [ ] [`backend/services/shared/src/main/kotlin/br/ufpr/dac/bantads/shared/domain/SagaType.kt`](backend/services/shared/src/main/kotlin/br/ufpr/dac/bantads/shared/domain/SagaType.kt)
- [ ] [`backend/services/shared/src/main/kotlin/br/ufpr/dac/bantads/shared/error/AuthErrorBody.kt`](backend/services/shared/src/main/kotlin/br/ufpr/dac/bantads/shared/error/AuthErrorBody.kt)
- [ ] [`backend/services/shared/src/main/kotlin/br/ufpr/dac/bantads/shared/error/ErroBody.kt`](backend/services/shared/src/main/kotlin/br/ufpr/dac/bantads/shared/error/ErroBody.kt)
- [ ] [`backend/services/shared/src/main/kotlin/br/ufpr/dac/bantads/shared/health/HealthResponse.kt`](backend/services/shared/src/main/kotlin/br/ufpr/dac/bantads/shared/health/HealthResponse.kt)
- [ ] [`backend/services/shared/src/main/kotlin/br/ufpr/dac/bantads/shared/json/BantadsJacksonConfiguration.kt`](backend/services/shared/src/main/kotlin/br/ufpr/dac/bantads/shared/json/BantadsJacksonConfiguration.kt)
- [ ] [`backend/services/shared/src/main/kotlin/br/ufpr/dac/bantads/shared/json/BantadsJson.kt`](backend/services/shared/src/main/kotlin/br/ufpr/dac/bantads/shared/json/BantadsJson.kt)
- [ ] [`backend/services/shared/src/main/kotlin/br/ufpr/dac/bantads/shared/money/Money.kt`](backend/services/shared/src/main/kotlin/br/ufpr/dac/bantads/shared/money/Money.kt)
- [ ] [`backend/services/shared/src/main/kotlin/br/ufpr/dac/bantads/shared/money/MoneyDeserializer.kt`](backend/services/shared/src/main/kotlin/br/ufpr/dac/bantads/shared/money/MoneyDeserializer.kt)
- [ ] [`backend/services/shared/src/main/kotlin/br/ufpr/dac/bantads/shared/money/MoneyJson.kt`](backend/services/shared/src/main/kotlin/br/ufpr/dac/bantads/shared/money/MoneyJson.kt)
- [ ] [`backend/services/shared/src/main/kotlin/br/ufpr/dac/bantads/shared/money/MoneySerializer.kt`](backend/services/shared/src/main/kotlin/br/ufpr/dac/bantads/shared/money/MoneySerializer.kt)
- [ ] [`backend/services/shared/src/main/kotlin/br/ufpr/dac/bantads/shared/text/PtBrNames.kt`](backend/services/shared/src/main/kotlin/br/ufpr/dac/bantads/shared/text/PtBrNames.kt)
- [ ] [`backend/services/shared/src/main/kotlin/br/ufpr/dac/bantads/shared/time/DateTimes.kt`](backend/services/shared/src/main/kotlin/br/ufpr/dac/bantads/shared/time/DateTimes.kt)
- [ ] [`backend/services/shared/src/test/kotlin/br/ufpr/dac/bantads/shared/amqp/EnvelopeJsonTest.kt`](backend/services/shared/src/test/kotlin/br/ufpr/dac/bantads/shared/amqp/EnvelopeJsonTest.kt)
- [ ] [`backend/services/shared/src/test/kotlin/br/ufpr/dac/bantads/shared/error/ErroBodyJsonTest.kt`](backend/services/shared/src/test/kotlin/br/ufpr/dac/bantads/shared/error/ErroBodyJsonTest.kt)
- [ ] [`backend/services/shared/src/test/kotlin/br/ufpr/dac/bantads/shared/money/MoneyJsonTest.kt`](backend/services/shared/src/test/kotlin/br/ufpr/dac/bantads/shared/money/MoneyJsonTest.kt)
- [ ] [`backend/services/shared/src/test/kotlin/br/ufpr/dac/bantads/shared/money/MoneyTest.kt`](backend/services/shared/src/test/kotlin/br/ufpr/dac/bantads/shared/money/MoneyTest.kt)
- [ ] [`backend/services/shared/src/test/kotlin/br/ufpr/dac/bantads/shared/text/PtBrNamesTest.kt`](backend/services/shared/src/test/kotlin/br/ufpr/dac/bantads/shared/text/PtBrNamesTest.kt)

#### `auth/`

- [ ] [`backend/services/auth/build.gradle.kts`](backend/services/auth/build.gradle.kts)
- [ ] [`backend/services/auth/Dockerfile`](backend/services/auth/Dockerfile)
- [ ] [`backend/services/auth/src/main/kotlin/br/ufpr/dac/bantads/auth/AuthApplication.kt`](backend/services/auth/src/main/kotlin/br/ufpr/dac/bantads/auth/AuthApplication.kt)
- [ ] [`backend/services/auth/src/main/kotlin/br/ufpr/dac/bantads/auth/config/PasswordConfig.kt`](backend/services/auth/src/main/kotlin/br/ufpr/dac/bantads/auth/config/PasswordConfig.kt)
- [ ] [`backend/services/auth/src/main/kotlin/br/ufpr/dac/bantads/auth/dto/RebootResponse.kt`](backend/services/auth/src/main/kotlin/br/ufpr/dac/bantads/auth/dto/RebootResponse.kt)
- [ ] [`backend/services/auth/src/main/kotlin/br/ufpr/dac/bantads/auth/dto/VerificarRequest.kt`](backend/services/auth/src/main/kotlin/br/ufpr/dac/bantads/auth/dto/VerificarRequest.kt)
- [ ] [`backend/services/auth/src/main/kotlin/br/ufpr/dac/bantads/auth/dto/VerificarResponse.kt`](backend/services/auth/src/main/kotlin/br/ufpr/dac/bantads/auth/dto/VerificarResponse.kt)
- [ ] [`backend/services/auth/src/main/kotlin/br/ufpr/dac/bantads/auth/health/HealthController.kt`](backend/services/auth/src/main/kotlin/br/ufpr/dac/bantads/auth/health/HealthController.kt)
- [ ] [`backend/services/auth/src/main/kotlin/br/ufpr/dac/bantads/auth/password/RandomPassword.kt`](backend/services/auth/src/main/kotlin/br/ufpr/dac/bantads/auth/password/RandomPassword.kt)
- [ ] [`backend/services/auth/src/main/kotlin/br/ufpr/dac/bantads/auth/reboot/RebootController.kt`](backend/services/auth/src/main/kotlin/br/ufpr/dac/bantads/auth/reboot/RebootController.kt)
- [ ] [`backend/services/auth/src/main/kotlin/br/ufpr/dac/bantads/auth/saga/AuthCommandHandler.kt`](backend/services/auth/src/main/kotlin/br/ufpr/dac/bantads/auth/saga/AuthCommandHandler.kt)
- [ ] [`backend/services/auth/src/main/kotlin/br/ufpr/dac/bantads/auth/saga/AuthCommandListener.kt`](backend/services/auth/src/main/kotlin/br/ufpr/dac/bantads/auth/saga/AuthCommandListener.kt)
- [ ] [`backend/services/auth/src/main/kotlin/br/ufpr/dac/bantads/auth/saga/SagaInbox.kt`](backend/services/auth/src/main/kotlin/br/ufpr/dac/bantads/auth/saga/SagaInbox.kt)
- [ ] [`backend/services/auth/src/main/kotlin/br/ufpr/dac/bantads/auth/saga/SagaInboxRepository.kt`](backend/services/auth/src/main/kotlin/br/ufpr/dac/bantads/auth/saga/SagaInboxRepository.kt)
- [ ] [`backend/services/auth/src/main/kotlin/br/ufpr/dac/bantads/auth/seed/SeedUsers.kt`](backend/services/auth/src/main/kotlin/br/ufpr/dac/bantads/auth/seed/SeedUsers.kt)
- [ ] [`backend/services/auth/src/main/kotlin/br/ufpr/dac/bantads/auth/user/AuthController.kt`](backend/services/auth/src/main/kotlin/br/ufpr/dac/bantads/auth/user/AuthController.kt)
- [ ] [`backend/services/auth/src/main/kotlin/br/ufpr/dac/bantads/auth/user/AuthService.kt`](backend/services/auth/src/main/kotlin/br/ufpr/dac/bantads/auth/user/AuthService.kt)
- [ ] [`backend/services/auth/src/main/kotlin/br/ufpr/dac/bantads/auth/user/Usuario.kt`](backend/services/auth/src/main/kotlin/br/ufpr/dac/bantads/auth/user/Usuario.kt)
- [ ] [`backend/services/auth/src/main/kotlin/br/ufpr/dac/bantads/auth/user/UsuarioRepository.kt`](backend/services/auth/src/main/kotlin/br/ufpr/dac/bantads/auth/user/UsuarioRepository.kt)
- [ ] [`backend/services/auth/src/main/kotlin/br/ufpr/dac/bantads/auth/web/AuthExceptionHandler.kt`](backend/services/auth/src/main/kotlin/br/ufpr/dac/bantads/auth/web/AuthExceptionHandler.kt)
- [ ] [`backend/services/auth/src/main/resources/application.yml`](backend/services/auth/src/main/resources/application.yml)
- [ ] [`backend/services/auth/src/test/kotlin/br/ufpr/dac/bantads/auth/AuthIT.kt`](backend/services/auth/src/test/kotlin/br/ufpr/dac/bantads/auth/AuthIT.kt)
- [ ] [`backend/services/auth/src/test/kotlin/br/ufpr/dac/bantads/auth/password/RandomPasswordTest.kt`](backend/services/auth/src/test/kotlin/br/ufpr/dac/bantads/auth/password/RandomPasswordTest.kt)
- [ ] [`backend/services/auth/src/test/resources/application-test.yml`](backend/services/auth/src/test/resources/application-test.yml)

---

### C — MongoDB + filas Auth

- [ ] MongoDB no compose up; `docker compose exec mongo mongosh --eval "db.adminCommand('ping')"` OK
- [ ] Fila `ms.auth.cmd` + DLQ em [`db/rabbitmq/definitions.json`](db/rabbitmq/definitions.json)
- [ ] `AuthIT` + `RandomPasswordTest` verdes (Testcontainers)
- [ ] `POST /login` com credencial de teste → 200 com token JWT
- [ ] `POST /login` senha errada → 401 `{ "auth": false, "message": "Login inválido!" }`
- [ ] `POST /login` sem body → 400 `{ status, erro, mensagem }`

---

## E03 — 08/09/2026 — MS Cliente

**Sumário:** copiar todos os arquivos do MS Cliente (solicitações, cadastro, HATEOAS, seed, consumidores AMQP). Com Cliente no ar, os fluxos R1 (autocadastro), R8 (listar/consultar solicitações), R10 (rejeição) e CAD-01 (consultar cliente) ficam disponíveis no Gateway.

**Aceite E03:** `POST /solicitacoes` → 201 + `Location`; `GET /clientes/{cpf}` (como gerente) → 200 com `_links`; 409 em duplicata; `ClienteIT` verde.

---

### A — Gateway: verificar proxy + cache cliente

- [ ] Confirmar `proxy.ts` encaminha para `CLIENTE_URL` nas rotas corretas
- [ ] Rewrite de `_links` para `:3000` nos responses (nenhum href com porta interna)
- [ ] `cache:cliente:{cpf}` TTL 5 min no GET cadastro; não cachear 404

---

### B — MS Cliente

- [ ] [`backend/services/cliente/build.gradle.kts`](backend/services/cliente/build.gradle.kts)
- [ ] [`backend/services/cliente/Dockerfile`](backend/services/cliente/Dockerfile)
- [ ] [`backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/ClienteApplication.kt`](backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/ClienteApplication.kt)
- [ ] [`backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/cadastro/CadastroController.kt`](backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/cadastro/CadastroController.kt)
- [ ] [`backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/cadastro/CadastroService.kt`](backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/cadastro/CadastroService.kt)
- [ ] [`backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/cadastro/ClienteEntity.kt`](backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/cadastro/ClienteEntity.kt)
- [ ] [`backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/cadastro/ClienteRepository.kt`](backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/cadastro/ClienteRepository.kt)
- [ ] [`backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/domain/EnderecoEmbeddable.kt`](backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/domain/EnderecoEmbeddable.kt)
- [ ] [`backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/dto/AutocadastroInput.kt`](backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/dto/AutocadastroInput.kt)
- [ ] [`backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/dto/EnderecoInput.kt`](backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/dto/EnderecoInput.kt)
- [ ] [`backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/dto/RebootResponse.kt`](backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/dto/RebootResponse.kt)
- [ ] [`backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/dto/RejeicaoInput.kt`](backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/dto/RejeicaoInput.kt)
- [ ] [`backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/dto/Views.kt`](backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/dto/Views.kt)
- [ ] [`backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/email/AmqpEmailCommandPublisher.kt`](backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/email/AmqpEmailCommandPublisher.kt)
- [ ] [`backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/email/EmailCommandPublisher.kt`](backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/email/EmailCommandPublisher.kt)
- [ ] [`backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/email/EmailPublisherConfig.kt`](backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/email/EmailPublisherConfig.kt)
- [ ] [`backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/hateoas/ClienteAssembler.kt`](backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/hateoas/ClienteAssembler.kt)
- [ ] [`backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/health/HealthController.kt`](backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/health/HealthController.kt)
- [ ] [`backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/reboot/RebootController.kt`](backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/reboot/RebootController.kt)
- [ ] [`backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/saga/ClienteCommandHandler.kt`](backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/saga/ClienteCommandHandler.kt)
- [ ] [`backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/saga/ClienteCommandListener.kt`](backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/saga/ClienteCommandListener.kt)
- [ ] [`backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/saga/SagaInboxEntity.kt`](backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/saga/SagaInboxEntity.kt)
- [ ] [`backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/saga/SagaInboxRepository.kt`](backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/saga/SagaInboxRepository.kt)
- [ ] [`backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/seed/SeedClientes.kt`](backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/seed/SeedClientes.kt)
- [ ] [`backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/solicitacao/SolicitacaoController.kt`](backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/solicitacao/SolicitacaoController.kt)
- [ ] [`backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/solicitacao/SolicitacaoEntity.kt`](backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/solicitacao/SolicitacaoEntity.kt)
- [ ] [`backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/solicitacao/SolicitacaoRepository.kt`](backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/solicitacao/SolicitacaoRepository.kt)
- [ ] [`backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/solicitacao/SolicitacaoRules.kt`](backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/solicitacao/SolicitacaoRules.kt)
- [ ] [`backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/solicitacao/SolicitacaoService.kt`](backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/solicitacao/SolicitacaoService.kt)
- [ ] [`backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/solicitacao/StatusSolicitacao.kt`](backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/solicitacao/StatusSolicitacao.kt)
- [ ] [`backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/web/ApiException.kt`](backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/web/ApiException.kt)
- [ ] [`backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/web/ClienteExceptionHandler.kt`](backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/web/ClienteExceptionHandler.kt)
- [ ] [`backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/web/Identity.kt`](backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/web/Identity.kt)
- [ ] [`backend/services/cliente/src/main/resources/application.yml`](backend/services/cliente/src/main/resources/application.yml)
- [ ] [`backend/services/cliente/src/main/resources/db/migration/V1__cliente_schema.sql`](backend/services/cliente/src/main/resources/db/migration/V1__cliente_schema.sql)
- [ ] [`backend/services/cliente/src/test/kotlin/br/ufpr/dac/bantads/cliente/ClienteIT.kt`](backend/services/cliente/src/test/kotlin/br/ufpr/dac/bantads/cliente/ClienteIT.kt)
- [ ] [`backend/services/cliente/src/test/kotlin/br/ufpr/dac/bantads/cliente/solicitacao/SolicitacaoRulesTest.kt`](backend/services/cliente/src/test/kotlin/br/ufpr/dac/bantads/cliente/solicitacao/SolicitacaoRulesTest.kt)
- [ ] [`backend/services/cliente/src/test/resources/application-test.yml`](backend/services/cliente/src/test/resources/application-test.yml)
- [ ] [`backend/services/cliente/src/test/resources/postgres-init.sql`](backend/services/cliente/src/test/resources/postgres-init.sql)

---

### C — Postgres cliente + filas

- [ ] Schema `cliente` no Postgres healthy; Flyway roda `V1__cliente_schema.sql`
- [ ] Filas `ms.cliente.cmd` e `ms.email.cmd` (+ DLQs) em `definitions.json`
- [ ] `ClienteIT` + `SolicitacaoRulesTest` verdes
- [ ] `POST /solicitacoes` → 201 + header `Location`
- [ ] Segunda `POST /solicitacoes` mesmo CPF → 409
- [ ] `GET /solicitacoes` (como gerente) → 200 lista

---

## E04 — 15/09/2026 — MS Conta command (CQRS write)

**Sumário:** copiar o lado **command** do MS Conta (event store, replay, depósito/saque/transferência, seed, AMQP). O lado query (saldo, extrato) fica para E05. Após esta semana, depósito/saque/transferência retornam 201, mas `GET /conta` ainda não tem saldo atualizado.

**Aceite E04:** `POST /contas/{numero}/deposito` → 201 sem campo `saldo`; `EventReplayTest` e `R13SelecaoTest` verdes.

---

### A — Gateway: proxy command + validação R6

- [ ] Confirmar `proxy.ts` encaminha depósito/saque para `CONTA_URL` (só CLIENTE dono)
- [ ] R6: body do front `{ contaDestino, valor }`; Gateway valida origem=destino (422) e busca nomes; POST enriquecido para o command
- [ ] 201 **sem** campo `saldo` no response; `_links.conta` e `_links.extrato` presentes

---

### B — MS Conta command

- [ ] [`backend/services/conta/build.gradle.kts`](backend/services/conta/build.gradle.kts)
- [ ] `backend/services/conta/Dockerfile` _(verificar se existe no protótipo; criar se necessário)_
- [ ] [`backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/ContaApplication.kt`](backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/ContaApplication.kt)
- [ ] [`backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/command/event/AccountState.kt`](backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/command/event/AccountState.kt)
- [ ] [`backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/command/event/EventReplay.kt`](backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/command/event/EventReplay.kt)
- [ ] [`backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/command/event/EventTypes.kt`](backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/command/event/EventTypes.kt)
- [ ] [`backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/command/http/ContaCommandController.kt`](backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/command/http/ContaCommandController.kt)
- [ ] [`backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/command/http/ContaCommandService.kt`](backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/command/http/ContaCommandService.kt)
- [ ] [`backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/command/http/Dtos.kt`](backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/command/http/Dtos.kt)
- [ ] [`backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/command/http/OperacaoAssembler.kt`](backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/command/http/OperacaoAssembler.kt)
- [ ] [`backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/command/numbering/AccountNumberGenerator.kt`](backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/command/numbering/AccountNumberGenerator.kt)
- [ ] [`backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/command/publish/AmqpContaEventPublisher.kt`](backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/command/publish/AmqpContaEventPublisher.kt)
- [ ] [`backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/command/publish/ContaEventPublisher.kt`](backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/command/publish/ContaEventPublisher.kt)
- [ ] [`backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/command/publish/ContaEventPublisherConfig.kt`](backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/command/publish/ContaEventPublisherConfig.kt)
- [ ] [`backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/command/r13/R13Selecao.kt`](backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/command/r13/R13Selecao.kt)
- [ ] [`backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/command/seed/SeedContas.kt`](backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/command/seed/SeedContas.kt)
- [ ] [`backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/command/store/EventoEntity.kt`](backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/command/store/EventoEntity.kt)
- [ ] [`backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/command/store/EventoRepository.kt`](backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/command/store/EventoRepository.kt)
- [ ] [`backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/command/store/EventStore.kt`](backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/command/store/EventStore.kt)
- [ ] [`backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/config/CommandPersistenceConfig.kt`](backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/config/CommandPersistenceConfig.kt)
- [ ] [`backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/health/HealthController.kt`](backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/health/HealthController.kt)
- [ ] [`backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/reboot/RebootController.kt`](backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/reboot/RebootController.kt)
- [ ] [`backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/reboot/RebootService.kt`](backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/reboot/RebootService.kt)
- [ ] [`backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/saga/ContaCommandHandler.kt`](backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/saga/ContaCommandHandler.kt)
- [ ] [`backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/saga/ContaCommandListener.kt`](backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/saga/ContaCommandListener.kt)
- [ ] [`backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/saga/SagaInboxEntity.kt`](backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/saga/SagaInboxEntity.kt)
- [ ] [`backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/saga/SagaInboxRepository.kt`](backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/saga/SagaInboxRepository.kt)
- [ ] [`backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/web/ApiException.kt`](backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/web/ApiException.kt)
- [ ] [`backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/web/ContaExceptionHandler.kt`](backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/web/ContaExceptionHandler.kt)
- [ ] [`backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/web/Identity.kt`](backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/web/Identity.kt)
- [ ] [`backend/services/conta/src/main/resources/application.yml`](backend/services/conta/src/main/resources/application.yml)
- [ ] [`backend/services/conta/src/main/resources/db/migration/V1__conta_command.sql`](backend/services/conta/src/main/resources/db/migration/V1__conta_command.sql)
- [ ] [`backend/services/conta/src/test/kotlin/br/ufpr/dac/bantads/conta/ContaIT.kt`](backend/services/conta/src/test/kotlin/br/ufpr/dac/bantads/conta/ContaIT.kt)
- [ ] [`backend/services/conta/src/test/kotlin/br/ufpr/dac/bantads/conta/command/event/EventReplayTest.kt`](backend/services/conta/src/test/kotlin/br/ufpr/dac/bantads/conta/command/event/EventReplayTest.kt)
- [ ] [`backend/services/conta/src/test/kotlin/br/ufpr/dac/bantads/conta/command/r13/R13SelecaoTest.kt`](backend/services/conta/src/test/kotlin/br/ufpr/dac/bantads/conta/command/r13/R13SelecaoTest.kt)
- [ ] [`backend/services/conta/src/test/resources/application-test.yml`](backend/services/conta/src/test/resources/application-test.yml)
- [ ] [`backend/services/conta/src/test/resources/postgres-init.sql`](backend/services/conta/src/test/resources/postgres-init.sql)

---

### C — Postgres conta_command + filas

- [ ] Schema `conta_command` no compose; Flyway roda `V1__conta_command.sql`
- [ ] Filas `ms.conta.events` e `ms.conta.cmd` (+ DLQs) em `definitions.json`
- [ ] `EventReplayTest` + `R13SelecaoTest` verdes
- [ ] `POST /contas/{numero}/deposito` → 201 (body sem campo `saldo`)
- [ ] `POST /contas/{numero}/saque` valor acima do saldo → 422
- [ ] Evento publicado em `ms.conta.events` após cada operação (verificar painel Rabbit)

---

## E05 — 22/09/2026 — MS Conta query (CQRS read) + reboot completo

**Sumário:** copiar o lado **query** do MS Conta (projector, read model, extrato, endpoints internos). Com query no ar, saldo e extrato ficam disponíveis. `POST /reboot` agora popula command **e** query simultaneamente, tornando o reboot completo.

**Aceite E05:** `GET /clientes/{cpf}/conta` → saldo correto como string; `GET /contas/{numero}/extrato` → movimentos Catharyna jan/2020; Catharyna `"800.00"` na query = replay do command; `ExtratoRegrasTest` verde.

---

### A — Gateway: proxy query + HATEOAS por perfil

- [ ] Confirmar que `proxy.ts` roteia R3A/R3B/R7 corretamente
- [ ] Gerente: sem rels `deposito`, `saque`, `transferencia` no response
- [ ] Extrato: ACL bloqueia GERENTE → 403

---

### B — MS Conta query _(só os arquivos do lado query — command já foi copiado em E04)_

- [ ] [`backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/config/QueryPersistenceConfig.kt`](backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/config/QueryPersistenceConfig.kt)
- [ ] [`backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/query/amqp/ContaEventListener.kt`](backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/query/amqp/ContaEventListener.kt)
- [ ] [`backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/query/extrato/ExtratoRegras.kt`](backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/query/extrato/ExtratoRegras.kt)
- [ ] [`backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/query/http/ClienteContaQueryController.kt`](backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/query/http/ClienteContaQueryController.kt)
- [ ] [`backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/query/http/ContaQueryAssembler.kt`](backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/query/http/ContaQueryAssembler.kt)
- [ ] [`backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/query/http/ContaQueryController.kt`](backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/query/http/ContaQueryController.kt)
- [ ] [`backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/query/http/ContaQueryService.kt`](backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/query/http/ContaQueryService.kt)
- [ ] [`backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/query/http/Dtos.kt`](backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/query/http/Dtos.kt)
- [ ] [`backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/query/http/InternalQueryController.kt`](backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/query/http/InternalQueryController.kt)
- [ ] [`backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/query/project/EventProjector.kt`](backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/query/project/EventProjector.kt)
- [ ] [`backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/query/store/ContaReadEntity.kt`](backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/query/store/ContaReadEntity.kt)
- [ ] [`backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/query/store/ContaReadRepository.kt`](backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/query/store/ContaReadRepository.kt)
- [ ] [`backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/query/store/MovimentacaoEntity.kt`](backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/query/store/MovimentacaoEntity.kt)
- [ ] [`backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/query/store/MovimentacaoRepository.kt`](backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/query/store/MovimentacaoRepository.kt)
- [ ] [`backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/query/store/ProjecaoAplicadaEntity.kt`](backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/query/store/ProjecaoAplicadaEntity.kt)
- [ ] [`backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/query/store/ProjecaoAplicadaRepository.kt`](backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/query/store/ProjecaoAplicadaRepository.kt)
- [ ] [`backend/services/conta/src/main/resources/db/query/V1__conta_query.sql`](backend/services/conta/src/main/resources/db/query/V1__conta_query.sql)
- [ ] [`backend/services/conta/src/test/kotlin/br/ufpr/dac/bantads/conta/query/extrato/ExtratoRegrasTest.kt`](backend/services/conta/src/test/kotlin/br/ufpr/dac/bantads/conta/query/extrato/ExtratoRegrasTest.kt)

---

### C — Postgres conta_query + projector + reboot

- [ ] Schema `conta_query` no compose; Flyway roda `V1__conta_query.sql`
- [ ] `ms.conta.events` consumido pelo `EventProjector`; evento duplicado não soma duas vezes
- [ ] `ExtratoRegrasTest` verde
- [ ] `POST /reboot` (Auth + Cliente + **Conta** + sem Gerente) → `{ "status": "ok", "clientes": 5, "contas": 5 }` parcial _(Gerente virá em E06)_
- [ ] Replay seed Catharyna → saldo `"800.00"` na query
- [ ] `GET /contas/{numero}/extrato?dataInicio=2020-01-01&dataFim=2020-01-31` → 7 movimentos jan/2020

---

## E06 — 29/09/2026 — MS Gerente + composition R11/R12

**Sumário:** copiar todos os arquivos do MS Gerente (CRUD, HATEOAS, seed, AMQP). Com Gerente no ar, as compositions R11 (clientes + saldos) e R12 (gerentes + contagem) ficam disponíveis. `POST /reboot` agora funciona **completamente** (todos os 4 MSs).

**Aceite E06:** `POST /reboot` → `{ "status": "ok", "clientes": 5, "gerentes": 4, "contas": 5 }` (segundo reboot = mesmo JSON); `GET /gerentes` → 4 gerentes com `quantidadeClientes`; `GET /clientes?busca=Cat` → Catharyna + Catianna; `GerenteIT` verde.

---

### A — Gateway: composition R11/R12 + cache gerente

- [ ] Confirmar `composition.ts` agrega R11 (cliente + saldo, sort `Intl.Collator pt-BR`) e R12 (gerentes + contagem)
- [ ] `cache:gerente:{cpf}` TTL 5 min; `DEL` no PUT 200
- [ ] `reboot.ts` chama Gerente em paralelo; timeout gateway ≥ 90 s

---

### B — MS Gerente

- [ ] [`backend/services/gerente/build.gradle.kts`](backend/services/gerente/build.gradle.kts)
- [ ] [`backend/services/gerente/Dockerfile`](backend/services/gerente/Dockerfile)
- [ ] [`backend/services/gerente/src/main/kotlin/br/ufpr/dac/bantads/gerente/GerenteApplication.kt`](backend/services/gerente/src/main/kotlin/br/ufpr/dac/bantads/gerente/GerenteApplication.kt)
- [ ] [`backend/services/gerente/src/main/kotlin/br/ufpr/dac/bantads/gerente/cadastro/GerenteController.kt`](backend/services/gerente/src/main/kotlin/br/ufpr/dac/bantads/gerente/cadastro/GerenteController.kt)
- [ ] [`backend/services/gerente/src/main/kotlin/br/ufpr/dac/bantads/gerente/cadastro/GerenteEntity.kt`](backend/services/gerente/src/main/kotlin/br/ufpr/dac/bantads/gerente/cadastro/GerenteEntity.kt)
- [ ] [`backend/services/gerente/src/main/kotlin/br/ufpr/dac/bantads/gerente/cadastro/GerenteRepository.kt`](backend/services/gerente/src/main/kotlin/br/ufpr/dac/bantads/gerente/cadastro/GerenteRepository.kt)
- [ ] [`backend/services/gerente/src/main/kotlin/br/ufpr/dac/bantads/gerente/cadastro/GerenteRules.kt`](backend/services/gerente/src/main/kotlin/br/ufpr/dac/bantads/gerente/cadastro/GerenteRules.kt)
- [ ] [`backend/services/gerente/src/main/kotlin/br/ufpr/dac/bantads/gerente/cadastro/GerenteService.kt`](backend/services/gerente/src/main/kotlin/br/ufpr/dac/bantads/gerente/cadastro/GerenteService.kt)
- [ ] [`backend/services/gerente/src/main/kotlin/br/ufpr/dac/bantads/gerente/dto/Dtos.kt`](backend/services/gerente/src/main/kotlin/br/ufpr/dac/bantads/gerente/dto/Dtos.kt)
- [ ] [`backend/services/gerente/src/main/kotlin/br/ufpr/dac/bantads/gerente/hateoas/GerenteAssembler.kt`](backend/services/gerente/src/main/kotlin/br/ufpr/dac/bantads/gerente/hateoas/GerenteAssembler.kt)
- [ ] [`backend/services/gerente/src/main/kotlin/br/ufpr/dac/bantads/gerente/health/HealthController.kt`](backend/services/gerente/src/main/kotlin/br/ufpr/dac/bantads/gerente/health/HealthController.kt)
- [ ] [`backend/services/gerente/src/main/kotlin/br/ufpr/dac/bantads/gerente/reboot/RebootController.kt`](backend/services/gerente/src/main/kotlin/br/ufpr/dac/bantads/gerente/reboot/RebootController.kt)
- [ ] [`backend/services/gerente/src/main/kotlin/br/ufpr/dac/bantads/gerente/saga/GerenteCommandHandler.kt`](backend/services/gerente/src/main/kotlin/br/ufpr/dac/bantads/gerente/saga/GerenteCommandHandler.kt)
- [ ] [`backend/services/gerente/src/main/kotlin/br/ufpr/dac/bantads/gerente/saga/GerenteCommandListener.kt`](backend/services/gerente/src/main/kotlin/br/ufpr/dac/bantads/gerente/saga/GerenteCommandListener.kt)
- [ ] [`backend/services/gerente/src/main/kotlin/br/ufpr/dac/bantads/gerente/saga/SagaInboxEntity.kt`](backend/services/gerente/src/main/kotlin/br/ufpr/dac/bantads/gerente/saga/SagaInboxEntity.kt)
- [ ] [`backend/services/gerente/src/main/kotlin/br/ufpr/dac/bantads/gerente/saga/SagaInboxRepository.kt`](backend/services/gerente/src/main/kotlin/br/ufpr/dac/bantads/gerente/saga/SagaInboxRepository.kt)
- [ ] [`backend/services/gerente/src/main/kotlin/br/ufpr/dac/bantads/gerente/seed/SeedGerentes.kt`](backend/services/gerente/src/main/kotlin/br/ufpr/dac/bantads/gerente/seed/SeedGerentes.kt)
- [ ] [`backend/services/gerente/src/main/kotlin/br/ufpr/dac/bantads/gerente/web/ApiException.kt`](backend/services/gerente/src/main/kotlin/br/ufpr/dac/bantads/gerente/web/ApiException.kt)
- [ ] [`backend/services/gerente/src/main/kotlin/br/ufpr/dac/bantads/gerente/web/GerenteExceptionHandler.kt`](backend/services/gerente/src/main/kotlin/br/ufpr/dac/bantads/gerente/web/GerenteExceptionHandler.kt)
- [ ] [`backend/services/gerente/src/main/kotlin/br/ufpr/dac/bantads/gerente/web/Identity.kt`](backend/services/gerente/src/main/kotlin/br/ufpr/dac/bantads/gerente/web/Identity.kt)
- [ ] [`backend/services/gerente/src/main/resources/application.yml`](backend/services/gerente/src/main/resources/application.yml)
- [ ] [`backend/services/gerente/src/main/resources/db/migration/V1__gerente_schema.sql`](backend/services/gerente/src/main/resources/db/migration/V1__gerente_schema.sql)
- [ ] [`backend/services/gerente/src/test/kotlin/br/ufpr/dac/bantads/gerente/GerenteIT.kt`](backend/services/gerente/src/test/kotlin/br/ufpr/dac/bantads/gerente/GerenteIT.kt)
- [ ] [`backend/services/gerente/src/test/kotlin/br/ufpr/dac/bantads/gerente/cadastro/GerenteRulesTest.kt`](backend/services/gerente/src/test/kotlin/br/ufpr/dac/bantads/gerente/cadastro/GerenteRulesTest.kt)
- [ ] [`backend/services/gerente/src/test/resources/application-test.yml`](backend/services/gerente/src/test/resources/application-test.yml)
- [ ] [`backend/services/gerente/src/test/resources/postgres-init.sql`](backend/services/gerente/src/test/resources/postgres-init.sql)

---

### C — Postgres gerente + reboot completo

- [ ] Schema `gerente` no compose; Flyway roda `V1__gerente_schema.sql`
- [ ] Fila `ms.gerente.cmd` + DLQ em `definitions.json`
- [ ] `GerenteIT` + `GerenteRulesTest` verdes
- [ ] `POST /reboot` completo → `{ "status": "ok", "clientes": 5, "gerentes": 4, "contas": 5 }`; segundo reboot = mesmo resultado
- [ ] Login `cli1/tads` → 200; login `ger1/tads` → 200
- [ ] `GET /gerentes` → Geniéve 2, Godophredo 2, Gyândula 1, Gadamântio 0 clientes
- [ ] `GET /clientes?busca=Cat` → Catharyna + Catianna (sort pt-BR)

---

## E07 — 06/10/2026 — MS Saga (engine + R9 aprovar cliente)

**Sumário:** copiar todos os arquivos do MS Saga (engine, registry, store, AMQP, timeout). Implementar SAGA R9 (aprovação de cliente) end-to-end com todos os passos nos MSs dependentes. Jobs Redis ficam ativos para polling.

**Aceite E07:** `POST /solicitacoes/{cpf}/aprovacao` → 202 + `Location`; poll `/jobs/{id}/status` → `CONCLUIDO`; login do novo cliente com senha recebida funciona; `SagaEngineTest` verde.

---

### A — Gateway: aprovação + polling de jobs

- [ ] Confirmar `aprovacao.ts`: 202 sem pré-validar PENDENTE; `jobId === sagaId`
- [ ] `jobs.ts`: dono do job; `PENDENTE`/`CONCLUIDO`/`FALHA`; TTL 5 min; sem `_links`
- [ ] `GET /jobs/{id}/result` só `CONCLUIDO + inline`; senão 409; expirado 404
- [ ] `DEL cache:cliente:{cpf}` no sucesso (confirmar que `RedisCacheInvalidator` chama)

---

### B — MS Saga

- [ ] [`backend/services/saga/build.gradle.kts`](backend/services/saga/build.gradle.kts)
- [ ] [`backend/services/saga/Dockerfile`](backend/services/saga/Dockerfile)
- [ ] [`backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/SagaApplication.kt`](backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/SagaApplication.kt)
- [ ] [`backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/amqp/DlqListener.kt`](backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/amqp/DlqListener.kt)
- [ ] [`backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/amqp/RabbitCommandBus.kt`](backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/amqp/RabbitCommandBus.kt)
- [ ] [`backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/amqp/ReplyListener.kt`](backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/amqp/ReplyListener.kt)
- [ ] [`backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/amqp/SagaCommandListener.kt`](backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/amqp/SagaCommandListener.kt)
- [ ] [`backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/config/ClockConfig.kt`](backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/config/ClockConfig.kt)
- [ ] [`backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/config/SagaProperties.kt`](backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/config/SagaProperties.kt)
- [ ] [`backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/engine/CacheInvalidator.kt`](backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/engine/CacheInvalidator.kt)
- [ ] [`backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/engine/CommandBus.kt`](backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/engine/CommandBus.kt)
- [ ] [`backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/engine/CompensationGuard.kt`](backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/engine/CompensationGuard.kt)
- [ ] [`backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/engine/PayloadSanitize.kt`](backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/engine/PayloadSanitize.kt)
- [ ] [`backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/engine/SagaDefinition.kt`](backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/engine/SagaDefinition.kt)
- [ ] [`backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/engine/SagaEngine.kt`](backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/engine/SagaEngine.kt)
- [ ] [`backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/engine/SagaRegistry.kt`](backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/engine/SagaRegistry.kt)
- [ ] [`backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/engine/SagaSecrets.kt`](backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/engine/SagaSecrets.kt)
- [ ] [`backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/engine/SagaState.kt`](backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/engine/SagaState.kt)
- [ ] [`backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/engine/SagaStatuses.kt`](backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/engine/SagaStatuses.kt)
- [ ] [`backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/engine/SagaStep.kt`](backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/engine/SagaStep.kt)
- [ ] [`backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/engine/StepKind.kt`](backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/engine/StepKind.kt)
- [ ] [`backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/engine/TimeoutScanner.kt`](backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/engine/TimeoutScanner.kt)
- [ ] [`backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/health/HealthController.kt`](backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/health/HealthController.kt)
- [ ] [`backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/job/JobRecord.kt`](backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/job/JobRecord.kt)
- [ ] [`backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/store/JobStore.kt`](backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/store/JobStore.kt)
- [ ] [`backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/store/RedisCacheInvalidator.kt`](backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/store/RedisCacheInvalidator.kt)
- [ ] [`backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/store/RedisCompensationGuard.kt`](backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/store/RedisCompensationGuard.kt)
- [ ] [`backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/store/RedisJobStore.kt`](backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/store/RedisJobStore.kt)
- [ ] [`backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/store/RedisSagaStateStore.kt`](backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/store/RedisSagaStateStore.kt)
- [ ] [`backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/store/SagaStateStore.kt`](backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/store/SagaStateStore.kt)
- [ ] [`backend/services/saga/src/main/resources/application.yml`](backend/services/saga/src/main/resources/application.yml)
- [ ] [`backend/services/saga/src/test/kotlin/br/ufpr/dac/bantads/saga/SagaIT.kt`](backend/services/saga/src/test/kotlin/br/ufpr/dac/bantads/saga/SagaIT.kt)
- [ ] [`backend/services/saga/src/test/kotlin/br/ufpr/dac/bantads/saga/engine/SagaEngineTest.kt`](backend/services/saga/src/test/kotlin/br/ufpr/dac/bantads/saga/engine/SagaEngineTest.kt)
- [ ] [`backend/services/saga/src/test/kotlin/br/ufpr/dac/bantads/saga/TestAmqpQueues.kt`](backend/services/saga/src/test/kotlin/br/ufpr/dac/bantads/saga/TestAmqpQueues.kt)

---

### C — Filas SAGA + conferência R9

- [ ] Filas `saga.cmd`, `orquestrador.reply`, `*.cmd.dlq` em `definitions.json`
- [ ] `SagaEngineTest` + `SagaIT` verdes
- [ ] `POST /reboot` → login `cli1/tads`; criar solicitação; POST aprovação → 202 + `Location`
- [ ] Poll até `CONCLUIDO` (< 5 s no seed)
- [ ] Novo cliente consegue fazer `POST /login` com senha recebida

---

## E08 — 13/10/2026 — MS Email + SAGA R13/R15

**Sumário:** copiar todos os arquivos do MS Email (consumidor `ms.email.cmd`, `FileMailSender`, `SmtpMailSender`). Com Email no ar, as SAGAs R9/R13/R15 ficam completas com notificações. Implementar e validar SAGAs R13 (inserir gerente) e R15 (remover gerente) end-to-end.

**Aceite E08:** `POST /gerentes` (R13) → 202 + job `CONCLUIDO` + arquivo em `outbox/`; `DELETE /gerentes/{cpf}` (R15) → 202 + job `CONCLUIDO`; auto-CPF → 403 síncrono; `EmailComposerTest` verde.

---

### A — Gateway: inserir/remover gerente + relatorio

- [ ] Confirmar `inserir-gerente.ts`: senha obrigatória; 202; senha **não** vai para Redis nem volta no job/GET
- [ ] Confirmar `remover-gerente.ts`: `X-User-CPF` == CPF do path → 403 síncrono **sem** job
- [ ] Confirmar `relatorio.ts`: GET → 202; composition async; result `{ clientes: [...] }` sem `_links`

---

### B — MS Email

- [ ] [`backend/services/email/build.gradle.kts`](backend/services/email/build.gradle.kts)
- [ ] [`backend/services/email/Dockerfile`](backend/services/email/Dockerfile)
- [ ] [`backend/services/email/src/main/kotlin/br/ufpr/dac/bantads/email/EmailApplication.kt`](backend/services/email/src/main/kotlin/br/ufpr/dac/bantads/email/EmailApplication.kt)
- [ ] [`backend/services/email/src/main/kotlin/br/ufpr/dac/bantads/email/amqp/EmailCommandListener.kt`](backend/services/email/src/main/kotlin/br/ufpr/dac/bantads/email/amqp/EmailCommandListener.kt)
- [ ] [`backend/services/email/src/main/kotlin/br/ufpr/dac/bantads/email/compose/Destinatarios.kt`](backend/services/email/src/main/kotlin/br/ufpr/dac/bantads/email/compose/Destinatarios.kt)
- [ ] [`backend/services/email/src/main/kotlin/br/ufpr/dac/bantads/email/compose/EmailComposer.kt`](backend/services/email/src/main/kotlin/br/ufpr/dac/bantads/email/compose/EmailComposer.kt)
- [ ] [`backend/services/email/src/main/kotlin/br/ufpr/dac/bantads/email/health/HealthController.kt`](backend/services/email/src/main/kotlin/br/ufpr/dac/bantads/email/health/HealthController.kt)
- [ ] [`backend/services/email/src/main/kotlin/br/ufpr/dac/bantads/email/mail/FileMailSender.kt`](backend/services/email/src/main/kotlin/br/ufpr/dac/bantads/email/mail/FileMailSender.kt)
- [ ] [`backend/services/email/src/main/kotlin/br/ufpr/dac/bantads/email/mail/MailModels.kt`](backend/services/email/src/main/kotlin/br/ufpr/dac/bantads/email/mail/MailModels.kt)
- [ ] [`backend/services/email/src/main/kotlin/br/ufpr/dac/bantads/email/mail/MailProperties.kt`](backend/services/email/src/main/kotlin/br/ufpr/dac/bantads/email/mail/MailProperties.kt)
- [ ] [`backend/services/email/src/main/kotlin/br/ufpr/dac/bantads/email/mail/SmtpMailSender.kt`](backend/services/email/src/main/kotlin/br/ufpr/dac/bantads/email/mail/SmtpMailSender.kt)
- [ ] [`backend/services/email/src/main/kotlin/br/ufpr/dac/bantads/email/send/EmailCommandService.kt`](backend/services/email/src/main/kotlin/br/ufpr/dac/bantads/email/send/EmailCommandService.kt)
- [ ] [`backend/services/email/src/main/resources/application.yml`](backend/services/email/src/main/resources/application.yml)
- [ ] [`backend/services/email/src/test/kotlin/br/ufpr/dac/bantads/email/EmailIT.kt`](backend/services/email/src/test/kotlin/br/ufpr/dac/bantads/email/EmailIT.kt)
- [ ] [`backend/services/email/src/test/kotlin/br/ufpr/dac/bantads/email/compose/EmailComposerTest.kt`](backend/services/email/src/test/kotlin/br/ufpr/dac/bantads/email/compose/EmailComposerTest.kt)
- [ ] [`backend/services/email/src/test/kotlin/br/ufpr/dac/bantads/email/mail/SmtpMailSenderTest.kt`](backend/services/email/src/test/kotlin/br/ufpr/dac/bantads/email/mail/SmtpMailSenderTest.kt)
- [ ] [`backend/services/email/src/test/resources/application-test.yml`](backend/services/email/src/test/resources/application-test.yml)

---

### C — Filas email + conferência R13/R15

- [ ] `MAIL_DEV=true` no compose (e-mails em `outbox/` em vez de SMTP)
- [ ] `EmailIT` + `EmailComposerTest` verdes
- [ ] `POST /gerentes` → 202; poll → `CONCLUIDO`; `outbox/` contém senha; login com a senha do form → 200
- [ ] E-mail duplicado em `POST /gerentes` → 202 depois `FALHA` + `GET /gerentes/{cpf}` → 404 (compensou)
- [ ] Body incompleto em `POST /gerentes` → 400 síncrono (sem job)
- [ ] `DELETE /gerentes/{cpf}` (outro gerente) → 202; poll → `CONCLUIDO`; login do removido → 401
- [ ] `DELETE /gerentes/{cpf}` (próprio CPF) → 403 síncrono

---

## E09 — 20/10/2026 — Contract tests (pytest T00–T16)

**Sumário:** copiar e executar toda a suíte de testes de contrato (`backend/contract-tests/`). Esta semana não adiciona código de serviço — é a semana de validação do contrato HTTP. Cada falha deve ser documentada com causa raiz.

**Aceite E09:** `pytest -v` → todos os testes T00–T16 verdes. Se houver falhas: causa raiz documentada e ticket para E11.

---

### A — Ajustes gateway pós-contrato

- [ ] Corrigir qualquer divergência de status code, header ou corpo JSON apontada pelo pytest
- [ ] Nenhum `_links.href` apontando para porta interna (`808x`)
- [ ] `Access-Control-Expose-Headers: Location` presente para respostas 202
- [ ] `GET /jobs/{id}/result` → 409 se `PENDENTE`; 404 se expirado; 409 se `FALHA`

---

### B — Contract tests: copiar e configurar

- [ ] [`backend/contract-tests/.env.example`](backend/contract-tests/.env.example)
- [ ] [`backend/contract-tests/pytest.ini`](backend/contract-tests/pytest.ini)
- [ ] [`backend/contract-tests/requirements.txt`](backend/contract-tests/requirements.txt)
- [ ] [`backend/contract-tests/conftest.py`](backend/contract-tests/conftest.py)
- [ ] [`backend/contract-tests/helpers.py`](backend/contract-tests/helpers.py)
- [ ] [`backend/contract-tests/test_t00_reboot.py`](backend/contract-tests/test_t00_reboot.py)
- [ ] [`backend/contract-tests/test_t01_solicitacoes.py`](backend/contract-tests/test_t01_solicitacoes.py)
- [ ] [`backend/contract-tests/test_t02_auth.py`](backend/contract-tests/test_t02_auth.py)
- [ ] [`backend/contract-tests/test_t03_conta.py`](backend/contract-tests/test_t03_conta.py)
- [ ] [`backend/contract-tests/test_t04_movimentacoes.py`](backend/contract-tests/test_t04_movimentacoes.py)
- [ ] [`backend/contract-tests/test_t08_gerente.py`](backend/contract-tests/test_t08_gerente.py)
- [ ] [`backend/contract-tests/test_t09_aprovacao.py`](backend/contract-tests/test_t09_aprovacao.py)
- [ ] [`backend/contract-tests/test_t11_clientes.py`](backend/contract-tests/test_t11_clientes.py)
- [ ] [`backend/contract-tests/test_t12_gerentes.py`](backend/contract-tests/test_t12_gerentes.py)
- [ ] [`backend/contract-tests/test_t13_gerentes.py`](backend/contract-tests/test_t13_gerentes.py)
- [ ] [`backend/contract-tests/test_t15_remover_gerente.py`](backend/contract-tests/test_t15_remover_gerente.py)
- [ ] [`backend/contract-tests/test_t16_relatorio.py`](backend/contract-tests/test_t16_relatorio.py)
- [ ] [`backend/contract-tests/test_t_hateoas_dinheiro.py`](backend/contract-tests/test_t_hateoas_dinheiro.py)

---

### C — Execução e triagem

- [ ] `pip install -r requirements.txt`; copiar `.env` a partir de `.env.example`
- [ ] `POST /reboot`; `pytest -v` → registrar resultado linha a linha
- [ ] Falhas: documentar status observado × esperado; priorizar para E11
- [ ] Dinheiro como **string** em `saldo`, `valor`, `limite` — nunca `Double`/`number`
- [ ] Dois formatos de erro: `{ auth, message }` (401/login) e `{ status, erro, mensagem }` (demais 4xx/5xx)

---

## E10 — 27/10/2026 — Integração frontend Angular

**Sumário:** integrar o frontend Angular 17+ com o backend completo em `:3000`. Verificar todas as telas funcionando no browser: login, dashboard, conta, solicitações, operações (depósito/saque/transferência), gerente. Não modificar código de backend nesta semana — só ajustar `.env` e `CORS_ORIGIN` se necessário.

**Aceite E10:** login CLIENTE e GERENTE funcionam no browser sem erro CORS; todas as operações de conta executam; fluxos de SAGA (aprovação, inserção, remoção) completam com atualização de tela.

---

### A — CORS e headers no browser

- [ ] `CORS_ORIGIN` aponta para a origem Angular correta (ex.: `http://localhost:4200`)
- [ ] Preflight OPTIONS para `x-access-token` → 204 com `Access-Control-Allow-Headers` corretos
- [ ] `Access-Control-Expose-Headers: Location` presente para 202 + jobs
- [ ] Nenhum erro CORS no DevTools do browser após login

---

### B — Verificar compose e MSs

- [ ] `docker compose ps` → 7 serviços + infra todos `healthy`
- [ ] `application.yml` de cada MS usa nome do container correto para conexão
- [ ] `POST /reboot` após subida → JSON exato `{ "status": "ok", "clientes": 5, "gerentes": 4, "contas": 5 }`

---

### C — Testes de integração Angular → Gateway

- [ ] Login CLIENTE `cli1/tads` → token JWT no header `x-access-token` do interceptor Angular
- [ ] Login GERENTE `ger1/tads` → tela de gerente carrega com lista de clientes
- [ ] Depósito (R4): saldo atualiza na tela após poll
- [ ] Saque (R5): 422 se saldo insuficiente; sucesso se OK
- [ ] Transferência (R6): 422 conta destino inválida; sucesso se OK; saldo do destino atualiza
- [ ] `POST /solicitacoes` sem token → autocadastro 201 (tela pública)
- [ ] Aprovação R9 pelo gerente → status da solicitação atualiza na tela; novo cliente consegue logar
- [ ] Inserção gerente R13 → 202; lista de gerentes atualiza
- [ ] Remoção gerente R15 → 202; login do gerente removido → 401; contas transferidas
- [ ] Relatório R16 → tabela de clientes renderiza após poll (não antes)
- [ ] Sem token → tela redireciona para login (não exibe 401 cru)

---

## E11 — 03/11/2026 — Ajustes pós-integração + R16 + jobs inline

**Sumário:** resolver itens abertos da E09 (pytest) e E10 (integração Angular), validar R16 (relatório assíncrono inline), garantir que o fluxo de jobs (status/result) funciona corretamente no front. Regressão completa.

**Aceite E11:** `pytest -v` verde sem exceções; R16 no front renderiza tabela; jobs `CONCLUIDO`/`FALHA` renderizam corretamente no front.

---

### A — Ajustes gateway finais

- [ ] Revalidar `relatorio.ts`: GET → 202; poll `/jobs/{id}/status`; result `{ clientes: [...] }` sem `_links`
- [ ] `GET /jobs/{id}/result` somente para `CONCLUIDO + inline`; senão 409; expirado 404
- [ ] Sem `_links` em: login, 202/status/result, `/health`, `/reboot`, linhas do relatório R16
- [ ] Rewrite recursivo de `href` confirmado em todos os objetos aninhados

---

### B — Ajustes MSs (se necessário)

- [ ] Corrigir qualquer campo Money retornado como número (deve ser string `"800.00"`)
- [ ] Corrigir qualquer `_links.href` interno vazando com porta `808x`
- [ ] `projecao_aplicada`: idempotência confirmada (evento duplicado não soma)

---

### C — Regressão completa

- [ ] `compile-services.ps1` (ou `.sh`) → frota inteira: `shared → auth → cliente → gerente → conta → saga → email → gateway`; zero erros
- [ ] `POST /reboot` → JSON exato
- [ ] `pytest -v` T00–T16 → verde
- [ ] Testes de integração Angular da E10 revalidados manualmente
- [ ] Sem token → 401 `{ "auth": false, "message": "Token não fornecido." }`
- [ ] Token expirado/revogado → 401 `{ "auth": false, "message": "Falha ao autenticar o token." }`

---

## E12 — 10/11/2026 — Aceite final e fecho

**Sumário:** semana de fechamento. Nenhum arquivo novo é copiado. Só validação dos critérios de aceite totais e fechamento do log.

**Aceite E12:** todos os itens do DoD abaixo marcados.

---

### A — Gateway: verificação final

- [ ] HATEOAS nível 3: UI navega inteiramente por `_links`; nenhum `href` aponta para porta interna
- [ ] Sliding window Redis: token ativo até 30 min de inatividade; logout revoga imediatamente; pós-reboot → 401
- [ ] `NODE_OPTIONS=--max-old-space-size=192` e `mem_limit: 256m` no compose

---

### B — MSs: verificação final

- [ ] Argon2id ativo: `POST /login` funciona; hash no MongoDB ≠ `tads` em texto claro
- [ ] Event store: `replay(eventos)` == saldo na query (verificar Catharyna `"800.00"`)
- [ ] 3 SAGAs orquestradas (R9/R13/R15): timeout 30 s; compensação idempotente; DLQ compensa uma vez
- [ ] Senhas SAGAs **não** aparecem nos logs do Saga nem no Redis

---

### C — Fecho

- [ ] `pytest -v` T00–T16 → zero falhas
- [ ] `compile-services.ps1` → zero erros em todos os módulos
- [ ] `docker compose ps` → 7 serviços + infra `healthy`
- [ ] `.env.example` sem segredos reais; `JWT_SECRET`, `MONGO_URI`, senhas de banco como placeholder
- [ ] Dinheiro string em 100% dos campos (`saldo`, `valor`, `limite`) — nunca `Double`/`Float`/`number`
- [ ] Front só fala com `:3000`; portas `808x` dos MSs **não** publicadas no host

---

## Definition of Done (E12)

- [ ] R1–R16 conformes ao Swagger
- [ ] 7 processos: `gateway`, `auth`, `cliente`, `gerente`, `conta`, `saga`, `email`
- [ ] Schema-per-service; CQRS + event store reais no MS Conta
- [ ] 3 SAGAs orquestradas (30 s, compensação, DLQ, idempotência)
- [ ] Composition: login, R11, R12, R16
- [ ] JWT somente no Gateway + Redis sessão 30 min + logout revoga
- [ ] Argon2id; HATEOAS Richardson nível 3 com rewrite total no Gateway
- [ ] `/health` + `/reboot` determinísticos
- [ ] Sem segredos no git; front e pytest só falam com `:3000`
- [ ] `pytest` T00–T16 verde; Angular integrado end-to-end
