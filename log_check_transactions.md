# Log de checagem das transações BANTADS

Marque o que já foi **testado no HTTPie** e **conferido no código** (`transacoes/` + implementação).  
Tutoriais: [`httpie/`](httpie/00-GENERAL-INFO.md) · [`transacoes/`](transacoes/00-GERAL.md).

**Como usar.** Cada transação tem um item **HTTPie** (rodar o request no Desktop e bater o contrato) e um item **Código** (abrir o tutorial de sequência e os arquivos citados). Os demais itens são regras, erros e subfluxos. Quando o seed estiver sujo, volte em `TX-INFRA-02` antes de continuar.

---

## TX-INFRA-01 — Health check do Gateway

- [ ] **HTTPie** — Siga [`httpie/TX-INFRA-01-health.md`](httpie/TX-INFRA-01-health.md). Método GET, URL `http://localhost:3000/health`, **sem** `x-access-token` e sem body. Confirme que o HTTPie não está apontando para porta 808x. Se der timeout/connection refused, a frota ainda não está `healthy` (`docker compose ps`).

- [ ] **Código** — Em [`backend/gateway/src/app.ts`](backend/gateway/src/app.ts) a rota é um handler estático `GET /health`. Em [`acl.ts`](backend/gateway/src/auth/acl.ts) ela entra na lista **pública**, então o hook JWT em [`hook.ts`](backend/gateway/src/auth/hook.ts) **não** deve exigir token. Cada MS tem `/health` próprio só para o Compose, não exposto no Gateway.

- [ ] **HTTP 200 `{ "status": "UP" }` sem `_links`** — O corpo tem exatamente a chave `status` com valor `UP` (maiúsculo). Não pode aparecer `_links`, `auth` nem envelope de erro. Qualquer outro JSON indica Gateway errado ou proxy na frente.

- [ ] **Healthchecks internos dos MSs não aparecem no Gateway** — No host, `localhost:8080` (e 8081…) **não** devem responder. Só a porta **3000** (Gateway), mais consoles de infra (5432, 27017, 6379, 5672, 15672). O front nunca chama microsserviço direto.

---

## TX-INFRA-02 — Reboot (recriar o seed)

- [ ] **HTTPie (timeout ≥ 90 s)** — Siga [`httpie/TX-INFRA-02-reboot.md`](httpie/TX-INFRA-02-reboot.md). POST `/reboot`, público, sem body. No HTTPie Desktop o timeout padrão (~30 s) costuma cortar a primeira chamada: suba para **90 s**. Espere 200, não um falso erro de timeout.

- [ ] **Código** — [`reboot.ts`](backend/gateway/src/routes/reboot.ts) dispara em paralelo `POST /internal/reboot` em Auth, Cliente, Gerente e Conta (timeout 60 s cada) e depois `FLUSHDB` no Redis do BANTADS. Confira os `RebootController` de cada MS e o seed de conta nos **dois** lados CQRS ([`SeedContas.kt`](backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/command/seed/SeedContas.kt)).

- [ ] **HTTP 200 com contagens do enunciado, sem `_links`** — Corpo **exato**: `{ "status": "ok", "clientes": 5, "gerentes": 4, "contas": 5 }`. `status` é a string `"ok"` (não `"UP"`). Não há `_links`. Se `clientes`/`gerentes`/`contas` vierem 0, o reboot interno de algum MS falhou (Gateway deveria ter respondido 500).

- [ ] **Idempotente: segundo reboot = mesmo JSON** — Sem mudar nada, POST `/reboot` de novo. O JSON tem que ser byte-a-byte o mesmo. Isso prova que o seed não “acumula” clientes/contas e que o event store é reconstruído, não só incrementado.

- [ ] **Saldos do seed no lado query** — Depois do reboot, logue `cli1`…`cli5` (ou um gerente) e GET das contas. Esperado: `1291` → `"800.00"`; `0950` → `"10000.00"`; `8573` → `"200.00"`; `5887` → `"150000.00"`; `7617` → `"1500.00"`. Sempre **string** com duas casas, nunca `800` number.

- [ ] **Event store replay = read model** — No código/teste de conta, o replay dos eventos do seed tem que reproduzir exatamente esses saldos. Se o GET da conta mostrar valor diferente do command, a projeção/CQRS está divergente (falha grave do enunciado).

- [ ] **Tokens antigos invalidam** — Se você tinha `tokenCliente`/`tokenGerente` no environment do HTTPie de **antes** do reboot, um GET autenticado deve virar 401 `"Falha ao autenticar o token."` (Redis zerado). Faça login de novo (TX-R2A) antes das próximas transações.

---

## TX-R2A — Login (R2)

- [ ] **HTTPie** — Siga [`httpie/TX-R2A-login.md`](httpie/TX-R2A-login.md). POST `/login` com JSON `{ "email", "senha" }` (campo **não** se chama `login`). Grave `token` em `tokenCliente` ou `tokenGerente`. Sem `_links` no body.

- [ ] **Código** — Fluxo: Gateway [`login.ts`](backend/gateway/src/routes/login.ts) → MS Auth `POST /auth/verificar` (Mongo + Argon2id, [`AuthService.verificar`](backend/services/auth/src/main/kotlin/br/ufpr/dac/bantads/auth/user/AuthService.kt)) → Gateway busca nome/e-mail no MS Cliente **ou** Gerente → [`jwt.sign`](backend/gateway/src/auth/jwt.ts) **só no Gateway** (`cpf`, `tipo`, `jti`, exp absoluto 8 h) → Redis [`createSession`](backend/gateway/src/redis/session.ts) (`sessao:{jti}` + `sessao:cpf:{cpf}`, TTL 30 min sliding). MS **não** valida JWT.

- [ ] **Cliente seed** — `cli1@bantads.com.br` / `tads` → 200, `auth: true`, `tipo: "CLIENTE"`, `usuario.cpf: "12912861012"`, `usuario.nome: "Catharyna"`, `usuario.email` igual ao login. Há `token` JWT (três partes). **Não** há senha no JSON. **Não** há `_links`.

- [ ] **Gerente seed** — `ger1@bantads.com.br` / `tads` → 200, `tipo: "GERENTE"`, `usuario.cpf: "98574307084"`, `usuario.nome: "Geniéve"`. Mesmas regras de ausência de `_links`/senha. Confirme que o HTTPie salvou este token à parte (`tokenGerente`), senão as rotas de gerente quebram.

- [ ] **Header `x-access-token`, não Bearer** — Nas requests seguintes, o token vai no header **`x-access-token`**. `Authorization: Bearer …` **não** é o contrato: o hook só lê aquele header. Se o HTTPie tiver aba Auth em Bearer, desligue e use Headers.

- [ ] **Senha errada → 401 login inválido** — Mesmo e-mail, senha `"errada"` → **401** (não 400/403) e corpo `{ "auth": false, "message": "Login inválido!" }` — **não** o envelope `{ status, erro, mensagem }`. Usuário inativo (depois de R15) usa a **mesma** mensagem.

