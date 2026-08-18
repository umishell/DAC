# Transações BANTADS — como ler estes tutoriais

Cada arquivo desta pasta descreve **uma transação** ponta a ponta (o mesmo recorte que um diagrama de sequência). O **ID** no topo é idêntico ao tutorial HTTPie correspondente em [`../httpie/`](../httpie/00-GENERAL-INFO.md).

Para JSON de request/resposta e o passo a passo no HTTPie Desktop, abra o link **HTTPie** de cada arquivo. Aqui o foco é **o que o sistema faz por dentro**.

## Cliente HTTP (o “Front”)

O Angular 17+ ainda **não** está no repositório. Em produção ele será o único cliente de negócio: interceptor com header `x-access-token`, signals e UI dirigida por `_links`. Enquanto isso, o papel de “Front” nestes diagramas é qualquer cliente do Gateway (`http://localhost:3000`) — HTTPie, pytest ou o futuro SPA.

Contrato do front: [`.cursor/agents/frontend-angular.md`](../.cursor/agents/frontend-angular.md) · OpenAPI: [`docs/swagger_bantads.md`](../docs/swagger_bantads.md).

O front **nunca** chama Postgres, Mongo, Redis nem as portas 808x. Só o Gateway.

## Pipeline comum (rotas autenticadas)

1. Browser/HTTPie → `http://localhost:3000`  
2. [CORS](../backend/gateway/src/app.ts) aceita `x-access-token`  
3. [Hook JWT + sessão Redis](../backend/gateway/src/auth/hook.ts) injeta identidade  
4. Handler do Gateway (proxy, composition ou SAGA)  
5. MS Kotlin (`Controller → Service → Repository → DB`) **ou** RabbitMQ  
6. Resposta reescrita (HATEOAS) de volta ao front

Rotas públicas (sem token): `GET /health`, `POST /login`, `POST /reboot`, `POST /solicitacoes` — ver [`acl.ts`](../backend/gateway/src/auth/acl.ts).

## Catálogo

| ID | Tutorial | HTTPie |
|---|---|---|
| `TX-INFRA-01` | [health](./TX-INFRA-01-health.md) | [HTTPie](../httpie/TX-INFRA-01-health.md) |
| `TX-INFRA-02` | [reboot](./TX-INFRA-02-reboot.md) | [HTTPie](../httpie/TX-INFRA-02-reboot.md) |
| `TX-R2A` | [login](./TX-R2A-login.md) | [HTTPie](../httpie/TX-R2A-login.md) |
| `TX-R2B` | [logout](./TX-R2B-logout.md) | [HTTPie](../httpie/TX-R2B-logout.md) |
| `TX-R1` | [autocadastro](./TX-R1-autocadastro.md) | [HTTPie](../httpie/TX-R1-autocadastro.md) |
| `TX-R3A` | [conta por CPF](./TX-R3A-consultar-conta-cpf.md) | [HTTPie](../httpie/TX-R3A-consultar-conta-cpf.md) |
| `TX-R3B` | [conta por número](./TX-R3B-consultar-conta-numero.md) | [HTTPie](../httpie/TX-R3B-consultar-conta-numero.md) |
| `TX-R4` | [depósito](./TX-R4-deposito.md) | [HTTPie](../httpie/TX-R4-deposito.md) |
| `TX-R5` | [saque](./TX-R5-saque.md) | [HTTPie](../httpie/TX-R5-saque.md) |
| `TX-R6` | [transferência](./TX-R6-transferencia.md) | [HTTPie](../httpie/TX-R6-transferencia.md) |
| `TX-R7` | [extrato](./TX-R7-extrato.md) | [HTTPie](../httpie/TX-R7-extrato.md) |
| `TX-R8A` | [listar solicitações](./TX-R8A-listar-solicitacoes.md) | [HTTPie](../httpie/TX-R8A-listar-solicitacoes.md) |
| `TX-R8B` | [consultar solicitação](./TX-R8B-consultar-solicitacao.md) | [HTTPie](../httpie/TX-R8B-consultar-solicitacao.md) |
| `TX-R9` | [aprovar cliente SAGA](./TX-R9-aprovar-cliente.md) | [HTTPie](../httpie/TX-R9-aprovar-cliente.md) |
| `TX-R10` | [rejeitar cliente](./TX-R10-rejeitar-cliente.md) | [HTTPie](../httpie/TX-R10-rejeitar-cliente.md) |
| `TX-CAD-01` | [consultar cliente](./TX-CAD-01-consultar-cliente.md) | [HTTPie](../httpie/TX-CAD-01-consultar-cliente.md) |
| `TX-R11` | [listar clientes](./TX-R11-consultar-clientes.md) | [HTTPie](../httpie/TX-R11-consultar-clientes.md) |
| `TX-R12` | [listar gerentes](./TX-R12-listar-gerentes.md) | [HTTPie](../httpie/TX-R12-listar-gerentes.md) |
| `TX-CAD-02` | [consultar gerente](./TX-CAD-02-consultar-gerente.md) | [HTTPie](../httpie/TX-CAD-02-consultar-gerente.md) |
| `TX-R13` | [inserir gerente SAGA](./TX-R13-inserir-gerente.md) | [HTTPie](../httpie/TX-R13-inserir-gerente.md) |
| `TX-R14` | [atualizar gerente](./TX-R14-atualizar-gerente.md) | [HTTPie](../httpie/TX-R14-atualizar-gerente.md) |
| `TX-R15` | [remover gerente SAGA](./TX-R15-remover-gerente.md) | [HTTPie](../httpie/TX-R15-remover-gerente.md) |
| `TX-R16` | [relatório](./TX-R16-relatorio-clientes.md) | [HTTPie](../httpie/TX-R16-relatorio-clientes.md) |
| `TX-JOB-01` | [job status](./TX-JOB-01-status.md) | [HTTPie](../httpie/TX-JOB-01-status.md) |
| `TX-JOB-02` | [job result](./TX-JOB-02-result.md) | [HTTPie](../httpie/TX-JOB-02-result.md) |
