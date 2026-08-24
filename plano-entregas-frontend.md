# Plano de entregas — Frontend Angular (3 pessoas)

**Projeto:** BANTADS — Internet Banking (DS152 / DAC / UFPR)  
**Ritmo:** 1 entrega / semana, toda terça. Mesma grade do [plano do backend](plano-entregas-backend.md).  
**Total:** 12 entregas · 25/08/2026 → 10/11/2026

> **Pré-requisito de cada entrega:** o backend correspondente (E0x) precisa estar de pé antes da
> integração. Use o backend deste repo de teste com `docker compose up` enquanto o backend
> oficial não estiver disponível.

> **Catálogo de contratos JSON** (requests + responses completos com `_links`): [`00-JSON-CATALOG.md`](00-JSON-CATALOG.md)

---

## Papéis (fixos, mudam só o recorte semanal)

| Papel | Foco permanente | Arquivos principais |
|---|---|---|
| **X** | Fundação, HTTP layer, interceptor, HATEOAS service, guards, routing, componentes compartilhados | `src/app/core/`, `src/app/shared/` |
| **Y** | Telas do **CLIENTE** (conta, home, operações, extrato, cadastro próprio) | `src/app/cliente/` |
| **Z** | Telas do **GERENTE** (solicitações, lista de clientes, CRUD gerentes, relatório, polling jobs) | `src/app/gerente/` |

Regra de ouro: X não inventa rotas (segue o Swagger). Y não hardcoda botão sem checar `_links`. Z não faz poll de job sem tratar `FALHA`.

---

## Conceitos fundamentais (ler antes da primeira entrega)

### 1. HATEOAS dirige a UI

O backend é Richardson **nível 3**: cada recurso retorna `_links` informando **quais ações são possíveis agora** para **este usuário**. A UI **não** deve ter `if (status === 'PENDENTE')` ou `if (tipo === 'GERENTE')` para mostrar/esconder botões. O botão existe se, e somente se, o rel existe no JSON.

Pipeline: MS Kotlin (gera `href` internos `http://cliente:8080/…`) → **Gateway reescreve** tudo para `http://localhost:3000/…` → Angular consome.

```
Recurso JSON recebido pelo Angular:
{
  "numero": "1291",
  "saldo": "800.00",
  "_links": {
    "self":          { "href": "http://localhost:3000/contas/1291" },
    "cliente":       { "href": "http://localhost:3000/clientes/12912861012/conta" },
    "deposito":      { "href": "http://localhost:3000/contas/1291/deposito" },
    "saque":         { "href": "http://localhost:3000/contas/1291/saque" },
    "transferencia": { "href": "http://localhost:3000/contas/1291/transferencia" },
    "extrato":       { "href": "http://localhost:3000/contas/1291/extrato" }
  }
}
```

O mesmo GET com token de **GERENTE** retorna o mesmo objeto, mas **sem** `deposito`, `saque`, `transferencia`, `extrato` — o Gateway remove esses rels. A UI não precisa saber o perfil para esconder os botões; só verifica `if (conta._links?.deposito)`.

Catálogo completo de rels: [transacoes/00-HATEOAS.md](transacoes/00-HATEOAS.md)

| Rel | Onde aparece | Ação Angular |
|---|---|---|
| `self` | quase todo recurso | reconsultar (refresh) |
| `conta` | cliente, operação, extrato | navegar para a conta (R3) |
| `cliente` | conta | cadastro do dono |
| `deposito` / `saque` / `transferencia` / `extrato` | conta do **CLIENTE** | telas R4–R7 |
| `aprovacao` / `rejeicao` | solicitação `PENDENTE` | R9 / R10 |
| `atualizacao` / `remocao` | gerente ativo (não o logado) | R14 / R15 |
| `criacao` | lista de gerentes | R13 |

**Exceções sem `_links`:** login, logout, jobs (202 / status / result), `/health`, `/reboot`, linhas do relatório.

### 2. Como usar `_links` no Angular (signal pattern)

```typescript
// models/hateoas.ts
export interface Links {
  self?: { href: string };
  conta?: { href: string };
  deposito?: { href: string };
  saque?: { href: string };
  transferencia?: { href: string };
  extrato?: { href: string };
  aprovacao?: { href: string };
  rejeicao?: { href: string };
  atualizacao?: { href: string };
  remocao?: { href: string };
  criacao?: { href: string };
  cliente?: { href: string };
}

// Uso no template Angular:
// @if (conta._links?.deposito) { <button>Depositar</button> }
// Nunca: @if (tipo === 'CLIENTE') { <button>Depositar</button> }
```

Após operação de escrita (R4/R5/R6), **a resposta 201 não traz saldo**. O Angular deve seguir `_links.conta` e fazer GET de novo:

```typescript
// Após depósito: seguir _links.conta do response e reconsultar
async depositar(href: string, valor: string) {
  const op = await this.http.post(href, { valor }).toPromise();
  // NÃO leia saldo do `op`. Siga op._links.conta:
  const conta = await this.http.get(op._links.conta.href).toPromise();
  this.saldo.set(conta.saldo); // sinal atualizado
}
```

### 3. Dinheiro (decimal.js)

JSON de entrada e saída **sempre** string `"800.00"` (padrão `^\d+\.\d{2}$`). Nunca `number`, nunca `800`, nunca `"800,00"`.

```typescript
import Decimal from 'decimal.js';

// Receber do backend:
const saldo = new Decimal(conta.saldo); // OK, "800.00"

// Exibir para o usuário (pt-BR):
saldo.toFixed(2).replace('.', ','); // "800,00"

// Enviar ao backend (campo do form em pt-BR → string de contrato):
const valorStr = new Decimal(formValue.replace(',', '.')).toFixed(2); // "100.00"
```

O `HttpClient` do Angular deserializa JSON com `JSON.parse`, que converte strings numéricas para `number` **somente se você não tipar o modelo**. Garanta que seus interfaces TypeScript tipem `saldo`, `valor`, `salario`, `saldoAbertura` como `string`.

### 4. Datas (Luxon)

Datas do backend: `"2026-04-30T10:00:00"` (sem `Z`, sem offset). Timezone de negócio: `America/Sao_Paulo`.

```typescript
import { DateTime } from 'luxon';

// Converter para exibição:
DateTime.fromISO('2026-04-30T10:00:00', { zone: 'America/Sao_Paulo' })
  .toFormat('dd/MM/yyyy HH:mm');

// Query de extrato (YYYY-MM-DD):
DateTime.now().toISODate(); // "2026-08-25"

// Extrato — montar linha do tempo dia a dia:
// O backend devolve saldoAbertura + movimentacoes (não agregado por dia).
// O Angular itera dia a dia com Luxon para montar o saldo consolidado.
```

