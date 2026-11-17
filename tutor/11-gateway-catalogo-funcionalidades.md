# 11. Gateway — catálogo completo de funcionalidades

[← Voltar ao índice](./README.md) · [Tipos de fluxo](./08-gateway-tipos-de-fluxo.md)

Referência **endpoint a endpoint**: padrão de execução, destino, uso de Redis/Rabbit e arquivos.  
Registro central: [`app.ts`](../backend/gateway/src/app.ts).

Legenda de padrões (detalhes no doc 08): **PUB** público · **HOOK** autenticado+ACL · **SESS** sessão Redis · **PRX** proxy MS · **CMP** composição · **SAG** saga Rabbit · **JOB-L** job local · **ADM** admin.

---

## 11.1 Infraestrutura e auth

| Método | Caminho | Padrão | Handler | Entrega / recebe | Redis | Rabbit |
|--------|---------|--------|---------|------------------|-------|--------|
| `GET` | `/health` | PUB | `app.ts` | — → `{ status: 'UP' }` | — | — |
| `POST` | `/login` | PUB→SESS | `login.ts` | Body → auth → cadastro MS → JWT + `usuario` | `createSession` | — |
| `POST` | `/logout` | HOOK+SESS | `logout.ts` | Token → revoke | `revokeSession` | — |

---

## 11.2 Jobs (polling assíncrono)

| Método | Caminho | Padrão | Handler | Por quê | Redis |
|--------|---------|--------|---------|---------|-------|
| `GET` | `/jobs/:jobId/status` | HOOK | `jobs.ts` | UX 202 Accepted | `readJob` |
| `GET` | `/jobs/:jobId/result` | HOOK | `jobs.ts` | Relatório / resultado inline | `readJob` |

**Origens de `jobId`:** sagas (`aprovacao`, `inserir-gerente`, `remover-gerente`), `relatorios/clientes`.

---

## 11.3 Solicitações de autocadastro (ms-cliente)

| Método | Caminho | ACL | Padrão | MS | Notas |
|--------|---------|-----|--------|-----|-------|
| `POST` | `/solicitacoes` | PUB | PRX | cliente | Autocadastro sem token |
| `GET` | `/solicitacoes` | gerente | PRX | cliente | Lista pendências |
| `GET` | `/solicitacoes/:cpf` | gerente | PRX | cliente | Detalhe solicitação |
| `POST` | `/solicitacoes/:cpf/rejeicao` | gerente | PRX | cliente | **Síncrono**, não saga |
| `POST` | `/solicitacoes/:cpf/aprovacao` | gerente | SAG | — | `aprovar-cliente` → `saga.cmd` |

Aprovação: [`aprovacao.ts`](../backend/gateway/src/routes/aprovacao.ts) — payload AMQP `{ cpf, solicitadoPorCpf }`.

---

## 11.4 Clientes

| Método | Caminho | ACL | Padrão | Função | MS / extras |
|--------|---------|-----|--------|--------|-------------|
| `GET` | `/clientes` | gerente | CMP | `listarClientes` | cliente + saldos (retry) |
| `GET` | `/clientes/:cpf` | gerenteOrSelf | PRX+cache | `cachedGet` | cliente, chave `cache:cliente:{cpf}` |
| `GET` | `/clientes/:cpf/conta` | gerenteOrSelf | PRX | `proxy` → conta | Conta do cliente |

Listagem: enriquece com saldo, cidade, UF, HATEOAS — [`composition.ts`](../backend/gateway/src/routes/composition.ts).

---

## 11.5 Contas e operações bancárias

| Método | Caminho | ACL | Padrão | Função | Notas |
|--------|---------|-----|--------|--------|-------|
| `GET` | `/contas/:numero` | gerenteOrSelf | PRX | conta | Saldo/status conta |
| `GET` | `/contas/:numero/extrato` | gerenteOrSelf | PRX | conta | Extrato |
| `POST` | `/contas/:numero/deposito` | cliente | PRX | conta | Forward body |
| `POST` | `/contas/:numero/saque` | cliente | PRX | conta | Forward body |
| `POST` | `/contas/:numero/transferencia` | cliente | PRX+**lógica** | `transferir` | Valida Zod, busca destino internal, nomes, monta body |

