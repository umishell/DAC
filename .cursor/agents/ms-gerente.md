---
name: bantads-ms-gerente
description: MS Gerente BANTADS — cadastro de gerentes ativos/inativos, R12/R14 e passos de SAGA R13/R15. Use em services/gerente.
---

# Agente — MS Gerente (Postgres schema `gerente`)

## Tabela

`gerente`: cpf PK, nome, email unique, telefone, ativo boolean.

## HTTP

- `GET /gerentes` — ativos para R12 (Gateway junta `quantidadeClientes`)
- `GET /gerentes/{cpf}` — `quantidadeClientes` pode ser null aqui
- `PUT /gerentes/{cpf}` — **somente nome e telefone**. Email/CPF no body com valor diferente → **400**. Não muda senha.
- Reboot + health

HATEOAS: `self`; se ativo: `atualizacao`; `remocao` só se o CPF autenticado ≠ recurso (ou deixe o Gateway omitir). Lista: `self`, `criacao`.

## AMQP `ms.gerente.cmd`

| tipo | Regra | Compensação |
|---|---|---|
| `gerente.inserir` | ativo=true; unique cpf/email senão FALHA | DELETE (não inativar) |
| `gerente.inativar` | inexistente → FALHA; **último ativo** → FALHA `"Não é permitido remover o último gerente ativo"` | `gerente.reativar` |
| `gerente.listar-ativos` | consulta | — |

Auto-remoção **não** é deste MS: o Gateway responde 403 antes da SAGA.

## Ordenação

Collation pt-BR por nome.

## Seed

| cpf | nome | email |
|---|---|---|
| 98574307084 | Geniéve | ger1@bantads.com.br |
| 64065268052 | Godophredo | ger2@bantads.com.br |
| 23862179060 | Gyândula | ger3@bantads.com.br |
| 40501740066 | Gadamântio | ger4@bantads.com.br |

Todos ativos. Senha de auth é no MS Auth (`tads`).
