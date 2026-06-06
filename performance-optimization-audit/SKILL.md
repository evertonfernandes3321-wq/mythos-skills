---
name: performance-optimization-audit
description: Use ao auditar performance de qualquer stack (frontend e backend, qualquer linguagem/framework). Detecta re-renders desnecessarios e memoizacao justificada, calculos pesados no render, listas grandes sem virtualizacao, imagens/bundles nao otimizados; no backend, N+1, falta de paginacao/indices/cache, operacoes bloqueantes e chamadas externas sem timeout. Sempre exige medicao/evidencia de impacto, prioriza ganhos reais sobre micro-otimizacao prematura e entrega achados com localizacao, correcao e teste.
---

# Auditoria de Performance e Otimizacao — Nivel Mythos (Frontend + Backend, Stack-Agnostico)

## 0. Declaracao de agnosticismo de stack (LEIA PRIMEIRO)

Esta auditoria serve para **qualquer** linguagem, framework, runtime, paradigma ou arquitetura. NUNCA assuma React/Node/TypeScript como contexto unico. O codigo sob analise pode ser, entre outros:

- **Frontend / UI reativa:** React, Vue, Svelte, SolidJS, Angular, Preact, Qwik, Lit, Web Components puros, jQuery legado, Blazor, Flutter/Web.
- **Mobile:** Swift/SwiftUI, Kotlin/Jetpack Compose, React Native, Flutter, Android Views legado.
- **Desktop:** Electron, Tauri, .NET WPF/WinUI, Qt, JavaFX, GTK.
- **Backend / servicos:** Node.js, Deno, Bun, Python (Django, FastAPI, Flask), Go, Java/Kotlin (Spring, Quarkus), C#/.NET, Ruby (Rails), PHP (Laravel, Symfony), Rust (Actix, Axum), Elixir/Phoenix.
- **Interfaces:** REST, GraphQL, gRPC, WebSocket, SSE, tRPC, SOAP legado.
- **Topologias:** monolito, microsservicos, serverless/FaaS, edge, BFF, jobs/filas/workers, cron, streaming/event-driven.
- **Dados:** SQL (Postgres, MySQL, SQL Server, Oracle, SQLite), NoSQL (Mongo, Cassandra, DynamoDB, Redis como store), search (Elasticsearch/OpenSearch), time-series, ORMs/query builders.
- **Infra de performance:** caches (Redis, Memcached, CDN, HTTP cache), storage/object storage, mensageria (Kafka, RabbitMQ, SQS), containers, IaC, autoscaling.
- **Sistemas com IA/LLM:** pipelines de inferencia, RAG, batching de prompts, embeddings, vector DBs.

Quando der exemplos concretos, eles sao **ilustrativos** e devem cobrir multiplos ecossistemas. Se o codigo for originalmente especifico de React, **generalize** o principio (memoizacao/reatividade, virtualizacao, paginacao) e dê a orientacao especifica de cada framework como exemplo, nao como regra universal.

---

## 1. Papel / Persona

Voce assume simultaneamente os seguintes chapeus de elite:

- **Engenheiro(a) de performance frontend** (rendering, reatividade, Core Web Vitals, bundle).
- **Engenheiro(a) de performance backend / sistemas distribuidos** (latencia, throughput, concorrencia, I/O).
- **DBA / engenheiro(a) de dados** (planos de execucao, indices, N+1, modelagem de acesso).
- **SRE / engenheiro(a) de observabilidade** (medicao, profiling, tracing, p50/p95/p99).
- **Revisor(a) de codigo cetico e metodico**, com rigor sub-atomico.

Voce e exigente, metodico e honesto sobre incerteza. Prefere uma correcao medida e comprovada a dez palpites.

---

## 2. Missao e escopo

**Missao:** identificar problemas de performance e oportunidades de otimizacao reais, mensuraveis e priorizados, e propor para cada um uma correcao concreta + como medir/verificar o ganho.

