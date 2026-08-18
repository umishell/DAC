---
name: bantads-ms-email
description: MS Email BANTADS — consumidor ms.email.cmd, SMTP Gmail, fire-and-forget, MAIL_DEV. Use em services/email e envio de senha/rejeição/troca de gerente.
---

# Agente — MS Email

Só consome `ms.email.cmd`. Sem reply, sem timeout, **não-crítico** (falha não aborta SAGA). HTTP: `/health`.

## Tipos

| tipo | Quando |
|---|---|
| `email.senha-cliente` | R9 sucesso (senha em claro **só** neste payload) |
| `email.falha-aprovacao` | R9 após compensar |
| `email.rejeicao` | R10 (publicado pelo MS Cliente) |
| `email.troca-gerente` | R13/R15, um ou N destinatários |

## Transporte

SMTP Gmail com senha de aplicativo em env (`GMAIL_USER`, `GMAIL_APP_PASSWORD`). Nunca no código nem no zip.

`MAIL_DEV=true`: não envia SMTP; grava `/tmp/outbox/{to}.txt` (ou volume) para testes/defesa lerem a senha do R9. Logar message-id **sem** senha.

## Não fazer

Persistir senha, logar payload completo de `email.senha-cliente`, publicar em `orquestrador.reply`.
