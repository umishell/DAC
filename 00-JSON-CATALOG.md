# Catálogo de contratos JSON — BANTADS API Gateway

Fonte canônica: [`docs/swagger_bantads.md`](docs/swagger_bantads.md).  
Tutoriais completos: [`transacoes/`](transacoes/00-GERAL.md) · HTTPie passo a passo: [`httpie/`](httpie/00-GENERAL-INFO.md).  
Plano frontend: [`plano-entregas-frontend.md`](plano-entregas-frontend.md).

**Convenções globais:**
- Dinheiro sempre `string` `^\d+\.\d{2}$` — `"800.00"`, nunca `800` ou `"800,00"`.
- CPF: string 11 dígitos sem pontuação — `"12912861012"`.
- Número de conta: string 4 dígitos — `"0950"` (zero à esquerda preservado).
- Datas: ISO 8601 **sem** offset — `"2026-08-18T16:50:00"`. Queries: `YYYY-MM-DD`.
- Token: header **`x-access-token`** (não `Authorization: Bearer`).
- Dois envelopes de erro: `{ auth, message }` para 401; `{ status, erro, mensagem }` para todo o resto.
- `_links` ausentes em: login, logout (204), reboot, health, jobs (202/status/result), linhas do relatório.

---

## Índice

| TX | Endpoint | Método | Auth |
|---|---|---|---|
| [TX-INFRA-01](#tx-infra-01--health-check) | `/health` | GET | Público |
| [TX-INFRA-02](#tx-infra-02--reboot) | `/reboot` | POST | Público |
| [TX-R2A](#tx-r2a--login) | `/login` | POST | Público |
| [TX-R2B](#tx-r2b--logout) | `/logout` | POST | Qualquer JWT |
| [TX-R1](#tx-r1--autocadastro) | `/solicitacoes` | POST | Público |
| [TX-R8A](#tx-r8a--listar-solicitações) | `/solicitacoes` | GET | GERENTE |
| [TX-R8B](#tx-r8b--consultar-solicitação) | `/solicitacoes/{cpf}` | GET | GERENTE |
| [TX-R9](#tx-r9--aprovar-cliente-saga) | `/solicitacoes/{cpf}/aprovacao` | POST | GERENTE |
| [TX-R10](#tx-r10--rejeitar-cliente) | `/solicitacoes/{cpf}/rejeicao` | POST | GERENTE |
| [TX-CAD-01](#tx-cad-01--consultar-cliente) | `/clientes/{cpf}` | GET | GERENTE ou próprio CLIENTE |
| [TX-R11](#tx-r11--listar-clientes-composition) | `/clientes` | GET | GERENTE |
| [TX-R3A](#tx-r3a--conta-por-cpf) | `/clientes/{cpf}/conta` | GET | GERENTE ou próprio CLIENTE |
| [TX-R3B](#tx-r3b--conta-por-número) | `/contas/{numero}` | GET | GERENTE ou CLIENTE dono |
| [TX-R4](#tx-r4--depósito) | `/contas/{numero}/deposito` | POST | CLIENTE dono |
| [TX-R5](#tx-r5--saque) | `/contas/{numero}/saque` | POST | CLIENTE dono |
| [TX-R6](#tx-r6--transferência) | `/contas/{numero}/transferencia` | POST | CLIENTE dono |
| [TX-R7](#tx-r7--extrato) | `/contas/{numero}/extrato` | GET | CLIENTE dono |
| [TX-R12](#tx-r12--listar-gerentes-composition) | `/gerentes` | GET | GERENTE |
| [TX-CAD-02](#tx-cad-02--consultar-gerente) | `/gerentes/{cpf}` | GET | GERENTE |
| [TX-R13](#tx-r13--inserir-gerente-saga) | `/gerentes` | POST | GERENTE |
| [TX-R14](#tx-r14--atualizar-gerente) | `/gerentes/{cpf}` | PUT | GERENTE |
| [TX-R15](#tx-r15--remover-gerente-saga) | `/gerentes/{cpf}` | DELETE | GERENTE |
| [TX-R16](#tx-r16--relatório-de-clientes) | `/relatorios/clientes` | GET | GERENTE |
| [TX-JOB-01](#tx-job-01--status-do-job) | `/jobs/{jobId}/status` | GET | Dono do job |
| [TX-JOB-02](#tx-job-02--resultado-inline-do-job) | `/jobs/{jobId}/result` | GET | Dono do job |

---

## TX-INFRA-01 — Health check

**Tutorial:** [transacoes/TX-INFRA-01-health.md](transacoes/TX-INFRA-01-health.md)

### Request

```http
GET /health HTTP/1.1
Host: localhost:3000
```

### Response 200 — Gateway no ar

> Sem `_links` (exceção HATEOAS).

```json
{
  "status": "UP"
}
```

---

## TX-INFRA-02 — Reboot

**Tutorial:** [transacoes/TX-INFRA-02-reboot.md](transacoes/TX-INFRA-02-reboot.md)

> Público · timeout ≥ 90 s · idempotente · invalida todas as sessões Redis.

### Request

```http
POST /reboot HTTP/1.1
Host: localhost:3000
```

_(sem body)_

### Response 200 — Seed recriado

> Sem `_links`. Resposta **byte-a-byte idêntica** em chamadas subsequentes.

```json
{
  "status": "ok",
  "clientes": 5,
  "gerentes": 4,
  "contas": 5
}
```

**Saldos do seed após reboot:**

| Conta | Cliente | Saldo |
|---|---|---|
| `"1291"` | Catharyna | `"800.00"` |
| `"0950"` | Cleuddônio | `"10000.00"` |
| `"8573"` | Catianna | `"200.00"` |
| `"5887"` | Cutardo | `"150000.00"` |
| `"7617"` | Coândrya | `"1500.00"` |

---

## TX-R2A — Login

**Tutorial:** [transacoes/TX-R2A-login.md](transacoes/TX-R2A-login.md)

> Público · sem `_links` · campo chama-se `email`, não `login`.

### Request

```http
POST /login HTTP/1.1
Host: localhost:3000
Content-Type: application/json
```

```json
{
  "email": "cli1@bantads.com.br",
  "senha": "tads"
}
```

### Response 200 — Autenticado (CLIENTE)

> Sem `_links`. `token` vai no header `x-access-token` de todas as requests seguintes.

```json
{
  "auth": true,
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJjcGYiOiIxMjkxMjg2MTAxMiIsInRpcG8iOiJDTElFTlRFIiwianRpIjoiYWJjZGVmZ2giLCJleHAiOjE3NTU1NTU1NTV9.assinatura",
  "tipo": "CLIENTE",
  "usuario": {
    "cpf": "12912861012",
    "nome": "Catharyna",
    "email": "cli1@bantads.com.br"
  }
}
```

### Response 200 — Autenticado (GERENTE)

```json
{
  "auth": true,
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "tipo": "GERENTE",
  "usuario": {
    "cpf": "98574307084",
    "nome": "Geniéve",
    "email": "ger1@bantads.com.br"
  }
}
```

### Erros

**401 — Credenciais inválidas ou usuário inativo:**

```json
{
  "auth": false,
  "message": "Login inválido!"
}
```

**400 — Body malformado (sem `email`/`senha` ou tipos errados):**

```json
{
  "status": 400,
  "erro": "Bad Request",
  "mensagem": "Requisição malformada"
}
```

**401 — Token ausente em rota protegida:**

```json
{
  "auth": false,
  "message": "Token não fornecido."
}
```

**401 — Token inválido/expirado/sessão encerrada:**

```json
{
  "auth": false,
  "message": "Falha ao autenticar o token."
}
```

**Seed de clientes e gerentes:**

| Email | Senha | Tipo | CPF | Nome |
|---|---|---|---|---|
| `cli1@bantads.com.br` | `tads` | CLIENTE | `12912861012` | Catharyna |
| `cli2@bantads.com.br` | `tads` | CLIENTE | `09506382000` | Cleuddônio |
| `cli3@bantads.com.br` | `tads` | CLIENTE | `85733854057` | Catianna |
| `cli4@bantads.com.br` | `tads` | CLIENTE | `58872160006` | Cutardo |
| `cli5@bantads.com.br` | `tads` | CLIENTE | `76179646090` | Coândrya |
| `ger1@bantads.com.br` | `tads` | GERENTE | `98574307084` | Geniéve |
| `ger2@bantads.com.br` | `tads` | GERENTE | `64065268052` | Godophredo |
| `ger3@bantads.com.br` | `tads` | GERENTE | `23862179060` | Gyândula |
| `ger4@bantads.com.br` | `tads` | GERENTE | `40501740066` | Gadamântio |

---

## TX-R2B — Logout

**Tutorial:** [transacoes/TX-R2B-logout.md](transacoes/TX-R2B-logout.md)

> Qualquer JWT válido · body vazio no response · sem `_links`.

### Request

```http
POST /logout HTTP/1.1
Host: localhost:3000
x-access-token: <token>
```

_(sem body)_

### Response 204 — Sessão encerrada

```
HTTP/1.1 204 No Content
```

_(corpo vazio — não é `{}`)_

### Após logout — mesmo token → 401

```json
{
  "auth": false,
  "message": "Falha ao autenticar o token."
}
```

---

## TX-R1 — Autocadastro

**Tutorial:** [transacoes/TX-R1-autocadastro.md](transacoes/TX-R1-autocadastro.md)

> Público · cria solicitação `PENDENTE` · **não** cria conta, Auth nem senha.

### Request

```http
POST /solicitacoes HTTP/1.1
Host: localhost:3000
Content-Type: application/json
```

```json
{
  "cpf": "11122233396",
  "nome": "Fulano de Tal",
  "email": "fulano@exemplo.com.br",
  "telefone": "41999990000",
  "salario": "4500.00",
  "endereco": {
    "logradouro": "Rua XV de Novembro",
    "numero": "1299",
    "complemento": null,
    "cep": "80060000",
    "cidade": "Curitiba",
    "uf": "PR"
  }
}
```

> `salario` é `string` `"4500.00"` — nunca `number` `4500`.

### Response 201 — Solicitação registrada

Header: `Location: /solicitacoes/11122233396`

```json
{
  "cpf": "11122233396",
  "nome": "Fulano de Tal",
  "email": "fulano@exemplo.com.br",
  "telefone": "41999990000",
  "salario": "4500.00",
  "endereco": {
    "logradouro": "Rua XV de Novembro",
    "numero": "1299",
    "complemento": null,
    "cep": "80060000",
    "cidade": "Curitiba",
    "uf": "PR"
  },
  "status": "PENDENTE",
  "motivo": null,
  "dataHoraProcessamento": null,
  "_links": {
    "self":      { "href": "http://localhost:3000/solicitacoes/11122233396" },
    "aprovacao": { "href": "http://localhost:3000/solicitacoes/11122233396/aprovacao" },
    "rejeicao":  { "href": "http://localhost:3000/solicitacoes/11122233396/rejeicao" }
  }
}
```

> `aprovacao` e `rejeicao` **só existem enquanto `PENDENTE`**. Após rejeição ou aprovação esses rels desaparecem.

### Erros

**409 — CPF já possui solicitação (qualquer estado):**

```json
{
  "status": 409,
  "erro": "Conflict",
  "mensagem": "CPF já possui solicitação"
}
```

**409 — E-mail já usado em outra solicitação:**

```json
{
  "status": 409,
  "erro": "Conflict",
  "mensagem": "E-mail já usado em outra solicitação"
}
```

**409 — CPF já é cliente do seed:**

```json
{
  "status": 409,
  "erro": "Conflict",
  "mensagem": "CPF já possui cadastro de cliente"
}
```

**400 — Salário como number, CEP com pontos, UF inválida:**

```json
{
  "status": 400,
  "erro": "Bad Request",
  "mensagem": "Requisição malformada"
}
```

---

## TX-R8A — Listar solicitações

**Tutorial:** [transacoes/TX-R8A-listar-solicitacoes.md](transacoes/TX-R8A-listar-solicitacoes.md)

> GERENTE · filtro opcional `?status=PENDENTE|APROVADA|NAO_APROVADA`.

### Request

```http
GET /solicitacoes HTTP/1.1
Host: localhost:3000
x-access-token: <tokenGerente>
```

_(ou `GET /solicitacoes?status=PENDENTE`)_

### Response 200 — Lista com item PENDENTE

> `_links.self` da lista inclui query string se filtrado.

```json
{
  "solicitacoes": [
    {
      "cpf": "11122233396",
      "nome": "Fulano de Tal",
      "email": "fulano@exemplo.com.br",
      "telefone": "41999990000",
      "salario": "4500.00",
      "endereco": {
        "logradouro": "Rua XV de Novembro",
        "numero": "1299",
        "complemento": null,
        "cep": "80060000",
        "cidade": "Curitiba",
        "uf": "PR"
      },
      "status": "PENDENTE",
      "motivo": null,
      "dataHoraProcessamento": null,
      "_links": {
        "self":      { "href": "http://localhost:3000/solicitacoes/11122233396" },
        "aprovacao": { "href": "http://localhost:3000/solicitacoes/11122233396/aprovacao" },
        "rejeicao":  { "href": "http://localhost:3000/solicitacoes/11122233396/rejeicao" }
      }
    }
  ],
  "_links": {
    "self": { "href": "http://localhost:3000/solicitacoes" }
  }
}
```

> Solicitação já processada (APROVADA ou NAO_APROVADA) **não** traz `aprovacao` nem `rejeicao` — apenas `self`.

### Com filtro `?status=PENDENTE`

```json
{
  "solicitacoes": [ ... ],
  "_links": {
    "self": { "href": "http://localhost:3000/solicitacoes?status=PENDENTE" }
  }
}
```

### Erros

**403 — token de CLIENTE:**

```json
{
  "status": 403,
  "erro": "Forbidden",
  "mensagem": "Acesso negado"
}
```

**401 — sem token:** `{ "auth": false, "message": "Token não fornecido." }`

---

## TX-R8B — Consultar solicitação

**Tutorial:** [transacoes/TX-R8B-consultar-solicitacao.md](transacoes/TX-R8B-consultar-solicitacao.md)

### Request

```http
GET /solicitacoes/11122233396 HTTP/1.1
Host: localhost:3000
x-access-token: <tokenGerente>
```

### Response 200 — Solicitação PENDENTE

```json
{
  "cpf": "11122233396",
  "nome": "Fulano de Tal",
  "email": "fulano@exemplo.com.br",
  "telefone": "41999990000",
  "salario": "4500.00",
  "endereco": {
    "logradouro": "Rua XV de Novembro",
    "numero": "1299",
    "complemento": null,
    "cep": "80060000",
    "cidade": "Curitiba",
    "uf": "PR"
  },
  "status": "PENDENTE",
  "motivo": null,
  "dataHoraProcessamento": null,
  "_links": {
    "self":      { "href": "http://localhost:3000/solicitacoes/11122233396" },
    "aprovacao": { "href": "http://localhost:3000/solicitacoes/11122233396/aprovacao" },
    "rejeicao":  { "href": "http://localhost:3000/solicitacoes/11122233396/rejeicao" }
  }
}
```

### Response 200 — Solicitação NAO_APROVADA (após TX-R10)

> `aprovacao` e `rejeicao` ausentes. `motivo` e `dataHoraProcessamento` preenchidos.

```json
{
  "cpf": "11122233396",
  "nome": "Fulano de Tal",
  "email": "fulano@exemplo.com.br",
  "telefone": "41999990000",
  "salario": "4500.00",
  "endereco": {
    "logradouro": "Rua XV de Novembro",
    "numero": "1299",
    "complemento": null,
    "cep": "80060000",
    "cidade": "Curitiba",
    "uf": "PR"
  },
  "status": "NAO_APROVADA",
  "motivo": "Renda incompatível com a política do banco",
  "dataHoraProcessamento": "2026-08-18T16:40:00",
  "_links": {
    "self": { "href": "http://localhost:3000/solicitacoes/11122233396" }
  }
}
```

### Erros

**404 — CPF sem solicitação:**

```json
{
  "status": 404,
  "erro": "Not Found",
  "mensagem": "Solicitação não encontrada"
}
```

**403 — CLIENTE autenticado:**

```json
{
  "status": 403,
  "erro": "Forbidden",
  "mensagem": "Acesso negado"
}
```

---

## TX-R9 — Aprovar cliente (SAGA)

**Tutorial:** [transacoes/TX-R9-aprovar-cliente.md](transacoes/TX-R9-aprovar-cliente.md)

> GERENTE · sem body · Gateway **não** pré-valida PENDENTE (falha vai para o job).

### Request

```http
POST /solicitacoes/22233344405/aprovacao HTTP/1.1
Host: localhost:3000
x-access-token: <tokenGerente>
```

_(sem body)_

### Response 202 — Job aceito

Header: `Location: /jobs/8f14e45f-ceea-4e1b-9d2a-52f7254b1f0b/status`

> Sem `_links`. Sem `senha`. Não há 404/409 aqui — falha vai para o job.

```json
{
  "jobId": "8f14e45f-ceea-4e1b-9d2a-52f7254b1f0b",
  "status": "PENDENTE"
}
```

### Polling → GET /jobs/{jobId}/status → CONCLUIDO (ver [TX-JOB-01](#tx-job-01--status-do-job))

```json
{
  "jobId": "8f14e45f-ceea-4e1b-9d2a-52f7254b1f0b",
  "status": "CONCLUIDO",
  "resultType": "resource",
  "dominio": "clientes",
  "resourceId": "22233344405"
}
```

> `resultType = "resource"` → ir para `GET /clientes/22233344405`. **Não** usar [TX-JOB-02](#tx-job-02--resultado-inline-do-job).

### Job FALHA (CPF inexistente ou já aprovado/rejeitado)

```json
{
  "jobId": "8f14e45f-ceea-4e1b-9d2a-52f7254b1f0b",
  "status": "FALHA",
  "erro": "Solicitação não encontrada ou já processada"
}
```

### Job FALHA (e-mail já de gerente — caso especial)

```json
{
  "jobId": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
  "status": "FALHA",
  "erro": "E-mail já cadastrado"
}
```

> Neste caso a solicitação fica `NAO_APROVADA` (com motivo automático), não volta para PENDENTE.

---

## TX-R10 — Rejeitar cliente

**Tutorial:** [transacoes/TX-R10-rejeitar-cliente.md](transacoes/TX-R10-rejeitar-cliente.md)

> GERENTE · síncrono · 200 (não 202) · e-mail fire-and-forget.

### Request

```http
POST /solicitacoes/11122233396/rejeicao HTTP/1.1
Host: localhost:3000
Content-Type: application/json
x-access-token: <tokenGerente>
```

```json
{
  "motivo": "Renda incompatível com a política do banco"
}
```

### Response 200 — Rejeitada

> `aprovacao` e `rejeicao` **saem** dos `_links`. `dataHoraProcessamento` gerado no servidor (fuso São Paulo).

```json
{
  "cpf": "11122233396",
  "nome": "Fulano de Tal",
  "email": "fulano@exemplo.com.br",
  "telefone": "41999990000",
  "salario": "4500.00",
  "endereco": {
    "logradouro": "Rua XV de Novembro",
    "numero": "1299",
    "complemento": null,
    "cep": "80060000",
    "cidade": "Curitiba",
    "uf": "PR"
  },
  "status": "NAO_APROVADA",
  "motivo": "Renda incompatível com a política do banco",
  "dataHoraProcessamento": "2026-08-18T16:40:00",
  "_links": {
    "self": { "href": "http://localhost:3000/solicitacoes/11122233396" }
  }
}
```

### Erros

**409 — Já processada (rejeitar de novo):**

```json
{
  "status": 409,
  "erro": "Conflict",
  "mensagem": "Solicitação não está PENDENTE"
}
```

**400 — Sem `motivo` ou motivo vazio:**

```json
{
  "status": 400,
  "erro": "Bad Request",
  "mensagem": "Requisição malformada"
}
```

**404 — CPF sem solicitação.**
**403 — CLIENTE.**

---

## TX-CAD-01 — Consultar cliente

**Tutorial:** [transacoes/TX-CAD-01-consultar-cliente.md](transacoes/TX-CAD-01-consultar-cliente.md)

> GERENTE ou próprio CLIENTE · cacheado 5 min · sem `saldo`.

### Request

```http
GET /clientes/12912861012 HTTP/1.1
Host: localhost:3000
x-access-token: <tokenGerente ou tokenCliente próprio>
```

### Response 200 — Cliente (seed Catharyna)

```json
{
  "cpf": "12912861012",
  "nome": "Catharyna",
  "email": "cli1@bantads.com.br",
  "telefone": "41999990001",
  "salario": "10000.00",
  "endereco": {
    "logradouro": "Rua XV de Novembro",
    "numero": "1299",
    "complemento": null,
    "cep": "80060000",
    "cidade": "Curitiba",
    "uf": "PR"
  },
  "_links": {
    "self":  { "href": "http://localhost:3000/clientes/12912861012" },
    "conta": { "href": "http://localhost:3000/clientes/12912861012/conta" }
  }
}
```

> Não há `saldo` neste DTO. Para ver saldo: seguir `_links.conta` → [TX-R3A](#tx-r3a--conta-por-cpf).

### Erros

**403 — CLIENTE consultando outro CPF:**

```json
{
  "status": 403,
  "erro": "Forbidden",
  "mensagem": "Acesso negado"
}
```

**404 — CPF não é cliente (pode ser solicitação PENDENTE ainda):**

```json
{
  "status": 404,
  "erro": "Not Found",
  "mensagem": "Cliente não encontrado"
}
```

---

## TX-R11 — Listar clientes (Composition)

**Tutorial:** [transacoes/TX-R11-consultar-clientes.md](transacoes/TX-R11-consultar-clientes.md)

> GERENTE · Composition MS Cliente + MS Conta · ordenado por nome pt-BR · **sem cache** (tem saldo).

### Request

```http
GET /clientes?busca=Cat HTTP/1.1
Host: localhost:3000
x-access-token: <tokenGerente>
```

_(sem `busca` = todos os clientes)_

### Response 200 — Com filtro `?busca=Cat` (seed)

```json
{
  "clientes": [
    {
      "cpf": "12912861012",
      "nome": "Catharyna",
      "cidade": "Curitiba",
      "estado": "PR",
      "saldo": "800.00",
      "_links": {
        "self":  { "href": "http://localhost:3000/clientes/12912861012" },
        "conta": { "href": "http://localhost:3000/clientes/12912861012/conta" }
      }
    },
    {
      "cpf": "85733854057",
      "nome": "Catianna",
      "cidade": "Curitiba",
      "estado": "PR",
      "saldo": "200.00",
      "_links": {
        "self":  { "href": "http://localhost:3000/clientes/85733854057" },
        "conta": { "href": "http://localhost:3000/clientes/85733854057/conta" }
      }
    }
  ],
  "_links": {
    "self": { "href": "http://localhost:3000/clientes?busca=Cat" }
  }
}
```

> Campos da linha R11: `cpf`, `nome`, `cidade`, `estado` (UF), `saldo` string, `_links.self` e `_links.conta`. Sem `email`/`salario` (esses são do relatório R16).

### Response 200 — Sem filtro, seed completo (pt-BR)

```json
{
  "clientes": [
    {
      "cpf": "12912861012",
      "nome": "Catharyna",
      "cidade": "Curitiba",
      "estado": "PR",
      "saldo": "800.00",
      "_links": {
        "self":  { "href": "http://localhost:3000/clientes/12912861012" },
        "conta": { "href": "http://localhost:3000/clientes/12912861012/conta" }
      }
    },
    {
      "cpf": "85733854057",
      "nome": "Catianna",
      "cidade": "Curitiba",
      "estado": "PR",
      "saldo": "200.00",
      "_links": {
        "self":  { "href": "http://localhost:3000/clientes/85733854057" },
        "conta": { "href": "http://localhost:3000/clientes/85733854057/conta" }
      }
    },
    {
      "cpf": "09506382000",
      "nome": "Cleuddônio",
      "cidade": "Curitiba",
      "estado": "PR",
      "saldo": "10000.00",
      "_links": {
        "self":  { "href": "http://localhost:3000/clientes/09506382000" },
        "conta": { "href": "http://localhost:3000/clientes/09506382000/conta" }
      }
    },
    {
      "cpf": "76179646090",
      "nome": "Coândrya",
      "cidade": "Curitiba",
      "estado": "PR",
      "saldo": "1500.00",
      "_links": {
        "self":  { "href": "http://localhost:3000/clientes/76179646090" },
        "conta": { "href": "http://localhost:3000/clientes/76179646090/conta" }
      }
    },
    {
      "cpf": "58872160006",
      "nome": "Cutardo",
      "cidade": "Curitiba",
      "estado": "PR",
      "saldo": "150000.00",
      "_links": {
        "self":  { "href": "http://localhost:3000/clientes/58872160006" },
        "conta": { "href": "http://localhost:3000/clientes/58872160006/conta" }
      }
    }
  ],
  "_links": {
    "self": { "href": "http://localhost:3000/clientes" }
  }
}
```

---

## TX-R3A — Conta por CPF

**Tutorial:** [transacoes/TX-R3A-consultar-conta-cpf.md](transacoes/TX-R3A-consultar-conta-cpf.md)

> GERENTE ou próprio CLIENTE · CQRS query · **sem cache** (saldo muda).

### Request

```http
GET /clientes/12912861012/conta HTTP/1.1
Host: localhost:3000
x-access-token: <tokenCliente>
```

### Response 200 — CLIENTE dono (rels de escrita presentes)

```json
{
  "numero": "1291",
  "cpfCliente": "12912861012",
  "cpfGerente": "98574307084",
  "saldo": "800.00",
  "dataCriacao": "2000-01-01",
  "_links": {
    "self":          { "href": "http://localhost:3000/contas/1291" },
    "cliente":       { "href": "http://localhost:3000/clientes/12912861012" },
    "deposito":      { "href": "http://localhost:3000/contas/1291/deposito" },
    "saque":         { "href": "http://localhost:3000/contas/1291/saque" },
    "transferencia": { "href": "http://localhost:3000/contas/1291/transferencia" },
    "extrato":       { "href": "http://localhost:3000/contas/1291/extrato" }
  }
}
```

### Response 200 — GERENTE (sem rels de escrita)

> `deposito`, `saque`, `transferencia`, `extrato` **ausentes** — Gateway remove conforme perfil.

```json
{
  "numero": "1291",
  "cpfCliente": "12912861012",
  "cpfGerente": "98574307084",
  "saldo": "800.00",
  "dataCriacao": "2000-01-01",
  "_links": {
    "self":    { "href": "http://localhost:3000/contas/1291" },
    "cliente": { "href": "http://localhost:3000/clientes/12912861012" }
  }
}
```

### Erros

**403 — CLIENTE tentando conta de outro:**

```json
{
  "status": 403,
  "erro": "Forbidden",
  "mensagem": "Acesso negado"
}
```

---

## TX-R3B — Conta por número

**Tutorial:** [transacoes/TX-R3B-consultar-conta-numero.md](transacoes/TX-R3B-consultar-conta-numero.md)

> GERENTE ou CLIENTE dono · `self` canônico da conta · número é string de 4 dígitos.

### Request

```http
GET /contas/1291 HTTP/1.1
Host: localhost:3000
x-access-token: <tokenCliente>
```

> Zero à esquerda preservado: `GET /contas/0950` (quatro caracteres, não `950`).

### Response 200 — CLIENTE dono

> Mesma estrutura de [TX-R3A](#tx-r3a--conta-por-cpf).

```json
{
  "numero": "1291",
  "cpfCliente": "12912861012",
  "cpfGerente": "98574307084",
  "saldo": "800.00",
  "dataCriacao": "2000-01-01",
  "_links": {
    "self":          { "href": "http://localhost:3000/contas/1291" },
    "cliente":       { "href": "http://localhost:3000/clientes/12912861012" },
    "deposito":      { "href": "http://localhost:3000/contas/1291/deposito" },
    "saque":         { "href": "http://localhost:3000/contas/1291/saque" },
    "transferencia": { "href": "http://localhost:3000/contas/1291/transferencia" },
    "extrato":       { "href": "http://localhost:3000/contas/1291/extrato" }
  }
}
```

### Erros

**404 — Número inexistente:**

```json
{
  "status": 404,
  "erro": "Not Found",
  "mensagem": "Conta não encontrada"
}
```

**403 — CLIENTE de outra conta.**

---

## TX-R4 — Depósito

**Tutorial:** [transacoes/TX-R4-deposito.md](transacoes/TX-R4-deposito.md)

> CLIENTE dono · event sourcing · **sem saldo no response** · consistência eventual (2–5 s).

### Request

```http
POST /contas/1291/deposito HTTP/1.1
Host: localhost:3000
Content-Type: application/json
x-access-token: <tokenCliente>
```

```json
{
  "valor": "10.00"
}
```

> `"valor"` é `string` `"10.00"` — nunca `number` `10`.

### Response 201 — Depósito registrado

> Sem `saldo`. Seguir `_links.conta` para reconsultar (CQRS eventual).

```json
{
  "numeroConta": "1291",
  "tipo": "DEPOSITO",
  "dataHora": "2026-08-18T16:50:00",
  "valor": "10.00",
  "destino": null,
  "_links": {
    "conta":   { "href": "http://localhost:3000/contas/1291" },
    "extrato": { "href": "http://localhost:3000/contas/1291/extrato" }
  }
}
```

> Após 2–5 s: `GET /contas/1291` → `"saldo": "810.00"` (seed `800 + 10`).

### Erros

**400 — Valor como number ou formato incorreto:**

```json
{
  "status": 400,
  "erro": "Bad Request",
  "mensagem": "Requisição malformada"
}
```

**403 — CLIENTE depositando em conta alheia ou GERENTE tentando depositar.**

---

## TX-R5 — Saque

**Tutorial:** [transacoes/TX-R5-saque.md](transacoes/TX-R5-saque.md)

> CLIENTE dono · saldo validado no command por replay (nunca no read model).

### Request

```http
POST /contas/1291/saque HTTP/1.1
Host: localhost:3000
Content-Type: application/json
x-access-token: <tokenCliente>
```

```json
{
  "valor": "10.00"
}
```

### Response 201 — Saque registrado

```json
{
  "numeroConta": "1291",
  "tipo": "SAQUE",
  "dataHora": "2026-08-18T16:51:00",
  "valor": "10.00",
  "destino": null,
  "_links": {
    "conta":   { "href": "http://localhost:3000/contas/1291" },
    "extrato": { "href": "http://localhost:3000/contas/1291/extrato" }
  }
}
```

> Após 2–5 s: `GET /contas/1291` → `"saldo": "790.00"` (seed puro `800 − 10`).

### Erros

**422 — Saldo insuficiente (validado no command por replay):**

```json
{
  "status": 422,
  "erro": "Unprocessable Entity",
  "mensagem": "Saldo insuficiente para a operação"
}
```

> Nenhum evento gravado. Saldo permanece inalterado.

**403 — Conta alheia ou GERENTE.  400 — Formato do valor.**

---

## TX-R6 — Transferência

**Tutorial:** [transacoes/TX-R6-transferencia.md](transacoes/TX-R6-transferencia.md)

> CLIENTE dono da origem · **não é SAGA** · Gateway enriquece CPF e nomes antes de enviar ao MS Conta.

### Request

> O front envia **apenas** `contaDestino` e `valor`. O Gateway busca CPF e nomes internamente.

```http
POST /contas/1291/transferencia HTTP/1.1
Host: localhost:3000
Content-Type: application/json
x-access-token: <tokenCliente>
```

```json
{
  "contaDestino": "0950",
  "valor": "100.00"
}
```

### Response 201 — Transferência registrada

> `destino` preenchido pelo Gateway (enriquecido com CPF e nome). Sem `saldo`.

```json
{
  "numeroConta": "1291",
  "tipo": "TRANSFERENCIA",
  "dataHora": "2026-08-18T16:52:00",
  "valor": "100.00",
  "destino": {
    "numeroConta": "0950",
    "cpf": "09506382000",
    "nome": "Cleuddônio"
  },
  "_links": {
    "conta":   { "href": "http://localhost:3000/contas/1291" },
    "extrato": { "href": "http://localhost:3000/contas/1291/extrato" }
  }
}
```

> Após 2–5 s: origem `1291` → `"700.00"` · destino `0950` → `"10100.00"`.

### Erros

**422 — Transferência para a própria conta:**

```json
{
  "status": 422,
  "erro": "Unprocessable Entity",
  "mensagem": "Não é permitido transferir para a própria conta"
}
```

**422 — Conta destino inexistente:**

```json
{
  "status": 422,
  "erro": "Unprocessable Entity",
  "mensagem": "Conta destino inexistente"
}
```

**422 — Saldo insuficiente:**

```json
{
  "status": 422,
  "erro": "Unprocessable Entity",
  "mensagem": "Saldo insuficiente para a operação"
}
```

**403 — Conta de outro ou GERENTE.  400 — Formato inválido.**

---

## TX-R7 — Extrato

**Tutorial:** [transacoes/TX-R7-extrato.md](transacoes/TX-R7-extrato.md)

> CLIENTE dono · sem `inicio`/`fim` = últimos 30 dias · max 365 dias · GERENTE **403**.

### Request

```http
GET /contas/1291/extrato?inicio=2020-01-01&fim=2020-01-31 HTTP/1.1
Host: localhost:3000
x-access-token: <tokenCliente>
```

### Response 200 — Janeiro/2020 seed da Catharyna (7 movimentações)

> O front (Luxon) itera dia a dia somando `saldoAbertura` com as movimentações para montar a linha do tempo.

```json
{
  "numeroConta": "1291",
  "dataInicio": "2020-01-01",
  "dataFim": "2020-01-31",
  "saldoAbertura": "0.00",
  "movimentacoes": [
    {
      "dataHora": "2020-01-01T10:00:00",
      "tipo": "DEPOSITO",
      "valor": "1000.00",
      "origem": null,
      "destino": null
    },
    {
      "dataHora": "2020-01-01T11:00:00",
      "tipo": "DEPOSITO",
      "valor": "900.00",
      "origem": null,
      "destino": null
    },
    {
      "dataHora": "2020-01-01T12:00:00",
      "tipo": "SAQUE",
      "valor": "550.00",
      "origem": null,
      "destino": null
    },
    {
      "dataHora": "2020-01-01T13:00:00",
      "tipo": "SAQUE",
      "valor": "350.00",
      "origem": null,
      "destino": null
    },
    {
      "dataHora": "2020-01-10T15:00:00",
      "tipo": "DEPOSITO",
      "valor": "2000.00",
      "origem": null,
      "destino": null
    },
    {
      "dataHora": "2020-01-15T08:00:00",
      "tipo": "SAQUE",
      "valor": "500.00",
      "origem": null,
      "destino": null
    },
    {
      "dataHora": "2020-01-20T12:00:00",
      "tipo": "TRANSFERENCIA",
      "valor": "1700.00",
      "origem": {
        "numeroConta": "1291",
        "cpf": "12912861012",
        "nome": "Catharyna"
      },
      "destino": {
        "numeroConta": "0950",
        "cpf": "09506382000",
        "nome": "Cleuddônio"
      }
    }
  ],
  "_links": {
    "self":  { "href": "http://localhost:3000/contas/1291/extrato" },
    "conta": { "href": "http://localhost:3000/contas/1291" }
  }
}
```

> `origem` e `destino` preenchidos **somente em TRANSFERENCIA**. Em DEPOSITO/SAQUE são `null`.

### Response 200 — Padrão (sem query, últimos 30 dias, em 2026)

> Sem movimentos recentes no seed → lista vazia, `saldoAbertura` = saldo atual.

```json
{
  "numeroConta": "1291",
  "dataInicio": "2026-07-25",
  "dataFim": "2026-08-24",
  "saldoAbertura": "800.00",
  "movimentacoes": [],
  "_links": {
    "self":  { "href": "http://localhost:3000/contas/1291/extrato" },
    "conta": { "href": "http://localhost:3000/contas/1291" }
  }
}
```

### Erros

**422 — Intervalo maior que 365 dias:**

```json
{
  "status": 422,
  "erro": "Unprocessable Entity",
  "mensagem": "Intervalo maior que 365 dias"
}
```

**422 — `fim` anterior a `inicio`:**

```json
{
  "status": 422,
  "erro": "Unprocessable Entity",
  "mensagem": "Intervalo inválido: fim anterior ao início"
}
```

**403 — GERENTE (extrato é só CLIENTE dono).  404 — Conta inexistente.**

---

## TX-R12 — Listar gerentes (Composition)

**Tutorial:** [transacoes/TX-R12-listar-gerentes.md](transacoes/TX-R12-listar-gerentes.md)

> GERENTE · Composition MS Gerente + MS Conta · só ativos · ordenado pt-BR por nome.

### Request

```http
GET /gerentes HTTP/1.1
Host: localhost:3000
x-access-token: <tokenGerente>   (Geniéve — CPF 98574307084)
```

### Response 200 — Seed (Geniéve autenticada)

> Lista tem `_links.self` + `_links.criacao` (para POST R13).  
> Geniéve (autenticada): **sem** `remocao` em si mesma.  
> Demais: têm `remocao`.

```json
{
  "gerentes": [
    {
      "cpf": "40501740066",
      "nome": "Gadamântio",
      "email": "ger4@bantads.com.br",
      "telefone": "41988880004",
      "ativo": true,
      "quantidadeClientes": 0,
      "_links": {
        "self":       { "href": "http://localhost:3000/gerentes/40501740066" },
        "atualizacao":{ "href": "http://localhost:3000/gerentes/40501740066" },
        "remocao":    { "href": "http://localhost:3000/gerentes/40501740066" }
      }
    },
    {
      "cpf": "98574307084",
      "nome": "Geniéve",
      "email": "ger1@bantads.com.br",
      "telefone": "41988880001",
      "ativo": true,
      "quantidadeClientes": 2,
      "_links": {
        "self":        { "href": "http://localhost:3000/gerentes/98574307084" },
        "atualizacao": { "href": "http://localhost:3000/gerentes/98574307084" }
      }
    },
    {
      "cpf": "64065268052",
      "nome": "Godophredo",
      "email": "ger2@bantads.com.br",
      "telefone": "41988880002",
      "ativo": true,
      "quantidadeClientes": 2,
      "_links": {
        "self":        { "href": "http://localhost:3000/gerentes/64065268052" },
        "atualizacao": { "href": "http://localhost:3000/gerentes/64065268052" },
        "remocao":     { "href": "http://localhost:3000/gerentes/64065268052" }
      }
    },
    {
      "cpf": "23862179060",
      "nome": "Gyândula",
      "email": "ger3@bantads.com.br",
      "telefone": "41988880003",
      "ativo": true,
      "quantidadeClientes": 1,
      "_links": {
        "self":        { "href": "http://localhost:3000/gerentes/23862179060" },
        "atualizacao": { "href": "http://localhost:3000/gerentes/23862179060" },
        "remocao":     { "href": "http://localhost:3000/gerentes/23862179060" }
      }
    }
  ],
  "_links": {
    "self":    { "href": "http://localhost:3000/gerentes" },
    "criacao": { "href": "http://localhost:3000/gerentes" }
  }
}
```

---

## TX-CAD-02 — Consultar gerente

**Tutorial:** [transacoes/TX-CAD-02-consultar-gerente.md](transacoes/TX-CAD-02-consultar-gerente.md)

> GERENTE · cacheado 5 min · `quantidadeClientes` pode ser `null` (contagem vive na listagem R12).

### Request

```http
GET /gerentes/98574307084 HTTP/1.1
Host: localhost:3000
x-access-token: <tokenGerente>   (Geniéve)
```

### Response 200 — Próprio gerente autenticado (sem `remocao`)

```json
{
  "cpf": "98574307084",
  "nome": "Geniéve",
  "email": "ger1@bantads.com.br",
  "telefone": "41988880001",
  "ativo": true,
  "_links": {
    "self":        { "href": "http://localhost:3000/gerentes/98574307084" },
    "atualizacao": { "href": "http://localhost:3000/gerentes/98574307084" }
  }
}
```

### Response 200 — Outro gerente (com `remocao`)

`GET /gerentes/40501740066` (Gadamântio)

```json
{
  "cpf": "40501740066",
  "nome": "Gadamântio",
  "email": "ger4@bantads.com.br",
  "telefone": "41988880004",
  "ativo": true,
  "_links": {
    "self":        { "href": "http://localhost:3000/gerentes/40501740066" },
    "atualizacao": { "href": "http://localhost:3000/gerentes/40501740066" },
    "remocao":     { "href": "http://localhost:3000/gerentes/40501740066" }
  }
}
```

> `quantidadeClientes` pode ser `null` neste recurso unitário — não é erro.

### Erros

**404 — CPF inexistente:**

```json
{
  "status": 404,
  "erro": "Not Found",
  "mensagem": "Gerente não encontrado"
}
```

---

## TX-R13 — Inserir gerente (SAGA)

**Tutorial:** [transacoes/TX-R13-inserir-gerente.md](transacoes/TX-R13-inserir-gerente.md)

> GERENTE · senha no formulário (não vai por e-mail) · unicidade de e-mail verificada **dentro da SAGA**.

### Request

```http
POST /gerentes HTTP/1.1
Host: localhost:3000
Content-Type: application/json
x-access-token: <tokenGerente>
```

```json
{
  "cpf": "55667788990",
  "nome": "Gumercindo",
  "email": "ger5@bantads.com.br",
  "telefone": "41988880005",
  "senha": "tads"
}
```

> `senha` obrigatória · nunca volta no response · nunca vai para Redis da SAGA.

### Response 202 — Job aceito

Header: `Location: /jobs/11111111-2222-3333-4444-555555555555/status`

```json
{
  "jobId": "11111111-2222-3333-4444-555555555555",
  "status": "PENDENTE"
}
```

### Polling → CONCLUIDO resource

```json
{
  "jobId": "11111111-2222-3333-4444-555555555555",
  "status": "CONCLUIDO",
  "resultType": "resource",
  "dominio": "gerentes",
  "resourceId": "55667788990"
}
```

> `resultType = "resource"` → `GET /gerentes/55667788990`.

### GET /gerentes/55667788990 — Recurso criado

```json
{
  "cpf": "55667788990",
  "nome": "Gumercindo",
  "email": "ger5@bantads.com.br",
  "telefone": "41988880005",
  "ativo": true,
  "_links": {
    "self":        { "href": "http://localhost:3000/gerentes/55667788990" },
    "atualizacao": { "href": "http://localhost:3000/gerentes/55667788990" },
    "remocao":     { "href": "http://localhost:3000/gerentes/55667788990" }
  }
}
```

### Job FALHA — E-mail duplicado

```json
{
  "jobId": "11111111-2222-3333-4444-555555555555",
  "status": "FALHA",
  "erro": "E-mail já cadastrado"
}
```

> Compensação: `GET /gerentes/{cpfNovo}` → **404** (não ficou órfão).

### Erro síncrono 400 — Body incompleto (sem `senha`, `cpf`, etc.)

```json
{
  "status": 400,
  "erro": "Bad Request",
  "mensagem": "Requisição malformada"
}
```

> Sem `jobId`. 400 síncrono antes de criar job.

---

## TX-R14 — Atualizar gerente

**Tutorial:** [transacoes/TX-R14-atualizar-gerente.md](transacoes/TX-R14-atualizar-gerente.md)

> GERENTE · só `nome` e `telefone` mutáveis · invalida cache.

### Request

```http
PUT /gerentes/98574307084 HTTP/1.1
Host: localhost:3000
Content-Type: application/json
x-access-token: <tokenGerente>
```

```json
{
  "nome": "Geniéve Silva",
  "telefone": "41988889999"
}
```

### Response 200 — Atualizado

```json
{
  "cpf": "98574307084",
  "nome": "Geniéve Silva",
  "email": "ger1@bantads.com.br",
  "telefone": "41988889999",
  "ativo": true,
  "_links": {
    "self":        { "href": "http://localhost:3000/gerentes/98574307084" },
    "atualizacao": { "href": "http://localhost:3000/gerentes/98574307084" }
  }
}
```

> Cache invalidado → próximo GET retorna o novo nome imediatamente.

### Erros

**400 — Tentativa de mudar e-mail ou CPF:**

```json
{
  "status": 400,
  "erro": "Bad Request",
  "mensagem": "CPF e e-mail são imutáveis"
}
```

**404 — CPF inexistente.  403 — CLIENTE.**

---

## TX-R15 — Remover gerente (SAGA)

**Tutorial:** [transacoes/TX-R15-remover-gerente.md](transacoes/TX-R15-remover-gerente.md)

> GERENTE · resultado **inline** · auto-remoção = **403 síncrono** (sem job).

### Request — Auto-remoção (403 síncrono)

```http
DELETE /gerentes/98574307084 HTTP/1.1
Host: localhost:3000
x-access-token: <tokenGerente>   (Geniéve, CPF 98574307084)
```

**Response 403 — sem job:**

```json
{
  "status": 403,
  "erro": "Forbidden",
  "mensagem": "Não é permitido remover a si mesmo"
}
```

### Request — Remoção de outro gerente

```http
DELETE /gerentes/40501740066 HTTP/1.1
Host: localhost:3000
x-access-token: <tokenGerente>
```

### Response 202 — Job aceito

Header: `Location: /jobs/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee/status`

```json
{
  "jobId": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
  "status": "PENDENTE"
}
```

### Polling → CONCLUIDO inline

```json
{
  "jobId": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
  "status": "CONCLUIDO",
  "resultType": "inline"
}
```

> `resultType = "inline"` → `GET /jobs/{jobId}/result`.

### GET /jobs/{jobId}/result — Resultado

```json
{
  "mensagem": "Gerente removido; 0 contas transferidas para Gyândula"
}
```

> Gadamântio no seed tem 0 contas; destino é o ativo com menos clientes (Gyândula=1). Com contas: `"Gerente removido; N contas transferidas para {Nome}"`.

### Login do removido → 401

`POST /login` com `ger4@bantads.com.br` / `tads`:

```json
{
  "auth": false,
  "message": "Login inválido!"
}
```

### Job FALHA (já inativo ou CPF inexistente)

```json
{
  "jobId": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
  "status": "FALHA",
  "erro": "Gerente não encontrado ou já inativo"
}
```

### Job FALHA — Último gerente ativo

```json
{
  "jobId": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
  "status": "FALHA",
  "erro": "Não é permitido remover o último gerente ativo"
}
```

---

## TX-R16 — Relatório de clientes

**Tutorial:** [transacoes/TX-R16-relatorio-clientes.md](transacoes/TX-R16-relatorio-clientes.md)

> GERENTE · **GET** (não POST) · composition assíncrona sem `saga.cmd` · resultado inline · sem `_links` nas linhas.

### Request

```http
GET /relatorios/clientes HTTP/1.1
Host: localhost:3000
x-access-token: <tokenGerente>
```

### Response 202 — Job aceito

Header: `Location: /jobs/bbbbbbbb-cccc-dddd-eeee-ffffffffffff/status`

```json
{
  "jobId": "bbbbbbbb-cccc-dddd-eeee-ffffffffffff",
  "status": "PENDENTE"
}
```

### Polling → CONCLUIDO inline

```json
{
  "jobId": "bbbbbbbb-cccc-dddd-eeee-ffffffffffff",
  "status": "CONCLUIDO",
  "resultType": "inline"
}
```

### GET /jobs/{jobId}/result — Lista de clientes

> Ordenada pt-BR por nome. Sem `_links` em nenhum lugar do envelope. `saldo` e `salario` são `string`.

```json
{
  "clientes": [
    {
      "cpf": "12912861012",
      "nome": "Catharyna",
      "email": "cli1@bantads.com.br",
      "salario": "10000.00",
      "numeroConta": "1291",
      "saldo": "800.00",
      "cpfGerente": "98574307084",
      "nomeGerente": "Geniéve"
    },
    {
      "cpf": "85733854057",
      "nome": "Catianna",
      "email": "cli3@bantads.com.br",
      "salario": "3000.00",
      "numeroConta": "8573",
      "saldo": "200.00",
      "cpfGerente": "23862179060",
      "nomeGerente": "Gyândula"
    },
    {
      "cpf": "09506382000",
      "nome": "Cleuddônio",
      "email": "cli2@bantads.com.br",
      "salario": "20000.00",
      "numeroConta": "0950",
      "saldo": "10000.00",
      "cpfGerente": "64065268052",
      "nomeGerente": "Godophredo"
    },
    {
      "cpf": "76179646090",
      "nome": "Coândrya",
      "email": "cli5@bantads.com.br",
      "salario": "1500.00",
      "numeroConta": "7617",
      "saldo": "1500.00",
      "cpfGerente": "64065268052",
      "nomeGerente": "Godophredo"
    },
    {
      "cpf": "58872160006",
      "nome": "Cutardo",
      "email": "cli4@bantads.com.br",
      "salario": "500.00",
      "numeroConta": "5887",
      "saldo": "150000.00",
      "cpfGerente": "98574307084",
      "nomeGerente": "Geniéve"
    }
  ]
}
```

---

## TX-JOB-01 — Status do job

**Tutorial:** [transacoes/TX-JOB-01-status.md](transacoes/TX-JOB-01-status.md)

> Dono do job (mesmo CPF do 202) · sem `_links` · TTL 5 min.

### Request

```http
GET /jobs/8f14e45f-ceea-4e1b-9d2a-52f7254b1f0b/status HTTP/1.1
Host: localhost:3000
x-access-token: <mesmo token do POST/DELETE que criou o job>
```

### Response 200 — PENDENTE (ainda rodando)

```json
{
  "jobId": "8f14e45f-ceea-4e1b-9d2a-52f7254b1f0b",
  "status": "PENDENTE"
}
```

### Response 200 — CONCLUIDO resource (R9 / R13)

```json
{
  "jobId": "8f14e45f-ceea-4e1b-9d2a-52f7254b1f0b",
  "status": "CONCLUIDO",
  "resultType": "resource",
  "dominio": "clientes",
  "resourceId": "22233344405"
}
```

> Para R13: `"dominio": "gerentes"`.  
> Próximo passo: `GET /{dominio}/{resourceId}`. **Não** chamar `/result`.

### Response 200 — CONCLUIDO inline (R15 / R16)

```json
{
  "jobId": "8f14e45f-ceea-4e1b-9d2a-52f7254b1f0b",
  "status": "CONCLUIDO",
  "resultType": "inline"
}
```

> Próximo passo: [TX-JOB-02](#tx-job-02--resultado-inline-do-job).

### Response 200 — FALHA

```json
{
  "jobId": "8f14e45f-ceea-4e1b-9d2a-52f7254b1f0b",
  "status": "FALHA",
  "erro": "E-mail já cadastrado"
}
```

> `erro` é mensagem de negócio (string), **não** o envelope `{ status, erro, mensagem }`.

### Erros

**404 — UUID inexistente ou TTL expirado (> 5 min):**

```json
{
  "status": 404,
  "erro": "Not Found",
  "mensagem": "Job inexistente ou expirado"
}
```

**403 — Outro usuário tentando ver o job:**

```json
{
  "status": 403,
  "erro": "Forbidden",
  "mensagem": "Job não pertence ao usuário autenticado"
}
```

---

## TX-JOB-02 — Resultado inline do job

**Tutorial:** [transacoes/TX-JOB-02-result.md](transacoes/TX-JOB-02-result.md)

> Só para `resultType = "inline"` + `status = "CONCLUIDO"` · sem `_links`.

### Request

```http
GET /jobs/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee/result HTTP/1.1
Host: localhost:3000
x-access-token: <mesmo token>
```

### Response 200 — Resultado R15 (remoção de gerente)

```json
{
  "mensagem": "Gerente removido; 0 contas transferidas para Gyândula"
}
```

### Response 200 — Resultado R16 (relatório)

> Mesma estrutura de `GET /jobs/{id}/result` descrita em [TX-R16](#tx-r16--relatório-de-clientes).

```json
{
  "clientes": [ ... ]
}
```

### Erros

**409 — Job não concluído, FALHA ou `resultType = "resource"` (não inline):**

```json
{
  "status": 409,
  "erro": "Conflict",
  "mensagem": "Job ainda não concluído, falhou ou não é inline"
}
```

**404 — Expirado ou inexistente.**

---

## Resumo de envelopes de erro

| Situação | Status | Corpo |
|---|---|---|
| Body malformado | 400 | `{ "status": 400, "erro": "Bad Request", "mensagem": "Requisição malformada" }` |
| Token ausente | 401 | `{ "auth": false, "message": "Token não fornecido." }` |
| Token inválido/sessão encerrada | 401 | `{ "auth": false, "message": "Falha ao autenticar o token." }` |
| Credenciais erradas ou inativo | 401 | `{ "auth": false, "message": "Login inválido!" }` |
| Perfil sem permissão ou posse | 403 | `{ "status": 403, "erro": "Forbidden", "mensagem": "Acesso negado" }` |
| Auto-remoção (R15) | 403 | `{ "status": 403, "erro": "Forbidden", "mensagem": "Não é permitido remover a si mesmo" }` |
| Recurso não encontrado | 404 | `{ "status": 404, "erro": "Not Found", "mensagem": "..." }` |
| Job expirado | 404 | `{ "status": 404, "erro": "Not Found", "mensagem": "Job inexistente ou expirado" }` |
| Conflito de estado | 409 | `{ "status": 409, "erro": "Conflict", "mensagem": "..." }` |
| Regra de negócio síncrona | 422 | `{ "status": 422, "erro": "Unprocessable Entity", "mensagem": "..." }` |
| Job aceito (SAGA/assíncrono) | 202 | `{ "jobId": "uuid", "status": "PENDENTE" }` + header `Location` |
| MS fora / timeout | 502/504 | gerado pelo Gateway |

---

## Resumo de `_links` por recurso

| Recurso | Rels possíveis | Condição |
|---|---|---|
| Solicitação `PENDENTE` | `self`, `aprovacao`, `rejeicao` | sempre |
| Solicitação `APROVADA`/`NAO_APROVADA` | `self` | sempre |
| Lista de solicitações | `self` | inclui query string |
| Cliente (TX-CAD-01) | `self`, `conta` | sempre |
| Lista de clientes (R11) | `self`, `conta` por item | sempre |
| Envelope lista R11 | `self` | com ou sem `?busca=` |
| Conta — CLIENTE dono | `self`, `cliente`, `deposito`, `saque`, `transferencia`, `extrato` | sempre |
| Conta — GERENTE | `self`, `cliente` | `deposito`/`saque`/`transferencia`/`extrato` removidos |
| Extrato | `self`, `conta` | sempre |
| Operação (depósito/saque/transf.) | `conta`, `extrato` | sem `self` |
| Gerente ativo — não o logado | `self`, `atualizacao`, `remocao` | sempre |
| Gerente ativo — o próprio logado | `self`, `atualizacao` | `remocao` removido |
| Gerente inativo | `self` | sem `atualizacao`/`remocao` |
| Lista de gerentes (R12) | `self`, `criacao` no envelope | gerentes individuais conforme acima |
| Login | _(sem `_links`)_ | exceção |
| Logout (204) | _(sem `_links`)_ | exceção |
| Jobs (202/status/result) | _(sem `_links`)_ | exceção |
| `/health` | _(sem `_links`)_ | exceção |
| `/reboot` | _(sem `_links`)_ | exceção |
| Relatório (result R16) | _(sem `_links`)_  | exceção |
