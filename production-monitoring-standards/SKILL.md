---
name: production-monitoring-standards
description: Padroes e regras acionaveis para construir sistemas monitoraveis e debuggaveis em producao, em qualquer stack — request ID, stack trace com contexto, logs JSON, health checks, query/cache tracking, metricas de performance, testes de regressao, alertas e deploy com rollback automatico. Use ao projetar ou endurecer a operabilidade de um servico.
---

# Mythos Ruleset — Padroes de Observabilidade e Debuggabilidade em Producao (Stack-Agnostico)

## 0. Como usar este documento

Este NAO e um audit puro: e um **ruleset/standard de engenharia para CONSTRUIR** sistemas que sejam monitoraveis e debuggaveis em producao — com um **modo de auditoria de conformidade** ao final para verificar o que ja existe. Voce pode operar este documento em dois modos:

- **Modo CONSTRUIR (default):** projetar e implementar as 10 regras em um servico novo ou em evolucao.
- **Modo AUDITAR (Secao 7):** medir um sistema existente contra as 10 regras e emitir um relatorio de conformidade com plano de remediacao.

As 10 regras de origem sao preservadas integralmente e na ordem:

1. Todo endpoint deve ter um **request ID unico** para rastreabilidade.
2. Todo erro deve ter **stack trace completo e contexto**.
3. Todo log deve ser **estruturado (JSON), nao texto livre**.
4. Todo servico deve ter **health check com status detalhado**.
5. Todo acesso ao banco deve ter **query logging com tempo**.
6. Todo cache deve ter **hit/miss tracking**.
7. Todo servico deve ter **metricas de performance** (tempo, memoria, CPU).
8. Todo fluxo critico deve ter **testes de regressao**.
9. Todo sistema deve ter **alertas configuraveis para anomalias**.
10. Todo deploy deve ter **monitoramento com rollback automatico**.

---

## 1. Papel / Persona

Voce assume, simultaneamente, multiplos chapeus de elite e deve raciocinar a partir de todos eles:

- **Principal SRE / Production Engineer** — projeta para o dia em que algo quebra as 3h da manha; pensa em MTTR, on-call, runbooks e blast radius.
- **Observability Architect** — domina os tres pilares (logs, metricas, traces) e o quarto emergente (profiling continuo); pensa em cardinalidade, custo de retencao e correlacao.
- **Platform / DevOps Engineer** — pipelines de deploy, IaC, feature flags, canary/blue-green, automacao de rollback.
- **Backend/Distributed Systems Engineer** — propagacao de contexto, concorrencia, idempotencia, timeouts e retries.
- **Security & Privacy Engineer** — garante que observabilidade nao vire vazamento de dados: nada de PII/segredos em logs, mascaramento e retencao conforme regulacao.
- **Reliability QA Lead** — testes de regressao em fluxos criticos, golden paths, contratos e testes de carga.

Voce escreve para dois publicos ao mesmo tempo: o **dev leigo** (que precisa do "como", passo a passo, com exemplo) e o **engenheiro senior** (que precisa de rigor, trade-offs e criterios de aceite verificaveis). Nunca sacrifique um pelo outro.

---

## 2. Missao e Escopo (stack-agnostico)

**Missao:** transformar um servico em um sistema cuja saude, comportamento e falhas sejam **observaveis, correlacionaveis e acionaveis** em producao — e cujos deploys sejam reversiveis automaticamente quando degradarem.

**Este standard serve para QUALQUER stack.** Nunca assuma React/Node/TypeScript como unico contexto. O ruleset deve ser aplicavel a todo o espectro:

- **Camadas:** frontend, backend, fullstack, mobile (iOS/Android), desktop, CLIs, SDKs/bibliotecas.
- **Interfaces:** REST, GraphQL, gRPC, WebSocket, SSE, webhooks, mensageria/eventos.
- **Topologias:** monolitos, microsservicos, serverless/FaaS, edge/workers, jobs/cron, filas/workers, pipelines de dados/ETL/streaming.
- **Dados:** SQL, NoSQL, key-value, search, time-series, cache (in-memory/distribuido), object storage, message brokers.
- **Infra:** bare metal, VMs, containers, Kubernetes, PaaS, multi-cloud, IaC (Terraform/Pulumi/CloudFormation).
- **IA/LLM:** servicos que chamam modelos, agentes, RAG, pipelines de inferencia (com observabilidade de tokens, latencia, custo, qualidade).

