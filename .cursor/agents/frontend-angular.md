---
name: bantads-frontend-angular
description: Frontend Angular 17+ do BANTADS — signals, HATEOAS dirigindo a UI, decimal.js, Luxon, polling 202, interceptor x-access-token. Use em qualquer código de tela, serviço HTTP ou modelo do front.
---

# Agente — Frontend Angular (signals)

O front **só** chama o API Gateway (`http://localhost:3000`). Nunca microsserviços, nunca json-server, nunca Local Storage como banco. Guardar JWT no browser é permitido.

## Stack

Angular **17+**, TypeScript, **signals** (não NgRx obrigatório). HTTP via serviços. `decimal.js` para dinheiro. `Luxon` (`DateTime`) para datas/extrato.

## Auth

- Login `POST /login` `{ email, senha }`
- Enviar token no header **`x-access-token`** (interceptor)
- 401 → logout e rota de login
- Perfis `CLIENTE` | `GERENTE` a partir de `tipo`

## HATEOAS dirige a UI

Não hardcodar se o botão existe: use `_links`.

- Solicitação `PENDENTE` → botões Aprovar/Recusar só se houver `aprovacao` / `rejeicao`
- Conta do cliente → depósito/saque/transferência/extrato pelos rels
- Gerente: `atualizacao` / `remocao` / lista `criacao`
- Após R4/R5/R6: **não** usar saldo da resposta (não vem). Seguir link `conta` e reconsultar (consistência eventual)

## Jobs (R9, R13, R15, R16)

202 → poll `GET /jobs/{id}/status`. `resource` → `GET /{dominio}/{resourceId}`. `inline` → `GET /jobs/{id}/result`. Tratar `FALHA` com `erro`. Job expira em 5 min.

## Extrato (R7)

Default últimos 30 dias; máx 365. O Gateway devolve `saldoAbertura` + `movimentacoes`. O front monta a linha do tempo **dia a dia** com Luxon (saldo consolidado mesmo sem movimento). Saída vermelha, entrada azul. Origem/destino só em transferência; entrada/saída = comparar CPF logado.

## Dinheiro e datas

- JSON sempre string `"1500.00"` — parse/format com decimal.js, nunca `number` do JS
- Exibir pt-BR; enviar no contrato do Swagger
- Datas naive sem offset, timezone de negócio America/Sao_Paulo

## Telas mínimas

Cliente: inicial (conta+saldo+menu), depósito, saque, transferência, extrato, dados cadastrais.

Gerente: inicial (solicitações todos os estados), aprovar (async), rejeitar (motivo), consultar clientes (busca+ordem nome), CRUD gerentes, relatório clientes (async).

Autocadastro público: mensagem de solicitação enviada; senha **não** existe ainda.

## Qualidade

Standalone components, signals para estado, serviços HTTP finos, models espelhando o Swagger. Interface caprichada (enunciado). Firefox na defesa.

Build do front entra na frota sequencial da raiz (`compile-services.ps1` / `.sh`), depois dos MSs e do gateway.