- [ ] **Body malformado → 400** — Sem `email`/`senha`, ou tipos errados → 400 `{ "status": 400, "erro": "Bad Request", "mensagem": "Requisição malformada" }`. É validação Zod no Gateway, antes do Auth.

- [ ] **Sem token em rota protegida → 401 token ausente** — GET `/clientes/12912861012` **sem** header → `{ "auth": false, "message": "Token não fornecido." }` (com ponto final). Distinto da mensagem de token inválido.

- [ ] **Token lixo → 401 falha ao autenticar** — Header `x-access-token: nao.e.jwt` (ou JWT expirado / sessão já apagada) → `{ "auth": false, "message": "Falha ao autenticar o token." }`. Cobre assinatura inválida, `exp` estourado, `jti` revogado e sessão Redis inexistente.

---

## TX-R2B — Logout (R2)

- [ ] **HTTPie** — Siga [`httpie/TX-R2B-logout.md`](httpie/TX-R2B-logout.md). POST `/logout` **com** o token ainda válido. Sem body. Faça **depois** de ter um login fresco (reboot apaga sessão).

- [ ] **Código** — [`logout.ts`](backend/gateway/src/routes/logout.ts) chama [`revokeSession`](backend/gateway/src/redis/session.ts): `DEL sessao:{jti}` e `sessao:cpf:{cpf}`, e `SET revogado:{jti}` com TTL = tempo restante do JWT. O próximo `onRequest` recusa mesmo se o JWT ainda verificar assinatura.

- [ ] **POST `/logout` → HTTP 204 vazio** — Status **204 No Content**. Corpo vazio (não `{}`). Sem `_links`. Se vier 200 com JSON, o contrato quebrou.

- [ ] **Reusar o mesmo token → 401** — Copie o token **antes** do logout e GET `/clientes/12912861012` com ele. Esperado: 401 `"Falha ao autenticar o token."` (não `"Token não fornecido."`, porque o header está presente). Para continuar o log, faça TX-R2A de novo.

---

## TX-R1 — Autocadastro

- [ ] **HTTPie** — Siga [`httpie/TX-R1-autocadastro.md`](httpie/TX-R1-autocadastro.md). POST `/solicitacoes` **público** (sem token). Use CPF que **não** está no seed (ex. `11122233396`) e e-mail novo. JSON com `salario` string e `endereco` completo (CEP 8 dígitos, UF duas letras).

- [ ] **Código** — Rota pública em `acl.ts`. [`proxy.ts`](backend/gateway/src/routes/proxy.ts) encaminha ao MS Cliente. [`SolicitacaoService.criar`](backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/solicitacao/SolicitacaoService.kt) grava tabela `solicitacao` (schema `cliente`). [`ClienteAssembler`](backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/hateoas/ClienteAssembler.kt) só põe `aprovacao`/`rejeicao` se `PENDENTE`. Gateway reescreve `href` para `localhost:3000`.

- [ ] **POST novo CPF → 201 + Location + PENDENTE** — Status **201 Created**. Header `Location: /solicitacoes/11122233396` (path relativo). Body `status: "PENDENTE"`, `motivo: null`, `dataHoraProcessamento: null`. Não existe senha no payload.

- [ ] **`_links` apontam ao Gateway, não ao MS** — Existem `self`, `aprovacao`, `rejeicao`. Todo `href` começa com `http://localhost:3000/...` e **não** contém `:8080` / hostname `cliente`. A UI do gerente deve montar botões **só** a partir desses rels.

- [ ] **Salário (e todo dinheiro) é string** — `"4500.00"` com ponto e duas casas. Se o HTTPie/JSON mandar `4500` number, espere 400. No response, `salario` também string.

- [ ] **CPF duplicado → 409** — Repetir o **mesmo** POST → 409 `{ status: 409, erro: "Conflict", mensagem: "CPF já possui solicitação" }`. Vale para qualquer estado (PENDENTE, APROVADA, NAO_APROVADA): um CPF só tem uma solicitação na vida.

- [ ] **E-mail duplicado em outra solicitação → 409** — Mesmo e-mail, **outro** CPF válido → 409 `"E-mail já usado em outra solicitação"`. A unicidade final de login no Auth só entra na aprovação (R9); aqui a checagem é na tabela de solicitações/clientes.

- [ ] **CPF já cliente do seed → 409** — POST com `cpf: "12912861012"` (Catharyna) → 409 `"CPF já possui cadastro de cliente"`. Distinto de “já possui solicitação”.

- [ ] **Não cria conta, Auth nem senha** — GET `/clientes/{cpfNovo}` (com gerente) deve ser **404**. Login com o e-mail do autocadastro deve falhar. Não há linha no Mongo até TX-R9. A mensagem da tela é só “solicitação enviada”.

---

## TX-R3A — Consultar conta por CPF (R3)

- [ ] **HTTPie** — Siga [`httpie/TX-R3A-consultar-conta-cpf.md`](httpie/TX-R3A-consultar-conta-cpf.md). GET `/clientes/12912861012/conta` com `tokenCliente` da Catharyna **depois** de reboot (saldo conhecido).

- [ ] **Código** — [`ClienteContaQueryController`](backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/query/http/ClienteContaQueryController.kt) lê **somente** o read model (`conta_query`). Posse: `Identity.requireGerenteOrSelf`. O Gateway, em [`hateoas.ts`](backend/gateway/src/http/hateoas.ts), **apaga** rels `deposito|saque|transferencia|extrato` se o perfil for GERENTE. **Proibido** cachear esta resposta.

- [ ] **Dono no seed** — 200, `numero: "1291"` (string), `cpfCliente: "12912861012"`, `cpfGerente: "98574307084"` (Geniéve), `saldo: "800.00"`, `dataCriacao: "2000-01-01"`. Se o saldo não for 800, o seed/CQRS ou um movimento anterior sujou o estado.

- [ ] **Links do cliente (menu da home)** — Como CLIENTE, `_links` inclui `self` (`/contas/1291`), `cliente`, `deposito`, `saque`, `transferencia`, `extrato`. A tela inicial **não** inventa rotas: só mostra botão se o rel existir.

- [ ] **Mesma URL com gerente: lê saldo, sem escrita** — `tokenGerente` no mesmo GET → 200 com o mesmo saldo, mas **sem** `deposito`/`saque`/`transferencia`/`extrato`. `self` e `cliente` permanecem. Garante HATEOAS por perfil, não só ACL 403.

- [ ] **Cliente em conta de outro CPF → 403** — Catharyna GET `/clientes/09506382000/conta` → 403 `{ status: 403, erro: "Forbidden", mensagem: "Acesso negado" }`. Nem 404 (não vaza existência) nem 200.

- [ ] **Sem cache de saldo** — No código do Gateway, `cachedGet` só vale cadastro (`cache:cliente` / `cache:gerente`). GET de conta sempre vai ao MS. Depois de um depósito, um GET imediatamente **pode** ainda mostrar o saldo antigo (eventual); isso é CQRS, não cache.

