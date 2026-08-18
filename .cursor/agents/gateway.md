---
name: bantads-gateway
description: API Gateway Fastify/TypeScript do BANTADS — JWT, Redis, proxy, API Composition, jobs 202, rewrite HATEOAS, reboot. Use ao editar gateway/, login, logout, cache, polling de jobs ou rotas públicas do contrato.
---

# Agente — API Gateway (Fastify + TypeScript)

Único ponto de entrada. Front e pytest só falam com você na porta **3000**.

## Stack

Fastify + TypeScript + undici. Redis para sessão, cache cadastral, jobs, tokens revogados. RabbitMQ só para `saga.cmd` (R9/R13/R15) e disparo do relatório R16. Consultas e writes síncronos: REST aos MSs.

## Pipeline (ordem fixa)

`CORS → JWT (header x-access-token) → Redis sessão existe e não revogada → sliding TTL 30 min → role check → injeta X-User-CPF e X-User-Tipo → handler`

- JWT: `jwt.sign({ cpf, tipo, jti }, SECRET, { expiresIn: '8h' })`. SECRET só no Gateway.
- `exp` é vida **absoluta** (não renovar). Sliding window só no Redis (`sessao:{jti}` + `sessao:cpf:{cpf}`).
- Sem token → 401 `{ auth: false, message: "Token não fornecido." }`
- Inválido/expirado/sessão ausente/revogada → 401 `{ auth: false, message: "Falha ao autenticar o token." }`
- Login: body `{ email, senha }`. Auth via REST no MS Auth; compor `usuario` (cpf, nome, email) no MS Cliente ou Gerente. Resposta `{ auth, token, tipo, usuario }` **sem** `_links`. Inativo/errado → 401 `"Login inválido!"`.
- Logout: DEL sessões; `revogado:{jti}` com TTL = restante do JWT; **204**.

## Rotas públicas

`POST /login`, `POST /reboot`, `GET /health`, `POST /solicitacoes`.

Não aceite `Authorization: Bearer` como contrato. Não aceite campo `login` no body. Contrato = Swagger.

## Compositions (você agrega via REST)

- Login = Auth + Cliente/Gerente
- R11 `GET /clientes?busca=` = Cliente + saldos do Conta query; sort `Intl.Collator('pt-BR', { sensitivity: 'base' })`
- R12 `GET /gerentes` = Gerentes ativos + contagem do Conta query
- R16 relatório = job 202 `resultType=inline` (composition assíncrona)
- R6 transferência: **enriquecer** antes do MS Conta (CPF destino no query + nomes no MS Cliente)

## Jobs

R9/R13/R15: gerar UUID, `jobId === sagaId`, gravar `job:{id}` TTL 5 min, publicar `saga.cmd`, responder **202** + `Location: /jobs/{id}/status`. Gateway **não** pré-valida estado da solicitação na aprovação.

R15: se `X-User-CPF` == CPF do path → **403 síncrono**, sem SAGA.

`GET /jobs/{id}/result`: só `CONCLUIDO` + `inline`; senão 409; expirado 404. Sem `_links`.

## Cache-aside (só cadastro)

- `cache:cliente:{cpf}` e `cache:gerente:{cpf}`, TTL 5 min
- Invalidar: R9 (cliente); R13/R14/R15 (gerente)
- **Nunca** cachear saldo, extrato, quantidadeClientes

## HATEOAS

MSs geram `_links` internos. Você **reescreve** todo `href` para `GATEWAY_PUBLIC_URL`. Links dependem de estado + perfil. Conta do gerente: sem deposito/saque/transferencia/extrato de escrita. Gerente não recebe `remocao` de si mesmo.

## Reboot

`POST /reboot` público: chama `/internal/reboot` em Auth, Cliente, Gerente, Conta; `FLUSHDB` do Redis do BANTADS; `{ status: "ok", clientes: 5, gerentes: 4, contas: 5 }`.

## Não fazer

- Não revalidar JWT nos MSs (eles confiam em `X-User-*`)
- Não expor portas dos MSs
- Não devolver saldo novo em R4/R5/R6
- Heap: `NODE_OPTIONS=--max-old-space-size=192`, `mem_limit: 256m`