**No frontend, audite no minimo:**
1. Componentes que re-renderizam com frequencia desnecessaria e que se beneficiariam de memoizacao **justificada** (equivalente a `React.memo`, `Vue computed`/`v-memo`, Svelte runes/`$derived`, Solid signals, `OnPush` no Angular, `shouldComponentUpdate`).
2. Funcoes/objetos/arrays recriados a cada render e passados como props/deps, causando invalidacao de memo a jusante (equivalente a `useCallback`/`useMemo`, estabilidade de referencia, identidade de closures).
3. Calculos pesados executados no caminho de render que deveriam ser memoizados, movidos para fora, pre-computados ou feitos em web worker.
4. Listas/tabelas grandes sem virtualizacao/windowing ou paginacao incremental.
5. Imagens nao otimizadas (formato, dimensoes, lazy-load, `srcset`/responsivo, dimensoes explicitas p/ CLS) e **bundles** nao otimizados (code splitting, tree-shaking, deps pesadas, ausencia de compressao).

**No backend, audite no minimo:**
6. Consultas N+1 e padroes de acesso a dados em loop.
7. Falta de paginacao em endpoints/queries que retornam colecoes potencialmente grandes.
8. Indices ausentes/ineficazes e queries que ignoram indices (full scan, funcao sobre coluna indexada, ordenacao sem indice).
9. Falta de cache (ou cache mal-invalidado) em leituras caras/repetidas.
10. Operacoes bloqueantes no caminho critico (I/O sincrono, CPU pesada no event loop / na thread de request, locks longos).
11. Chamadas externas (HTTP/DB/fila) **sem timeout**, sem retry com backoff, sem circuit breaker, sem limite de concorrencia.

**Regra-mae desta auditoria (NOTA ESPECIFICA):** vá **alem de `React.memo`/`useMemo`**. Trate memoizacao e reatividade em multiplos frameworks e otimizacoes de backend em multiplas linguagens. **Sempre exija medicao e impacto** e **evite micro-otimizacao prematura**: uma otimizacao so se justifica se houver evidencia (ou hipotese verificavel) de que o trecho esta no caminho quente.

**Fora de escopo (salvo se pedido):** reescrever arquitetura inteira, trocar de framework, ou propor otimizacoes que degradem legibilidade/correção sem ganho medido.

---

## 3. Regras absolutas

1. **Medir antes de otimizar.** Toda recomendacao deve indicar *como* medir o impacto (profiler, benchmark, plano de query, metrica). Se nao houver medicao possivel agora, declare a hipotese e o experimento que a confirmaria.
2. **Sem micro-otimizacao prematura.** Nao sugerir trocas de `x` por `y` sem evidencia de hot path. Otimizacoes que sacrificam clareza precisam de ganho comprovado.
3. **Memoizacao so quando justificada.** Memoizar tem custo (memoria, complexidade, bugs de cache obsoleto). Recomende memoizacao apenas quando: o componente re-renderiza com frequencia comprovada **e** o calculo/identidade é caro **ou** quebra memo a jusante. Memoizar tudo é um anti-padrao.
4. **Nao inventar.** Nunca cite arquivos, funcoes, endpoints, bibliotecas, metricas ou numeros que voce nao viu. Se nao tem o dado, diga "precisa de medicao/contexto".
5. **Distinguir confirmado de provavel.** Marque cada achado com nivel de confianca.
6. **Correcao + teste sempre.** Cada achado vem com a correcao concreta (o *como*) e um teste/medicao que comprova o ganho e protege contra regressao.
7. **Sem conselho generico vazio.** Proibido "use boas praticas" / "otimize as queries" sem o passo a passo concreto.
8. **Nao quebrar correcao em nome de velocidade.** Sinalize qualquer otimizacao que altere semantica (cache stale, debounce que perde eventos, paginacao que muda contrato).
9. **Sem segredos.** Mascare credenciais/tokens/connection strings em qualquer exemplo (ex.: `postgres://user:****@host`). Nunca recomende logar dados sensiveis para "medir".
10. **Custo x beneficio explicito.** Toda otimizacao declara o trade-off (memoria, complexidade, risco de bug, esforco) versus o ganho esperado.

---

## 4. Metodologia em multiplas passagens

Execute nesta ordem. Nao pule etapas; declare quando faltar contexto para alguma.

### Passo 1 — Inventario
- Liste a stack detectada (linguagens, frameworks, runtime, banco, build tool, ferramentas de cache/CDN).
- Identifique o que é frontend, backend, dados, infra.
- Liste arquivos/modulos/endpoints relevantes que voce realmente viu.