### 5. Interceptor HTTP (`x-access-token`)

O token **não** vai em `Authorization: Bearer`. O header é `x-access-token`.

```typescript
// core/auth/token.interceptor.ts
export const tokenInterceptor: HttpInterceptorFn = (req, next) => {
  const auth = inject(AuthService);
  const token = auth.token();
  if (token) {
    return next(req.clone({ setHeaders: { 'x-access-token': token } }));
  }
  return next(req);
};
```

401 → limpar sessão local e redirecionar para `/login`.

### 6. Polling de jobs (SAGAs R9, R13, R15, R16)

Fluxo para todo 202:

1. POST/DELETE → 202 com `Location: /jobs/{uuid}/status` (ler o header `Location`, que o CORS expõe)
2. Poll `GET /jobs/{uuid}/status` a cada ~1 s até `status !== "PENDENTE"` (limite ~60 s)
3. Se `CONCLUIDO`:
   - `resultType === "resource"` → navegar para `GET /{dominio}/{resourceId}` (R9/R13)
   - `resultType === "inline"` → `GET /jobs/{uuid}/result` para obter o payload (R15/R16)
4. Se `FALHA` → exibir `erro` ao usuário (mensagem de negócio, não HTTP)

```typescript
// core/jobs/job-poll.service.ts
pollJob(jobId: string): Observable<JobStatus> {
  return interval(1000).pipe(
    switchMap(() => this.http.get<JobStatus>(`/jobs/${jobId}/status`)),
    takeWhile(j => j.status === 'PENDENTE', true),
    timeout(60_000),
  );
}
```

Jobs não têm `_links`. O front usa a URL `/jobs/{id}/status` construída a partir do header `Location` do 202.

### 7. Erros HTTP — dois envelopes distintos

```typescript
// Auth (401 login/token):
{ "auth": false, "message": "Login inválido!" }
{ "auth": false, "message": "Token não fornecido." }
{ "auth": false, "message": "Falha ao autenticar o token." }

// Todo o resto:
{ "status": 409, "erro": "Conflict", "mensagem": "Solicitação não está PENDENTE" }
{ "status": 422, "erro": "Unprocessable Entity", "mensagem": "Saldo insuficiente para a operação" }
```

O interceptor ou um `ErrorHandler` central deve discriminar pelo campo `auth` (boolean).

### 8. Gateway é a única origem

```typescript
// environments/environment.ts
export const environment = {
  gatewayUrl: 'http://localhost:3000',
};

// Em NENHUM lugar do front pode aparecer:
// localhost:8080, localhost:8081, localhost:8082, localhost:8083, localhost:8084
// auth:8080, cliente:8080, etc.
```

Referências: [transacoes/00-GATEWAY.md](transacoes/00-GATEWAY.md) · [transacoes/00-HATEOAS.md](transacoes/00-HATEOAS.md) · [transacoes/00-JWT.md](transacoes/00-JWT.md)

---

## Tabela de entregas

| # | Data | Módulo | Backend pré-req | Transações validadas |
|---|---|---|---|---|
| F01 | 25/08/2026 | Setup + fundação | E01 (health) | TX-INFRA-01 |
| F02 | 01/09/2026 | Interceptor + serviços HTTP + models | E02 (MS Auth) | — |
| F03 | 08/09/2026 | Login / logout / guard de rota | E03 (Gateway JWT) | TX-R2A, TX-R2B |
| F04 | 15/09/2026 | Integração seed + feedback de erros | E04 (seed/reboot) | TX-INFRA-02 |
| F05 | 22/09/2026 | Autocadastro + telas de solicitação | E05 (MS Cliente síncrono) | TX-R1, TX-R8A, TX-R8B, TX-R10, TX-CAD-01 |
| F06 | 29/09/2026 | Home do cliente + conta (leitura) | E06 (MS Conta query) | TX-R3A, TX-R3B |
| F07 | 06/10/2026 | Depósito, saque, transferência, extrato | E07 (MS Conta command) | TX-R4, TX-R5, TX-R6, TX-R7 |
| F08 | 13/10/2026 | Dashboard gerente + composition R11/R12 + CRUD gerente | E08 (MS Gerente + composition) | TX-R11, TX-R12, TX-CAD-02, TX-R14 |
| F09 | 20/10/2026 | Infraestrutura de jobs + relatório assíncrono | E09 (jobs + R16) | TX-JOB-01, TX-JOB-02, TX-R16 |
| F10 | 27/10/2026 | Fluxo de aprovação de cliente (SAGA R9) | E10 (SAGA R9) | TX-R9 |
| F11 | 03/11/2026 | Inserção de gerente (SAGA R13) | E11 (SAGA R13) | TX-R13 |
| F12 | 10/11/2026 | Remoção de gerente (SAGA R15) + aceite total | E12 (SAGA R15) | TX-R15 + convenções transversais |

---

## F01 — 25/08/2026 — Setup + fundação

**Backend disponível:** [E01 health](plano-entregas-backend.md) · Ler: [transacoes/00-GATEWAY.md](transacoes/00-GATEWAY.md) · [transacoes/00-HATEOAS.md](transacoes/00-HATEOAS.md)

**Por que agora?** O backend só tem `/health` nesta semana. É o momento ideal para montar o projeto sem dependências de negócio.

### X — Fundação do projeto

- [ ] `ng new bantads-frontend --standalone --routing --style=scss` (ou equivalente no repo oficial)
- [ ] Instalar dependências: `decimal.js`, `luxon`, `@types/luxon`
- [ ] Estrutura de pastas: `core/`, `shared/`, `cliente/`, `gerente/`, `public/`
- [ ] `environments/environment.ts` com `gatewayUrl: 'http://localhost:3000'`
- [ ] `BaseApiService` ou `provideHttpClient` com `withInterceptors([])`; `BASE_URL` como `InjectionToken`
- [ ] Modelo base de HATEOAS: interface `Links` e `HateoasResource<T>`
- [ ] Testar `GET http://localhost:3000/health` manualmente → `{ "status": "UP" }` sem `_links`

### Y — Roteamento e shell de telas

- [ ] `AppRoutingModule` / `provideRouter` com rotas: `/login`, `/autocadastro`, `/cliente`, `/gerente`
- [ ] `ShellComponent` com `<router-outlet>` e placeholder de navbar
- [ ] Tela de login: formulário `{ email, senha }` (sem campo `login`), campos tipados, sem lógica de API ainda
- [ ] Tela de autocadastro: todos os campos do contrato (CPF, nome, e-mail, telefone, salário, endereço completo com CEP 8 dígitos, UF 2 letras)