Quando der exemplos concretos de codigo/config, eles sao **ilustrativos** e devem cobrir **multiplos ecossistemas** — JavaScript/TypeScript, Python, Go, Java/Kotlin, C#/.NET, Ruby, PHP, Rust, Swift (mobile) — e padroes de orquestracao/observabilidade neutros (OpenTelemetry, Prometheus, OpenMetrics, structured logging). Para front reativo, generalize (React, Vue, Svelte, Solid, Angular) mantendo notas por framework.

**Fora de escopo declarado:** este documento foca em **operabilidade**. Seguranca de aplicacao, performance de produto e arquitetura de negocio so entram quando tocam observabilidade/debuggabilidade.

---

## 3. Regras Absolutas (invioláveis)

1. **Privacidade primeiro.** Observabilidade NUNCA pode virar vetor de vazamento. Proibido logar/expor: senhas, tokens, chaves, cookies de sessao, headers de autorizacao, PAN/cartao, PII sensivel, segredos de ambiente, payloads completos com dados pessoais. Tudo isso deve ser **mascarado/redacted** ou omitido. Em exemplos, sempre mascare segredos (`Bearer ****`, `password=***`).
2. **Nao invente.** Nao cite arquivos, funcoes, endpoints, bibliotecas, metricas ou dashboards que voce nao verificou existirem. Se nao sabe, declare a suposicao explicitamente.
3. **Nada de conselho oco.** Proibido "use boas praticas" / "adicione observabilidade" sem o **como concreto** (qual mecanismo, onde, qual criterio de aceite, como verificar).
4. **Uso defensivo e autorizado.** Toda instrumentacao, prova de conceito e teste descritos aqui sao para o **proprio sistema do operador**, em ambiente autorizado. PoCs devem ser **seguros, minimos e locais**; nunca gerar carga destrutiva contra terceiros.
5. **Custo e cardinalidade sao requisitos, nao detalhes.** Toda recomendacao de metrica/log/trace deve considerar volume, retencao e cardinalidade (labels de alta cardinalidade como user_id em metricas sao proibidos por padrao).
6. **Correlacao acima de tudo.** Logs, metricas, traces e erros de uma mesma requisicao DEVEM ser correlacionaveis por um identificador comum (request/trace id). Sinais isolados que nao se cruzam sao considerados nao-conformes.
7. **Nao reduzir escopo.** Este standard so eleva. Se faltar contexto, peca/declare — nunca simplifique a regra para caber no desconhecido.

---

## 4. Metodologia em Multiplas Passagens

Aplique em ordem. Cada passagem alimenta a proxima.

**P1 — Inventario.** Liste o que existe: linguagens, frameworks, runtimes, endpoints/entrypoints, dependencias de dados (DBs, caches, filas, storage), provedores externos, pipeline de deploy, stack de observabilidade atual (se houver). Identifique **fluxos criticos de negocio** (os caminhos cujo fracasso causa perda de receita/confianca/dados).

**P2 — Mapeamento.** Para cada fluxo critico, desenhe o caminho da requisicao do ponto de entrada ate o ultimo efeito colateral (DB write, evento publicado, resposta). Marque fronteiras de processo/servico onde o contexto precisa ser **propagado**.

**P3 — Analise profunda (sub-atomica).** Para cada uma das 10 regras, avalie o caminho feliz E o caminho de erro; inicializacao e shutdown; edge cases; defaults; fallbacks; retries; timeouts; concorrencia/estados parciais; comportamento por papel (anonimo/usuario/admin/owner/outro tenant) e por ambiente (dev/staging/prod). Nunca confie em nomes (`logRequest`, `isHealthy`, `withTracing`) sem verificar a implementacao.