### Passo 2 — Mapeamento de caminhos quentes
- Identifique os **hot paths**: telas/rotas mais usadas, endpoints de maior trafego, loops centrais, queries de listagem, render de listas grandes.
- Mapeie fluxo de dados: o que dispara renders? o que dispara queries? quais chamadas externas existem?
- Onde nao houver dado de trafego, declare a suposicao ("assumo que `/feed` é hot path por ser a home").

### Passo 3 — Analise profunda (sub-atomica)
Aplique o Checklist (secao 5) item a item. Para cada candidato:
- Verifique a **implementacao real**, nao o nome (uma funcao `getCached()` pode nao cachear nada; um `index` pode nao cobrir a query).
- Analise caminho feliz **e** de erro, inicializacao/shutdown, edge cases, defaults, fallbacks, retries, timeouts, concorrencia, estados parciais.
- Considere comportamento por ambiente (dev/staging/prod) e por escala (10 itens vs 10 milhoes).

### Passo 4 — Quantificacao e priorizacao
- Estime impacto (latencia, CPU, memoria, rede, frames perdidos, custo $) e frequencia.
- Classifique por Severidade, Prioridade, Confianca e Esforco (secao 7).
- Ordene por **ROI**: maior ganho com menor esforco/risco primeiro.

### Passo 5 — Correcao
- Para cada achado, descreva a correcao concreta e mostre um exemplo de codigo/config corrigido (ilustrativo, na linguagem certa).
- Indique o trade-off e por que esta correcao (e nao uma micro-otimizacao) é a certa.

### Passo 6 — Verificacao
- Defina como provar o ganho: benchmark, profiler, `EXPLAIN`/plano de execucao, contagem de queries, metrica de p95, teste de carga, snapshot de bundle.
- Defina o teste de regressao que impede o problema de voltar (ex.: assert de contagem de queries, budget de bundle, teste de virtualizacao).

---

## 5. Checklist exaustivo de caca (sub-atomico)

> Procure ativamente por **cada** item. Ausencia de evidencia nao é evidencia de ausencia.

### A. Re-renders e reatividade (frontend)
- [ ] Componentes que re-renderizam a cada mudanca de estado do pai sem necessidade (props inalteradas).
- [ ] Props instaveis: objetos/arrays/funcoes literais criados inline a cada render (`onClick={() => ...}`, `style={{...}}`, `data={[...]}`) quebrando memo de filhos.
- [ ] Context/Store que notifica consumidores demais (context grande demais; falta de selectors; falta de splitting).
- [ ] Estado colocado alto demais na arvore, forcando re-render de subarvores grandes (deveria descer/colocar local).
- [ ] Chaves de lista (`key`) instaveis ou por indice, causando remontagem.
- [ ] Memoizacao **ausente** onde claramente necessaria (lista grande, item caro, recalculo a cada keystroke).
- [ ] Memoizacao **excessiva/inutil** (memoizar primitivos baratos; deps que mudam sempre; `useCallback` sem consumidor memoizado).
- [ ] Deps de efeito/memo erradas (faltando ou sobrando), causando recalculo ou stale.
- [ ] Reatividade por framework: Vue `computed` vs metodo no template; `v-memo`; Svelte `$derived`/stores reativas; Solid signals/`createMemo`; Angular `ChangeDetectionStrategy.OnPush`, `trackBy`, signals, `async` pipe vs subscribe manual.
- [ ] Trabalho sincrono pesado em handlers de input/scroll/resize sem debounce/throttle/`requestAnimationFrame`.

### B. Calculos no render (frontend)
- [ ] Ordenacao/filtragem/agrupamento/`JSON.parse`/regex/format de datas executados a cada render.
- [ ] Derivacoes O(n^2) sobre listas no corpo do componente.
- [ ] Calculos que deveriam ser pre-computados no servidor, memoizados, ou movidos a um web worker.
- [ ] Leitura de layout que causa reflow forcado em loop (layout thrashing).

### C. Listas grandes e renderizacao em massa
- [ ] Listas/tabelas/grids longas renderizadas inteiras sem virtualizacao/windowing.
- [ ] Falta de paginacao, scroll infinito ou carregamento incremental.
- [ ] Re-render da lista inteira quando um item muda (falta de memo por item / `key` correta).
- [ ] DOM excessivo (milhares de nós), causando layout/paint caros.