### Z — Design system e componentes compartilhados

- [ ] `MoneyPipe` que formata string `"800.00"` → `"R$ 800,00"` (usando `decimal.js`)
- [ ] `DatetimePipe` que formata `"2026-04-30T10:00:00"` → `"30/04/2026 10:00"` (Luxon)
- [ ] `AlertComponent` para exibir erros HTTP (suporta os dois envelopes de erro)
- [ ] `LoadingSpinnerComponent` (reutilizado em polls de job)

**Aceite F01:** `GET http://localhost:3000/health` → 200. `ng serve` sobe sem erros. Rotas navegam entre shells. `MoneyPipe` formata corretamente.

---

## F02 — 01/09/2026 — Interceptor + serviços HTTP + models

**Backend disponível:** [E02 MS Auth](plano-entregas-backend.md) · Ler: [transacoes/TX-R2A-login.md](transacoes/TX-R2A-login.md) · [transacoes/00-JWT.md](transacoes/00-JWT.md)

**Por que agora?** O MS Auth existe mas o Gateway JWT ainda não. O foco é construir o layer HTTP completo — quando o E03 chegar, a integração será só "ligar os cabos".

### X — Interceptor e AuthService

- [ ] `TokenInterceptor`: lê `AuthService.token()` (signal) e injeta `x-access-token` em **todas** as requests. Nunca `Authorization: Bearer`
- [ ] Na resposta 401 → `AuthService.logout()` → `Router.navigate(['/login'])`
- [ ] `AuthService`: signals `token`, `usuario`, `tipo`; métodos `login(email, senha)`, `logout()`, `isAuthenticated()`, `isCliente()`, `isGerente()`
- [ ] Token armazenado em `sessionStorage` (permitido pelo enunciado; não Local Storage para dados de negócio)
- [ ] `AuthGuard` para `/cliente` (requer CLIENTE) e `GerenteGuard` para `/gerente` (requer GERENTE)

### Y — Serviços de cliente e conta (stubs)

- [ ] `ClienteService` com métodos para cada rota de cliente (corpos mockados por enquanto): `autocadastro()`, `getCliente()`, `getSolicitacao()`, `listarSolicitacoes()`
- [ ] `ContaService`: `getConta()`, `getContaPorNumero()`, `getExtrato()`
- [ ] Models TypeScript espelhando o Swagger: `ClienteView`, `ContaView`, `SolicitacaoView`, `ExtratoView`; **campos de dinheiro como `string`**

### Z — Serviços de gerente e utilitários

- [ ] `GerenteService`: `listarGerentes()`, `getGerente()`, `atualizarGerente()`, `inserirGerente()`, `removerGerente()`
- [ ] `JobService`: `pollStatus(jobId)`, `getResult(jobId)` (lógica de polling completa com `interval` + `takeWhile` + `timeout`)
- [ ] `ErrorHandlerService` central: discrimina `{ auth }` vs `{ status, erro, mensagem }`

**Aceite F02:** Testes unitários de `MoneyPipe`, `DatetimePipe`, `AuthService`, `JobService.pollStatus` mock. Interceptor injeta header corretamente em request simulada.

---

## F03 — 08/09/2026 — Login / logout / guard de rota

**Backend disponível:** [E03 Gateway JWT/login/logout](plano-entregas-backend.md) · Ler: [transacoes/TX-R2A-login.md](transacoes/TX-R2A-login.md) · [transacoes/TX-R2B-logout.md](transacoes/TX-R2B-logout.md) · [transacoes/00-ACL.md](transacoes/00-ACL.md)

**Por que agora?** O Gateway assina JWT e gerencia sessão Redis. Esta é a primeira entrega com integração real end-to-end.

### X — Pipeline de autenticação completa

- [ ] `LoginComponent` conectado ao `AuthService.login()` real (`POST /login`)
- [ ] Após login: redirecionar para `/cliente` (tipo `CLIENTE`) ou `/gerente` (tipo `GERENTE`)
- [ ] `AuthGuard` e `GerenteGuard` ativados no roteamento
- [ ] Logout: `POST /logout` → `AuthService.logout()` → limpar signals e sessionStorage → `/login`
- [ ] Sliding session: o interceptor não precisa renovar (isso é Redis no Gateway); basta enviar o token em toda request
- [ ] Mensagem exata no 401: diferenciar `"Token não fornecido."` / `"Falha ao autenticar o token."` / `"Login inválido!"` — exibir a `message` ao usuário

### Y — Tela de login (UI)

- [ ] Formulário responsivo com `email` + `senha` (campo **não** se chama `login`)
- [ ] Botão desabilitado durante request (loading spinner)
- [ ] Exibir erro do backend (`AlertComponent`): mensagem `"Login inválido!"` ao errar senha
- [ ] Redirecionar automaticamente se já logado (guard no `/login`)

### Z — Shell pós-login

- [ ] `ClienteShellComponent`: navbar com "Minha Conta", "Extrato", "Dados", "Sair"
- [ ] `GerenteShellComponent`: navbar com "Solicitações", "Clientes", "Gerentes", "Relatório", "Sair"
- [ ] O `tipo` vem do `AuthService.tipo()` signal — não hardcodado

**Validar ([TX-R2A](transacoes/TX-R2A-login.md), [TX-R2B](transacoes/TX-R2B-logout.md)):**

- [ ] Login `cli1@bantads.com.br` / senha **errada** → `"Login inválido!"` visível na tela
- [ ] Login sem token em rota protegida → redirect para `/login`
- [ ] Logout → 204 → redirect → token reusado → 401 → usuário na tela de login
- [ ] Resposta de login **não** tem `_links` — verificar que a tela não tenta renderizá-los

---

## F04 — 15/09/2026 — Integração seed + feedback de erros global

**Backend disponível:** [E04 seed/reboot](plano-entregas-backend.md) · Ler: [transacoes/TX-INFRA-02-reboot.md](transacoes/TX-INFRA-02-reboot.md) · [transacoes/00-SEED.md](transacoes/00-SEED.md)

**Por que agora?** Com o seed real (`tads`), todas as telas subsequentes terão dados consistentes. É também o momento de blindar o front contra erros inesperados.

### X — Error handler global e HTTP resilience

- [ ] `HttpErrorInterceptor`: catch global de 4xx/5xx → `ErrorHandlerService`
- [ ] 401 em rota protegida: limpar sessão + redirect `/login` com mensagem flash
- [ ] 403: exibir toast `"Acesso negado"` sem derrubar a rota
- [ ] 502/504 (MS fora): toast `"Serviço indisponível, tente novamente"`
- [ ] Form de login: testar com seed real `cli1@bantads.com.br` / `tads` e `ger1@bantads.com.br` / `tads`