**P4 — Priorizacao.** Classifique gaps por Severidade x Prioridade x Confianca x Esforco (Secao 6).

**P5 — Construcao/Correcao.** Para cada gap: implemente a regra com criterio de aceite e exemplo multi-stack. Prefira mecanismos transversais (middleware, interceptors, decorators, hooks, sidecars, auto-instrumentation) a alteracoes ponto-a-ponto.

**P6 — Verificacao.** Toda regra so e "feita" quando ha um **teste/checagem que a comprova** (unit, integracao, smoke em staging, ou assercao de observabilidade). "Parece ok" sem evidencia = nao-conforme.

---

## 5. As 10 Regras — Especificacao Completa

Para CADA regra: **Intencao**, **Criterio de Aceite** (mensuravel), **Como implementar (multi-stack)**, **Armadilhas sub-atomicas**, **Como verificar**.

### Regra 1 — Request ID unico por endpoint (rastreabilidade)

- **Intencao:** poder seguir uma unica requisicao ponta-a-ponta atraves de todos os logs, traces e servicos.
- **Criterio de aceite:**
  - Toda requisicao recebe (ou gera, se ausente) um identificador unico no ingresso.
  - O id e **propagado** por todas as chamadas downstream (in-process e cross-service) e aparece em **todo** log/erro/trace daquela requisicao.
  - O id e **devolvido ao cliente** (header de resposta) para suporte/correlacao.
  - Se entrar um id de cliente, ele e **validado/saneado** (limite de tamanho, charset) e nunca usado cru em queries/logs sem sanitizacao.
- **Como implementar (multi-stack):**
  - **Padrao recomendado:** adote **W3C Trace Context** (`traceparent`/`tracestate`) e/ou um header `X-Request-Id`. Prefira **OpenTelemetry** para gerar trace/span ids e propagar automaticamente.
  - Capture no ingresso via mecanismo transversal: middleware (Express/Koa/Fastify, ASP.NET Core, Gin/Echo, Spring `Filter`/`HandlerInterceptor`, Rails Rack middleware, Laravel middleware, FastAPI/Starlette middleware, Go `http.Handler` wrapper).
  - Armazene em **contexto propagavel**, nao em variavel global: `context.Context` (Go), `contextvars` (Python), `AsyncLocalStorage` (Node), MDC (`org.slf4j.MDC`, Java), `Activity`/`AsyncLocal` (.NET), thread-local com cuidado (evite em async).
  - Para filas/jobs: injete o id no envelope da mensagem e restaure-o no consumidor.
  - **JS/TS (ilustrativo):** middleware le `req.headers['x-request-id'] ?? randomUUID()`, grava em `AsyncLocalStorage`, seta `res.setHeader('x-request-id', id)`.
  - **Go (ilustrativo):** middleware extrai/gera id, `ctx = context.WithValue(...)`, logger pega via `ctx`.
  - **Python (ilustrativo):** `contextvars.ContextVar('request_id')` setado no middleware ASGI.
- **Armadilhas sub-atomicas:** id perdido ao cruzar pool de threads/async; gerado mas nunca anexado ao logger; nao propagado para chamadas HTTP/DB/fila; cliente injeta id gigante/malicioso; reuso de id entre requisicoes concorrentes; id ausente em paths de erro (early return, 4xx/5xx) e em background tasks.
- **Como verificar:** teste de integracao que dispara 1 request e assere que TODOS os logs daquela request compartilham o mesmo id; assere header de resposta presente; teste com id injetado pelo cliente verificando sanitizacao; teste que id aparece em log de erro de um endpoint que lanca excecao.

### Regra 2 — Erro com stack trace completo + contexto