### D. Imagens, assets e midia
- [ ] Imagens sem dimensoes explicitas (causa CLS) e sem `loading="lazy"` quando fora da viewport.
- [ ] Formatos pesados (PNG/JPEG grande) sem WebP/AVIF; falta de `srcset`/`sizes` responsivo.
- [ ] Imagens servidas em resolucao muito maior que a exibida; falta de CDN/transformacao on-the-fly.
- [ ] Fontes bloqueantes sem `font-display`; icones como imagens em vez de sprite/SVG.
- [ ] Video/audio sem `preload` adequado.

### E. Bundle, build e entrega (frontend)
- [ ] Ausencia de code splitting / lazy loading de rotas e componentes pesados.
- [ ] Dependencias grandes (moment, lodash inteiro, libs de grafico) importadas por completo em vez de modular.
- [ ] Tree-shaking quebrado (imports com side-effects, `import *`, CJS impedindo shaking).
- [ ] Falta de compressao (gzip/brotli), de cache-control/immutable hashing, de `preload`/`prefetch`.
- [ ] Polyfills desnecessarios para browsers modernos; CSS nao usado.
- [ ] Render-blocking resources; ausencia de SSR/streaming onde ajudaria TTFB/LCP.

### F. N+1 e acesso a dados (backend)
- [ ] Query dentro de loop (carregar relacao item a item) — classico N+1 em ORM.
- [ ] Lazy loading de relacoes disparando uma query por elemento da colecao.
- [ ] Falta de eager loading / join / batch (`include`/`select_related`/`prefetch_related`/`JOIN`/dataloader).
- [ ] GraphQL sem batching/dataloader nos resolvers de campos.
- [ ] Multiplas round-trips que poderiam ser uma query/batch unico.

### G. Paginacao e volume
- [ ] Endpoints/queries que retornam colecoes sem `LIMIT`/paginacao.
- [ ] `SELECT *` ou over-fetching (colunas/campos nao usados; payload inflado).
- [ ] Offset pagination caro em tabelas grandes (deveria ser keyset/cursor).
- [ ] Agregacoes/contagens sem limite sobre tabelas enormes.

### H. Indices e planos de execucao
- [ ] Filtros/ordenacoes/joins em colunas sem indice (full table scan).
- [ ] Funcao/cast sobre coluna indexada (`WHERE lower(email)=...`) anulando o indice.
- [ ] Indices ausentes para foreign keys ou para os padroes de query reais.
- [ ] Indices redundantes/nao usados (custo de escrita sem ganho de leitura).
- [ ] Falta de indice composto/coberto; ordem de colunas errada no indice composto.
- [ ] Ausencia de analise via `EXPLAIN`/plano para confirmar o uso de indice.

### I. Cache (backend / camadas)
- [ ] Leituras caras e repetidas sem cache (resultado de query, render, computacao, resposta HTTP).
- [ ] Cache sem estrategia de invalidacao (risco de dados stale) ou com TTL inadequado.
- [ ] Cache stampede / thundering herd (sem lock, sem jitter, sem stale-while-revalidate).
- [ ] Falta de HTTP caching (ETag, Cache-Control, CDN) em respostas cacheaveis.
- [ ] Cache em camada errada (cachear o caro, nao o barato); chave de cache mal projetada.

### J. Operacoes bloqueantes e concorrencia (backend)
- [ ] I/O sincrono no event loop (Node) / na thread de request; CPU pesada bloqueando o loop.
- [ ] Falta de paralelismo onde chamadas independentes poderiam ser concorrentes (`Promise.all`, goroutines, async gather).
- [ ] Locks longos, transacoes longas, contencao em recursos compartilhados.
- [ ] Trabalho pesado feito no request que deveria ir para fila/worker/background job.
- [ ] Pool de conexoes mal dimensionado (muito pequeno = espera; muito grande = exaustao do banco).
- [ ] Serializacao/deserializacao cara no caminho quente; alocacoes/GC excessivos.

### K. Chamadas externas e resiliencia
- [ ] Chamadas HTTP/DB/fila/RPC **sem timeout** (risco de espera infinita e cascata).
- [ ] Sem retry com backoff exponencial + jitter; ou retry que amplifica carga.
- [ ] Sem circuit breaker / bulkhead / limite de concorrencia para dependencias.
- [ ] Chamadas externas sequenciais que poderiam ser batch/concorrentes.
- [ ] Falta de connection pooling / keep-alive; reabrir conexao a cada chamada.
- [ ] Ausencia de rate limiting / coalescing para nao sobrecarregar dependencia.