---

## TX-R3B — Consultar conta pelo número

- [ ] **HTTPie** — Siga [`httpie/TX-R3B-consultar-conta-numero.md`](httpie/TX-R3B-consultar-conta-numero.md). GET `/contas/1291` (e `/contas/0950` com `cli2`). É o `self` que a home devolve.

- [ ] **Código** — [`ContaQueryController.obter`](backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/query/http/ContaQueryController.kt). ACL do Gateway para `GET /contas/{4 dígitos}` é `gerenteOrSelf` **por path de cliente** incompleto: a posse da **conta de outro número** é o MS (`requireGerenteOrOwner`). Confirme 403 no MS, não um 200 vazado.

- [ ] **`/contas/1291` dono = mesmo DTO de TX-R3A** — Mesmos campos e, para o cliente, os mesmos rels de escrita. `self` canônico é este path, não `/clientes/{cpf}/conta`.

- [ ] **Zero à esquerda é string de path** — GET `/contas/0950` (quatro caracteres, começa com zero). Se o HTTPie “numberizar” para `950`, a rota não casa (`^\d{4}$`) e vira 404/unknown. Use string na URL.

- [ ] **Outro cliente na conta alheia → 403** — `cli2` em `/contas/1291` → 403 `"Acesso negado"`. Gerente na mesma URL → 200 sem links de movimento.

- [ ] **Conta inexistente → 404** — `/contas/0001` → `{ status: 404, erro: "Not Found", mensagem: "Conta não encontrada" }`.

- [ ] **Reconsulta após R4/R5/R6 (consistência eventual)** — Este GET é o jeito certo de ver saldo novo. Se vier o valor antigo, espere ~2 s e repita até 3× / 5 s (como os testes de contrato). Não trate isso como falha na primeira tentativa.

---

## TX-R4 — Depósito

- [ ] **HTTPie** — Siga [`httpie/TX-R4-deposito.md`](httpie/TX-R4-deposito.md). Reboot primeiro. POST `/contas/1291/deposito` com `tokenCliente` da **dona**. Body `{ "valor": "10.00" }`.

- [ ] **Código** — [`ContaCommandController.depositar`](backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/command/http/ContaCommandController.kt) → [`writeMoney`](backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/command/http/ContaCommandService.kt): posse no command, append no **event store** (`conta_command`), publish **depois do commit** em `ms.conta.events`. [`EventProjector`](backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/query/project/EventProjector.kt) credita `conta_query`. A 201 **não** lê o read model.

- [ ] **201 sem campo `saldo`** — `tipo: "DEPOSITO"`, `numeroConta: "1291"`, `valor: "10.00"`, `dataHora` ISO sem offset (`America/Sao_Paulo`). Se existir `saldo` no JSON, o contrato quebrou (o front não pode confiar nisso).

- [ ] **`_links.conta` e `_links.extrato`** — O front **deve** seguir `conta` para reconsultar. `href` no Gateway. Não há `self` de operação obrigatório no Swagger além desses rels.

- [ ] **GET conta após 2–5 s → `"810.00"`** — Seed 800 + depósito 10. Se ficar 800 para sempre, a fila `ms.conta.events` ou o projector falhou. Se vier 810 na 201, também está errado (saldo não deveria estar ali).

- [ ] **Valor number / casas erradas → 400** — `{ "valor": 10 }` ou `"10.0"` ou `"10,00"` → 400 malformado. Padrão `^\d+\.\d{2}$`.

- [ ] **Depositar na conta de outro → 403** — Catharyna POST `/contas/0950/deposito` → 403. Gerente no POST de depósito → 403 já no Gateway (ACL `cliente`).

- [ ] **Evento no command; saldo da query é projeção** — No código, o saldo do command vem de **replay dos eventos**, nunca de `SELECT saldo`. A query só aplica o evento (idempotente via `projecao_aplicada`). Marque este item lendo `writeMoney` + `EventProjector`, não só o HTTP.

---

## TX-R5 — Saque

- [ ] **HTTPie** — Siga [`httpie/TX-R5-saque.md`](httpie/TX-R5-saque.md). Defina se está em seed puro (800) ou depois do depósito T04 (810). Teste **primeiro** o 422, depois o saque válido.

- [ ] **Código** — Mesmo `writeMoney` com `EventTypes.SAQUE`. A comparação `Money.gte(state.saldo, valor)` usa o estado **replayado**. 422 **antes** de append. Não há SAGA.

- [ ] **Saldo insuficiente → 422** — `{ "valor": "900.00" }` com saldo 800 → `{ status: 422, erro: "Unprocessable Entity", mensagem: "Saldo insuficiente para a operação" }`. **Não** é 400. Nenhum evento deve ser gravado (saldo da conta permanece 800).

- [ ] **Saque válido → 201 sem saldo** — `{ "valor": "10.00" }` → 201 `tipo: "SAQUE"`, sem `saldo`. `destino` nulo/ausente.

- [ ] **GET conta projetada** — Seed puro: `"790.00"`. Se você fez T04 (+10) e T05 (−10) como os testes de contrato: de volta a `"800.00"`. Anote qual cenário usou para não “falhar” o checklist.

- [ ] **Gerente / outra conta → 403** — POST saque com `tokenGerente` ou na conta 0950 com token da Catharyna → 403 `"Acesso negado"`.

- [ ] **Saldo não lido do read model na hora do saque** — Confira no código que não há `ContaReadRepository` no command de saque. Um atraso de projeção **não** pode autorizar saque a maior nem recusar saque válido.

---

## TX-R6 — Transferência

- [ ] **HTTPie** — Siga [`httpie/TX-R6-transferencia.md`](httpie/TX-R6-transferencia.md). Reboot. POST `/contas/1291/transferencia` com `{ "contaDestino": "0950", "valor": "100.00" }` e token da Catharyna. Depois teste os 422.

- [ ] **Código** — **Não é SAGA.** [`transferir` em proxy.ts](backend/gateway/src/routes/proxy.ts): valida mesma conta; GET interno da conta destino (CPF); GET `/clientes/nomes?cpfs=`; só então POST no command com `origem` e `destino` completos. [`ContaCommandService.transferir`](backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/command/http/ContaCommandService.kt) grava `TransferênciaOrigem` + `TransferênciaDestino` no **mesmo** `tx.execute`.

- [ ] **Body do front só `{ contaDestino, valor }`** — O JSON que **você** envia no HTTPie **não** tem nomes/CPFs. Se o contrato aceitar só isso e o MS exigir o enrich, o Gateway é obrigatório. Confira no código que o MS Conta recebe o body já enriquecido.

- [ ] **201 com `destino` preenchido** — `tipo: "TRANSFERENCIA"`, `valor: "100.00"`, `destino.numeroConta: "0950"`, `destino.cpf: "09506382000"`, `destino.nome: "Cleuddônio"` (acento). Sem `saldo`.

- [ ] **Sem campo `saldo` na 201** — Igual R4/R5: o front reconsulta as duas contas.