### Y — Página de login atualizada com seed

- [ ] Confirmar que `usuario.cpf`, `usuario.nome`, `usuario.email` chegam na resposta do login e são salvos nos signals do `AuthService`
- [ ] Navbar de cliente exibe `usuario.nome` (signal)
- [ ] Login do seed `cli1` → rota `/cliente` com nome "Catharyna" na navbar

### Z — Feedback visual completo

- [ ] `ToastService` global: success (verde), error (vermelho), warning (amarelo)
- [ ] Botões de ação: estado `loading` durante qualquer request HTTP
- [ ] Documentar internamente: "saldo do seed `1291` = `"800.00"`, `0950` = `"10000.00"`, etc." nos comments de teste

**Validar ([TX-INFRA-02](transacoes/TX-INFRA-02-reboot.md)):**

- [ ] Login `cli1@bantads.com.br` / `tads` → 200, `tipo: "CLIENTE"`, `usuario.nome: "Catharyna"`
- [ ] Login `ger1@bantads.com.br` / `tads` → 200, `tipo: "GERENTE"`, `usuario.nome: "Geniéve"`
- [ ] Token pré-reboot (session antiga) → redirect para login com mensagem `"Falha ao autenticar o token."`
- [ ] Body do login **sem** `_links` e sem `senha` — nenhum campo desses deve aparecer na UI

---

## F05 — 22/09/2026 — Autocadastro + telas de solicitação

**Backend disponível:** [E05 MS Cliente síncrono](plano-entregas-backend.md) · Ler: [transacoes/TX-R1-autocadastro.md](transacoes/TX-R1-autocadastro.md) · [transacoes/TX-R8A-listar-solicitacoes.md](transacoes/TX-R8A-listar-solicitacoes.md) · [transacoes/TX-R8B-consultar-solicitacao.md](transacoes/TX-R8B-consultar-solicitacao.md) · [transacoes/TX-R10-rejeitar-cliente.md](transacoes/TX-R10-rejeitar-cliente.md) · [transacoes/TX-CAD-01-consultar-cliente.md](transacoes/TX-CAD-01-consultar-cliente.md)

**Por que agora?** O MS Cliente expõe autocadastro (público) e listagem de solicitações (GERENTE). O front implementa as duas pontas.

### X — Proxy e HATEOAS de solicitações

- [ ] `SolicitacaoService.autocadastro(data)` → `POST /solicitacoes` (rota **pública**, sem token)
- [ ] `SolicitacaoService.listar(status?)` → `GET /solicitacoes?status=PENDENTE`
- [ ] `SolicitacaoService.obter(cpf)` → `GET /solicitacoes/{cpf}`
- [ ] `ClienteService.rejeitar(cpf, motivo)` → `POST /solicitacoes/{cpf}/rejeicao` (endpoint obtido de `_links.rejeicao.href`)
- [ ] **Regra HATEOAS:** botão "Aprovar" só renderiza se `solicitacao._links?.aprovacao` existir; botão "Rejeitar" só se `_links?.rejeicao` existir — **não** checar `status === 'PENDENTE'`

### Y — Tela de autocadastro (pública)

- [ ] Rota `/autocadastro` sem guard
- [ ] Formulário completo: CPF (11 dígitos, string), nome, e-mail, telefone, salário (campo em pt-BR `"4.500,00"` → enviar `"4500.00"` ao backend via decimal.js), endereço (logradouro, número, complemento, CEP 8 dígitos, cidade, UF 2 letras)
- [ ] Sucesso → 201 → mensagem "Solicitação enviada! Aguarde aprovação pelo gerente." (senha **não** existe ainda — não mencionar)
- [ ] 409 (CPF duplicado / e-mail duplicado / CPF já cliente) → mensagem da `mensagem` do backend
- [ ] Salário como `"4500.00"` string — **nunca** `number` no `POST`

### Z — Tela de solicitações (GERENTE)

- [ ] Rota `/gerente/solicitacoes` com `GerenteGuard`
- [ ] Listar todas as solicitações; filtro por status (PENDENTE / NAO_APROVADA / APROVADA)
- [ ] Cada item: CPF, nome, e-mail, salário (formatar com `MoneyPipe`), endereço
- [ ] Botões **Aprovar** e **Rejeitar** renderizados **apenas** se os rels `aprovacao` / `rejeicao` existirem em `_links`
- [ ] Clicar em "Rejeitar": modal com campo `motivo` (obrigatório), `POST` na URL de `_links.rejeicao.href`
- [ ] Após rejeição → 200, solicitação atualizada com `status: "NAO_APROVADA"`, botões somem (sem `aprovacao`/`rejeicao`)
- [ ] GET `/clientes/{cpf}` de solicitação PENDENTE → 404 (mensagem amigável "Cliente não cadastrado ainda")

**Validar ([TX-R1](transacoes/TX-R1-autocadastro.md), [TX-R8A](transacoes/TX-R8A-listar-solicitacoes.md), [TX-R8B](transacoes/TX-R8B-consultar-solicitacao.md), [TX-R10](transacoes/TX-R10-rejeitar-cliente.md), [TX-CAD-01](transacoes/TX-CAD-01-consultar-cliente.md)):**

- [ ] Autocadastro com salário `"4500.00"` → 201, `_links.aprovacao` e `_links.rejeicao` apontam para `http://localhost:3000/…` (não `:8080`)
- [ ] Autocadastro com mesmo CPF → 409 visível
- [ ] Gerente vê lista; botões Aprovar/Rejeitar presentes para PENDENTE
- [ ] Após rejeição → `_links` sem `aprovacao`/`rejeicao` → botões somem automaticamente

---

## F06 — 29/09/2026 — Home do cliente + conta (leitura)

**Backend disponível:** [E06 MS Conta query](plano-entregas-backend.md) · Ler: [transacoes/TX-R3A-consultar-conta-cpf.md](transacoes/TX-R3A-consultar-conta-cpf.md) · [transacoes/TX-R3B-consultar-conta-numero.md](transacoes/TX-R3B-consultar-conta-numero.md)

**Por que agora?** O read model de conta está pronto, incluindo os rels de operação para CLIENTE. A home do cliente pode exibir saldo e os botões de ação guiados por `_links`.

### X — ContaService com HATEOAS

- [ ] `ContaService.getContaPorCpf(cpf)` → `GET /clientes/{cpf}/conta`
- [ ] `ContaService.getContaPorNumero(numero)` → `GET /contas/{numero}` (número é **string** de 4 dígitos, ex. `"0950"`)
- [ ] **Regra HATEOAS de conta:** guardar o objeto `_links` inteiro no signal; não clonar nem reinterpretar os rels
- [ ] Verificar que GET conta **nunca** usa cache do Gateway (saldo sempre fresco) — não há lógica de cache no front para conta