Transferência é o proxy **mais complexo**: três chamadas HTTP encadeadas no Gateway (ver [08 § 8.5](./08-gateway-tipos-de-fluxo.md#85-padrão-d--proxy-http-síncrono)).

---

## 11.6 Gerentes

| Método | Caminho | ACL | Padrão | Destino | Redis / Rabbit |
|--------|---------|-----|--------|---------|----------------|
| `GET` | `/gerentes` | gerente | CMP | `listarGerentes` | — |
| `GET` | `/gerentes/:cpf` | gerente | PRX+cache | gerente MS | `cache:gerente:{cpf}` |
| `PUT` | `/gerentes/:cpf` | gerente | PRX | gerente MS | `del` cache se 200 |
| `POST` | `/gerentes` | gerente | SAG | `inserir-gerente` | job + Rabbit |
| `DELETE` | `/gerentes/:cpf` | gerente | SAG | `remover-gerente` | job + Rabbit; 403 se auto-remoção |

Inserir: body validado [`gerenteInputSchema`](../backend/gateway/src/types/schemas.ts) → payload saga.

---

## 11.7 Relatórios

| Método | Caminho | ACL | Padrão | Fluxo |
|--------|---------|-----|--------|-------|
| `GET` | `/relatorios/clientes` | gerente | JOB-L | 202 → `setImmediate(runRelatorio)` → `collectRelatorioClientes` → job `CONCLUIDO` + `resultado` |

Consultar dados: `GET /jobs/{id}/result` após status `CONCLUIDO` e `resultType: INLINE`.

---

## 11.8 Administração / desenvolvimento

| Método | Caminho | ACL | Padrão | Efeito |
|--------|---------|-----|--------|--------|
| `POST` | `/reboot` | PUB | ADM | Reboot 4 MSs + `flushdb` Redis |

---

## 11.9 Recursos transversais (não são rotas)

| Funcionalidade | Onde | O que faz |
|----------------|------|-----------|
| CORS | `app.ts` | Frontend Angular (`CORS_ORIGIN`) |
| HATEOAS | `http/hateoas.ts` | Reescreve links internos → `publicUrl` |
| Erros PT | `http/errors.ts`, `http/pt-br.ts` | Corpos JSON padronizados |
| Timeout MS | `http/ms-client.ts` | 5s padrão; reboot 60s |
| Config | `config.ts` | URLs MS, Redis, Rabbit, JWT |
| AMQP | `amqp/publisher.ts` | Só fila `saga.cmd` |
| Tipos / Zod | `types/*` | Validação login, transferência, gerente |

---

## 11.10 Mapa arquivo → rotas registradas

| Arquivo `routes/` | Rotas |
|-------------------|-------|
| `login.ts` | `POST /login` |
| `logout.ts` | `POST /logout` |
| `jobs.ts` | `GET /jobs/:jobId/status`, `GET /jobs/:jobId/result` |
| `aprovacao.ts` | `POST /solicitacoes/:cpf/aprovacao` |
| `inserir-gerente.ts` | `POST /gerentes` |
| `remover-gerente.ts` | `DELETE /gerentes/:cpf` |
| `relatorio.ts` | `GET /relatorios/clientes` |
| `reboot.ts` | `POST /reboot` |
| `proxy.ts` | solicitacoes, clientes (parcial), contas, gerentes GET/PUT |
| `composition.ts` | (sem register) — usado por proxy e relatorio |

---

## 11.11 Árvore de decisão: “esta URL usa o quê?”

```
/solicitacoes/:cpf/aprovacao     → SAG + job + Rabbit
/solicitacoes (GET/POST/rejeição)→ PRX → cliente
/gerentes POST, DELETE           → SAG + job + Rabbit
/gerentes GET (lista)            → CMP
/gerentes GET/:cpf, PUT          → PRX (+ cache)
/clientes GET (lista)            → CMP
/clientes GET/:cpf               → PRX + cache
/contas/* deposito/saque         → PRX → conta
/contas/* transferencia          → PRX custom transferir()
/relatorios/clientes             → JOB-L (sem Rabbit)
/login, /logout                  → auth + Redis sessão
/jobs/*                          → Redis read only
/reboot                          → ADM flush Redis
```

---

## 11.12 Cobertura de testes de contrato (ponte)

Muitos requisitos BANTADS batem diretamente neste catálogo. Ao ler falha em `backend/contract-tests`, localize a rota aqui e o padrão no [08](./08-gateway-tipos-de-fluxo.md) para saber se investigar Redis, Rabbit ou MS HTTP.

---

## 11.13 Links relacionados

- Pastas do código: [06-pastas-gateway.md](./06-pastas-gateway.md)
- Autenticação: [09-gateway-autenticacao-acl.md](./09-gateway-autenticacao-acl.md)
- Redis: [10-gateway-redis-completo.md](./10-gateway-redis-completo.md)
- Sagas após publish: [07-fluxos-e-formatos.md](./07-fluxos-e-formatos.md)