- [ ] **Saldos projetados no seed puro** — Origem 1291 → `"700.00"`; destino 0950 (token `cli2`) → `"10100.00"`. Esperar 2–5 s. `cli1` **não** consegue GET `/contas/0950` (403); use `cli2` ou gerente.

- [ ] **Origem = destino → 422** — `{ "contaDestino": "1291", "valor": "100.00" }` → `"Não é permitido transferir para a própria conta"`. Pode ser recusado já no Gateway (antes do MS).

- [ ] **Destino inexistente → 422** — `"0001"` → `"Conta destino inexistente"` (422, **não** 404). O enunciado trata conta destino inválida como regra de negócio da transferência.

- [ ] **Saldo insuficiente → 422** — Valor maior que o saldo da origem → mesma mensagem de saque `"Saldo insuficiente para a operação"`. Destino não deve ser creditado (atomicidade).

- [ ] **Nomes no extrato = enrich** — GET extrato da 1291 no dia da transferência: `origem.nome` / `destino.nome` iguais aos do MS Cliente na hora do POST. Não podem estar vazios em TRANSFERENCIA.

---

## TX-R7 — Extrato

- [ ] **HTTPie** — Siga [`httpie/TX-R7-extrato.md`](httpie/TX-R7-extrato.md). GET `/contas/1291/extrato` com token da dona. Teste o período jan/2020 **e** o default sem query **e** os 422.

- [ ] **Código** — [`ContaQueryService.extrato`](backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/query/http/ContaQueryService.kt) + [`ExtratoRegras`](backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/query/extrato/ExtratoRegras.kt). O MS **não** devolve linha por dia: só `saldoAbertura` + lista de movimentos. O front (Luxon) itera os dias. ACL Gateway: extrato é perfil **CLIENTE** (gerente 403).

- [ ] **Janeiro/2020 no seed da Catharyna** — `inicio=2020-01-01&fim=2020-01-31` → `saldoAbertura: "0.00"` (só o `Criado` em 2000), `movimentacoes.length === 7`, `dataInicio`/`dataFim` iguais à query.

- [ ] **Última linha é a transferência de 20/01/2020** — Índice 6: `tipo: "TRANSFERENCIA"`, `valor: "1700.00"`, `dataHora: "2020-01-20T12:00:00"`, `origem.nome: "Catharyna"`, `destino.numeroConta: "0950"`. Depósitos/saques no seed têm `origem`/`destino` nulos.

- [ ] **Sem query = últimos 30 dias** — Em 2026, com seed só até 2020 na Catharyna, `movimentacoes` pode ser `[]` e `saldoAbertura` igual ao saldo atual (`"800.00"` se não houve R4/R6). Isso é correto, não é bug de “extrato vazio”.

- [ ] **Intervalo > 365 dias → 422** — `inicio=2020-01-01&fim=2021-01-02` → `"Intervalo maior que 365 dias"`. 365 dias no limite deve passar; 366 não.

- [ ] **`fim` anterior a `inicio` → 422** — `"Intervalo inválido: fim anterior ao início"`. Outro 422, outra mensagem — não misturar com o de 365 dias.

- [ ] **Gerente no extrato → 403** — GET extrato com `tokenGerente` → 403 no Gateway (ACL), mesmo ele podendo GET a conta. Extrato é operação de cliente dono.

- [ ] **Dinheiro sempre string `^\d+\.\d{2}$`** — `saldoAbertura` e cada `valor` de movimentação. Walk no JSON: nenhum number solto nesses campos.

---

## TX-R8A — Listar solicitações (R8)

- [ ] **HTTPie** — Siga [`httpie/TX-R8A-listar-solicitacoes.md`](httpie/TX-R8A-listar-solicitacoes.md). Precisa de `tokenGerente` e, para ver PENDENTE, ter rodado TX-R1.

- [ ] **Código** — [`SolicitacaoController.listar`](backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/solicitacao/SolicitacaoController.kt) exige GERENTE. Assembler só adiciona `aprovacao`/`rejeicao` se status `PENDENTE`. [`hateoas.ts`](backend/gateway/src/http/hateoas.ts) `applyListSelf` coloca `_links.self` da **lista** (com query string se houver).

- [ ] **GET lista: PENDENTE tem os dois botões** — 200, array `solicitacoes`. O item `11122233396` (se criou no R1) tem `aprovacao` e `rejeicao`. A tela do gerente **não** mostra botão se o rel não existir.

- [ ] **Processada só tem `self`** — Depois de R9 ou R10, o mesmo CPF na lista **não** traz `aprovacao`/`rejeicao`. Evita aprovar/rejeitar de novo pela UI.

- [ ] **Filtro `?status=PENDENTE`** — GET `/solicitacoes?status=PENDENTE` só devolve pendentes. `_links.self` da lista deve **incluir** `status=PENDENTE` (href completo da request).

- [ ] **Token cliente → 403** — `cli1` no GET `/solicitacoes` → 403 `"Acesso negado"`. Não vaza a fila de análise.

- [ ] **Sem token → 401** — `{ "auth": false, "message": "Token não fornecido." }`. Distinguir de 403.

---

## TX-R8B — Consultar uma solicitação

- [ ] **HTTPie** — Siga [`httpie/TX-R8B-consultar-solicitacao.md`](httpie/TX-R8B-consultar-solicitacao.md). GET `/solicitacoes/{cpf}` com gerente. Use o CPF do R1 ou o do caso especial R9.

- [ ] **Código** — [`SolicitacaoController.obter`](backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/solicitacao/SolicitacaoController.kt) → `findByCpf` ou 404 `"Solicitação não encontrada"`. Mesmo assembler da lista (links dependem do status).

- [ ] **CPF existente → 200** — Mesmo DTO de um item de TX-R8A (campos + `_links` coerentes com o status atual). É o `self` que a lista aponta.

- [ ] **CPF inexistente → 404** — `/solicitacoes/00000000000` → `"Solicitação não encontrada"` no envelope `{ status, erro, mensagem }`.

- [ ] **Cliente autenticado → 403** — Mesmo tendo sido o autor do autocadastro, o GET autenticado como CLIENTE é 403 (perfil gerente). Autocadastro em si é público; a consulta depois não.

---

## TX-R9 — Aprovar cliente (SAGA)

- [ ] **HTTPie** — Siga [`httpie/TX-R9-aprovar-cliente.md`](httpie/TX-R9-aprovar-cliente.md). Não aprove o mesmo CPF que já rejeitou no R10. Fluxo limpo: autocadastro `22233344405` / `beltrano@exemplo.com.br`, depois POST aprovação, poll, GET cliente, ler outbox, login.

- [ ] **Código** — [`aprovacao.ts`](backend/gateway/src/routes/aprovacao.ts): UUID = `jobId` = `sagaId`, Redis job, publish `saga.cmd`. [`SagaRegistry.aprovarCliente`](backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/engine/SagaRegistry.kt): marcar aprovada → listar gerentes → escolher gerente com menos contas → criar cliente → Auth criar + senha aleatória → criar conta aleatória → e-mail FF. [`SagaEngine`](backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/engine/SagaEngine.kt): timeout 30 s nos passos transacionais; senha **não** no estado Redis; e-mail duplicado marca `NAO_APROVADA` em vez de voltar a PENDENTE.