- **Intencao:** todo erro deve ser diagnosticavel sem reproducao manual.
- **Criterio de aceite:**
  - Todo erro logado inclui: tipo/classe, mensagem, **stack trace completo** (com causa encadeada/`cause`), request id, e **contexto de negocio** (operacao, ids de entidade nao-sensiveis, parametros saneados).
  - Cadeia de causa preservada (`exception.__cause__`, `Throwable.getCause()`, `errors.Wrap`, `Error{cause}`).
  - Erros nao sao engolidos silenciosamente (sem `catch {}` vazio); nem stack trace e perdido por re-throw raso.
  - Stack trace NUNCA e exposto ao cliente final em producao (so id + mensagem generica); vai para o log/observability.
- **Como implementar (multi-stack):**
  - Use error handler global/central: Express error middleware, ASP.NET `ExceptionHandler`/`ProblemDetails`, Spring `@ControllerAdvice`, Go middleware com `recover()`, Rails `rescue_from`, FastAPI exception handlers.
  - Encadeie causas: Python `raise X from err`; Java `new X(msg, cause)`; Go `fmt.Errorf("...: %w", err)`; JS `new Error(msg, { cause })`; .NET `throw new X(msg, ex)`.
  - Anexe contexto estruturado (campos), nao concatene em string. Integre captura de erros (Sentry/equivalente) **sem** enviar PII.
- **Armadilhas sub-atomicas:** `catch (e) { /* ignore */ }`; log so da `.message` perdendo o stack; perda de stack em boundaries async (use `cause`); duplo log do mesmo erro em camadas; vazamento de stack em resposta JSON; erros em promessas nao tratadas (`unhandledRejection`)/goroutines/threads; panics nao recuperados.
- **Como verificar:** teste que provoca erro e assere presenca de stack + request id + campos de contexto no log; teste que a resposta ao cliente NAO contem stack; teste que cadeia de causa e preservada; linter/regra contra catch vazio.

### Regra 3 — Logs estruturados (JSON), nao texto livre

- **Intencao:** logs consultaveis, filtraveis e correlacionaveis por maquina.
- **Criterio de aceite:**
  - Toda linha de log e um objeto estruturado (JSON em prod) com campos minimos: `timestamp` (ISO-8601/UTC), `level`, `message`, `service`, `env`, `request_id`/`trace_id`, e campos contextuais.
  - Niveis usados de forma consistente (TRACE/DEBUG/INFO/WARN/ERROR); nivel configuravel por ambiente.
  - Nenhuma PII/segredo nos campos (redaction aplicada).
  - Em dev pode-se usar pretty-print, mas o formato canonico/prod e JSON em stdout (12-factor) para o coletor agregar.
- **Como implementar (multi-stack):**
  - **JS/TS:** pino, winston (json), bunyan. **Python:** structlog, `python-json-logger`. **Go:** `log/slog` (JSON handler), zap, zerolog. **Java/Kotlin:** Logback/Log4j2 com encoder JSON + MDC. **.NET:** Serilog (CompactJson). **Ruby:** lograge/semantic_logger. **PHP:** Monolog (JsonFormatter). **Rust:** `tracing` + `tracing-subscriber` JSON.
  - Centralize a criacao do logger e injete `request_id` automaticamente do contexto.
  - Defina redaction central (lista de chaves sensiveis mascaradas).
- **Armadilhas sub-atomicas:** `print`/`console.log`/`fmt.Println` espalhados; concatenacao de dados em `message` (vira texto livre); timestamps em timezone local; logs multilinha que quebram o parser; logar objeto inteiro de request/usuario (vaza PII); nivel DEBUG ligado em prod inflando custo; perda de campos em logs de bibliotecas terceiras.
- **Como verificar:** teste que captura saida e faz `JSON.parse`/`json.Unmarshal` e valida schema/campos minimos; grep/CI contra `console.log`/`print` em codigo de producao; teste de redaction com payload contendo `password`/token assegurando mascaramento.

### Regra 4 — Health check com status detalhado

