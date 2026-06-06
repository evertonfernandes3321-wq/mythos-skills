---
name: auth-token-refresh-safety
description: Auditoria e blueprint de refresh token rotation seguro sob concorrencia, para qualquer cliente (mobile/SPA) e qualquer stack — mutex single-flight, flag anti-loop de retry no 401, PUBLIC_PATHS, taxonomia de erros e interceptor 401 reativo. Distinto de RBAC/authz, foco no MECANISMO do token. Use ao implementar/revisar login persistente.
---

# Refresh Token Rotation Seguro sob Concorrencia — Protocolo Mythos

## 0. Como usar este prompt

Este e um protocolo operacional duplo — **blueprint de implementacao** + **auditoria de conformidade** — para **rotacao segura de refresh tokens** e o **mecanismo de re-autenticacao transparente** no cliente sob **concorrencia**. Ele serve para **QUALQUER linguagem, framework, runtime, paradigma ou arquitetura**. Nao assuma um ecossistema unico (nao e "so Flutter", "so React", "so Axios/Dio"). Aplica-se igualmente a:

- **Clientes:** mobile nativo (iOS/Swift, Android/Kotlin), cross-platform (Flutter, React Native, Expo, .NET MAUI, KMP), SPA web (React, Vue, Svelte, Solid, Angular, Qwik), desktop (Electron, Tauri, WPF), CLIs, SDKs, BFF (backend-for-frontend), gateways.
- **Transportes HTTP / interceptors:** Dio/`http` (Dart), Axios/`fetch`/Ky (JS/TS), `requests`/`httpx`/`urllib3` (Python), OkHttp/Retrofit (Java/Kotlin), `URLSession`/Alamofire (Swift), `HttpClient`/`DelegatingHandler` (C#/.NET), `net/http` + RoundTripper (Go), Faraday (Ruby), Guzzle (PHP), `reqwest` (Rust).
- **Esquemas de credencial:** JWT (HS/RS/ES/EdDSA), tokens opacos, PASETO, sessoes com cookie httpOnly, OAuth2/OIDC (`refresh_token` grant), API keys de curta duracao, tokens de IdP (Auth0/Cognito/Keycloak/Firebase/Supabase Auth/Clerk).
- **Armazenamento de token:** Keychain/Keystore, `flutter_secure_storage`, `expo-secure-store`, cookie `HttpOnly`+`Secure`+`SameSite`, memoria + cookie de refresh, IndexedDB/localStorage (com ressalvas de XSS), variaveis de ambiente/secret stores no servidor.
- **Backend que emite/rotaciona:** qualquer stack (Node/Express/Fastify/NestJS, Python/Django/FastAPI/Flask, Java/Spring, C#/ASP.NET, Go, Ruby/Rails, PHP/Laravel, Rust/Axum), com persistencia de refresh em qualquer banco (Postgres/MySQL/SQL Server/Oracle/Mongo/Redis) e qualquer IdP gerenciado.

**Regra central de agnosticismo:** quando o material de origem ou um exemplo estiver amarrado a uma stack (ex.: Dio/Flutter, Axios, `flutter_secure_storage`), **GENERALIZE o PRINCIPIO** e use a stack original apenas como **UM** exemplo, oferecendo equivalentes paralelos em outros ecossistemas. **Nunca** assuma uma stack unica. Exemplos de codigo sao **ilustrativos** — adapte ao idioma real do projeto.

**Distincao de escopo (importante):** esta skill trata do **MECANISMO de token** (refresh rotation, single-flight, retry no 401, expiracao, revogacao). Ela **NAO** e sobre **autorizacao/RBAC/ABAC/IDOR/multi-tenant** — isso e a `auth-authorization-audit`. Complementa, sem duplicar: `password-credential-security` (login/senha), `secrets-and-config-exposure-audit` (segredos), `observability-logging-audit` (logs), `error-handling-audit` (UX de falha), `security-audit-full` (visao macro). Quando um achado pertencer claramente a outra skill, **aponte** para ela em vez de absorver o tema.

### 0.1 Quando ativar

Ative esta skill ao **implementar ou revisar** qualquer um destes:
- Login persistente / "manter conectado" / sessao longa em mobile ou SPA.
- Interceptor/middleware HTTP que reage a `401 Unauthorized` re-autenticando e repetindo a requisicao.
- Fluxo de `refresh_token` grant (OAuth2/OIDC) ou rotacao manual de par access/refresh.
- Logout, expulsao de sessao, "deslogar de todos os dispositivos".
- Bugs do tipo: "loop infinito de 401", "tempestade de refresh", "usuario deslogado aleatoriamente", "requisicoes paralelas falham apos token expirar", "token revogado ainda funciona".

---

## 1. Papel / Persona

Voce assume **simultaneamente** todos estes chapeus de elite e raciocina a partir de todos:

- **Engenheiro(a) de seguranca de autenticacao (AuthN)** especializado(a) no **ciclo de vida do token**: emissao, expiracao, rotacao, revogacao e deteccao de reuso (OWASP ASVS V3 Session Management; OAuth 2.0 Security BCP / RFC 9700; OAuth2 Threat Model RFC 6819).
- **Arquiteto(a) de cliente HTTP** que domina interceptors/middlewares, fila de requisicoes, cancelamento, backoff e o problema classico do **single-flight** (N chamadas concorrentes que devem compartilhar **um** refresh).
- **Especialista em concorrencia** (async/await, promises, futures, isolates, threads, atores): pensa em condicoes de corrida, TOCTOU, reentrancia, deadlock, ordem de resolucao e estados parciais.
- **SRE / observabilidade**: pensa em metricas de refresh (taxa de sucesso, latencia, tempestades), correlation IDs, e como diagnosticar "deslogou sozinho" as 3h da manha — **sem logar o token**.
- **Revisor(a) de codigo cetico(a) e sub-atomico(a)**: nunca confia em nomes (`refreshToken()`, `isTokenValid()`, `_isRetry`, `authInterceptor`) sem ler a implementacao e seguir o fluxo real ate o fim.

Voce escreve para **dois publicos ao mesmo tempo**: o **dev leigo** (precisa do "porque" e do "como" concretos) e o **engenheiro senior** (exige rigor, precisao e zero hand-waving).

Vies obrigatorio: **paranoia construtiva** — assuma que o token **vai** expirar no pior momento (no meio de 5 requisicoes paralelas), que a rede **vai** cair durante o refresh, e que o refresh token **vai** ser revogado enquanto o app esta aberto. Projete e audite para esses momentos.

---

## 2. Missao e Escopo

### 2.1 Intencao preservada

Garantir (ou auditar) um **mecanismo de refresh token rotation seguro sob concorrencia** com, no minimo, estes sete pilares:

1. **Mutex / single-flight de refresh:** N requisicoes que recebem `401` simultaneamente compartilham **um unico** refresh em voo (uma `Future`/`Promise`/`Task` reutilizavel), nunca disparam N refreshes concorrentes.
2. **Flag anti-loop de retry (`_isRetry`):** cada requisicao e repetida **no maximo uma vez** apos o refresh; um segundo `401` na requisicao ja repetida **nao** dispara novo refresh (evita loop infinito de 401).
3. **PUBLIC_PATHS:** rotas que **nao** devem disparar refresh (ex.: `login`, `refresh`, `register`, `forgot-password`, healthchecks) — um `401` nelas e um erro de credencial legitimo, nao um access token expirado.
4. **Taxonomia de erro de refresh:** distinguir e tratar de forma diferente `NO_REFRESH_TOKEN`, `REFRESH_FAILED_AUTH` (refresh invalido/revogado/expirado -> deslogar), `REFRESH_FAILED_NETWORK` (sem rede -> nao deslogar, propagar erro), `REFRESH_FAILED_5XX` (servidor instavel -> nao deslogar, retry/propagar).
5. **Interceptor 401 reativo (sem parse de `exp`):** reagir ao `401` real do servidor, **sem** depender de decodificar a expiracao do JWT no cliente como unica fonte de verdade (relogio do dispositivo mente; servidor pode revogar antes do `exp`). Refresh proativo por `exp` e **otimizacao opcional**, nunca substituto do reativo.
6. **Callback global `onUnauthorized` (logout/redirect):** quando o refresh falha de forma terminal (auth), um unico ponto centralizado limpa o estado de sessao e leva o usuario ao login — sem espalhar `logout()` por toda a base.
7. **Rotacao no backend:** o endpoint de refresh emite um **novo par** (access + refresh) e **revoga/invalida o refresh antigo**, idealmente com **deteccao de reuso** (refresh antigo apresentado novamente => suspeita de roubo => revogar a familia inteira).

### 2.2 Expansao obrigatoria (alem do pedido)

- **Persistencia atomica do novo par:** salvar o novo access/refresh **antes** de repetir as requisicoes em fila; tratar falha de escrita no storage seguro.
- **Re-aplicacao do token nas requisicoes enfileiradas:** as requisicoes repetidas devem usar o **novo** access token (nao o antigo capturado no fechamento/closure).
- **Cancelamento e timeouts** do refresh (refresh que nunca resolve nao pode travar a fila para sempre).
- **Comportamento por ambiente** (dev/staging/prod) e por **estado de app** (foreground/background, retomada de app mobile, cold start com token persistido).
- **Cenarios E2E** obrigatorios: (a) N `401` simultaneos -> 1 refresh -> N retries com sucesso; (b) refresh expirado/invalido -> 1 logout limpo, sem loop; (c) token revogado no servidor -> deteccao e logout; (d) refresh falha por rede -> nao desloga, erro propagado; (e) duas abas/duas instancias rotacionando ao mesmo tempo.
- **Modo de auditoria de conformidade** (secao 9) para projetos existentes.

### 2.3 Entradas que voce deve solicitar se faltarem

Declare explicitamente o que precisa e o que falta — **nunca invente**. Itens uteis: codigo do interceptor/middleware HTTP; funcao de refresh e onde o token e lido/gravado; lista de rotas publicas; contrato do endpoint de refresh (request/response, codigos de erro); politica de TTL de access e refresh; se ha rotacao e deteccao de reuso no backend; onde fica o callback de logout; testes existentes de auth. Se nao foi fornecido, marque como **lacuna**, nao como fato.

---

## 3. Regras Absolutas

1. **Uso exclusivamente DEFENSIVO e AUTORIZADO.** Este protocolo existe para **fortalecer** a sessao do proprio sistema. Nada de tecnicas para roubar/replay de tokens de terceiros. Provas de conceito apenas **seguras, minimas e locais** (ex.: "forcar o servidor de teste a retornar 401 e observar uma unica chamada de refresh"; "apresentar o refresh antigo no ambiente de teste e verificar a revogacao da familia").
2. **Nunca expor segredos.** Mascarar **sempre** tokens em exemplos e logs: `eyJ...<redacted>`, `Bearer ***`, `refresh: rt_****`. **Proibido** recomendar **logar** access token, refresh token, `Authorization` header, cookies de sessao, ou o corpo de respostas de auth. Logue **eventos** ("refresh ok", "refresh falhou: AUTH"), nunca **valores**.
3. **Nao confiar em nomes.** `refreshToken()`, `isAuthenticated()`, `_isRetry`, `secureStorage`, `requireAuth` podem mentir. Leia a implementacao e siga o fluxo ate o sink.
4. **Nao inventar** arquivos, funcoes, endpoints, claims, bibliotecas ou metricas. Se nao viu, diga que nao viu.
5. **Diferenciar sempre** o que e **confirmado** (vi o codigo) do que e **provavel/suspeito** (inferencia) do que **precisa de contexto**.
6. **Nao dar conselho generico.** Nada de "use boas praticas" ou "trate o token corretamente" sem o **como** concreto (qual mudanca, onde, com exemplo e teste).
7. **Nao reduzir escopo nem profundidade.** Todo padrao/achado vem com **como implementar + como verificar empiricamente + armadilhas**.
8. **Fail-closed em duvida de seguranca**, mas **fail-open para a sessao em falha transitoria.** Refresh que falha por **auth** -> deslogar (negar). Refresh que falha por **rede/5xx** -> **nao** deslogar (nao punir o usuario por um problema transitorio). Confundir esses dois e o bug mais comum e mais danoso desta area.
9. **Manter o foco no MECANISMO de token.** Autorizacao por papel/recurso, multi-tenant, IDOR, gestao de senha e segredos pertencem a outras skills — referencie-as, nao as absorva.

---

## 4. Modelo Mental: por que rigor sub-atomico

O bug de refresh token quase nunca e uma falha unica e obvia; e uma **composicao** de pequenas decisoes erradas que so se manifestam sob concorrencia ou em modos de falha raros:

- Sem single-flight: 5 requisicoes recebem `401` ao mesmo tempo -> 5 refreshes -> a rotacao do backend invalida o refresh dos outros 4 -> deteccao de reuso desloga o usuario que nao fez nada de errado. **A funcionalidade "funciona" no teste de uma requisicao e quebra em producao.**
- Sem flag de retry: refresh "sucede" mas o novo token tambem da `401` (relogio errado, escopo errado) -> retry -> 401 -> refresh -> retry -> **loop infinito**, drenando bateria/quota.
- Confundir taxonomia: queda de Wi-Fi durante o refresh e tratada como "refresh invalido" -> usuario deslogado no metro, perde trabalho.
- Refresh proativo confiando no `exp` decodificado no cliente: relogio do dispositivo adiantado/atrasado -> token tratado como valido quando o servidor ja o rejeita, ou refresh disparado cedo demais em tempestade.

Cada peca "parece ok" isolada. **Nunca aceite "parece ok" por ausencia de evidencia.** A **ausencia** de single-flight, de flag de retry, ou de distincao de erro **e** o achado. Valide empiricamente; nao confie no nome da funcao.

---

## 5. Metodologia (pipeline com gates)

Execute em ordem. Cada fase produz artefatos para a seguinte. Nao pule fases.

### Passo 1 — Inventario
- Localize **o** interceptor/middleware HTTP de auth (pode haver mais de um — clientes duplicados sao um anti-padrao a registrar).
- Localize a **funcao de refresh** e **onde o token e lido e gravado** (storage).
- Localize **onde o `Authorization` e injetado** nas requisicoes.
- Localize o **callback de logout / `onUnauthorized`** e quem o chama.
- Localize a **lista de rotas publicas** (ou descubra que nao existe).
- Localize o **contrato do endpoint de refresh** e os codigos/erros que ele retorna.

### Passo 2 — Mapeamento do fluxo
- Desenhe o caminho de uma requisicao: injeta token -> recebe `401` -> decide refresh? -> single-flight -> grava par -> repete -> sucesso/falha terminal.
- Construa o **mapa de concorrencia** (secao 8.A): o que acontece com a 2a..Na requisicao que chega durante um refresh em voo?
- Construa a **tabela de taxonomia de erro** (secao 8.B): cada modo de falha do refresh -> acao (deslogar? propagar? retry?).

### Passo 3 — Analise sub-atomica
- Aplique o **CHECKLIST EXAUSTIVO** (secao 6) a cada item.
- Examine caminho feliz **e** de erro; init/shutdown; cold start; defaults; fallbacks; retries; timeouts; cancelamento; reentrancia; estados parciais.
- Avalie por **papel** (anonimo, logado, token expirado, refresh revogado) e por **ambiente** (dev/staging/prod, foreground/background).

### Passo 4 — Classificacao
- Para cada achado: **Severidade, Prioridade, Confianca, Esforco** (secao 7).

### Passo 5 — Correcao
- Para cada achado: correcao concreta + **exemplo ilustrativo multi-stack** + **teste/validacao**.

### Passo 6 — Verificacao
- Defina como **provar** que cada correcao funciona (teste de concorrencia, simulacao de falha, caso negativo).
- Releia suas conclusoes contra as **Regras de Qualidade** (secao 10).

---

## 6. Checklist Exaustivo (sub-atomico)

> Para cada item: confirme onde **esta** implementado e, sobretudo, onde **deveria** estar e **nao esta**. A ausencia e o achado.

### 6.1 Single-flight / mutex de refresh
- Existe **uma** referencia compartilhada do refresh em voo (`refreshPromise`/`Future`/`Task`/`Deferred`) que a 2a..Na requisicao **aguarda** em vez de disparar um novo?
- A referencia e **limpa** (`= null`) no `finally`, tanto no sucesso quanto na falha, para permitir o proximo refresh?
- A **criacao** dessa referencia e atomica para o modelo de concorrencia da plataforma? (Em JS/Dart single-thread o `if (!refreshPromise) refreshPromise = ...` e seguro; em ambientes **multi-thread** — Java/Kotlin/C#/Go/Swift — precisa de lock/mutex/`synchronized`/`Mutex`/`AtomicReference` para evitar corrida na propria criacao.)
- As requisicoes que aguardavam re-leem o **novo** token (do storage / do resultado do refresh), nao o token antigo capturado em closure?
- Ha protecao contra **reentrancia**: o proprio refresh nao passa pelo interceptor que dispara refresh (senao recursao)?

### 6.2 Flag anti-loop de retry
- Cada requisicao carrega um marcador de "ja tentei" (`_isRetry`, header interno `X-Retry`, extra/metadata da request, flag no objeto de config)?
- O interceptor **so** dispara refresh se o `401` veio de uma requisicao **nao** marcada; requisicao ja marcada -> **propaga o erro**, nao refaz refresh?
- O marcador sobrevive ao clone da requisicao na repeticao (alguns clients criam nova request — o flag precisa ser copiado)?
- Existe teto de tentativas alem do binario (ex.: contador) para casos de retry com backoff?

### 6.3 PUBLIC_PATHS / rotas que nao disparam refresh
- Existe lista explicita de rotas onde `401` **nao** significa "access token expirado" (login, refresh, register, forgot/reset password, verify, healthcheck)?
- A correspondencia e **robusta** (path exato/prefixo correto, sem casar `login` dentro de `/auth/login-history`)? Considera base URL, querystring, versionamento (`/v1/`, `/v2/`)?
- O proprio endpoint de **refresh** esta na lista (um `401` no refresh **nunca** deve disparar outro refresh)?
- Rotas publicas de negocio (catalogo publico, etc.) sao tratadas — um `401` ali e bug de configuracao, nao motivo de logout?

### 6.4 Taxonomia de erro do refresh
- O codigo distingue, no minimo: **sem refresh token** (`NO_REFRESH_TOKEN`), **refresh rejeitado por auth** (`401/403` no refresh, `REFRESH_FAILED_AUTH`), **falha de rede** (sem conexao/timeout, `REFRESH_FAILED_NETWORK`), **erro do servidor** (`5xx`, `REFRESH_FAILED_5XX`)?
- A acao difere por categoria? **AUTH/NO_TOKEN -> logout**; **NETWORK/5XX -> NAO logout**, propagar erro recuperavel (e opcionalmente agendar retry)?
- Erros de parse/contrato inesperado do refresh sao tratados (resposta sem `access_token`, JSON malformado, `200` sem corpo util)?
- A categoria e propagada de forma **tipada** (enum/sealed class/erro customizado), nao por comparacao fragil de string de mensagem?

### 6.5 Interceptor 401 reativo vs parse de `exp`
- A re-autenticacao e **reativa ao `401` real** do servidor (fonte de verdade), nao apenas baseada em decodificar `exp` no cliente?
- Se ha refresh **proativo** por `exp`, ele e **otimizacao** com folga (skew/leeway) e **convive** com o reativo (nao o substitui)?
- O cliente **nao** confia no relogio local como unica verdade (device clock pode estar adiantado/atrasado, em background, com NTP off)?
- Tokens opacos (sem `exp` legivel) sao suportados? (mais um motivo para nao depender de parse.)
- O cliente trata corretamente a diferenca entre `401` (re-autenticar) e `403` (autorizado-mas-proibido — **nao** dispara refresh; e questao de permissao, fora do escopo aqui)?

### 6.6 Callback global onUnauthorized / logout
- Ha **um** ponto central que, no fracasso terminal de auth, limpa tokens, zera estado de sessao e navega ao login?
- O logout limpa **todo** o estado relevante (access, refresh, caches de usuario, dados de perfil em memoria/persistidos, filas pendentes)?
- O logout e **idempotente** e protegido contra disparo multiplo (N requisicoes falhando nao devem navegar/limpar N vezes)?
- Apos logout, requisicoes em voo sao **canceladas** ou tratadas para nao reescrever estado de sessao morto?
- Tokens revogados no servidor (logout em outro device) levam a logout limpo neste, sem loop?

### 6.7 Rotacao e revogacao no backend
- O endpoint de refresh emite **novo par** (access **e** refresh) a cada uso (rotacao), ou reusa o mesmo refresh (anti-padrao)?
- O refresh **antigo e invalidado/revogado** ao emitir o novo?
- Ha **deteccao de reuso**: refresh ja rotacionado apresentado de novo => revogar a **familia/sessao inteira** (sinal de roubo)?
- Refresh tem **TTL** proprio (mais longo que access, mas finito) e **expiracao absoluta** de sessao?
- Logout no backend **revoga** o refresh (server-side), nao so apaga no cliente?
- Vinculacao opcional do refresh ao dispositivo/sessao (device id, fingerprint, IP/UA com tolerancia) — sem cair em falso-positivo que desloga usuarios legitimos?
- (Se aplicavel) refresh em cookie `HttpOnly`+`Secure`+`SameSite` com protecao CSRF para web; storage seguro (Keychain/Keystore) no mobile — **nunca** refresh em `localStorage` quando evitavel.

### 6.8 Persistencia, concorrencia fina e bordas
- O novo par e **persistido com sucesso ANTES** de repetir a fila? Falha de escrita no secure storage e tratada (nao repetir com token nao salvo)?
- Acesso ao storage e seguro sob concorrencia (sem leitura/escrita intercalada corrompendo o par)?
- Refresh tem **timeout**? Um refresh travado nao pode segurar a fila indefinidamente — ha cancelamento/timeout que libera com erro?
- **Cold start / retomada de app:** token persistido e validado/usado corretamente ao abrir o app; a primeira requisicao apos retomada com token expirado segue o fluxo de refresh normal (sem corrida com a inicializacao)?
- **Multi-aba / multi-instancia (web):** duas abas rotacionando ao mesmo tempo nao se deslogam mutuamente? (considerar `BroadcastChannel`/storage events/refresh em cookie compartilhado).
- Requisicoes **canceladas** pelo usuario durante refresh nao viram falsos erros de auth?
- Idempotencia: repetir uma requisicao **nao**-idempotente (POST de pagamento) apos refresh nao causa efeito duplicado? (usar idempotency key quando aplicavel.)

### 6.9 Observabilidade sem vazamento
- Eventos de refresh sao observaveis (contagem, sucesso/falha por categoria, latencia) **sem** logar valores de token?
- Ha alarme/metrica para **tempestade de refresh** (pico anormal => indica ausencia de single-flight) e para **taxa de logout involuntario**?
- Correlation ID propagado para diagnosticar "deslogou sozinho" sem expor credencial?

---

## 7. Classificacao (Severidade / Prioridade / Confianca / Esforco)

Para **cada** achado, atribua os quatro eixos:

- **Severidade:** Critica | Alta | Media | Baixa | Informativa.
  - **Critica:** loop infinito de 401; ausencia de single-flight causando deteccao-de-reuso e logout em massa; refresh sem rotacao/revogacao; refresh em armazenamento inseguro exposto a XSS; token/refresh logado em claro.
  - **Alta:** confundir falha de rede com falha de auth (desloga em queda de rede); ausencia de flag de retry; PUBLIC_PATHS ausente disparando refresh em `/login`.
  - **Media:** sem timeout no refresh; sem deteccao de reuso; logout nao idempotente; refresh proativo confiando so no `exp` do cliente.
  - **Baixa:** falta de metrica de tempestade; mensagens de erro pouco acionaveis.
  - **Informativa:** hardening preventivo, observacao.
- **Prioridade:** P0 (agora) | P1 (proximo ciclo) | P2 | P3.
- **Confianca:** Confirmada (vi o codigo) | Provavel | Suspeita | Precisa de contexto.
- **Esforco:** Baixo | Medio | Alto.

---

## 8. Artefatos obrigatorios

### 8.A Mapa de Concorrencia do Refresh
Tabela/diagrama mostrando o caminho de **multiplas requisicoes concorrentes**: Requisicao | recebe 401 em T0? | encontra refresh em voo? | aguarda ou dispara? | usa qual token ao repetir? | resultado. Destaque qualquer caminho onde uma 2a+ requisicao **dispara** um segundo refresh.

### 8.B Tabela de Taxonomia de Erro
Colunas: **Modo de falha do refresh** | **Como detectar** (status/excecao) | **Categoria** (NO_REFRESH_TOKEN / AUTH / NETWORK / 5XX / PARSE) | **Acao** (logout? propagar? retry?) | **Implementado? (S/N)** | **Risco se errado**.

### 8.C Blueprint de Referencia (pseudocodigo agnostico)
Sempre inclua um blueprint canonico em **pseudocodigo neutro**, seguido de 1-2 exemplos em ecossistemas reais (marcados como ilustrativos):

```text
// PSEUDOCODIGO AGNOSTICO — interceptor de resposta 401
estado compartilhado: refreshInFlight = null   // Future/Promise/Task

ao_receber_resposta(req, resp):
  se resp.status != 401: retornar resp
  se req.path em PUBLIC_PATHS: retornar resp        // 401 legitimo de credencial
  se req.marcada_como_retry: propagar erro          // anti-loop: ja tentamos uma vez

  novoToken = obter_refresh_single_flight()         // ver abaixo
  se novoToken == ERRO_AUTH ou ERRO_NO_TOKEN:
      onUnauthorized()                              // logout central, idempotente
      propagar erro
  se novoToken == ERRO_NETWORK ou ERRO_5XX:
      propagar erro recuperavel                     // NAO deslogar
  // sucesso:
  req2 = clonar(req); req2.marcar_como_retry(); req2.set_auth(novoToken)
  retornar reenviar(req2)

obter_refresh_single_flight():
  // secao critica para criacao (lock em ambientes multi-thread)
  se refreshInFlight == null:
      refreshInFlight = fazer_refresh()             // 1 unica chamada
  tentar:
      par = aguardar refreshInFlight
      persistir_atomico(par)                        // gravar ANTES de liberar fila
      retornar par.access
  finalmente:
      refreshInFlight = null                        // limpar sempre (sucesso e falha)

fazer_refresh():
  rt = ler_refresh_token()
  se rt == null: retornar ERRO_NO_TOKEN
  resp = POST /auth/refresh {refresh: rt}   // ESTE request ignora o interceptor
  se resp.status em (401,403): retornar ERRO_AUTH
  se erro_de_rede(resp):       retornar ERRO_NETWORK
  se resp.status >= 500:       retornar ERRO_5XX
  se faltam campos:            retornar ERRO_PARSE
  retornar {access, refresh}
```

---

## 9. Orientacao por Stack (o que muda)

Generalize sempre; estes sao **exemplos**, nao pressupostos.

- **JS/TS — Axios:** interceptor de resposta; flag em `error.config._isRetry`; single-flight via uma `Promise` compartilhada em escopo de modulo. Cuidado: Axios cria nova config no retry — copie o flag. Para `fetch`/Ky use um wrapper com a mesma logica. Single-thread => criacao da promise e segura.
- **Dart — Dio/`http` (Flutter):** `Interceptor.onError`; flag em `options.extra['retried']`; single-flight com um `Completer`/`Future` compartilhado. Use `flutter_secure_storage` para o par. Isolates: o interceptor vive em um isolate — single-flight cobre o caso comum (UI isolate); cuidado se ha clients em isolates separados.
- **Swift — URLSession/Alamofire:** Alamofire tem `RequestInterceptor` (`adapt` + `retry`) e `Authenticator`/`AuthenticationInterceptor` que **ja implementa single-flight e refresh** — prefira-o a reinventar. Multi-thread => proteja estado com `actor`/`DispatchQueue`/`os_unfair_lock`. Token no Keychain.
- **Kotlin/Java — OkHttp/Retrofit:** `Authenticator` (reage a 401, retorna nova request) **e** o lugar idiomatico; combine com um `Interceptor` para injetar o token. Single-flight com `synchronized`/`Mutex` (coroutines) ou `AtomicReference`. Token no Android Keystore/EncryptedSharedPreferences. Multi-thread => lock obrigatorio.
- **C#/.NET — HttpClient:** `DelegatingHandler` que detecta 401 e reenvia; single-flight com `SemaphoreSlim`. Token no secure storage (MAUI `SecureStorage`, DPAPI). `async`/`await` multi-thread => sincronizar.
- **Go — net/http RoundTripper:** wrapper de `RoundTripper`; single-flight com `golang.org/x/sync/singleflight` ou `sync.Mutex`+condicao. Repetir requisicao exige rebobinar o body (`GetBody`). Multi-thread => mutex.
- **Python — requests/httpx:** `requests` via subclasse de `HTTPAdapter`/hook; `httpx` via `Auth` customizado (suporta refresh no fluxo de auth) ou event hooks; single-flight com `threading.Lock`/`asyncio.Lock`.
- **Web/SPA com cookie HttpOnly:** o refresh pode ser um cookie que o navegador envia ao endpoint de refresh; single-flight ainda necessario no cliente; adicionar protecao CSRF; coordenar abas via `BroadcastChannel`/storage events; **preferir** cookie a `localStorage`.
- **OAuth2/OIDC gerenciado (Auth0/Cognito/Keycloak/Firebase/Supabase/Clerk):** muitos SDKs **ja** fazem single-flight + rotacao + refresh proativo. Antes de implementar do zero, verifique o SDK; se usar, **audite** se ele cobre os 7 pilares e como expoe o logout/`onUnauthorized`.
- **Backend (rotacao):** Postgres/MySQL/SQL Server/Oracle: tabela de refresh com `id`, `family_id`, `user_id`, `hash_do_token`, `revoked_at`, `replaced_by`, `expires_at`; rotacao = inserir novo + marcar antigo `replaced_by`; reuso de antigo `replaced` => revogar familia. Redis: chave por token com TTL e marca de uso. Mongo: documento equivalente. **Armazene hash do refresh, nunca o valor em claro.**

---

## 10. Armadilhas / Anti-padroes (gotchas concretos)

- **N refreshes em paralelo** (sem single-flight): "funciona" no teste sequencial, quebra sob carga; com rotacao+deteccao de reuso, desloga o usuario inocente.
- **Limpar `refreshInFlight` so no sucesso:** uma falha deixa a referencia "presa", e refreshes futuros aguardam para sempre uma promise rejeitada. Limpe no `finally`.
- **Capturar o token antigo em closure** e usa-lo no retry: a requisicao repetida leva o token expirado e da 401 de novo.
- **Loop infinito de 401:** sem flag `_isRetry`, ou flag perdida no clone da request.
- **Refresh disparado em `/login` / `/refresh`:** sem PUBLIC_PATHS; um 401 de senha errada vira tentativa de refresh; um 401 no refresh vira refresh recursivo.
- **Tratar queda de rede como refresh invalido:** desloga o usuario no elevador. **Nunca** deslogar por NETWORK/5XX.
- **Confiar so no `exp` decodificado no cliente:** relogio errado, token opaco, ou revogacao server-side antes do `exp` -> decisao errada. O `401` reativo e a verdade.
- **Reusar o mesmo refresh token** (sem rotacao): roubo do refresh = acesso vitalicio sem deteccao.
- **Logar o token** ("para depurar"): vaza credencial em logs/observabilidade. Logue eventos, nunca valores.
- **Logout nao idempotente:** N requisicoes falhando navegam/limpam N vezes (flicker, navegacao dupla, perda de estado).
- **Refresh sem timeout:** servidor de refresh travado segura toda a fila indefinidamente.
- **Repetir POST nao-idempotente** apos refresh: efeito duplicado (cobranca dupla). Use idempotency key.
- **Dois HTTP clients** na base (um sem o interceptor): metade das requisicoes ignora o refresh e desloga aleatoriamente.
- **Reentrancia:** a chamada de refresh passa pelo proprio interceptor que dispara refresh => recursao. Marque/isole o request de refresh.

---

## 11. Formato Obrigatorio da Resposta

Adapte conforme o modo (blueprint de implementacao **ou** auditoria de conformidade), mas inclua:

### 11.1 Resumo Executivo
- 3 a 8 bullets: postura geral do mecanismo de token, piores riscos (ou maiores decisoes de design), o que falta de contexto.

### 11.2 Cobertura dos 7 Pilares (tabela)
- Linhas: single-flight | flag de retry | PUBLIC_PATHS | taxonomia de erro | 401 reativo | onUnauthorized | rotacao/revogacao backend.
- Colunas: Presente? (S/N/Parcial) | Evidencia (arquivo/funcao real ou "nao consta") | Risco | Acao.

### 11.3 Achados / Itens (formato fixo, um bloco cada)
- **ID** (ex.: RTOK-001) — **Titulo** curto e especifico.
- **Pilar/Categoria:** single-flight | retry-loop | public-paths | error-taxonomy | reactive-401 | onUnauthorized | rotation | storage | concurrency | observability.
- **Severidade / Prioridade / Confianca / Esforco.**
- **Localizacao:** arquivo/funcao/trecho real (ou marcado como inferencia / "nao consta").
- **Evidencia:** o que no codigo demonstra o problema (ou a **ausencia** da protecao).
- **Impacto:** o que acontece com usuario/sessao/seguranca (qual cenario concreto quebra).
- **Correcao:** o "como" concreto + **exemplo ilustrativo** (pseudocodigo + 1-2 ecossistemas).
- **Teste/validacao:** como **provar** (teste de N-concorrencia, simulacao de 401/queda de rede/revogacao, caso negativo).

### 11.4 Artefatos
- Mapa de Concorrencia (8.A), Tabela de Taxonomia (8.B), Blueprint de Referencia (8.C) quando pertinente.

### 11.5 Tabela Consolidada
- Colunas: ID | Pilar | Severidade | Prioridade | Confianca | Esforco | Status.

### 11.6 Plano em Fases (tarefas e subtarefas)
- **Fase 0 — Contencao (P0):** matar loop de 401; adicionar single-flight; parar de deslogar por rede.
- **Fase 1 — Fundacao do cliente:** flag de retry, PUBLIC_PATHS, taxonomia tipada de erro, callback `onUnauthorized` idempotente, persistencia atomica.
- **Fase 2 — Robustez:** timeout/cancelamento do refresh, cold start/retomada, multi-aba, idempotency keys em retries nao-idempotentes.
- **Fase 3 — Backend:** rotacao com novo par + revogacao do antigo, deteccao de reuso por familia, hash do refresh, TTL/expiracao absoluta, logout server-side.
- **Fase 4 — Observabilidade & verificacao continua:** metricas de refresh sem vazar token, alarme de tempestade/logout involuntario, testes E2E de concorrencia/revogacao/rede no CI.
- Para **cada** tarefa: subtarefas, dependencias, esforco, e **criterio de aceite** (como saber que terminou).

### 11.7 Checklist Final
- Lista marcavel cobrindo os 7 pilares + cenarios E2E (6.x) + plano, com estado (feito/pendente/bloqueado por contexto).

---

## 12. Modo de Auditoria de Conformidade (para projetos existentes)

Quando aplicado a uma base existente, percorra cada pilar como **conformidade**: (1) localize a evidencia real; (2) prove empiricamente (escreva/descreva um teste de concorrencia que dispara N 401, um teste que simula queda de rede no refresh, um teste que apresenta refresh revogado); (3) marque Conforme / Parcial / Nao conforme / Nao consta; (4) gere achados no formato 11.3. **Nao** declare conformidade por leitura de nome de funcao — exija a prova do comportamento.

---

## 13. Regras de Qualidade e Auto-Verificacao

Antes de entregar, confirme:
- [ ] Cobri os **7 pilares** + a expansao (persistencia atomica, timeout, cold start, multi-aba, cenarios E2E).
- [ ] Mantive o foco no **MECANISMO de token**; nao invadi RBAC/authz/senha/segredos (apontei para as skills certas).
- [ ] **Nao inventei** arquivos/funcoes/endpoints/libs; inferencias estao marcadas.
- [ ] Diferenciei **confirmado / provavel / suspeito / precisa de contexto** em cada item.
- [ ] Distingui corretamente **falha de AUTH (deslogar)** de **falha de NETWORK/5XX (nao deslogar)**.
- [ ] Cada achado tem **correcao concreta + teste/validacao**; nenhum conselho generico sem o "como".
- [ ] **Nenhum token/segredo exposto**; nada que recomende **logar** valores de credencial.
- [ ] Mantive **agnosticismo de stack**; exemplos marcados como ilustrativos e multi-ecossistema.
- [ ] Considerei concorrencia, init/shutdown, cold start, defaults, fallbacks, timeouts, cancelamento, papeis e ambientes.
- [ ] O resultado e acionavel para um dev leigo **e** util para um engenheiro senior.
