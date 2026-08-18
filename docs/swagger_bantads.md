openapi: 3.0.3

info:  
  title: BANTADS API  
  version: 2.0.0  
  description: |  
    Contrato REST do \*\*API Gateway\*\* do BANTADS (DS152 \- DAC / UFPR).  
    O front-end e a aplicação de teste  só se comunicam com o  
    Gateway — os microsserviços não são expostos.

    \#\# Convenções (valem para toda a API)

    \- \*\*Autenticação\*\*: JWT no header \`x-access-token\`, assinado pelo Gateway  
      no login (\`jwt.sign\` com \`SECRET\`). O Gateway mantém a \*\*sessão no Redis\*\*  
      (\`sessao:\<jti\>\`, TTL de 30 min \= inatividade, sliding window; exp do JWT \=  
      vida absoluta). A verificação valida assinatura+exp \*\*e\*\* a existência da  
      sessão. Token \*\*ausente\*\* → \*\*401\*\* \`{ auth: false, message: "Token não  
      fornecido." }\`; token \*\*inválido/expirado ou sessão inexistente/revogada\*\*  
      → \*\*401\*\* \`{ auth: false, message: "Falha ao autenticar o token." }\`.  
      Perfil errado ou recurso de outro usuário: \*\*403\*\* (\`{ status, erro,  
      mensagem }\`).  
    \- \*\*Perfis\*\*: cada operação indica o perfil exigido (CLIENTE, GERENTE ou  
      Público). A posse é validada pelo back-end via header interno  
      \`X-User-CPF\` injetado pelo Gateway (o front não envia esse header).  
    \- \*\*Valores monetários\*\*: sempre \*\*strings decimais com ponto e 2 casas\*\*  
      (ex.: \`"1500.00"\`), nunca número JSON — evita imprecisão de  
      float/double.  
    \- \*\*Datas\*\*: ISO 8601 sem offset (\`2026-04-30T10:00:00\`); parâmetros de  
      data no formato \`YYYY-MM-DD\`.  
    \- \*\*CPF\*\*: string de 11 dígitos, sem pontuação. \*\*Número de conta\*\*:  
      string de 4 dígitos (pode iniciar com zero, ex.: \`"0950"\`).  
    \- \*\*HATEOAS (Richardson nível 3)\*\*: todo DTO tem o objeto \`\_links\`  
      (estilo HAL: \`{ "rel": { "href": "..." } }\`), com os \`href\` reescritos  
      pelo Gateway para apontar para ele mesmo. Os links presentes dependem  
      do \*\*estado\*\* do recurso (ex.: solicitação PENDENTE tem \`aprovacao\` e  
      \`rejeicao\`; processada, só \`self\`) e do \*\*perfil\*\* de quem consulta.  
      \*\*Exceções sem \`\_links\`\*\*: retorno do login, respostas de jobs  
      (202/status/result), \`/health\` e \`/reboot\`.  
    \- \*\*Operações assíncronas\*\* (aprovação de cliente, inserção e remoção de  
      gerente, relatório de clientes): retornam \*\*202 Accepted\*\* com um Job  
      no corpo e o header \`Location: /jobs/{jobId}/status\`. O front faz  
      polling no status; com \`resultType=resource\` busca  
      \`GET /{dominio}/{resourceId}\`; com \`resultType=inline\` busca  
      \`GET /jobs/{jobId}/result\`. O job expira no Redis em \*\*5 min\*\*  
      (depois disso: 404). Falhas de negócio dentro da SAGA (ex.: e-mail  
      duplicado, último gerente ativo) aparecem como job \`FALHA\` com \`erro\`  
      — o 202 inicial não as antecipa.  
    \- \*\*Ordenação\*\*: listas ordenadas de forma crescente por nome usando  
      \*\*collation pt-BR\*\* (case-insensitive e acentos tratados como a letra  
      base — equivalente a \`Intl.Collator('pt-BR')\` no Node e  
      \`COLLATE "pt-BR-x-icu"\` no PostgreSQL).  
    \- \*\*Sem paginação\*\*: volume de dados didático.  
    \- \*\*Erros\*\*: corpo padrão \`{ status, erro, mensagem }\`. 400 \= requisição  
      malformada; 422 \= regra de negócio violada em operação síncrona.

  contact:  
    name: DS152 \- Desenvolvimento de Aplicações Corporativas (UFPR/TADS)

servers:  
  \# Added by API Auto Mocking Plugin  
  \- description: SwaggerHub API Auto Mocking  
    url: https://virtserver.swaggerhub.com/RAZERANTHOM/bantads/2.0.0  
  \- url: http://localhost:3000  
    description: API Gateway local (ajuste a porta à do seu Gateway)

tags:  
  \- name: Autenticação  
    description: Login e logout (R2)  
  \- name: Solicitações  
    description: Autocadastro e aprovação/rejeição (R1, R8, R9, R10)  
  \- name: Clientes  
    description: Dados de cliente e consultas do gerente (R3, R11)  
  \- name: Contas  
    description: Depósito, saque, transferência e extrato (R3-R7)  
  \- name: Gerentes  
    description: CRUD de gerentes (R12-R15)  
  \- name: Relatórios  
    description: Relatório de clientes (R16)  
  \- name: Jobs  
    description: Acompanhamento de operações assíncronas (seção 5.8)  
  \- name: Infra  
    description: Health check

security:  
  \- tokenAuth: \[\]

paths:

  /login:  
    post:  
      tags: \[Autenticação\]  
      summary: Login (R2)  
      description: |  
        \*\*Público.\*\* Autentica por e-mail/senha, assina o JWT (\`jwt.sign\`) e  
        devolve \`{ auth: true, token, tipo, usuario }\`. Credenciais inválidas  
        ou usuário \*\*Inativo\*\* → \*\*401\*\* \`{ auth: false, message: "Login  
        inválido\!" }\`. Resposta \*\*sem \`\_links\`\*\* (exceção do HATEOAS).  
      security: \[\]  
      requestBody:  
        required: true  
        content:  
          application/json:  
            schema: { $ref: '\#/components/schemas/LoginInput' }  
      responses:  
        '200':  
          description: Autenticado  
          content:  
            application/json:  
              schema: { $ref: '\#/components/schemas/LoginResponse' }  
        '400': { $ref: '\#/components/responses/BadRequest' }  
        '401':  
          description: Login inválido (credenciais erradas ou usuário inativo)  
          content:  
            application/json:  
              schema:  
                type: object  
                properties:  
                  auth: { type: boolean, example: false }  
                  message: { type: string, example: Login inválido\! }

  /logout:  
    post:  
      tags: \[Autenticação\]  
      summary: Logout (R2)  
      description: |  
        \*\*CLIENTE ou GERENTE.\*\* Revoga o token atual: adiciona o \`jti\` à  
        lista de revogados no Redis (TTL \= tempo restante do JWT) e apaga a  
        sessão (\`sessao:\<jti\>\` e a chave reversa \`sessao:cpf:\<cpf\>\`).  
      responses:  
        '204': { description: Sessão encerrada }  
        '401': { $ref: '\#/components/responses/Unauthorized' }

  /health:  
    get:  
      tags: \[Infra\]  
      summary: Health check do Gateway  
      description: |  
        \*\*Público.\*\* Retorna 200 se o Gateway está no ar. Sem \`\_links\`.  
        (Cada MS tem o seu \`/health\` na rede interna, usado pelo healthcheck  
        do docker-compose — não exposto aqui.)  
      security: \[\]  
      responses:  
        '200':  
          description: Gateway no ar  
          content:  
            application/json:  
              schema:  
                type: object  
                properties:  
                  status: { type: string, example: UP }

  /reboot:  
    post:  
      tags: \[Infra\]  
      summary: Recria os dados do seed (primeira chamada da app de teste)  
      description: |  
        \*\*Público.\*\* Recria os DADOS PRÉ-CADASTRADOS (seção 4\) em todos os  
        serviços, voltando o sistema a um estado conhecido: reconstrói o seed  
        (Cliente; Conta command e query; Gerente; Auth) e limpa solicitações,  
        jobs e sessões. É a \*\*primeira chamada\*\* que a aplicação de teste faz,  
        antes de qualquer outra — endpoint de apoio à correção automatizada.  
        Sem \`\_links\`.  
      security: \[\]  
      responses:  
        '200':  
          description: Seed recriado  
          content:  
            application/json:  
              schema:  
                type: object  
                properties:  
                  status: { type: string, example: ok }  
                  clientes: { type: integer, example: 5 }  
                  gerentes: { type: integer, example: 4 }  
                  contas: { type: integer, example: 5 }

  /solicitacoes:  
    post:  
      tags: \[Solicitações\]  
      summary: Autocadastro de cliente (R1)  
      description: |  
        \*\*Público.\*\* Grava a solicitação de criação de conta (síncrono) com  
        status \`PENDENTE\`. Rejeita CPF que já possui solicitação (em qualquer  
        estado) e e-mail já usado em outra solicitação — a garantia final de  
        unicidade do e-mail é do MS Auth, na aprovação (R9).  
      security: \[\]  
      requestBody:  
        required: true  
        content:  
          application/json:  
            schema: { $ref: '\#/components/schemas/AutocadastroInput' }  
      responses:  
        '201':  
          description: Solicitação registrada  
          headers:  
            Location:  
              schema: { type: string, example: /solicitacoes/12912861012 }  
          content:  
            application/json:  
              schema: { $ref: '\#/components/schemas/Solicitacao' }  
        '400': { $ref: '\#/components/responses/BadRequest' }  
        '409':  
          description: CPF já possui solicitação/conta, ou e-mail já usado em outra solicitação  
          content:  
            application/json:  
              schema: { $ref: '\#/components/schemas/Erro' }  
    get:  
      tags: \[Solicitações\]  
      summary: Lista solicitações de autocadastro (R8)  
      description: |  
        \*\*GERENTE.\*\* Todas as solicitações, em todos os estados. Cada item  
        PENDENTE traz os links \`aprovacao\` e \`rejeicao\` (é com eles que a  
        tela do gerente monta os botões — HATEOAS dirigindo a UI).  
      parameters:  
        \- name: status  
          in: query  
          required: false  
          description: Filtro opcional por estado  
          schema: { $ref: '\#/components/schemas/StatusSolicitacao' }  
      responses:  
        '200':  
          description: Lista de solicitações  
          content:  
            application/json:  
              schema: { $ref: '\#/components/schemas/SolicitacoesList' }  
        '401': { $ref: '\#/components/responses/Unauthorized' }  
        '403': { $ref: '\#/components/responses/Forbidden' }

  /solicitacoes/{cpf}:  
    get:  
      tags: \[Solicitações\]  
      summary: Consulta uma solicitação  
      description: '\*\*GERENTE.\*\*'  
      parameters: \[ { $ref: '\#/components/parameters/cpf' } \]  
      responses:  
        '200':  
          description: Solicitação  
          content:  
            application/json:  
              schema: { $ref: '\#/components/schemas/Solicitacao' }  
        '401': { $ref: '\#/components/responses/Unauthorized' }  
        '403': { $ref: '\#/components/responses/Forbidden' }  
        '404': { $ref: '\#/components/responses/NotFound' }

  /solicitacoes/{cpf}/aprovacao:  
    post:  
      tags: \[Solicitações\]  
      summary: Aprova um cliente (R9) — assíncrono, SAGA  
      description: |  
        \*\*GERENTE.\*\* Publica a SAGA \*Aprovar Cliente\* e retorna \*\*202\*\*  
        imediatamente (\`jobId\` \= \`sagaId\`). O Gateway não valida o estado da  
        solicitação — solicitação inexistente ou não-PENDENTE resulta em job  
        \`FALHA\`. Sucesso: job \`CONCLUIDO\` com \`resultType=resource\`,  
        \`dominio=clientes\`, \`resourceId=\<cpf\>\` → \`GET /clientes/{cpf}\`.  
        Caso especial: falha por e-mail duplicado no MS Auth marca a  
        solicitação como \`NAO\_APROVADA\` com motivo automático.  
      parameters: \[ { $ref: '\#/components/parameters/cpf' } \]  
      responses:  
        '202': { $ref: '\#/components/responses/JobAceito' }  
        '401': { $ref: '\#/components/responses/Unauthorized' }  
        '403': { $ref: '\#/components/responses/Forbidden' }

  /solicitacoes/{cpf}/rejeicao:  
    post:  
      tags: \[Solicitações\]  
      summary: Rejeita um cliente (R10) — síncrono  
      description: |  
        \*\*GERENTE.\*\* Operação síncrona (retorna 200 com a solicitação  
        atualizada). O e-mail com o motivo é publicado em \`ms.email.cmd\`  
        de forma fire-and-forget.  
      parameters: \[ { $ref: '\#/components/parameters/cpf' } \]  
      requestBody:  
        required: true  
        content:  
          application/json:  
            schema: { $ref: '\#/components/schemas/RejeicaoInput' }  
      responses:  
        '200':  
          description: Solicitação rejeitada  
          content:  
            application/json:  
              schema: { $ref: '\#/components/schemas/Solicitacao' }  
        '400': { $ref: '\#/components/responses/BadRequest' }  
        '401': { $ref: '\#/components/responses/Unauthorized' }  
        '403': { $ref: '\#/components/responses/Forbidden' }  
        '404': { $ref: '\#/components/responses/NotFound' }  
        '409':  
          description: Solicitação não está PENDENTE  
          content:  
            application/json:  
              schema: { $ref: '\#/components/schemas/Erro' }

  /clientes:  
    get:  
      tags: \[Clientes\]  
      summary: Consulta todos os clientes (R11) — API Composition  
      description: |  
        \*\*GERENTE.\*\* Todos os clientes do banco com CPF, nome, cidade,  
        estado e saldo (Composition: MS Cliente \+ MS Conta query). Ordenação  
        crescente por nome (collation pt-BR). O parâmetro \`busca\` filtra por  
        CPF \*\*ou\*\* nome, aceitando trecho parcial.  
      parameters:  
        \- name: busca  
          in: query  
          required: false  
          description: Trecho de CPF ou de nome  
          schema: { type: string, example: Cat }  
      responses:  
        '200':  
          description: Lista de clientes  
          content:  
            application/json:  
              schema: { $ref: '\#/components/schemas/ClientesList' }  
        '401': { $ref: '\#/components/responses/Unauthorized' }  
        '403': { $ref: '\#/components/responses/Forbidden' }

  /clientes/{cpf}:  
    get:  
      tags: \[Clientes\]  
      summary: Consulta os dados cadastrais de um cliente  
      description: |  
        \*\*GERENTE ou o próprio CLIENTE.\*\* Dados cadastrais (MS Cliente).  
        É o recurso apontado pelo job da aprovação  
        (\`dominio=clientes\`, \`resourceId=\<cpf\>\`). Cacheado no Gateway  
        (\`cache:cliente:\<cpf\>\`, TTL 5 min, invalidado na aprovação R9).  
      parameters: \[ { $ref: '\#/components/parameters/cpf' } \]  
      responses:  
        '200':  
          description: Cliente  
          content:  
            application/json:  
              schema: { $ref: '\#/components/schemas/Cliente' }  
        '401': { $ref: '\#/components/responses/Unauthorized' }  
        '403': { $ref: '\#/components/responses/Forbidden' }  
        '404': { $ref: '\#/components/responses/NotFound' }

  /clientes/{cpf}/conta:  
    get:  
      tags: \[Contas\]  
      summary: Consulta a conta do cliente (R3)  
      description: |  
        \*\*GERENTE ou o próprio CLIENTE.\*\* Sub-recurso singleton (cada  
        cliente tem exatamente uma conta). Devolve número, saldo atual e  
        links para as operações — é o ponto de partida da tela inicial do  
        cliente. Dados do lado \*\*query\*\* do CQRS (consistência eventual:  
        após uma operação, o saldo pode demorar instantes para refletir).  
        \*\*Não cachear\*\* (regra da seção 5.5 do enunciado).  
      parameters: \[ { $ref: '\#/components/parameters/cpf' } \]  
      responses:  
        '200':  
          description: Conta do cliente  
          content:  
            application/json:  
              schema: { $ref: '\#/components/schemas/Conta' }  
        '401': { $ref: '\#/components/responses/Unauthorized' }  
        '403': { $ref: '\#/components/responses/Forbidden' }  
        '404': { $ref: '\#/components/responses/NotFound' }

  /contas/{numero}:  
    get:  
      tags: \[Contas\]  
      summary: Consulta uma conta pelo número  
      description: |  
        \*\*GERENTE ou o CLIENTE dono da conta.\*\* Mesma representação de  
        \`/clientes/{cpf}/conta\` (é o \`self\` canônico da conta). Lado query  
        do CQRS; não cachear.  
      parameters: \[ { $ref: '\#/components/parameters/numeroConta' } \]  
      responses:  
        '200':  
          description: Conta  
          content:  
            application/json:  
              schema: { $ref: '\#/components/schemas/Conta' }  
        '401': { $ref: '\#/components/responses/Unauthorized' }  
        '403': { $ref: '\#/components/responses/Forbidden' }  
        '404': { $ref: '\#/components/responses/NotFound' }

  /contas/{numero}/deposito:  
    post:  
      tags: \[Contas\]  
      summary: Depósito (R4)  
      description: |  
        \*\*CLIENTE dono da conta\*\* (posse validada via \`X-User-CPF\`).  
        Gera o evento \`Depósito\` no event store. A resposta \*\*não devolve o  
        novo saldo\*\* — o front deve reconsultar a conta (link \`conta\`);  
        a projeção é assíncrona (consistência eventual).  
      parameters: \[ { $ref: '\#/components/parameters/numeroConta' } \]  
      requestBody:  
        required: true  
        content:  
          application/json:  
            schema: { $ref: '\#/components/schemas/OperacaoInput' }  
      responses:  
        '201':  
          description: Depósito registrado  
          content:  
            application/json:  
              schema: { $ref: '\#/components/schemas/OperacaoRealizada' }  
        '400': { $ref: '\#/components/responses/BadRequest' }  
        '401': { $ref: '\#/components/responses/Unauthorized' }  
        '403': { $ref: '\#/components/responses/Forbidden' }  
        '404': { $ref: '\#/components/responses/NotFound' }

  /contas/{numero}/saque:  
    post:  
      tags: \[Contas\]  
      summary: Saque (R5)  
      description: |  
        \*\*CLIENTE dono da conta.\*\* O saldo é validado no lado \*\*command\*\*,  
        por replay dos eventos (nunca no read model). Gera o evento \`Saque\`.  
        Resposta sem o novo saldo (ver Depósito).  
      parameters: \[ { $ref: '\#/components/parameters/numeroConta' } \]  
      requestBody:  
        required: true  
        content:  
          application/json:  
            schema: { $ref: '\#/components/schemas/OperacaoInput' }  
      responses:  
        '201':  
          description: Saque registrado  
          content:  
            application/json:  
              schema: { $ref: '\#/components/schemas/OperacaoRealizada' }  
        '400': { $ref: '\#/components/responses/BadRequest' }  
        '401': { $ref: '\#/components/responses/Unauthorized' }  
        '403': { $ref: '\#/components/responses/Forbidden' }  
        '404': { $ref: '\#/components/responses/NotFound' }  
        '422':  
          description: Saldo insuficiente  
          content:  
            application/json:  
              schema: { $ref: '\#/components/schemas/Erro' }

  /contas/{numero}/transferencia:  
    post:  
      tags: \[Contas\]  
      summary: Transferência (R6)  
      description: |  
        \*\*CLIENTE dono da conta de origem.\*\* O Gateway \*\*enriquece\*\* a  
        requisição antes de roteá-la ao MS Conta: obtém o CPF do destino no  
        lado query e os nomes de origem/destino no MS Cliente (seção 5.10).  
        O MS Conta grava os eventos \`TransferênciaOrigem\` e  
        \`TransferênciaDestino\` \*\*atomicamente\*\* (não é SAGA — um único  
        serviço). Resposta sem o novo saldo.  
      parameters: \[ { $ref: '\#/components/parameters/numeroConta' } \]  
      requestBody:  
        required: true  
        content:  
          application/json:  
            schema: { $ref: '\#/components/schemas/TransferenciaInput' }  
      responses:  
        '201':  
          description: Transferência registrada  
          content:  
            application/json:  
              schema: { $ref: '\#/components/schemas/OperacaoRealizada' }  
        '400': { $ref: '\#/components/responses/BadRequest' }  
        '401': { $ref: '\#/components/responses/Unauthorized' }  
        '403': { $ref: '\#/components/responses/Forbidden' }  
        '404': { $ref: '\#/components/responses/NotFound' }  
        '422':  
          description: Saldo insuficiente, conta destino inexistente ou transferência para a própria conta  
          content:  
            application/json:  
              schema: { $ref: '\#/components/schemas/Erro' }

  /contas/{numero}/extrato:  
    get:  
      tags: \[Contas\]  
      summary: Extrato (R7)  
      description: |  
        \*\*CLIENTE dono da conta.\*\* Devolve o \*\*saldo de abertura\*\* (saldo  
        consolidado anterior à data inicial) e as movimentações do período —  
        o front-end monta a linha do tempo diária com Luxon. Sem \`inicio\` e  
        \`fim\`, assume os \*\*últimos 30 dias\*\*. Intervalo máximo: \*\*365 dias\*\*.  
      parameters:  
        \- { $ref: '\#/components/parameters/numeroConta' }  
        \- name: inicio  
          in: query  
          required: false  
          description: Data inicial (default hoje \- 30 dias)  
          schema: { type: string, format: date, example: '2025-01-01' }  
        \- name: fim  
          in: query  
          required: false  
          description: Data final (default hoje)  
          schema: { type: string, format: date, example: '2025-01-31' }  
      responses:  
        '200':  
          description: Extrato do período  
          content:  
            application/json:  
              schema: { $ref: '\#/components/schemas/Extrato' }  
        '400': { $ref: '\#/components/responses/BadRequest' }  
        '401': { $ref: '\#/components/responses/Unauthorized' }  
        '403': { $ref: '\#/components/responses/Forbidden' }  
        '404': { $ref: '\#/components/responses/NotFound' }  
        '422':  
          description: Intervalo maior que 365 dias ou fim anterior ao início  
          content:  
            application/json:  
              schema: { $ref: '\#/components/schemas/Erro' }

  /gerentes:  
    get:  
      tags: \[Gerentes\]  
      summary: Listagem de gerentes (R12) — API Composition  
      description: |  
        \*\*GERENTE.\*\* Gerentes \*\*ativos\*\*, ordenados por nome (collation  
        pt-BR), com a quantidade de clientes (Composition: MS Gerente \+  
        MS Conta query).  
      responses:  
        '200':  
          description: Lista de gerentes  
          content:  
            application/json:  
              schema: { $ref: '\#/components/schemas/GerentesList' }  
        '401': { $ref: '\#/components/responses/Unauthorized' }  
        '403': { $ref: '\#/components/responses/Forbidden' }  
    post:  
      tags: \[Gerentes\]  
      summary: Insere um gerente (R13) — assíncrono, SAGA  
      description: |  
        \*\*GERENTE.\*\* Publica a SAGA \*Inserção de Gerente\* e retorna \*\*202\*\*.  
        A senha vem no formulário (não é enviada por e-mail). A unicidade do  
        e-mail é garantida pelo MS Auth \*\*dentro da SAGA\*\* — duplicidade  
        resulta em job \`FALHA\` (o 202 não a antecipa). Sucesso: job  
        \`CONCLUIDO\`, \`resultType=resource\`, \`dominio=gerentes\`,  
        \`resourceId=\<cpf\>\` → \`GET /gerentes/{cpf}\`. A transferência de uma  
        conta ao novo gerente segue a regra do R13 (pode não haver conta a  
        transferir).  
      requestBody:  
        required: true  
        content:  
          application/json:  
            schema: { $ref: '\#/components/schemas/GerenteInput' }  
      responses:  
        '202': { $ref: '\#/components/responses/JobAceito' }  
        '400': { $ref: '\#/components/responses/BadRequest' }  
        '401': { $ref: '\#/components/responses/Unauthorized' }  
        '403': { $ref: '\#/components/responses/Forbidden' }

  /gerentes/{cpf}:  
    get:  
      tags: \[Gerentes\]  
      summary: Consulta um gerente  
      description: |  
        \*\*GERENTE.\*\* Recurso apontado pelo job da inserção  
        (\`dominio=gerentes\`). Cacheado no Gateway (\`cache:gerente:\<cpf\>\`,  
        TTL 5 min, invalidado em R13/R14/R15). \`quantidadeClientes\` pode  
        vir nula aqui (dado do MS Conta, presente na listagem R12).  
      parameters: \[ { $ref: '\#/components/parameters/cpf' } \]  
      responses:  
        '200':  
          description: Gerente  
          content:  
            application/json:  
              schema: { $ref: '\#/components/schemas/Gerente' }  
        '401': { $ref: '\#/components/responses/Unauthorized' }  
        '403': { $ref: '\#/components/responses/Forbidden' }  
        '404': { $ref: '\#/components/responses/NotFound' }  
    put:  
      tags: \[Gerentes\]  
      summary: Atualiza um gerente (R14) — síncrono  
      description: |  
        \*\*GERENTE.\*\* Atualiza somente \*\*nome\*\* e \*\*telefone\*\*. E-mail (login)  
        e CPF são imutáveis — presença deles no corpo com valor diferente do  
        atual resulta em \*\*400\*\*. Não altera senha.  
      parameters: \[ { $ref: '\#/components/parameters/cpf' } \]  
      requestBody:  
        required: true  
        content:  
          application/json:  
            schema: { $ref: '\#/components/schemas/GerenteUpdate' }  
      responses:  
        '200':  
          description: Gerente atualizado  
          content:  
            application/json:  
              schema: { $ref: '\#/components/schemas/Gerente' }  
        '400': { $ref: '\#/components/responses/BadRequest' }  
        '401': { $ref: '\#/components/responses/Unauthorized' }  
        '403': { $ref: '\#/components/responses/Forbidden' }  
        '404': { $ref: '\#/components/responses/NotFound' }  
    delete:  
      tags: \[Gerentes\]  
      summary: Remove um gerente (R15) — assíncrono, SAGA  
      description: |  
        \*\*GERENTE.\*\* Publica a SAGA \*Remoção de Gerente\* e retorna \*\*202\*\*.  
        Remoção lógica: seta INATIVO, desativa o registro de autenticação,  
        apaga a sessão no Redis (logout forçado) e transfere as contas ao  
        gerente ativo com menos clientes. Regras de negócio (gerente  
        inexistente, \*\*último gerente ativo\*\*) resultam em job \`FALHA\`.  
        Sucesso: job \`CONCLUIDO\`, \`resultType=inline\` →  
        \`GET /jobs/{jobId}/result\` (mensagem de sucesso).

        \*\*Pré-condição síncrona:\*\* um gerente \*\*não pode remover a si mesmo\*\*  
        — o Gateway rejeita com \*\*403\*\* (CPF autenticado igual ao CPF do path)  
        antes de publicar a SAGA.  
      parameters: \[ { $ref: '\#/components/parameters/cpf' } \]  
      responses:  
        '202': { $ref: '\#/components/responses/JobAceito' }  
        '401': { $ref: '\#/components/responses/Unauthorized' }  
        '403':  
          description: Perfil sem permissão, ou o gerente tentou remover a si mesmo  
          content:  
            application/json:  
              schema: { $ref: '\#/components/schemas/Erro' }

  /relatorios/clientes:  
    get:  
      tags: \[Relatórios\]  
      summary: Relatório de clientes (R16) — assíncrono, API Composition  
      description: |  
        \*\*GERENTE.\*\* Dispara a composição assíncrona e retorna \*\*202\*\*  
        (em sistemas reais, relatórios volumosos são assíncronos). Job  
        \`CONCLUIDO\` com \`resultType=inline\` → \`GET /jobs/{jobId}/result\`  
        devolve a lista completa (CPF, nome, e-mail, salário, conta, saldo,  
        CPF e nome do gerente), ordenada por nome do cliente  
        (collation pt-BR).  
      responses:  
        '202': { $ref: '\#/components/responses/JobAceito' }  
        '401': { $ref: '\#/components/responses/Unauthorized' }  
        '403': { $ref: '\#/components/responses/Forbidden' }

  /jobs/{jobId}/status:  
    get:  
      tags: \[Jobs\]  
      summary: Status de um job assíncrono  
      description: |  
        \*\*CLIENTE ou GERENTE\*\* (o mesmo usuário que iniciou a operação).  
        Endpoint de polling do padrão 202\. Sem \`\_links\` (exceção do  
        HATEOAS). O job expira em 5 min no Redis — depois disso, 404\.  
      parameters: \[ { $ref: '\#/components/parameters/jobId' } \]  
      responses:  
        '200':  
          description: Estado atual do job  
          content:  
            application/json:  
              schema: { $ref: '\#/components/schemas/Job' }  
        '401': { $ref: '\#/components/responses/Unauthorized' }  
        '404':  
          description: Job inexistente ou expirado (TTL 5 min)  
          content:  
            application/json:  
              schema: { $ref: '\#/components/schemas/Erro' }

  /jobs/{jobId}/result:  
    get:  
      tags: \[Jobs\]  
      summary: Resultado inline de um job concluído  
      description: |  
        \*\*CLIENTE ou GERENTE.\*\* Só para jobs com \`resultType=inline\`  
        (R15: mensagem de sucesso; R16: lista de clientes). Sem \`\_links\`.  
      parameters: \[ { $ref: '\#/components/parameters/jobId' } \]  
      responses:  
        '200':  
          description: Resultado do job  
          content:  
            application/json:  
              schema:  
                oneOf:  
                  \- $ref: '\#/components/schemas/ResultadoRemocaoGerente'  
                  \- $ref: '\#/components/schemas/ResultadoRelatorioClientes'  
        '401': { $ref: '\#/components/responses/Unauthorized' }  
        '404':  
          description: Job inexistente ou expirado (TTL 5 min)  
          content:  
            application/json:  
              schema: { $ref: '\#/components/schemas/Erro' }  
        '409':  
          description: Job ainda não concluído, falhou ou não é inline  
          content:  
            application/json:  
              schema: { $ref: '\#/components/schemas/Erro' }

components:

  securitySchemes:  
    tokenAuth:  
      type: apiKey  
      in: header  
      name: x-access-token  
      description: \>  
        JWT assinado pelo API Gateway no login (verificado por assinatura+exp e  
        pela sessão no Redis), enviado no header x-access-token. Ausente → 401  
        { auth, message }; inválido/expirado ou sessão inexistente/revogada →  
        401 { auth, message }.

  parameters:  
    cpf:  
      name: cpf  
      in: path  
      required: true  
      description: CPF (11 dígitos, sem pontuação)  
      schema: { type: string, pattern: '^\\d{11}$', example: '12912861012' }  
    numeroConta:  
      name: numero  
      in: path  
      required: true  
      description: Número da conta (4 dígitos, pode iniciar com zero)  
      schema: { type: string, pattern: '^\\d{4}$', example: '0950' }  
    jobId:  
      name: jobId  
      in: path  
      required: true  
      description: UUID do job (igual ao sagaId nas operações de SAGA)  
      schema: { type: string, format: uuid }

  responses:  
    JobAceito:  
      description: Operação aceita — acompanhar via job  
      headers:  
        Location:  
          description: URL de polling do job  
          schema: { type: string, example: /jobs/8f14e45f-ceea-4e1b-9d2a-52f7254b1f0b/status }  
      content:  
        application/json:  
          schema: { $ref: '\#/components/schemas/Job' }  
    BadRequest:  
      description: Requisição malformada (campo ausente/ inválido)  
      content:  
        application/json:  
          schema: { $ref: '\#/components/schemas/Erro' }  
    Unauthorized:  
      description: \>  
        Token não fornecido (header x-access-token ausente) ou  
        inválido/expirado — ambos 401 (ver o verifyJWT do servidor).  
      content:  
        application/json:  
          schema:  
            type: object  
            properties:  
              auth: { type: boolean, example: false }  
              message: { type: string, example: Token não fornecido. }  
    Forbidden:  
      description: Perfil sem permissão ou recurso de outro usuário  
      content:  
        application/json:  
          schema: { $ref: '\#/components/schemas/Erro' }  
    NotFound:  
      description: Recurso não encontrado  
      content:  
        application/json:  
          schema: { $ref: '\#/components/schemas/Erro' }

  schemas:

    \# \---------- infra \----------

    Link:  
      type: object  
      required: \[href\]  
      properties:  
        href: { type: string, example: 'http://localhost:3000/contas/1291' }

    Links:  
      type: object  
      description: \>  
        Mapa HATEOAS (estilo HAL). Os links presentes dependem do estado do  
        recurso e do perfil do usuário. Os \`href\` apontam sempre para o API  
        Gateway (reescritos por ele).  
      additionalProperties: { $ref: '\#/components/schemas/Link' }  
      example:  
        self: { href: 'http://localhost:3000/contas/1291' }  
        deposito: { href: 'http://localhost:3000/contas/1291/deposito' }  
        saque: { href: 'http://localhost:3000/contas/1291/saque' }  
        transferencia: { href: 'http://localhost:3000/contas/1291/transferencia' }  
        extrato: { href: 'http://localhost:3000/contas/1291/extrato' }

    Erro:  
      type: object  
      required: \[status, erro, mensagem\]  
      properties:  
        status: { type: integer, example: 422 }  
        erro: { type: string, example: Unprocessable Entity }  
        mensagem: { type: string, example: Saldo insuficiente para a operação }

    Dinheiro:  
      type: string  
      description: Valor monetário como string decimal (ponto, 2 casas)  
      pattern: '^\\d+\\.\\d{2}$'  
      example: '1500.00'

    \# \---------- autenticação \----------

    LoginInput:  
      type: object  
      required: \[email, senha\]  
      properties:  
        email: { type: string, format: email, example: cli1@bantads.com.br }  
        senha: { type: string, format: password, example: tads }

    Usuario:  
      type: object  
      description: Nunca contém a senha  
      required: \[cpf, nome, email\]  
      properties:  
        cpf: { type: string, example: '12912861012' }  
        nome: { type: string, example: Catharyna }  
        email: { type: string, format: email, example: cli1@bantads.com.br }

    LoginResponse:  
      type: object  
      description: \>  
        \`auth\` \+ \`token\` (JWT), como no verifyJWT do servidor, mais \`tipo\` e  
        \`usuario\` que o front do BANTADS precisa (§5.4). Sem \`\_links\`.  
      required: \[auth, token, tipo, usuario\]  
      properties:  
        auth: { type: boolean, example: true }  
        token: { type: string, example: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9... }  
        tipo:  
          type: string  
          enum: \[CLIENTE, GERENTE\]  
          example: CLIENTE  
        usuario: { $ref: '\#/components/schemas/Usuario' }

    \# \---------- solicitações \----------

    StatusSolicitacao:  
      type: string  
      enum: \[PENDENTE, APROVADA, NAO\_APROVADA\]

    Endereco:  
      type: object  
      required: \[logradouro, numero, cep, cidade, uf\]  
      properties:  
        logradouro: { type: string, example: Rua XV de Novembro }  
        numero: { type: string, example: '1299' }  
        complemento: { type: string, nullable: true, example: Ap. 42 }  
        cep: { type: string, pattern: '^\\d{8}$', example: '80060000' }  
        cidade: { type: string, example: Curitiba }  
        uf: { type: string, pattern: '^\[A-Z\]{2}$', example: PR }

    AutocadastroInput:  
      type: object  
      required: \[cpf, nome, email, telefone, salario, endereco\]  
      properties:  
        cpf: { type: string, pattern: '^\\d{11}$', example: '11122233396' }  
        nome: { type: string, example: Fulano de Tal }  
        email: { type: string, format: email, example: fulano@exemplo.com.br }  
        telefone: { type: string, example: '41999990000' }  
        salario: { $ref: '\#/components/schemas/Dinheiro' }  
        endereco: { $ref: '\#/components/schemas/Endereco' }

    Solicitacao:  
      allOf:  
        \- $ref: '\#/components/schemas/AutocadastroInput'  
        \- type: object  
          required: \[status, \_links\]  
          properties:  
            status: { $ref: '\#/components/schemas/StatusSolicitacao' }  
            motivo:  
              type: string  
              nullable: true  
              description: Motivo da rejeição (apenas quando NAO\_APROVADA)  
              example: null  
            dataHoraProcessamento:  
              type: string  
              nullable: true  
              description: Data/hora da aprovação ou rejeição (ISO 8601\)  
              example: null  
            \_links: { $ref: '\#/components/schemas/Links' }  
      example:  
        cpf: '11122233396'  
        nome: Fulano de Tal  
        email: fulano@exemplo.com.br  
        telefone: '41999990000'  
        salario: '4500.00'  
        endereco:  
          logradouro: Rua XV de Novembro  
          numero: '1299'  
          complemento: null  
          cep: '80060000'  
          cidade: Curitiba  
          uf: PR  
        status: PENDENTE  
        motivo: null  
        dataHoraProcessamento: null  
        \_links:  
          self: { href: 'http://localhost:3000/solicitacoes/11122233396' }  
          aprovacao: { href: 'http://localhost:3000/solicitacoes/11122233396/aprovacao' }  
          rejeicao: { href: 'http://localhost:3000/solicitacoes/11122233396/rejeicao' }

    RejeicaoInput:  
      type: object  
      required: \[motivo\]  
      properties:  
        motivo: { type: string, example: Renda incompatível com a política do banco }

    SolicitacoesList:  
      type: object  
      required: \[solicitacoes, \_links\]  
      properties:  
        solicitacoes:  
          type: array  
          items: { $ref: '\#/components/schemas/Solicitacao' }  
        \_links: { $ref: '\#/components/schemas/Links' }

    \# \---------- clientes \----------

    Cliente:  
      type: object  
      required: \[cpf, nome, email, telefone, salario, endereco, \_links\]  
      properties:  
        cpf: { type: string, example: '12912861012' }  
        nome: { type: string, example: Catharyna }  
        email: { type: string, format: email, example: cli1@bantads.com.br }  
        telefone: { type: string, example: '41999990001' }  
        salario: { $ref: '\#/components/schemas/Dinheiro' }  
        endereco: { $ref: '\#/components/schemas/Endereco' }  
        \_links: { $ref: '\#/components/schemas/Links' }  
      example:  
        cpf: '12912861012'  
        nome: Catharyna  
        email: cli1@bantads.com.br  
        telefone: '41999990001'  
        salario: '10000.00'  
        endereco:  
          logradouro: Rua XV de Novembro  
          numero: '1299'  
          complemento: null  
          cep: '80060000'  
          cidade: Curitiba  
          uf: PR  
        \_links:  
          self: { href: 'http://localhost:3000/clientes/12912861012' }  
          conta: { href: 'http://localhost:3000/clientes/12912861012/conta' }

    ClienteResumo:  
      type: object  
      description: Linha da consulta R11 (Composition Cliente \+ Conta)  
      required: \[cpf, nome, cidade, estado, saldo, \_links\]  
      properties:  
        cpf: { type: string, example: '12912861012' }  
        nome: { type: string, example: Catharyna }  
        cidade: { type: string, example: Curitiba }  
        estado: { type: string, example: PR }  
        saldo: { $ref: '\#/components/schemas/Dinheiro' }  
        \_links: { $ref: '\#/components/schemas/Links' }

    ClientesList:  
      type: object  
      required: \[clientes, \_links\]  
      properties:  
        clientes:  
          type: array  
          items: { $ref: '\#/components/schemas/ClienteResumo' }  
        \_links: { $ref: '\#/components/schemas/Links' }

    \# \---------- contas \----------

    Conta:  
      type: object  
      description: Lado query do CQRS — saldo em consistência eventual  
      required: \[numero, cpfCliente, cpfGerente, saldo, dataCriacao, \_links\]  
      properties:  
        numero: { type: string, example: '1291' }  
        cpfCliente: { type: string, example: '12912861012' }  
        cpfGerente: { type: string, example: '98574307084' }  
        saldo: { $ref: '\#/components/schemas/Dinheiro' }  
        dataCriacao: { type: string, format: date, example: '2000-01-01' }  
        \_links: { $ref: '\#/components/schemas/Links' }  
      example:  
        numero: '1291'  
        cpfCliente: '12912861012'  
        cpfGerente: '98574307084'  
        saldo: '800.00'  
        dataCriacao: '2000-01-01'  
        \_links:  
          self: { href: 'http://localhost:3000/contas/1291' }  
          cliente: { href: 'http://localhost:3000/clientes/12912861012' }  
          deposito: { href: 'http://localhost:3000/contas/1291/deposito' }  
          saque: { href: 'http://localhost:3000/contas/1291/saque' }  
          transferencia: { href: 'http://localhost:3000/contas/1291/transferencia' }  
          extrato: { href: 'http://localhost:3000/contas/1291/extrato' }

    OperacaoInput:  
      type: object  
      required: \[valor\]  
      properties:  
        valor: { $ref: '\#/components/schemas/Dinheiro' }

    TransferenciaInput:  
      type: object  
      required: \[contaDestino, valor\]  
      properties:  
        contaDestino: { type: string, pattern: '^\\d{4}$', example: '0950' }  
        valor: { $ref: '\#/components/schemas/Dinheiro' }

    ParteTransferencia:  
      type: object  
      description: Identificação de origem/destino em uma transferência  
      required: \[numeroConta, cpf, nome\]  
      properties:  
        numeroConta: { type: string, example: '0950' }  
        cpf: { type: string, example: '09506382000' }  
        nome: { type: string, example: Cleuddônio }

    OperacaoRealizada:  
      type: object  
      description: \>  
        Confirmação da operação. NÃO contém o novo saldo — o front deve  
        reconsultar a conta (link \`conta\`); a projeção do read model é  
        assíncrona.  
      required: \[numeroConta, tipo, dataHora, valor, \_links\]  
      properties:  
        numeroConta: { type: string, example: '1291' }  
        tipo:  
          type: string  
          enum: \[DEPOSITO, SAQUE, TRANSFERENCIA\]  
        dataHora: { type: string, example: '2026-04-30T10:00:00' }  
        valor: { $ref: '\#/components/schemas/Dinheiro' }  
        destino:  
          allOf: \[ { $ref: '\#/components/schemas/ParteTransferencia' } \]  
          nullable: true  
          description: Presente apenas em transferências  
        \_links: { $ref: '\#/components/schemas/Links' }  
      example:  
        numeroConta: '1291'  
        tipo: TRANSFERENCIA  
        dataHora: '2026-04-30T10:00:00'  
        valor: '100.00'  
        destino: { numeroConta: '0950', cpf: '09506382000', nome: Cleuddônio }  
        \_links:  
          conta: { href: 'http://localhost:3000/contas/1291' }  
          extrato: { href: 'http://localhost:3000/contas/1291/extrato' }

    Movimentacao:  
      type: object  
      description: \>  
        Linha do extrato (read model "Histórico de Movimentações").  
        \`origem\`/\`destino\` preenchidos apenas em transferências — o front  
        determina entrada/saída comparando o CPF do usuário logado.  
      required: \[dataHora, tipo, valor\]  
      properties:  
        dataHora: { type: string, example: '2020-01-20T12:00:00' }  
        tipo:  
          type: string  
          enum: \[DEPOSITO, SAQUE, TRANSFERENCIA\]  
        valor: { $ref: '\#/components/schemas/Dinheiro' }  
        origem:  
          allOf: \[ { $ref: '\#/components/schemas/ParteTransferencia' } \]  
          nullable: true  
        destino:  
          allOf: \[ { $ref: '\#/components/schemas/ParteTransferencia' } \]  
          nullable: true

    Extrato:  
      type: object  
      description: \>  
        Saldo de abertura \+ movimentações do período. O saldo consolidado  
        dia a dia é montado pelo front-end (Luxon), acumulando sobre o  
        \`saldoAbertura\`.  
      required: \[numeroConta, dataInicio, dataFim, saldoAbertura, movimentacoes, \_links\]  
      properties:  
        numeroConta: { type: string, example: '1291' }  
        dataInicio: { type: string, format: date, example: '2020-01-01' }  
        dataFim: { type: string, format: date, example: '2020-01-31' }  
        saldoAbertura:  
          allOf: \[ { $ref: '\#/components/schemas/Dinheiro' } \]  
          description: Saldo consolidado anterior à data inicial  
        movimentacoes:  
          type: array  
          items: { $ref: '\#/components/schemas/Movimentacao' }  
        \_links: { $ref: '\#/components/schemas/Links' }

    \# \---------- gerentes \----------

    GerenteInput:  
      type: object  
      required: \[cpf, nome, email, telefone, senha\]  
      properties:  
        cpf: { type: string, pattern: '^\\d{11}$', example: '40501740066' }  
        nome: { type: string, example: Gadamântio }  
        email: { type: string, format: email, example: ger4@bantads.com.br }  
        telefone: { type: string, example: '41988887777' }  
        senha: { type: string, format: password, example: tads }

    GerenteUpdate:  
      type: object  
      description: Somente nome e telefone são mutáveis (R14)  
      required: \[nome, telefone\]  
      properties:  
        nome: { type: string, example: Gadamântio de Souza }  
        telefone: { type: string, example: '41988887777' }

    Gerente:  
      type: object  
      required: \[cpf, nome, email, telefone, ativo, \_links\]  
      properties:  
        cpf: { type: string, example: '98574307084' }  
        nome: { type: string, example: Geniéve }  
        email: { type: string, format: email, example: ger1@bantads.com.br }  
        telefone: { type: string, example: '41988880001' }  
        ativo: { type: boolean, example: true }  
        quantidadeClientes:  
          type: integer  
          nullable: true  
          description: Preenchido na listagem (R12 — Composition com MS Conta)  
          example: 2  
        \_links: { $ref: '\#/components/schemas/Links' }  
      example:  
        cpf: '98574307084'  
        nome: Geniéve  
        email: ger1@bantads.com.br  
        telefone: '41988880001'  
        ativo: true  
        quantidadeClientes: 2  
        \_links:  
          self: { href: 'http://localhost:3000/gerentes/98574307084' }  
          atualizacao: { href: 'http://localhost:3000/gerentes/98574307084' }  
          remocao: { href: 'http://localhost:3000/gerentes/98574307084' }

    GerentesList:  
      type: object  
      required: \[gerentes, \_links\]  
      properties:  
        gerentes:  
          type: array  
          items: { $ref: '\#/components/schemas/Gerente' }  
        \_links: { $ref: '\#/components/schemas/Links' }

    \# \---------- jobs \----------

    Job:  
      type: object  
      description: \>  
        Envelope do job assíncrono (formato da seção 5.8). Nas operações de  
        SAGA, \`jobId\` \= \`sagaId\`. Sem \`\_links\` — usar o header \`Location\`  
        da resposta 202 e os caminhos fixos \`/jobs/{jobId}/status\` e  
        \`/jobs/{jobId}/result\`.  
      required: \[jobId, status\]  
      properties:  
        jobId: { type: string, format: uuid, example: 8f14e45f-ceea-4e1b-9d2a-52f7254b1f0b }  
        status:  
          type: string  
          enum: \[PENDENTE, CONCLUIDO, FALHA\]  
          example: PENDENTE  
        resultType:  
          type: string  
          nullable: true  
          enum: \[resource, inline, null\]  
          example: null  
        dominio:  
          type: string  
          nullable: true  
          description: Presente quando resultType=resource (clientes | gerentes)  
          example: clientes  
        resourceId:  
          type: string  
          nullable: true  
          description: Id do recurso criado (CPF) quando resultType=resource  
          example: '12912861012'  
        erro:  
          type: string  
          nullable: true  
          description: Mensagem de erro quando status=FALHA  
          example: null

    ResultadoRemocaoGerente:  
      type: object  
      description: Resultado inline do R15  
      required: \[mensagem\]  
      properties:  
        mensagem: { type: string, example: Gerente removido; 2 contas transferidas para Gyândula }

    RelatorioClienteLinha:  
      type: object  
      description: Linha do Relatório de Clientes (R16)  
      required: \[cpf, nome, email, salario, numeroConta, saldo, cpfGerente, nomeGerente\]  
      properties:  
        cpf: { type: string, example: '12912861012' }  
        nome: { type: string, example: Catharyna }  
        email: { type: string, format: email, example: cli1@bantads.com.br }  
        salario: { $ref: '\#/components/schemas/Dinheiro' }  
        numeroConta: { type: string, example: '1291' }  
        saldo: { $ref: '\#/components/schemas/Dinheiro' }  
        cpfGerente: { type: string, example: '98574307084' }  
        nomeGerente: { type: string, example: Geniéve }

    ResultadoRelatorioClientes:  
      type: object  
      description: Resultado inline do R16 (ordenado por nome, collation pt-BR)  
      required: \[clientes\]  
      properties:  
        clientes:  
          type: array  
          items: { $ref: '\#/components/schemas/RelatorioClienteLinha' }