### Subtransações da SAGA (sucesso)

- [ ] **Autocadastro prévio** — CPF e e-mail **novos** (não seed, não gerente). 201 PENDENTE. Sem isso a SAGA falha no primeiro passo e você não valida o caminho feliz.

- [ ] **POST aprovação → 202 imediato** — Sem body. `status: "PENDENTE"` no job, **sem** `_links`. Header `Location: /jobs/{uuid}/status` com o **mesmo** UUID do `jobId`. A resposta **não** espera a SAGA terminar (não pode demorar 30 s).

- [ ] **Gateway não pré-valida PENDENTE** — POST aprovação de CPF inexistente ou já processado **também** é 202. A falha aparece depois no job `FALHA`. Se o POST vier 404/409, o Gateway está validando demais (contrário ao Swagger).

- [ ] **Poll até CONCLUIDO resource** — GET `/jobs/{id}/status` com o **mesmo** token gerente, a cada ~0,5–1 s, até ~45 s. Esperado: `status: "CONCLUIDO"`, `resultType: "resource"`, `dominio: "clientes"`, `resourceId` = CPF aprovado. **Não** chame `/jobs/{id}/result` neste caso (é resource, não inline).

- [ ] **GET `/clientes/{cpf}` → 200** — Recurso apontado pelo job. Cadastro completo, `_links.conta`. Cache `cache:cliente:{cpf}` deve ter sido invalidado/DEL na conclusão da SAGA para não servir 404 antigo.

- [ ] **Número da conta aleatório de 4 dígitos** — GET da conta do novo cliente: `numero` tem 4 dígitos e **não** é `"2223"` (4 primeiros do CPF `22233344405`). Colisão: o gerador tenta de novo até achar livre. Seed 1291/0950/… é coincidência do enunciado, não regra de contas novas.

- [ ] **Gerente = ativo com menos clientes** — No seed, Gadamântio tem 0: a conta nova deve ir para ele (ou, se empate no mínimo, qualquer um do conjunto mínimo). Confira `cpfGerente` na conta. “Quem aprovou” (Geniéve) **não** precisa ser o gerente da conta.

- [ ] **Outbox MAIL_DEV com a senha** — Arquivo `outbox/beltrano@exemplo.com.br.txt` (raiz do repo, volume do MS Email). Linha `senha: …`. Se `MAIL_DEV=false` e Gmail não estiver configurado, este item não se aplica da mesma forma.

- [ ] **Login do novo cliente com a senha do outbox** — POST `/login` e-mail + senha gerada → `tipo: CLIENTE`. GET `/clientes/{cpf}` com esse token → 200 (próprio cadastro).

- [ ] **E-mail FF não aborta; senha clara só no payload Auth→orquestrador→Email** — No código: passo `EMAIL_SENHA_CLIENTE` é `FIRE_AND_FORGET` (sem reply, sem timeout). Estado Redis da SAGA **sem** campo senha. Logs não devem imprimir a senha. Persistência só hash Argon2 no Mongo.

### Falhas da SAGA (POST ainda 202)

- [ ] **Aprovar de novo / CPF inexistente → job FALHA** — Segundo POST no mesmo CPF já APROVADA, ou `00000000000`: HTTP do POST = **202**. Poll → `status: "FALHA"` e campo `erro` preenchido. O front trata falha no job, não no POST.

- [ ] **E-mail já de gerente (caso especial)** — Autocadastro com `email: "ger1@bantads.com.br"` e CPF novo → 201. Aprovar → job `FALHA`, `erro: "E-mail já cadastrado"`. GET solicitação → `NAO_APROVADA`, `motivo: "E-mail já cadastrado"`. GET `/clientes/{cpf}` → 404. Mongo **sem** usuário nesse CPF. Compensação **não** devolve a solicitação para PENDENTE.

- [ ] **Compensação idempotente** — No código: timeout 30 s e DLQ podem sinalizar o mesmo passo duas vezes; [`CompensationGuard`](backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/engine) deve ignorar a segunda. Não precisa reproduzir DLQ no HTTPie; leia o engine e os testes do SAGA. Marque se a leitura/teste unitário cobre “não compensar duas vezes”.

---

## TX-R10 — Rejeitar cliente

- [ ] **HTTPie** — Siga [`httpie/TX-R10-rejeitar-cliente.md`](httpie/TX-R10-rejeitar-cliente.md). Só em solicitação **PENDENTE** (R1). Não use o CPF que você pretende aprovar no R9.

- [ ] **Código** — [`SolicitacaoService.rejeitar`](backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/solicitacao/SolicitacaoService.kt): update síncrono + `emailPublisher.publishRejeicao` em `ms.email.cmd`. **Não** passa por `saga.cmd`. Falha de e-mail não desfaz o 200.

- [ ] **200 NAO_APROVADA + dataHora** — Body `{ "motivo": "Renda incompatível com a política do banco" }` → 200, `status: "NAO_APROVADA"`, `motivo` igual ao enviado, `dataHoraProcessamento` ISO sem offset (gerado no servidor, fuso São Paulo).

- [ ] **`_links` só `self`** — Sumiram `aprovacao` e `rejeicao`. A UI não pode mais mostrar os botões.

- [ ] **Segunda rejeição → 409** — Mesmo POST de novo → `"Solicitação não está PENDENTE"`. 409 (conflito de estado), não 422.

- [ ] **Sem `motivo` → 400** — Body `{}` ou motivo vazio → 400 malformado.

- [ ] **Outbox/e-mail com o motivo** — Em MAIL_DEV, o arquivo do e-mail do candidato contém o texto da recusa. Fire-and-forget: o 200 já veio **antes** de garantir SMTP.

- [ ] **Não usa job/202** — Status é **200**, não 202. Não há `jobId`. Se vier 202, alguém misturou R10 com SAGA.

---

## TX-CAD-01 — Consultar cliente (cadastro)

- [ ] **HTTPie** — Siga [`httpie/TX-CAD-01-consultar-cliente.md`](httpie/TX-CAD-01-consultar-cliente.md). GET `/clientes/12912861012` com gerente **ou** com a própria Catharyna.

- [ ] **Código** — [`cachedGet`](backend/gateway/src/routes/proxy.ts) + [`cache:cliente:{cpf}`](backend/gateway/src/redis/cache.ts) TTL 5 min. Miss: [`CadastroController.obter`](backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/cadastro/CadastroController.kt) (`requireGerenteOrSelf`). Invalidação: SAGA R9 `cache.deleteCliente`. **Não** incluir saldo neste DTO.

- [ ] **200 cadastro seed** — `nome: "Catharyna"`, `email: "cli1@bantads.com.br"`, `telefone: "41999990001"`, `salario: "10000.00"` (string), endereço Curitiba/PR Rua XV… **Não** há campo `saldo` aqui.

