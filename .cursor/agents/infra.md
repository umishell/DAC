---
name: bantads-infra
description: Infra BANTADS — Docker Compose, schemas Postgres, RabbitMQ/DLQ, Redis, Mongo, mem_limit, start.sh, healthchecks. Use em docker-compose, Dockerfiles, db/init, scripts de subida.
---

# Agente — Infra / DevOps

## Contêineres

Um por app (gateway, auth, cliente, gerente, conta, saga, email) + postgres + mongo + redis + rabbitmq. Rede `bantads`. Publicar no host: Gateway **3000**, Postgres 5432, Mongo 27017, Redis 6379, Rabbit 5672 + management 15672. **Não** publicar 808x dos MSs.

MS Conta = **um** JVM (command+query) para caber em 8 GB.

## mem_limit (coluna 8 GB)

| Serviço | limit | Extra |
|---|---|---|
| gateway | 256m | `--max-old-space-size=192` |
| cada MS Java | 512m | `-XX:MaxRAMPercentage=60 -XX:+UseSerialGC` |
| postgres | 384m | `shared_buffers=128MB` |
| mongo | 384m | `--wiredTigerCacheSizeGB 0.25` |
| redis | 128m | `--maxmemory 100mb --maxmemory-policy noeviction` |
| rabbitmq | 512m | `vm_memory_high_watermark 0.6` |

`depends_on: condition: service_healthy`. Spring `start_period: 40s`.

## Postgres

DB `bantads`, schemas `cliente`, `gerente`, `conta_command`, `conta_query`. Collation `"pt-BR-x-icu"`. User **por schema**. Flyway em cada MS no próprio schema. Init em `db/postgres/init/` (raiz do repo).

## RabbitMQ

Default exchange. Filas: `saga.cmd`, `ms.cliente.cmd`, `ms.conta.cmd`, `ms.gerente.cmd`, `ms.auth.cmd`, `ms.email.cmd`, `orquestrador.reply`, `ms.conta.events` + DLQs correspondentes (exceto email/saga/reply). Retry 3× / 5s (TTL wait queue ou delayed plugin) depois DLQ. Import `definitions.json`.

## Redis

`noeviction`. Usado por Gateway e Orquestrador.

## Scripts

`start.sh` na raiz: `docker compose build` **um serviço por vez** e `up -d`. Compose na raiz orquestra `backend/` e `frontend/`. Compilar a frota: `compile-services.sh` / `.ps1` na raiz (MSs + gateway + frontend, um por vez). `.env.example` na raiz, sem segredos. Health: Gateway `wget` `/health`; MSs `curl` `/health`.

## Imagens

Gateway: node:22-alpine multi-stage. MSs: temurin 21 jre + curl. Frontend futuro: nginx estático (`mem_limit` 64m).