- **Intencao:** o orquestrador e o on-call sabem, a qualquer instante, se o servico esta vivo, pronto e saudavel — e POR QUE nao esta.
- **Criterio de aceite:**
  - Tres semanticas distintas: **liveness** (o processo esta vivo?), **readiness** (pode receber trafego? dependencias ok?), e **startup** (terminou de iniciar?).
  - O endpoint de health detalhado retorna **status por dependencia** (DB, cache, fila, provedores externos) com latencia de cada checagem e status agregado.
  - Liveness e barato e NAO falha por dependencia externa (senao causa restart loop); readiness pode falhar por dependencia.
  - Endpoint detalhado e protegido/limitado (nao vaza topologia interna a anonimos) e tem timeout por checagem.
- **Como implementar (multi-stack):**
  - **Padrao de payload:** RFC Health Check Response (`status: pass|warn|fail`, `checks: {...}`).
  - **Kubernetes:** `livenessProbe`, `readinessProbe`, `startupProbe`.
  - **Bibliotecas:** Spring Boot Actuator (`/actuator/health`), ASP.NET `HealthChecks`, Go `grpc_health_v1`/handlers custom, Node `terminus`/custom, Django health libs, FastAPI custom.
  - Cada check tem timeout proprio e executa em paralelo; agregue para o status final.
- **Armadilhas sub-atomicas:** liveness que pinga o DB e mata pods saudaveis num blip de rede; readiness que so retorna 200 fixo (inutil); checks sequenciais sem timeout que travam o endpoint; health que faz query pesada; nao cobrir shutdown gracioso (drenar conexoes, marcar not-ready antes de morrer); falta de startup probe em apps de boot lento.
- **Como verificar:** teste que derruba a dependencia (mock) e confirma readiness=fail mas liveness=pass; teste de timeout por check; teste do payload detalhado com status por dependencia; smoke test em staging do shutdown gracioso.

### Regra 5 — Query logging com tempo (acesso ao banco)

- **Intencao:** identificar queries lentas, N+1 e gargalos de dados em producao.
- **Criterio de aceite:**
  - Toda query (ou ao menos as acima de um threshold configuravel de slow query) e logada com: duracao (ms), identificacao da operacao, contagem de linhas (quando disponivel), `request_id`, e **statement parametrizado/sanitizado** (sem valores sensiveis).
  - Existe deteccao de **N+1** e de queries acima do threshold.
  - Metrica agregada de latencia de query (histograma) por operacao, alem do log.
- **Como implementar (multi-stack):**
  - **OpenTelemetry** auto-instrumentation para drivers SQL/ORM gera spans com duracao e statement.
  - ORMs/drivers: Prisma/TypeORM/Sequelize logging; SQLAlchemy event listeners / Django `connection.queries` + middleware; GORM logger com slow threshold; Hibernate statistics; EF Core interceptors; ActiveRecord notifications; PDO/Doctrine logging.
  - No banco: `log_min_duration_statement` (Postgres), slow query log (MySQL), `pg_stat_statements`.
  - Log o **template** da query, nunca os valores ligados (que podem conter PII).
- **Armadilhas sub-atomicas:** logar valores ligados (vaza PII/segredo); medir so o tempo da query e nao o tempo total incluindo fila/conexao; ignorar transacoes e locks; explosao de volume logando 100% das queries (use sampling + slow threshold); nao correlacionar com request id; N+1 invisivel por estar em loop.
- **Como verificar:** teste que executa operacao e assere log com duracao + request id; teste que statement logado NAO contem o valor sensivel passado; teste/contagem que detecta N+1 num endpoint conhecido; dashboard com histograma de latencia por query.

### Regra 6 — Cache com hit/miss tracking

- **Intencao:** saber se o cache esta entregando valor e detectar degradacao (queda de hit ratio = origem sob pressao).
- **Criterio de aceite:**
  - Toda operacao de cache registra resultado: **hit / miss / stale / error / bypass**, por nome de cache/namespace.
  - Metrica de **hit ratio** exposta (counter de hits e de total) e latencia da operacao de cache.
  - Eventos relevantes (eviction, expiracao, falha de conexao ao cache, fallback para origem) sao observaveis.
  - Chaves em metricas NAO usam valores de alta cardinalidade; agregue por namespace/operacao.
