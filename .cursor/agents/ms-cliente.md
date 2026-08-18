---
name: bantads-ms-cliente
description: MS Cliente BANTADS — solicitações de autocadastro, cadastro de cliente, R1/R8/R10 e passos de SAGA R9/R13/R15. Use em services/cliente.
---

# Agente — MS Cliente (Postgres schema `cliente`)

## Tabelas

- `solicitacao` PK cpf: dados cadastrais + `status PENDENTE|APROVADA|NAO_APROVADA` + motivo + `data_hora_processamento`. Unique email.
- `cliente` PK cpf: cadastro efetivo (só após aprovação). Sem status.

## HTTP

- `POST /solicitacoes` público (Gateway não exige JWT): 201 + `Location` + HATEOAS. 409 se CPF já tem solicitação **em qualquer estado** ou e-mail já usado em outra solicitação; 409 se já existe cliente com o CPF.
- `GET /solicitacoes?status=` e `GET /solicitacoes/{cpf}` — GERENTE (posse via header)
- `POST /solicitacoes/{cpf}/rejeicao` `{ motivo }`: se não PENDENTE → 409; senão NAO_APROVADA + timestamp. Publicar `email.rejeicao` fire-and-forget.
- `GET /clientes/{cpf}` e `GET /clientes?busca=` (trecho de CPF **ou** nome, ILIKE/collation pt-BR)
- Batch interno de nomes/e-mails por CPFs (SAGA e transferência)

HATEOAS solicitação: sempre `self`; se PENDENTE: `aprovacao`, `rejeicao`. Cliente: `self`, `conta`.

## AMQP `ms.cliente.cmd`

| tipo | Sucesso | Compensação / nota |
|---|---|---|
| `cliente.marcar-aprovada` | PENDENTE→APROVADA; reply com dados da solicitação | volta PENDENTE (exceto e-mail duplicado) |
| `cliente.marcar-nao-aprovada` | NAO_APROVADA + motivo `"E-mail já cadastrado"` | caso especial R9 |
| `cliente.criar` | copia solicitação → `cliente` | `cliente.remover` |
| `cliente.obter-por-cpfs` | consulta | sem compensação |

Não PENDENTE em `marcar-aprovada` → FALHA (job FALHA no Gateway, não 4xx do 202).

## Ordenação

`ORDER BY nome COLLATE "pt-BR-x-icu"`.

## Seed

5 clientes da seção 4. Endereços/telefones **fixos** (Curitiba/PR). Reboot trunca solicitações.