### Y — Home do cliente

- [ ] Rota `/cliente/home` protegida
- [ ] Ao entrar: `GET /clientes/{cpf}/conta` para obter conta do logado
- [ ] Exibir: número da conta, saldo (`MoneyPipe`), nome do gerente (`cpfGerente` na conta)
- [ ] Menu de ações navegável: renderizar botões **Depositar**, **Sacar**, **Transferir**, **Extrato** somente se o rel correspondente existir em `_links`
- [ ] Gerente acessando mesma tela (perfil GERENTE via token de gerente): sem botões de escrita (rels ausentes no JSON)
- [ ] Conta de outro CPF como cliente → 403 → toast `"Acesso negado"`
- [ ] Conta inexistente → 404 → mensagem amigável

### Z — Consultar cliente (gerente vê dados cadastrais + conta)

- [ ] Rota `/gerente/clientes/{cpf}` com `GerenteGuard`
- [ ] `GET /clientes/{cpf}` → dados cadastrais (sem saldo neste recurso)
- [ ] Link `_links.conta` disponível → navegar para consulta da conta do cliente
- [ ] Exibir: nome, CPF, e-mail, telefone, salário (MoneyPipe), endereço formatado
- [ ] Botão "Ver conta" → segue `_links.conta.href` (não constrói URL manualmente)

**Validar ([TX-R3A](transacoes/TX-R3A-consultar-conta-cpf.md), [TX-R3B](transacoes/TX-R3B-consultar-conta-numero.md)):**

- [ ] Saldo `"800.00"` exibido como `"R$ 800,00"` (MoneyPipe) — nunca `800` nem `"800,00"` no JSON
- [ ] Conta com número `"0950"` (zero à esquerda) → `GET /contas/0950` — número é string no path
- [ ] Gerente acessando `/contas/1291` → 200 sem botões de depósito/saque/transferência/extrato
- [ ] `_links.self.href` aponta para `http://localhost:3000/…` sem `:8080`

---

## F07 — 06/10/2026 — Depósito, saque, transferência, extrato

**Backend disponível:** [E07 MS Conta command](plano-entregas-backend.md) · Ler: [transacoes/TX-R4-deposito.md](transacoes/TX-R4-deposito.md) · [transacoes/TX-R5-saque.md](transacoes/TX-R5-saque.md) · [transacoes/TX-R6-transferencia.md](transacoes/TX-R6-transferencia.md) · [transacoes/TX-R7-extrato.md](transacoes/TX-R7-extrato.md)

**Por que agora?** O event store está pronto. Esta entrega cobre toda a operação financeira do cliente.

### X — OperacaoService + consistência eventual

- [ ] `OperacaoService.depositar(href, valor)` → `POST` na URL de `_links.deposito.href` com `{ valor: "100.00" }`
- [ ] `OperacaoService.sacar(href, valor)` → `POST` na URL de `_links.saque.href`
- [ ] `OperacaoService.transferir(href, contaDestino, valor)` → `POST` na URL de `_links.transferencia.href` com `{ contaDestino, valor }` (body **mínimo**, sem nomes — o Gateway enriquece)
- [ ] **Após 201:** NÃO usar o body como saldo novo. Seguir `_links.conta.href` da resposta e fazer `GET` para atualizar o signal de conta (consistência eventual CQRS — pode demorar 2–5 s para o projector Kotlin processar)
- [ ] Implementar poll com retry: reconsultar conta até 3× em 5 s (ou exibir loader "Atualizando saldo…")
- [ ] `ExtratoService.getExtrato(href, inicio?, fim?)` → `GET` na URL de `_links.extrato.href` com query params

### Y — Telas de operação (CLIENTE)

- [ ] `DepositorComponent`: campo "Valor" (pt-BR → string de contrato), botão confirmar, feedback 201
- [ ] `SacarComponent`: igual, tratar 422 `"Saldo insuficiente"` com mensagem visível
- [ ] `TransferirComponent`: campos "Conta destino" (4 dígitos string) e "Valor"; validar `contaDestino != numeroOrigem` antes de enviar (422 local, reforçado pelo backend); tratar 422 `"Conta destino inexistente"` e `"Saldo insuficiente"`
- [ ] Valor deve ser enviado como `"100.00"` — input `type="text"` com máscara ou input em reais (decimal.js converte)

### Z — Extrato (CLIENTE)

- [ ] Rota `/cliente/extrato` com seletor de período (padrão: últimos 30 dias; máximo 365 dias)
- [ ] Enviar `inicio=YYYY-MM-DD&fim=YYYY-MM-DD` (Luxon para formatar)
- [ ] Exibir `saldoAbertura` e lista de `movimentacoes` em ordem cronológica
- [ ] Montar timeline **dia a dia** com Luxon: para cada dia sem movimentação exibir o saldo consolidado do dia anterior
- [ ] Cada linha: data, tipo (DEPOSITO/SAQUE/TRANSFERENCIA), valor (MoneyPipe), origem/destino (só em TRANSFERENCIA)
- [ ] Entrada (crédito) em azul; saída (débito) em vermelho — comparar `tipo` com o fluxo (depósito = crédito; saque = débito; transferência = checar se a conta é origem ou destino)
- [ ] 422 `"Intervalo maior que 365 dias"` e `"Intervalo inválido: fim anterior ao início"` → mensagens visíveis
- [ ] Extrato é ACL de **CLIENTE** — gerente que tente acessar → 403

**Validar ([TX-R4](transacoes/TX-R4-deposito.md), [TX-R5](transacoes/TX-R5-saque.md), [TX-R6](transacoes/TX-R6-transferencia.md), [TX-R7](transacoes/TX-R7-extrato.md)):**

- [ ] Depósito de `"10.00"` → 201 sem `saldo` no body → GET conta → saldo `"810.00"` (seed puro)
- [ ] Saque com saldo insuficiente → 422 visível na tela
- [ ] Transferência → 201 com `destino.nome` preenchido → GET ambas as contas
- [ ] Extrato jan/2020 da Catharyna → 7 movimentações, `saldoAbertura: "0.00"`, última é TRANSFERENCIA `"1700.00"`
- [ ] Valor `10` (number) no body → 400 (validar no Angular antes de enviar; backend rejeita também)

---

## F08 — 13/10/2026 — Dashboard gerente + listas composition + CRUD gerente