- [ ] **`_links.self` e `_links.conta`** — `conta` aponta para TX-R3A. Sem links de depósito neste recurso.

- [ ] **Outro cliente no CPF alheio → 403** — `cli1` GET `/clientes/09506382000` → 403.

- [ ] **Só solicitação, ainda não cliente → 404** — CPF do R1 ainda PENDENTE: GET `/clientes/{cpf}` → `"Cliente não encontrado"`. Aprovação (R9) é que cria a linha `cliente`.

- [ ] **Cache-aside e invalidação R9** — Segundo GET igual deve bater cache (mesmo JSON; no código `readCache` antes do MS). Depois de aprovar um **novo** CPF, o GET desse CPF não pode ficar 404 cacheado: a SAGA dá DEL na chave. Marque os dois comportamentos.

---

## TX-R11 — Consultar todos os clientes (composition)

- [ ] **HTTPie** — Siga [`httpie/TX-R11-consultar-clientes.md`](httpie/TX-R11-consultar-clientes.md). GET `/clientes` e `/clientes?busca=Cat` com `tokenGerente`.

- [ ] **Código** — [`listarClientes`](backend/gateway/src/routes/composition.ts): paralelo MS Cliente (cadastro + busca) + MS Conta `GET /internal/saldos`. [`composeClientes`](backend/gateway/src/routes/composition.ts) junta cidade/UF do endereço com saldo. Sort [`Intl.Collator('pt-BR')`](backend/gateway/src/http/pt-br.ts). **Não** cachear o resultado (tem saldo).

- [ ] **`?busca=Cat` → Catharyna, Catianna** — Nessa ordem, só esses dois nomes. Cleuddônio **não** entra. `busca` casa trecho de **nome ou CPF**.

- [ ] **Campos de cada linha (R11)** — `cpf`, `nome`, `cidade`, `estado` (UF), `saldo` string, `_links.self` e `_links.conta`. Não exige e-mail/salário nesta lista (isso é R16).

- [ ] **Sem busca: ordem pt-BR do seed** — Catharyna, Catianna, Cleuddônio, Coândrya, Cutardo (acentos = letra base, crescente por nome). Cinco clientes se ninguém foi aprovado a mais.

- [ ] **Token cliente → 403** — R11 é GERENTE.

- [ ] **Não cacheia saldo** — Confirme no Gateway que esta rota **não** usa `cachedGet`. Um depósito recente pode atrasar neste GET até a projeção — eventual, não cache escondendo defasagem eterna.

---

## TX-R12 — Listagem de gerentes (composition)

- [ ] **HTTPie** — Siga [`httpie/TX-R12-listar-gerentes.md`](httpie/TX-R12-listar-gerentes.md). GET `/gerentes` com token da **Geniéve** (para testar ausência de `remocao` nela).

- [ ] **Código** — [`listarGerentes`](backend/gateway/src/routes/composition.ts) + `/internal/contagem-por-gerente`. Lista `_links.criacao`. [`hateoas.ts`](backend/gateway/src/http/hateoas.ts): se `user.cpf === gerente.cpf`, **delete** `remocao`. Só gerentes `ativo: true`.

- [ ] **4 ativos, ordem de nomes** — Gadamântio, Geniéve (ou “Geniéve Silva” se já rodou R14), Godophredo, Gyândula. Collation pt-BR. `len === 4` no seed puro.

- [ ] **Quantidades de clientes no seed** — CPF `98574307084` → 2; `64065268052` → 2; `23862179060` → 1; `40501740066` → 0 (ou 1 se já houve R9 atribuindo conta nova a Gadamântio). Anote se o seed não está puro.

- [ ] **HATEOAS CRUD** — Lista tem `self` + `criacao` (POST R13). Cada item: `self`, `atualizacao`. Geniéve logada: **sem** `remocao`. Gadamântio/outros: **com** `remocao`. A UI não mostra “excluir a si mesmo”.

- [ ] **Token cliente → 403** — Perfil GERENTE obrigatório.

---

## TX-CAD-02 — Consultar um gerente

- [ ] **HTTPie** — Siga [`httpie/TX-CAD-02-consultar-gerente.md`](httpie/TX-CAD-02-consultar-gerente.md). GET `/gerentes/98574307084` e `/gerentes/40501740066` com o mesmo `tokenGerente`.

- [ ] **Código** — `cachedGet` com `cache:gerente:{cpf}`. Invalidar em R13/R14/R15. [`GerenteController.obter`](backend/services/gerente/src/main/kotlin/br/ufpr/dac/bantads/gerente/cadastro/GerenteController.kt). `quantidadeClientes` neste recurso **pode ser null** (composition da lista é que preenche).

- [ ] **GET próprio Geniéve** — 200, `atualizacao` presente, **sem** `remocao`. `email`/`cpf` imutáveis visíveis.

- [ ] **GET outro (Gadamântio)** — 200 com `_links.remocao` (DELETE R15). Comparar com a lista R12.

- [ ] **`quantidadeClientes` nula aqui é aceitável** — Não falhe o checklist se o GET unitário não trouxer a contagem. A R12 é a tela que mostra quantidade.

- [ ] **CPF inexistente → 404** — `"Gerente não encontrado"`.

---

## TX-R13 — Inserção de gerente (SAGA)

- [ ] **HTTPie** — Siga [`httpie/TX-R13-inserir-gerente.md`](httpie/TX-R13-inserir-gerente.md). Reboot recomendado para a regra da 1ª inserção (conta `7617`). Body com **senha no formulário** (não vai por e-mail).

- [ ] **Código** — [`inserir-gerente.ts`](backend/gateway/src/routes/inserir-gerente.ts) valida body; **não** checa e-mail único (isso é Auth na SAGA). [`SagaRegistry.inserirGerente`](backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/engine/SagaRegistry.kt): inserir gerente → Auth criar (senha do payload, guardada fora do Redis) → identificar conta R13 → se `semConta`, **pula** atribuir/e-mail. [`R13Selecao`](backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/command/r13/R13Selecao.kt): mais contas; empate → menor soma de saldos; transfere a conta de **menor** saldo; nunca zera quem só tem 1.

### Subtransações da SAGA (sucesso)

- [ ] **POST `/gerentes` → 202** — JSON com `cpf`, `nome`, `email`, `telefone`, `senha`. 202 `PENDENTE` + `Location`. A senha **não** volta no job nem no GET gerente.

- [ ] **Job CONCLUIDO resource gerentes** — `resultType: "resource"`, `dominio: "gerentes"`, `resourceId` = CPF enviado. Poll TX-JOB-01. Não use TX-JOB-02.

- [ ] **GET gerente + login com a senha do form** — 200 no recurso. POST `/login` com `ger5@…` / `tads` (ou a senha que você mandou) → `tipo: GERENTE`. Prova que o Auth persistiu o hash dessa senha, não uma aleatória.

