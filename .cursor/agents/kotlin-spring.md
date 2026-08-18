---
name: bantads-kotlin-spring
description: Convenções Kotlin/Spring Boot 3.4 dos microsserviços BANTADS — camadas, DTOs, JPA, HATEOAS, Money, erros, health. Use em qualquer MS Java/Kotlin ou no módulo shared.
---

# Agente — Kotlin / Spring Boot (MSs)

## Stack

Kotlin 2.x, Java 21, Spring Boot 3.4+, Gradle Kotlin DSL, Spring Data JPA ou Mongo, Spring HATEOAS, Spring AMQP. Jackson: `WRITE_BIGDECIMAL_AS_PLAIN`, dinheiro como **string**. `FAIL_ON_UNKNOWN_PROPERTIES=false` nos MSs.

## Arquitetura de cada MS

`RestController → Service → Repository → DB`

- Controller magro: HTTP, validação de entrada, montagem de RepresentationModel
- Service: regras, transações, replay, idempotência
- Repository: persistência. **Nunca** devolver entidade JPA na API
- DTOs: `data class`. Campo `valor`/`saldo`/`salario`: serializar via helper `Money` (`BigDecimal` scale 2, JSON string)

## Money (módulo `shared`)

```kotlin
// JSON: "800.00"  |  Postgres: NUMERIC(19,4)  |  evento: string 2 casas
fun parse(s: String): BigDecimal  // rejeita se não casar ^\d+\.\d{2}$
fun format(v: BigDecimal): String // sempre 2 casas
```

Nunca `Double`/`Float`. Operações com `add`/`subtract` no helper.

## HATEOAS

Spring HATEOAS estilo HAL: `{ rel: { href } }`. URLs **internas** do MS; o Gateway reescreve. Não gerar `_links` em `/health`.

## HTTP interno

- `GET /health` → `{ "status": "UP" }` 200
- `POST /internal/reboot` — truncar e reseed (chamado pelo Gateway)
- Rotas de negócio exigem `X-User-CPF` e `X-User-Tipo` (exceto reboot/health e autocadastro público no MS Cliente)
- MSs **não** validam JWT

## AMQP

Consumidores `*.cmd` idempotentes na tabela `saga_inbox (saga_id, tipo) UNIQUE`. Envelope padrão do plano (campo `tipo` estável). Reply em `orquestrador.reply` com `status: SUCESSO | FALHA`.

## JVM no Docker

`mem_limit: 512m`, `JAVA_TOOL_OPTIONS=-XX:MaxRAMPercentage=60 -XX:+UseSerialGC`. Healthcheck `curl -f http://localhost:8080/health`, `start_period: 40s`.

## Testes

JUnit 5 + MockK + Testcontainers. Regras de domínio (R13, replay, Money) **sem Spring**.

## Não fazer

- Acessar schema/banco de outro MS
- Expor entidade persistente
- Coroutines (use thread pool Web/AMQP)
- God-service que mistura HTTP, AMQP e SQL no mesmo arquivo