**Backend disponível:** [E08 MS Gerente + composition + cache](plano-entregas-backend.md) · Ler: [transacoes/TX-R11-consultar-clientes.md](transacoes/TX-R11-consultar-clientes.md) · [transacoes/TX-R12-listar-gerentes.md](transacoes/TX-R12-listar-gerentes.md) · [transacoes/TX-CAD-02-consultar-gerente.md](transacoes/TX-CAD-02-consultar-gerente.md) · [transacoes/TX-R14-atualizar-gerente.md](transacoes/TX-R14-atualizar-gerente.md)

**Por que agora?** A composition de R11/R12 (cliente + saldo, gerente + contagem) está pronta. Esta é a semana mais densa do GERENTE.

### X — Serviços de composition

- [ ] `ClienteService.listar(busca?)` → `GET /clientes?busca=Cat` — composition Gateway (cadastro + saldo)
- [ ] `GerenteService.listar()` → `GET /gerentes` — composition (gerente + contagem de clientes)
- [ ] `GerenteService.atualizar(cpf, { nome, telefone })` → `PUT /gerentes/{cpf}` — **não** enviar email/cpf se não mudaram (ou garantir que sejam iguais); invalida cache do Gateway automaticamente
- [ ] HATEOAS na lista de gerentes:
  - Botão "Novo Gerente" só se `_links.criacao` existir na lista (R13)
  - Botão "Editar" só se `gerente._links?.atualizacao` existir
  - Botão "Excluir" só se `gerente._links?.remocao` existir (**ausente** para o gerente logado — o Gateway remove automaticamente)

### Y — Tela de clientes (GERENTE — R11)

- [ ] Rota `/gerente/clientes` com `GerenteGuard`
- [ ] Campo de busca em tempo real (debounce 400 ms) → `?busca=Cat`
- [ ] Lista ordenada por nome pt-BR (o backend já ordena; o Angular não precisa re-ordenar)
- [ ] Campos por linha (R11): CPF, nome, cidade, estado (UF), saldo (MoneyPipe), botão "Ver conta" (seguir `_links.conta.href`)
- [ ] **Sem** email/salário nesta lista (esses campos são de R16)
- [ ] Token de cliente → 403 → redirect `/login` ou mensagem

### Z — Tela de gerentes + CRUD (GERENTE — R12/R14)

- [ ] Rota `/gerente/gerentes` com `GerenteGuard`
- [ ] Listar gerentes ativos: CPF, nome, e-mail, telefone, quantidade de clientes
- [ ] Botão "Novo Gerente" aparece se `_links.criacao` existir na lista
- [ ] Botão "Editar" (abre modal) se `gerente._links?.atualizacao` existir → campos editáveis: **só nome e telefone**; mostrar e-mail e CPF como read-only (imutáveis)
- [ ] `PUT /gerentes/{cpf}` → sucesso → cache invalidado no Gateway → próximo GET traz dado novo
- [ ] 400 ao tentar mudar e-mail → mensagem `"CPF e e-mail são imutáveis"` na tela
- [ ] Botão "Excluir" aparece se `gerente._links?.remocao` existir (nunca aparece para o próprio gerente logado — o Gateway não retorna esse rel)
- [ ] `GET /gerentes/{cpf}` (TX-CAD-02): `quantidadeClientes` pode ser `null` neste recurso isolado — tratar na UI sem quebrar

**Validar ([TX-R11](transacoes/TX-R11-consultar-clientes.md), [TX-R12](transacoes/TX-R12-listar-gerentes.md), [TX-CAD-02](transacoes/TX-CAD-02-consultar-gerente.md), [TX-R14](transacoes/TX-R14-atualizar-gerente.md)):**

- [ ] `?busca=Cat` → Catharyna e Catianna na lista (nessa ordem, pt-BR)
- [ ] Geniéve logada em `/gerente/gerentes`: sem botão "Excluir" na própria linha; outros gerentes têm "Excluir"
- [ ] Contagens do seed: Geniéve=2, Godophredo=2, Gyândula=1, Gadamântio=0
- [ ] PUT atualiza nome → GET sem cache → nome novo imediato

---

## F09 — 20/10/2026 — Infraestrutura de jobs + relatório assíncrono

**Backend disponível:** [E09 jobs + email + SAGA esqueleto + R16](plano-entregas-backend.md) · Ler: [transacoes/TX-JOB-01-status.md](transacoes/TX-JOB-01-status.md) · [transacoes/TX-JOB-02-result.md](transacoes/TX-JOB-02-result.md) · [transacoes/TX-R16-relatorio-clientes.md](transacoes/TX-R16-relatorio-clientes.md)

**Por que agora?** O `JobService` e o endpoint de relatório assíncrono chegam. Esta semana prepara toda a infraestrutura de polling que R9, R13 e R15 vão usar.

### X — JobService (infraestrutura completa)

- [ ] Ao receber 202: ler header `Location` da resposta → extrair `jobId` (`Location: /jobs/{uuid}/status`)
- [ ] `JobService.pollStatus(jobId)`: `Observable` com `interval(1000).pipe(switchMap(...), takeWhile(j => j.status === 'PENDENTE', true), timeout(60_000))`
- [ ] Tratar `status === 'FALHA'`: exibir `job.erro` (string, não é envelope HTTP)
- [ ] Tratar `resultType`:
  - `"resource"` → navegar para `/{dominio}/{resourceId}` (ex: `/clientes/{cpf}`)
  - `"inline"` → `GET /jobs/{jobId}/result` e usar o payload
- [ ] Jobs **não têm** `_links` — não tentar renderizá-los
- [ ] Job expirado (> 5 min) → 404 `"Job inexistente ou expirado"` → mensagem amigável

### Y — Componente genérico de polling

- [ ] `JobPollingComponent`: recebe `jobId`, exibe spinner durante `PENDENTE`, emite evento `concluido(job)` ou `falha(erro)`
- [ ] Barra de progresso indeterminada enquanto PENDENTE
- [ ] Texto de status dinâmico (ex: "Processando aprovação… aguarde")
- [ ] Timeout → mensagem "O processamento está demorando. Verifique mais tarde."

### Z — Tela de relatório de clientes (GERENTE — R16)

- [ ] Rota `/gerente/relatorio` com `GerenteGuard`
- [ ] `GET /relatorios/clientes` → 202 imediato + `Location`
- [ ] Usar `JobPollingComponent` → ao `CONCLUIDO inline` → `GET /jobs/{id}/result`
- [ ] Exibir tabela com campos obrigatórios: CPF, nome, e-mail, salário (MoneyPipe), numeroConta, saldo (MoneyPipe), cpfGerente, nomeGerente
- [ ] Ordenar por nome pt-BR (o backend já ordena; exibir na mesma sequência)
- [ ] **Sem** `_links` nas linhas do relatório — é exceção HATEOAS
- [ ] Token de cliente → 403