- [ ] **Seed: 1ª inserção pega Coândrya `7617`** — No seed, Geniéve e Godophredo empatam em 2 contas; Godophredo tem menor soma; menor conta dele é `7617` (`1500.00`). Só vale com seed puro (reboot).

- [ ] **GET `/contas/7617` após projeção** — `cpfGerente` = CPF do Gumercindo (`55667788990` no tutorial). Evento `GerenteAlterado` + projector. Esperar 2–5 s. Godophredo fica com 1 conta (Cleuddônio), nunca 0.

- [ ] **`semConta`: sucesso sem e-mail de troca** — Se todos os ativos têm no máximo 1 conta, a SAGA **não** executa atribuir/consultar cliente/e-mail e mesmo assim `CONCLUIDO`. O novo gerente fica com 0 clientes. Não precisa forçar este cenário no HTTPie se o seed ainda tem quem tem 2; marque lendo o `skipIfTrue` no registry.

- [ ] **Inserção nunca zera gerente existente** — A regra “se o escolhido só tem 1 conta, não transfere” está no código R13. Marque ao ler `R13Selecao` / testes `R13SelecaoTest`.

### Falhas

- [ ] **E-mail duplicado → 202 depois FALHA + compensação** — Body com `email: "ger1@bantads.com.br"` e CPF novo → POST 202. Job `FALHA` `"E-mail já cadastrado"`. GET `/gerentes/{cpfNovo}` → **404** (passo gerente foi compensado). Não fica gerente sem Auth.

- [ ] **Body incompleto → 400 síncrono** — Sem senha/CPF/e-mail → 400 **antes** de criar job. Não há `jobId`. Distinto da duplicata de e-mail (essa é assíncrona).

---

## TX-R14 — Atualização de gerente

- [ ] **HTTPie** — Siga [`httpie/TX-R14-atualizar-gerente.md`](httpie/TX-R14-atualizar-gerente.md). PUT `/gerentes/98574307084` `{ "nome": "Geniéve Silva", "telefone": "41988889999" }`.

- [ ] **Código** — [`GerenteService.atualizar`](backend/services/gerente/src/main/kotlin/br/ufpr/dac/bantads/gerente/cadastro/GerenteService.kt): só grava nome/telefone; se `email`/`cpf` no body forem diferentes → 400 `"CPF e e-mail são imutáveis"`. Gateway [`PUT` em proxy.ts](backend/gateway/src/routes/proxy.ts) dá `DEL cache:gerente:{cpf}` no 200.

- [ ] **PUT válido → 200, e-mail/CPF iguais** — Nome e telefone novos; `email` continua `ger1@bantads.com.br`; `cpf` o mesmo. Login ainda é o e-mail antigo.

- [ ] **Tentar mudar e-mail → 400** — Incluir `"email": "outro@bantads.com.br"` → 400, mensagem de imutáveis. O registro no Auth **não** muda.

- [ ] **CPF inexistente → 404** — PUT em CPF que não existe.

- [ ] **Cliente → 403** — ACL GERENTE no Gateway.

- [ ] **Cache invalidado no 200** — GET gerente antes (popula cache), PUT, GET de novo: nome novo imediato, não o cache de 5 min com “Geniéve” antigo.

---

## TX-R15 — Remoção de gerente (SAGA)

- [ ] **HTTPie** — Siga [`httpie/TX-R15-remover-gerente.md`](httpie/TX-R15-remover-gerente.md). Login **Geniéve**. Teste 403 em si mesma **antes** de apagar Gadamântio. Reboot se o estado de gerentes estiver irreconhecível.

- [ ] **Código** — [`remover-gerente.ts`](backend/gateway/src/routes/remover-gerente.ts): se `request.user.cpf === path` → 403 **sem** publish. Senão 202 + SAGA. [`SagaRegistry.removerGerente`](backend/services/saga/src/main/kotlin/br/ufpr/dac/bantads/saga/engine/SagaRegistry.kt): inativar → Auth desativar → **LOCAL** apaga `sessao:cpf` + `sessao:jti` → listar ativos → transferir contas → e-mails FF. Job `inline` com `mensagem`.

### Subtransações

- [ ] **Auto-remoção 403 sem job** — DELETE `/gerentes/98574307084` com token da Geniéve → 403 `"Não é permitido remover a si mesmo"`. **Não** há `jobId` nem `Location`. A SAGA não inicia (Redis sem job novo).

- [ ] **DELETE Gadamântio → 202 PENDENTE** — `/gerentes/40501740066`. Mesmo padrão de Location/job das outras SAGAs. Gadamântio no seed tem 0 contas (mensagem com “0 contas” se seed puro).

- [ ] **Job CONCLUIDO inline** — `resultType: "inline"` (não `resource`). Não existe `GET /gerentes/{cpf}` como resultado de sucesso (ele fica inativo / some da lista R12).

- [ ] **GET `/jobs/{id}/result`** — 200 `{ "mensagem": "Gerente removido; N contas transferidas para {Nome}" }` sem `_links`. N e o nome do destino seguem a regra (ativo com **menos** clientes, ≠ removido). Seed puro + Gadamântio: N=0, destino típico Gyândula.

- [ ] **Login do removido → 401** — `ger4@bantads.com.br` / `tads` → `"Login inválido!"` (Auth `ativo=false`). Mesma mensagem de senha errada (não vazar “usuário desativado”).

- [ ] **Logout forçado no Redis** — Se Gadamântio estava com sessão (`token` de `ger4`), um GET autenticado com esse token após a SAGA → 401. O orquestrador apaga `sessao:cpf:{cpf}` e o `jti` apontado. Marque no HTTPie (login ger4, DELETE por ger1, reuse token ger4) **ou** no código do passo LOCAL.

- [ ] **Contas vão para quem tem menos clientes (ativo ≠ removido)** — Se remover alguém com contas, GET das contas migradas: `cpfGerente` novo. Evento `GerenteAlterado`. Nunca transferir para o próprio removido.

- [ ] **E-mails FF aos clientes transferidos** — Passo `EMAIL_TROCA_GERENTE` skip se `semContas`. Com contas, outbox por e-mail de cliente. Não aborta a SAGA se o SMTP falhar.

- [ ] **DELETE de novo / CPF inexistente → 202 + job FALHA** — Já inativo ou `00000000000`: POST/DELETE ainda **202**. Poll `FALHA`. O 404/409 **não** vem no DELETE.

- [ ] **GET result de job FALHA → 409** — TX-JOB-02: `"Job ainda não concluído, falhou ou não é inline"`. O erro de negócio está no **status** (`erro`), não no result.

- [ ] **Último gerente ativo → job FALHA** — Mensagem `"Não é permitido remover o último gerente ativo"`. Difícil no seed (são 4). Marque lendo `GerenteRules.ULTIMO_ATIVO` e o teste da SAGA, ou só execute se você já removeu os outros.

---

## TX-R16 — Relatório de clientes (composition async)