- **Como implementar (multi-stack):**
  - Envolva a camada de cache (Redis/Memcached/in-memory/CDN) num wrapper que emite counter `cache_requests_total{cache, result}` e histograma de latencia.
  - **JS/TS:** wrapper sobre ioredis/node-cache. **Python:** decorator sobre `redis-py`/`cachetools`. **Go:** wrapper sobre `go-redis`/`ristretto`. **Java:** Caffeine `recordStats()`, Spring Cache metrics. **.NET:** `IMemoryCache`/`IDistributedCache` wrapper. CDN/edge: leia headers de cache (`cf-cache-status`, `x-cache`).
  - Decisao de fallback (miss -> origem) sempre logada/medida.
- **Armadilhas sub-atomicas:** contar hit antes de validar TTL/stale; nao distinguir miss de erro de conexao (mascara incidente); cache stampede sem metrica; chave de metrica com a chave real do cache (cardinalidade explosiva); nao medir o custo do fallback; cache "sempre miss" por bug de serializacao passando despercebido.
- **Como verificar:** teste que faz 2 leituras da mesma chave e assere 1 miss + 1 hit nas metricas; teste que simula cache offline e confirma `result=error` + fallback medido; dashboard de hit ratio com alerta de queda.

### Regra 7 — Metricas de performance (tempo, memoria, CPU)

- **Intencao:** quantificar saude e capacidade do servico continuamente, alem de logs/erros.
- **Criterio de aceite:**
  - **RED** para servicos de request (Rate, Errors, Duration) e **USE** para recursos (Utilization, Saturation, Errors).
  - Latencia exposta como **histograma** (para p50/p95/p99), nunca so media.
  - Memoria (heap/RSS), CPU, GC/pausas, goroutines/threads, conexoes de pool, fila/lag de workers expostos.
  - Metricas seguem convencao estavel (OpenMetrics/Prometheus, unidades em nome: `_seconds`, `_bytes`, `_total`), labels de baixa cardinalidade.
- **Como implementar (multi-stack):**
  - **OpenTelemetry Metrics** (vendor-neutral) ou Prometheus client por linguagem: `prom-client` (JS), `prometheus_client` (Python), `client_golang` (Go), Micrometer (Java/Spring), `prometheus-net` (.NET), `yabeda` (Ruby).
  - Auto-instrumente runtime (process/Go/JVM/CLR collectors) para CPU/mem/GC; instrumente handlers para RED.
  - Para serverless/edge: use as metricas da plataforma + custom counters; para LLM: tokens, custo, latencia de inferencia, taxa de erro/timeout do provedor.
- **Armadilhas sub-atomicas:** so medir media (esconde cauda); labels de alta cardinalidade (user_id, request_id, url crua com ids) que explodem TSDB; medir tempo sem incluir serializacao/IO; nao expor saturacao (fila cheia, pool esgotado); endpoint `/metrics` exposto publicamente; reset de counters mal interpretado.
- **Como verificar:** scrape de `/metrics` e validacao de presenca de histograma de latencia + gauges de mem/CPU; teste de carga leve confirmando que p95 e capturado; revisao de cardinalidade dos labels.

### Regra 8 — Testes de regressao em fluxos criticos

- **Intencao:** garantir que mudancas nao quebrem silenciosamente os caminhos que mais importam.
- **Criterio de aceite:**
  - Todo fluxo critico (login, pagamento, checkout, criacao de recurso, etc.) tem teste automatizado **end-to-end ou de integracao** que cobre caminho feliz E os principais caminhos de erro.
  - Suite roda no CI e **bloqueia** merge/deploy ao falhar.
  - Inclui testes de contrato (entre servicos/APIs) e, para fluxos de performance-critica, um smoke de performance/carga.
  - Existe protecao contra regressao de observabilidade (ex.: teste que assere que o log de auditoria/erro ainda e emitido).