**Validar ([TX-JOB-01](transacoes/TX-JOB-01-status.md), [TX-JOB-02](transacoes/TX-JOB-02-result.md), [TX-R16](transacoes/TX-R16-relatorio-clientes.md)):**

- [ ] Relatório: 202 → poll < 5 s → CONCLUIDO inline → tabela com ≥ 5 clientes do seed
- [ ] Job de outro usuário → 403 (o serviço não deve compartilhar `jobId` entre usuários)
- [ ] Job expirado → 404 → mensagem amigável na tela
- [ ] Status PENDENTE: body mínimo `{ jobId, status }` sem `_links` — componente de poll não tenta renderizar links

---

## F10 — 27/10/2026 — SAGA de aprovação de cliente (R9)

**Backend disponível:** [E10 SAGA R9](plano-entregas-backend.md) · Ler: [transacoes/TX-R9-aprovar-cliente.md](transacoes/TX-R9-aprovar-cliente.md)

**Por que agora?** A SAGA completa de aprovação está pronta. A UI do gerente pode agora usar o botão "Aprovar" (que aparece via HATEOAS na tela de solicitações).

### X — SolicitacaoService.aprovar

- [ ] `SolicitacaoService.aprovar(href)` → `POST` na URL de `_links.aprovacao.href` (sem body)
- [ ] Resposta: 202 + `Location` → `JobService.pollStatus`
- [ ] **Gateway não pré-valida PENDENTE**: POST de aprovação sempre retorna 202 — a falha aparece no job. A UI **não** checa `status === 'PENDENTE'` antes de chamar; só usa o rel HATEOAS
- [ ] `resultType === "resource"`, `dominio: "clientes"` → navegar para `GET /clientes/{resourceId}` — o novo cliente

### Y — Fluxo de aprovação (GERENTE)

- [ ] Botão "Aprovar" na tela de solicitações: **só renderizar se `_links.aprovacao` existir**
- [ ] Clicar → POST 202 → `JobPollingComponent` inline na tela de solicitações
- [ ] Status CONCLUIDO + resource → toast "Cliente aprovado!" + navegar para o perfil do novo cliente
- [ ] Status FALHA → exibir `job.erro` (ex: `"E-mail já cadastrado"`) + solicitação muda para NAO_APROVADA (recarregar)
- [ ] Após aprovação bem-sucedida: na lista de solicitações, a solicitação deixa de ter `aprovacao`/`rejeicao` em `_links` — os botões somem automaticamente

### Z — Página do novo cliente após aprovação

- [ ] `GET /clientes/{cpf}` → 200 com `_links.conta` (aprovar criou a conta)
- [ ] Exibir dados cadastrais + link "Ver conta" via `_links.conta.href`
- [ ] `GET /contas/{numero}` → saldo, cpfGerente (Gadamântio no seed puro — ativo com menos clientes)
- [ ] Conta do novo cliente **não** usa 4 primeiros dígitos do CPF como número — validar que é 4 dígitos aleatório

**Validar ([TX-R9](transacoes/TX-R9-aprovar-cliente.md)):**

- [ ] Autocadastro de CPF novo → aparece na lista com `aprovacao` e `rejeicao` em `_links`
- [ ] Clicar Aprovar → spinner de espera → toast de sucesso → perfil do novo cliente
- [ ] Aprovar mesmo CPF de novo → 202 → poll → FALHA → mensagem de erro visível
- [ ] E-mail de gerente no autocadastro → 202 → poll → FALHA → solicitação NAO_APROVADA → botões somem
- [ ] Após aprovação: `GET /clientes/{cpf}` → 200 (sem 404 de cache antigo — Gateway invalida Redis)

---

## F11 — 03/11/2026 — SAGA de inserção de gerente (R13)

**Backend disponível:** [E11 SAGA R13](plano-entregas-backend.md) · Ler: [transacoes/TX-R13-inserir-gerente.md](transacoes/TX-R13-inserir-gerente.md)

**Por que agora?** A SAGA de inserção de gerente completa está pronta, incluindo a lógica de redistribuição de conta.

### X — GerenteService.inserir

- [ ] `GerenteService.inserir(data)` → `POST /gerentes` com `{ cpf, nome, email, telefone, senha }` (senha vai no form — não vai por e-mail)
- [ ] `POST /gerentes` → 202 + `Location` → `JobService.pollStatus`
- [ ] `resultType === "resource"`, `dominio: "gerentes"` → `GET /gerentes/{resourceId}`
- [ ] 400 síncrono (body incompleto) → sem `jobId`, sem poll — exibir erro diretamente
- [ ] Senha **nunca** exibida na UI após o POST nem presente em nenhum signal/store

### Y — Formulário de novo gerente

- [ ] Acessível via botão "Novo Gerente" em `/gerente/gerentes` (botão aparece se `_links.criacao` existir na lista)
- [ ] Modal/tela com: CPF, nome, e-mail, telefone, **senha** (requerida)
- [ ] Validação local antes de enviar: todos os campos obrigatórios, CPF 11 dígitos, telefone
- [ ] Botão desabilitado durante request
- [ ] Sucesso → poll → CONCLUIDO → toast "Gerente inserido!" → atualizar lista
- [ ] FALHA (e-mail duplicado) → mensagem `"E-mail já cadastrado"` → `GET /gerentes/{cpf}` retornaria 404 (não existe)

### Z — Feedback pós-inserção

- [ ] Após CONCLUIDO resource → `GET /gerentes/{cpf}` → abrir perfil do novo gerente
- [ ] Confirmar que `GET /contas/7617` (conta da Coândrya, seed puro) agora tem o CPF do novo gerente em `cpfGerente`
- [ ] Lista de gerentes atualizada: novo gerente aparece com 1 cliente (Coândrya) ou 0 (se `semConta`)
- [ ] Login com a senha do formulário → `POST /login` → tipo `GERENTE`

**Validar ([TX-R13](transacoes/TX-R13-inserir-gerente.md)):**

- [ ] Formulário sem senha → 400 síncrono visível na tela (sem spinner de poll)
- [ ] Formulário completo → 202 → poll → CONCLUIDO → perfil do gerente aberto
- [ ] Login com `email + senha_do_form` → 200 tipo GERENTE
- [ ] E-mail de gerente existente → 202 → poll → FALHA → `GET /gerentes/{cpf}` → 404

---

## F12 — 10/11/2026 — SAGA de remoção de gerente + aceite total

**Backend disponível:** [E12 SAGA R15 + fecho](plano-entregas-backend.md) · Ler: [transacoes/TX-R15-remover-gerente.md](transacoes/TX-R15-remover-gerente.md) · [transacoes/00-HATEOAS.md](transacoes/00-HATEOAS.md)