- [ ] **HTTPie** — Siga [`httpie/TX-R16-relatorio-clientes.md`](httpie/TX-R16-relatorio-clientes.md). GET `/relatorios/clientes` (método **GET**, não POST) com gerente. Poll + GET result.

- [ ] **Código** — [`relatorio.ts`](backend/gateway/src/routes/relatorio.ts): cria job, `setImmediate` composition, **não** publica `saga.cmd`. [`composeRelatorioClientes`](backend/gateway/src/routes/composition.ts): Cliente + saldos + nomes de gerente. `resultType=inline`. TTL job 5 min.

- [ ] **GET → 202 sem `_links` / sem `cpf` no envelope** — Body só `jobId` + `status: "PENDENTE"`. Não é a lista ainda. `Location` para o status. Cliente no mesmo GET → 403 (item mais abaixo).

- [ ] **Poll rápido → CONCLUIDO inline** — Costuma ser &lt; 5 s (só REST interno). `resultType: "inline"`. Sem `dominio`/`resourceId`.

- [ ] **GET result: lista completa R16** — ≥ 5 clientes no seed. Campos **obrigatórios por linha**: `cpf`, `nome`, `email`, `salario`, `numeroConta`, `saldo`, `cpfGerente`, `nomeGerente`. Ordem crescente por nome pt-BR (Catharyna … Cutardo). `salario`/`saldo` string. Se R14 rodou, `nomeGerente` pode ser “Geniéve Silva”.

- [ ] **Linhas sem `_links`** — Relatório/job são exceção HATEOAS. Nem o envelope nem cada linha têm `_links`.

- [ ] **Token cliente → 403** — GET `/relatorios/clientes` com `cli1` → 403 `"Acesso negado"`. Nem 202.

- [ ] **Job expira 5 min → 404** — Depois do TTL Redis, GET status/result → `"Job inexistente ou expirado"`. Não precisa esperar 5 min se o código de `JOB_TTL_SECONDS` estiver conferido; se testar no HTTPie, anote o horário.

---

## TX-JOB-01 — Polling do status do job

- [ ] **HTTPie** — Siga [`httpie/TX-JOB-01-status.md`](httpie/TX-JOB-01-status.md). Use um `jobId` real de R9/R13/R15/R16. Mesmo token de quem disparou. Repita GET até sair de PENDENTE.

- [ ] **Código** — [`jobs.ts`](backend/gateway/src/routes/jobs.ts) + [`jobStatusBody`](backend/gateway/src/redis/jobs.ts): só inclui `resultType`/`dominio`/`resourceId`/`erro` se não nulos. Dono = `job.cpf` == usuário do JWT. TTL 5 min. Sem `_links`. Nas SAGAs o **orquestrador** atualiza o mesmo UUID; no R16 o Gateway atualiza.

- [ ] **200 PENDENTE enquanto corre** — Body mínimo `{ jobId, status: "PENDENTE" }`. Ainda **sem** `resultType` (ou null omitido). Front continua o poll; não trata como erro.

- [ ] **200 CONCLUIDO com o resultType certo** — R9/R13: `resource` + `dominio` + `resourceId`. R15/R16: `inline` sem `resourceId`. Confira que o front ramifica: resource → GET entidade; inline → TX-JOB-02.

- [ ] **200 FALHA com `erro`** — SAGA de negócio (e-mail duplicado, último gerente, etc.). O POST/DELETE original foi 202. O `erro` é string de mensagem, **não** o envelope `{ status, erro, mensagem }` HTTP.

- [ ] **UUID inexistente / TTL → 404** — `"Job inexistente ou expirado"`. Envelope padrão de erro (não `{ auth, message }`).

- [ ] **Outro usuário → 403** — Dispare o job como ger1; GET status com token da Catharyna (ou ger2) → `"Job não pertence ao usuário autenticado"`.

- [ ] **Sem `_links` no status** — Exceção HATEOAS. Polling usa URL fixa `/jobs/{id}/status`, não rels.

---

## TX-JOB-02 — Resultado inline do job

- [ ] **HTTPie** — Siga [`httpie/TX-JOB-02-result.md`](httpie/TX-JOB-02-result.md). Só depois do status `CONCLUIDO` + `inline` (R15 ou R16).

- [ ] **Código** — GET result exige `status === CONCLUIDO` **e** `resultType === inline`; senão 409. Devolve `job.resultado` cru, **sem** `applyHateoas`.

- [ ] **Após R15: `{ mensagem }`** — Uma string começando com `"Gerente removido"`. Sem lista de clientes.

- [ ] **Após R16: `{ clientes: [...] }`** — Mesmo payload descrito em TX-R16. Sem `_links`.

- [ ] **Job resource (R9/R13) neste endpoint → 409** — Mesmo `CONCLUIDO`, `resultType=resource` → `"Job ainda não concluído, falhou ou não é inline"`. O recurso está em `GET /clientes/{cpf}` ou `GET /gerentes/{cpf}`.

- [ ] **Ainda PENDENTE → 409** — Chamar result cedo demais: mesma mensagem 409. Front deve pollar o **status** primeiro.

- [ ] **Expirado → 404** — TTL 5 min; mesma mensagem de job inexistente do TX-JOB-01.

---

## Convenções transversais (marcar quando revisar a frota)

- [ ] **HTTPie: environment e header** — Collection com `baseUrl=http://localhost:3000`. Tokens em variáveis. Toda rota autenticada usa **`x-access-token`**. Timeout 90 s só no reboot. JSON body com `Content-Type` application/json.

- [ ] **Front/testes só falam com o Gateway** — Nenhum request HTTPie para `localhost:808x`. Compose não publica as portas dos MSs. Interceptor Angular futuro = mesma regra.

- [ ] **Dinheiro JSON sempre string `"800.00"`** — Padrão `^\d+\.\d{2}$` em request e response (`saldo`, `valor`, `salario`, `saldoAbertura`). Nunca `number` / `800.0` / `"800,00"`.

- [ ] **Datas** — JSON: `2026-04-30T10:00:00` **sem** `Z` e sem offset. Query de extrato: `YYYY-MM-DD`. Relógio de negócio `America/Sao_Paulo`.

- [ ] **HATEOAS** — DTOs de negócio têm `_links`; `href` no Gateway. **Sem** `_links`: login, 202/status/result de jobs, `/health`, `/reboot`. Links dependem de **estado** (PENDENTE vs processada) e **perfil** (gerente sem escrita na conta; sem `remocao` de si mesmo).

- [ ] **Dois formatos de erro** — Auth (401 login/token): `{ "auth": false, "message": "…" }`. Resto: `{ "status": N, "erro": "Bad Request|Forbidden|Not Found|Conflict|Unprocessable Entity", "mensagem": "…" }`. Não misturar.

- [ ] **SAGA orquestrada; e-mail FF** — Só o orquestrador publica `ms.*.cmd`; MS **não** chama MS. E-mail sem `orquestrador.reply` e **não** dispara compensação. Passos Cliente/Gerente/Conta/Auth: timeout 30 s + compensação idempotente.
