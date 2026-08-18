---
name: bantads-contract-api
description: Contrato HTTP BANTADS — Swagger 2.0.0, dinheiro, datas, HATEOAS, seed, pytest de aceite T00–T16. Use ao definir DTOs, status codes, testes de contrato ou reboot/seed.
---

# Agente — Contrato da API e testes

Fonte: `docs/swagger_bantads.md`. Não adicionar rotas/campos. Header de auth: **`x-access-token`**. Login: `{ email, senha }` → `{ auth, token, tipo, usuario }`.

## Formatos

- Dinheiro: string `^\d+\.\d{2}$`
- CPF path/body: `^\d{11}$`
- Conta: `^\d{4}$` sempre string
- Data/hora: `2026-04-30T10:00:00` (sem offset)
- Data query: `YYYY-MM-DD`
- Ordenação de nomes: collation pt-BR (acentos = letra base)

## Sem `_links`

Login, 202/job status/result, `/health`, `/reboot`.

## Jobs

`PENDENTE|CONCLUIDO|FALHA`. R9/R13 resource; R15/R16 inline. TTL 5 min → 404. Falha de SAGA ≠ 4xx do POST (sempre 202 + job FALHA).

## Seed que os testes cravam

Clientes: Catharyna 1291 `"800.00"`, Cleuddônio 0950 `"10000.00"`, Catianna 8573 `"200.00"`, Cutardo 5887 `"150000.00"`, Coândrya 7617 `"1500.00"`. Senha `tads`. Gerentes ger1–ger4. Contagens: Geniéve 2, Godophredo 2, Gyândula 1, Gadamântio 0. Replay do event store **igual** a esses saldos. Movimentações: seção 4 do enunciado.

`POST /reboot` → `{ status: "ok", clientes: 5, gerentes: 4, contas: 5 }`.

## Suíte `backend/contract-tests/`

pytest `-s -v`, `.env URL=http://localhost:3000` sem barra final. Stateful (token + cache arquivo). Ordem T00→T16 em `docs/backend_plan.md` seção 2.2.

Retry CQRS: 2s + até 3× / 5s após R4/R5/R6. R1 não gera senha; T09 lê senha do outbox `MAIL_DEV`.

Não alterar `docs/professorTests/` para distorcer o contrato. Não implementar domínio aéreo.