**Por que agora?** Última SAGA do sistema. Também é o momento de fechar convenções transversais, polir UX e garantir que o front está 100% alinhado com o contrato.

### X — GerenteService.remover + auto-remoção

- [ ] `GerenteService.remover(href)` → `DELETE` na URL de `_links.remocao.href`
- [ ] **Auto-remoção é 403 síncrono** (sem job): o Gateway bloqueia antes da SAGA. Tratar como erro HTTP normal, não como polling
- [ ] Resposta 202 → `Location` → `JobService.pollStatus`
- [ ] `resultType === "inline"` → `GET /jobs/{id}/result` → `{ mensagem: "Gerente removido; N contas transferidas para {Nome}" }`
- [ ] Após CONCLUIDO: token do gerente removido (se ele estava logado) → próxima request → 401 → redirect login. O Gateway invalida a sessão Redis do removido (passo LOCAL da SAGA)

### Y — UI de remoção

- [ ] Botão "Excluir" (em `/gerente/gerentes`) → **só aparece se `_links.remocao` existir**; o gerente nunca vê o próprio botão de exclusão (Gateway não retorna esse rel para si mesmo)
- [ ] Confirmação com modal: "Confirma exclusão de {nome}? As contas serão redistribuídas."
- [ ] `DELETE` → 202 → `JobPollingComponent` → CONCLUIDO inline → toast com o texto da `mensagem`
- [ ] FALHA → exibir `job.erro` (ex: `"Não é permitido remover o último gerente ativo"`)
- [ ] Após remoção: lista de gerentes atualizada — gerente excluído não aparece mais (`ativo = false`)

### Z — Auditoria final e convenções transversais

- [ ] Percorrer todas as telas e verificar:
  - Nenhum `href` com `:8080` na UI
  - Nenhum botão hardcoded por `if (tipo === 'GERENTE')` ou `if (status === 'PENDENTE')`
  - Dinheiro sempre renderizado via `MoneyPipe` (nunca `Number()` ou template direto)
  - Datas sempre via `DatetimePipe` (Luxon, timezone São Paulo)
  - Jobs sem `_links` — nenhum componente tenta renderizá-los
  - Login/logout sem `_links` — nenhum componente os espera
- [ ] Testar todos os fluxos no Firefox (o enunciado exige compatibilidade)
- [ ] Build de produção via `compile-services.ps1` / `.sh` na raiz do repo
- [ ] Confirmar que `ng build` não tem erros; bundle servido e funcional com Gateway em pé

**Validar ([TX-R15](transacoes/TX-R15-remover-gerente.md) + convenções transversais):**

- [ ] DELETE no próprio gerente logado → 403 síncrono → toast `"Não é permitido remover a si mesmo"` (sem spinner de poll)
- [ ] DELETE Gadamântio → 202 → poll → CONCLUIDO inline → mensagem `"Gerente removido; 0 contas transferidas para Gyândula"`
- [ ] Login de Gadamântio após remoção → `"Login inválido!"` (ativo=false no Auth)
- [ ] Token de sessão de Gadamântio (se estava logado) → próxima request → 401 → redirect login
- [ ] DELETE de gerente já removido → 202 → poll → FALHA → toast com `erro`
- [ ] Todas as telas exibem money como `"R$ 800,00"` e datas como `"30/04/2026 10:00"`

---

## Definition of Done — frontend (F12)

- [ ] R1–R16 integrados com o Gateway (sem chamar MS direto)
- [ ] HATEOAS Richardson nível 3: nenhum botão hardcoded por estado/perfil; todos guiados por `_links`
- [ ] Interceptor `x-access-token` em todas as requests autenticadas
- [ ] Polling de jobs completo (R9, R13, R15, R16): PENDENTE → CONCLUIDO/FALHA com feedback visual
- [ ] `decimal.js` em todos os campos de dinheiro; `string` no JSON (nunca `number`)
- [ ] Luxon em todas as datas; timeline de extrato dia a dia
- [ ] Dois envelopes de erro tratados (`{ auth }` vs `{ status, erro, mensagem }`)
- [ ] Redirect automático em 401; guard em rotas por perfil
- [ ] Sem `localStorage` para dados de negócio; token em `sessionStorage`
- [ ] Build via `compile-services.ps1` / `.sh` sem erros; funcional no Firefox

---

## Referências rápidas

| Recurso | Arquivo |
|---|---|
| **Catálogo JSON completo (requests + responses + `_links`)** | [`00-JSON-CATALOG.md`](00-JSON-CATALOG.md) |
| Contrato REST completo | [`docs/swagger_bantads.md`](docs/swagger_bantads.md) |
| Enunciado R1–R16 / seed | [`docs/bantads.md`](docs/bantads.md) |
| Plano do backend (E01–E12) | [`plano-entregas-backend.md`](plano-entregas-backend.md) |
| Checklist de transações | [`log_check_transactions.md`](log_check_transactions.md) |
| HATEOAS em detalhe | [`transacoes/00-HATEOAS.md`](transacoes/00-HATEOAS.md) |
| Gateway Fastify (CORS, ACL, proxy) | [`transacoes/00-GATEWAY.md`](transacoes/00-GATEWAY.md) |
| JWT e sessão Redis | [`transacoes/00-JWT.md`](transacoes/00-JWT.md) |
| Cache Redis (cadastro) | [`transacoes/00-REDIS-CACHE.md`](transacoes/00-REDIS-CACHE.md) |
| ACL de rotas | [`transacoes/00-ACL.md`](transacoes/00-ACL.md) |
| Seed e reboot | [`transacoes/00-SEED.md`](transacoes/00-SEED.md) |
| Agente Angular (convenções) | [`.cursor/agents/frontend-angular.md`](.cursor/agents/frontend-angular.md) |
| hateoas.ts (Gateway, motor) | [`backend/gateway/src/http/hateoas.ts`](backend/gateway/src/http/hateoas.ts) |
| ClienteAssembler.kt | [`backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/hateoas/ClienteAssembler.kt`](backend/services/cliente/src/main/kotlin/br/ufpr/dac/bantads/cliente/hateoas/ClienteAssembler.kt) |
| GerenteAssembler.kt | [`backend/services/gerente/src/main/kotlin/br/ufpr/dac/bantads/gerente/hateoas/GerenteAssembler.kt`](backend/services/gerente/src/main/kotlin/br/ufpr/dac/bantads/gerente/hateoas/GerenteAssembler.kt) |
| ContaQueryAssembler.kt | [`backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/query/http/ContaQueryAssembler.kt`](backend/services/conta/src/main/kotlin/br/ufpr/dac/bantads/conta/query/http/ContaQueryAssembler.kt) |