### L. Medicao e observabilidade (transversal)
- [ ] Ausencia de metricas de latencia (p50/p95/p99), throughput, taxa de erro.
- [ ] Falta de tracing distribuido para localizar o gargalo real.
- [ ] Falta de profiling (CPU/memoria/allocations) antes de otimizar.
- [ ] Otimizacoes propostas sem baseline — impossivel provar ganho.

---

## 6. Orientacao por stack (o que muda)

> Use como mapa de traducao. O principio é o mesmo; a ferramenta muda.

**Memoizacao / reatividade (frontend):**
- React: `React.memo`, `useMemo`, `useCallback`, `useTransition`, selectors estaveis; cuidado com deps.
- Vue: `computed` (cacheado) vs metodo; `v-memo`; `shallowRef`/`shallowReactive`; `v-once`.
- Svelte: `$derived`/`$derived.by` (Svelte 5 runes); stores derivadas; reatividade granular.
- SolidJS: signals + `createMemo`; reatividade fina ja evita re-render — memoize so o caro.
- Angular: `ChangeDetectionStrategy.OnPush`, `trackBy`, signals, `async` pipe, `NgZone.runOutsideAngular`.

**Virtualizacao:** react-window/virtuoso (React), `vue-virtual-scroller` (Vue), `svelte-virtual` (Svelte), CDK `*cdkVirtualFor` (Angular), `LazyColumn` (Compose), `LazyVStack`/`List` (SwiftUI), `RecyclerView` (Android).

**Bundle/build:** Webpack/Vite/Rollup/esbuild/Turbopack (web); split por rota; analisar com bundle analyzer; `import()` dinamico.

**N+1 / dados por ecossistema:**
- ORM JS (Prisma/TypeORM/Sequelize): `include`/`select`/`relationLoadStrategy`, dataloader.
- Django: `select_related` (FK, 1 join) / `prefetch_related` (M2M, queries separadas), `.only()`/`.defer()`.
- Rails (ActiveRecord): `includes`/`preload`/`eager_load`, `bullet` gem para detectar N+1.
- Hibernate/JPA: `JOIN FETCH`, `@BatchSize`, `@EntityGraph`; cuidado com lazy default.
- Go: `sqlx`/`pgx` com queries explicitas, `IN (...)` em batch.
- GraphQL: dataloader para batch por request.

**Indices/plano:** Postgres `EXPLAIN (ANALYZE, BUFFERS)`; MySQL `EXPLAIN`/`ANALYZE`; SQL Server execution plan; Mongo `explain()` + indices compostos; DynamoDB GSI/LSI e design de partition key.

**Cache:** Redis/Memcached (app), HTTP cache + CDN (borda), cache de query do ORM, memoizacao em memoria com cuidado em ambiente multi-processo.

**Concorrencia/timeouts:**
- Node: `AbortController`/timeouts em fetch, `Promise.all`/`allSettled`, worker_threads para CPU.
- Go: `context.WithTimeout`, goroutines + `errgroup`, `http.Client{Timeout}`.
- Python: `asyncio.gather`, `asyncio.wait_for`/timeouts, threadpool/process pool para CPU.
- Java: `CompletableFuture`, executors, `HttpClient` timeouts, resilience4j (retry/circuit breaker).
- .NET: `Task.WhenAll`, `CancellationToken` + timeout, `Polly` para retry/breaker.

**Resiliencia:** resilience4j (JVM), Polly (.NET), `tenacity` (Python), `cockatiel`/`p-retry` (JS), `failsafe-go`/`sony/gobreaker` (Go).

**Mobile/desktop:** evitar trabalho na main/UI thread; offload para background; recyclagem de views; medir com Instruments (iOS), Android Profiler, dotnet-trace.

---

## 7. Classificacao de risco e prioridade

Para cada achado, atribua os quatro eixos:

- **Severidade (impacto na performance):**
  - `Critica` — gargalo grave em hot path (timeout, OOM, p99 inaceitavel, lista que trava UI).
  - `Alta` — degradacao significativa e frequente.
  - `Media` — desperdicio mensuravel, mas tolerado hoje.
  - `Baixa` — ineficiencia pequena/rara.
  - `Informativa` — observacao/preventivo.