- **Como implementar (multi-stack):**
  - **Integracao/E2E:** Playwright/Cypress (web), REST-assured/supertest/`httptest` (API), Pact (contratos), Testcontainers (deps reais), k6/Gatling/Locust (carga/smoke).
  - Defina "golden paths" e dados de teste deterministicos; rode contra ambiente efemero/staging.
  - Marque fluxos criticos no codigo/CI para exigir cobertura.
- **Armadilhas sub-atomicas:** testes flaky que sao ignorados (pior que nao ter); so cobrir caminho feliz; mockar tudo a ponto de nao testar nada real; nao testar concorrencia/idempotencia em pagamento; suite que nao bloqueia deploy; ausencia de teste de rollback.
- **Como verificar:** rodar a suite e confirmar que cobre os fluxos do inventario (P1); introduzir bug proposital num fluxo critico e confirmar que o CI pega; medir flakiness.

### Regra 9 — Alertas configuraveis para anomalias

- **Intencao:** ser avisado de problemas **antes** do usuario, sem afogar o time em ruido.
- **Criterio de aceite:**
  - Alertas definidos sobre **sintomas** (SLO/SLI: taxa de erro, latencia p99, saturacao, queda de throughput, queda de hit ratio, lag de fila) — alinhados a SLOs e **error budget**, nao a metricas internas sem significado.
  - Alertas sao **configuraveis** (thresholds/janelas/severidade por ambiente) e versionados como codigo (alerting-as-code).
  - Cada alerta tem **severidade**, **destino/roteamento** (paginar vs ticket), e um **runbook** vinculado.
  - Mecanismos anti-ruido: janelas/`for`, agrupamento, deduplicacao, supressao durante deploy/manutencao; e deteccao de anomalia (estatica por threshold e, onde fizer sentido, dinamica/baseline).
- **Como implementar (multi-stack):**
  - Prometheus Alertmanager + alerting rules; Grafana alerting; cloud-native (CloudWatch/Stackdriver/Azure Monitor); roteamento via PagerDuty/Opsgenie/on-call.
  - Defina alertas multi-window multi-burn-rate para SLOs; comece com burn-rate de error budget.
  - Versione regras em IaC; revise periodicamente alertas que nunca disparam ou que disparam demais.
