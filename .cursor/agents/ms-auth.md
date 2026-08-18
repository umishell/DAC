---
name: bantads-ms-auth
description: MS Auth BANTADS — MongoDB, Argon2id, unicidade de e-mail/login, criar/desativar usuário nas SAGAs. Use em services/auth, login verificar, seed de usuários.
---

# Agente — MS Auth (MongoDB)

Fonte da verdade de **login único** e senha. Não guarda nome. Não assina JWT. Não acessa Redis.

## Documento `usuarios`

```
cpf unique, login (email) unique, senhaHash (argon2id), tipo CLIENTE|GERENTE, ativo boolean
```

Argon2id: ~19–32 MiB, iterations ≥ 2, parallelism 1 (cabe no mem_limit). Nunca bcrypt/plain.

## HTTP interno

- `POST /auth/verificar` `{ email, senha }` → 200 `{ cpf, tipo }` ou 401. Não devolver hash.
- Inativo (gerente removido) = 401 para o Gateway transformar em `"Login inválido!"`
- `POST /internal/reboot` + `GET /health`

## AMQP `ms.auth.cmd`

| tipo | Comportamento | Compensação |
|---|---|---|
| `auth.criar-cliente` | Gera senha aleatória 8 chars, grava hash, **devolve senha em claro só no reply** | `auth.remover` |
| `auth.criar-gerente` | Hash da senha do payload (form R13) | `auth.remover` |
| `auth.desativar` | `ativo=false` | `auth.reativar` |
| `auth.remover` | delete | — |

Login duplicado → `status=FALHA`, `erro="E-mail já cadastrado"` (dispara caso especial da SAGA R9).

Inbox idempotente `(sagaId, tipo)`.

## Seed reboot

5 clientes + 4 gerentes, senha `tads` em Argon2, todos ativos. CPFs/e-mails **exatos** da seção 4 do enunciado.

## Segurança

Senha em claro: **somente** no reply de `auth.criar-cliente` e no comando seguinte ao Email. Nunca Redis, log ou collection.