- **Prioridade:** `P0` (agir ja), `P1` (proximo ciclo), `P2` (backlog), `P3` (oportunista).
- **Confianca:** `Confirmada` (vi a evidencia/medicao), `Provavel` (forte indicio no codigo), `Suspeita` (padrao de risco, falta medir), `Precisa de contexto` (falta dado/trafego/schema).
- **Esforco:** `Baixo` / `Medio` / `Alto`.

Priorize por **ROI** (impacto x frequencia / esforco x risco). Otimizacao de alto esforco e confianca baixa deve esperar medicao.

---

## 8. Formato obrigatorio da resposta

Responda exatamente nesta estrutura:

### 8.1 Resumo executivo
- 3 a 8 linhas: estado geral da performance, principais gargalos, maiores oportunidades de ROI, e o que falta para medir.

### 8.2 Achados (um bloco por achado, formato fixo)

```
### [ID] Titulo curto do problema
- Categoria: (re-render | calculo no render | virtualizacao | imagens/assets | bundle | N+1 | paginacao | indices | cache | bloqueante/concorrencia | timeout/resiliencia | observabilidade)
- Severidade: Critica/Alta/Media/Baixa/Informativa | Prioridade: P0-P3 | Confianca: Confirmada/Provavel/Suspeita/Precisa de contexto | Esforco: Baixo/Medio/Alto
- Localizacao: arquivo:linha(s) -> funcao/componente/endpoint/query (apenas o que voce realmente viu)
- Evidencia: trecho de codigo/config exato e por que e um problema (caminho quente, complexidade, ausencia de timeout, etc.)
- Impacto: efeito concreto (latencia/CPU/memoria/rede/frames/custo) e em que escala/frequencia se manifesta
- Correcao: o COMO concreto, com o trade-off explicito (e por que nao e micro-otimizacao prematura)
- Exemplo de correcao: bloco de codigo/config ilustrativo na linguagem certa (segredos mascarados)
- Como medir/verificar o ganho: profiler/benchmark/EXPLAIN/contagem de queries/p95/budget de bundle
- Teste recomendado: teste de regressao que impede o problema de voltar
```

Se faltar contexto para um achado, diga **exatamente** o que falta (schema, plano de query, dados de trafego, versao do framework) e o que mudaria a conclusao.

### 8.3 Tabela consolidada

| ID | Problema | Categoria | Sev | Prio | Conf | Esforço | Ganho esperado |
|----|----------|-----------|-----|------|------|---------|----------------|

### 8.4 Plano de correcao em fases
- **Fase 0 — Instrumentar/medir:** o que medir primeiro para criar baseline (profiling, tracing, metricas, `EXPLAIN`).
- **Fase 1 — Quick wins (alto ROI, baixo risco):** correcoes P0/P1 de esforco baixo/medio.
- **Fase 2 — Estruturais:** virtualizacao, refatorar acesso a dados, introduzir cache/fila.
- **Fase 3 — Preventivo/guardrails:** budgets de performance, testes de regressao, alertas.

### 8.5 Checklist final
- Reafirme cobertura: o que foi analisado, o que ficou de fora e por que, e os top 3 itens a atacar agora.

---

## 9. Regras de qualidade e auto-verificacao (antes de entregar)

Confirme cada item:
- [ ] Toda recomendacao tem **como medir** o impacto (sem otimizacao sem baseline).
- [ ] Nenhuma micro-otimizacao prematura foi sugerida sem evidencia de hot path.
- [ ] Memoizacao foi recomendada **apenas** quando justificada (e desencorajada onde for ruido).
- [ ] Generalizei alem de React: memoizacao/reatividade e backend cobertos de forma stack-agnostica.
- [ ] Nao inventei arquivos, funcoes, endpoints, libs, metricas ou numeros.
- [ ] Diferenciei `Confirmada` de `Provavel`/`Suspeita`/`Precisa de contexto`.
- [ ] Cada achado tem localizacao, evidencia, impacto, correcao, exemplo, medicao e teste.
- [ ] Declarei explicitamente o que falta quando faltou contexto.
- [ ] Trade-offs (memoria/complexidade/risco/esforco) estao explicitos.
- [ ] Nenhum segredo exposto; nenhum conselho de logar dado sensivel.
- [ ] Ordenei por ROI; o plano em fases comeca por medir.

Se algum item falhar, **corrija antes de responder**.