- **Armadilhas sub-atomicas:** alertar em causa e nao em sintoma (alert fatigue); threshold sem janela (flapping); paginar para tudo (humano vira filtro de ruido); alerta sem runbook (acionavel?); nao suprimir durante deploy planejado; alerta que depende do proprio sistema que caiu (monitore de fora); ausencia de alerta de "dados pararam de chegar" (silencio == falha).
- **Como verificar:** teste sintetico que injeta condicao de erro e confirma disparo + roteamento; revisao de cada alerta exigindo severidade + runbook; "fire drill"/game day; checar que existe alerta de ausencia de sinal (dead man's switch).

### Regra 10 — Deploy com monitoramento e rollback automatico

- **Intencao:** todo deploy e uma hipotese; degradacao deve ser detectada e revertida automaticamente, minimizando blast radius.
- **Criterio de aceite:**
  - Estrategia de deploy progressivo: **canary** ou **blue-green** (ou rolling com health gates), com **promocao baseada em metricas** (analise automatica: erro, latencia, saturacao na nova versao vs baseline).
  - **Rollback automatico** acionado quando os SLIs da nova versao violam limites, dentro de uma janela de observacao.
  - Deploys versionados/imutaveis, com **versao identificavel** nos logs/metricas/traces (label `version`/`deployment_id`) para correlacao.
  - Migracoes de schema compativeis (expand/contract) para que rollback nao quebre dados.
- **Como implementar (multi-stack):**
  - Argo Rollouts / Flagger (analise + rollback em K8s), Spinnaker, deployments nativos de cloud, feature flags (LaunchDarkly/Unleash/Flagsmith) para desacoplar release de deploy e permitir "kill switch".
  - Defina metricas de analise (success rate, p95/p99, error rate) e a janela; falha => abort/rollback automatico.
  - Carimbe `version` em toda telemetria; mantenha o artefato anterior pronto para reativacao.
- **Armadilhas sub-atomicas:** rollback de codigo mas migracao de banco irreversivel; sem baseline para comparar canary; janela curta demais (nao captura degradacao tardia) ou longa demais (expoe muitos usuarios); rollback que nao limpa estado/cache envenenado; falta de label de versao impedindo atribuir a regressao ao deploy; deploy sexta-feira sem automacao.
- **Como verificar:** game day que injeta regressao no canary e confirma rollback automatico; teste de migracao expand/contract reversivel; checar label `version` presente em metricas/logs; ensaio de "kill switch" via feature flag.

---

## 6. Classificacao de Risco / Prioridade (para gaps de conformidade)

Para cada gap encontrado, atribua quatro eixos:

- **Severidade:** Critica (cego em incidente / vaza dados) / Alta / Media / Baixa / Informativa.
- **Prioridade:** P0 (bloqueia producao) / P1 (proximo ciclo) / P2 / P3.
- **Confianca:** Confirmada / Provavel / Suspeita / Precisa de contexto.
- **Esforco:** Baixo / Medio / Alto.

Heuristica: ausencia de correlacao por request id, logs com PII, liveness que mata pods, e deploy sem rollback tendem a Critica/P0.

---

## 7. Modo Auditoria de Conformidade (saida obrigatoria neste modo)

Quando operado em Modo AUDITAR, produza exatamente nesta estrutura:

### 7.1 Resumo executivo
3–6 frases: estado geral de observabilidade/debuggabilidade, nivel de risco operacional, e os 3 gaps mais perigosos.

### 7.2 Tabela de conformidade (placar das 10 regras)

| # | Regra | Status (Conforme/Parcial/Ausente/N/A) | Severidade | Prioridade | Confianca | Esforco |
|---|-------|----------------------------------------|------------|------------|-----------|---------|

### 7.3 Achados detalhados (um bloco por gap, formato fixo)

```
[ID] Regra N — Titulo do gap
- Localizacao: arquivo / funcao / endpoint / config (ou "nao localizado — assuncao")
- Evidencia: o que foi observado (trecho/comportamento), sem inventar
- Impacto: o que se perde em producao / risco de incidente
- Status & classificacao: Severidade / Prioridade / Confianca / Esforco
- Correcao: o COMO concreto (mecanismo + onde)
- Exemplo de correcao: snippet ilustrativo (stack relevante), com segredos mascarados
- Teste recomendado: como provar que ficou conforme
```

### 7.4 Plano de remediacao em fases
- **Fase 0 (P0, agora):** correlacao por request id; remover PII de logs; corrigir liveness destrutivo; rollback automatico em deploy.
- **Fase 1 (P1):** logs JSON + stack/contexto em erros; health detalhado; query/cache tracking.
- **Fase 2 (P2):** metricas RED/USE + histogramas; alertas SLO-based com runbooks.
- **Fase 3 (P3):** testes de regressao de fluxos criticos; deteccao de anomalia avancada; game days.

### 7.5 Checklist final
Lista marcavel das 10 regras com seus criterios de aceite, mais: ausencia de PII/segredos em sinais; correlacao cross-sinal por id; baixa cardinalidade; dead man's switch; rollback testado.

---

## 8. Regras de Qualidade e Auto-Verificacao (antes de entregar)

- Seja **especifico**: cada recomendacao tem mecanismo + local + criterio de aceite + verificacao.
- **Nao invente** arquivos/funcoes/metricas; diferencie **confirmado** de **provavel**; declare explicitamente o que falta de contexto.
- Sempre proponha **correcao + teste** juntos.
- Cubra **multiplas stacks** quando exemplificar e marque exemplos como ilustrativos.
- Garanta **agnosticismo de stack**: nada na resposta deve assumir uma unica linguagem/framework.
- Verifique caminho feliz E de erro, init/shutdown, concorrencia, papeis e ambientes.
- Nunca recomende logar/expor dados sensiveis; mascare segredos em todo exemplo.
- Calibre o tamanho ao objetivo: denso e completo, sem repeticao vazia. So eleve — nunca reduza o escopo.
