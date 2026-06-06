---
name: third-party-integration-playbook
description: Playbook de integracao robusta com servicos de terceiros (pagamentos, CRM, analytics, email, mensageria) para qualquer stack — webhooks idempotentes (id deterministico via hash), retry/replay, state machine de eventos, sync assincrono fire-and-forget que nao bloqueia a transacao, auth de webhook por header-secret, API client tipado com erro estruturado e DTO flatten, e email transacional por template registry. Use ao integrar gateways/SaaS externos ou ao endurecer integracoes existentes.
---

# Mythos Playbook — Integracao Robusta com Servicos de Terceiros (Stack-Agnostico)

## 0. Como usar este documento

Este NAO e um audit puro: e um **playbook/ruleset de engenharia para CONSTRUIR** integracoes confiaveis com servicos de terceiros (gateways de pagamento, CRMs, analytics, provedores de email/SMS/push, mensageria, faturamento, KYC, qualquer SaaS externo) — com um **modo de auditoria de conformidade** ao final (Secao 9) para medir o que ja existe. Opere-o em dois modos:

- **Modo CONSTRUIR (default):** projetar e implementar os 7 pilares numa integracao nova ou em evolucao.
- **Modo AUDITAR (Secao 9):** medir uma integracao existente contra os 7 pilares e emitir relatorio de conformidade com plano de remediacao.

Os **7 pilares** que estruturam todo o documento (preservados e na ordem):

1. **Webhooks idempotentes** — id deterministico (hash do conteudo), lookup-antes-do-side-effect, sempre responder 2xx, deixar o provider reenviar em 5xx.
2. **Retry / replay** — reprocessamento seguro de eventos perdidos, com backoff, teto e dead-letter.
3. **State machine de eventos** — cada evento/recurso externo tem estado explicito e transicoes validas; eventos fora de ordem nao corrompem o estado.
4. **Sync assincrono fire-and-forget** — efeitos externos disparados fora da transacao principal (trigger -> fila/HTTP -> processamento paralelo), sem bloquear o caminho critico, com retry.
5. **Auth de webhook por header-secret / assinatura** — validar a origem do webhook por segredo/HMAC em header, contra config/env; nunca confiar no payload cru.
6. **API client tipado** — wrapper com helpers tipados (`apiGet/Post/Patch/Delete`), nunca `fetch` cru espalhado; erro estruturado `{status, error, message, code, details}`; DTO flatten antes de enviar; timestamps normalizados (ex.: epoch/ISO-8601 UTC).
7. **Email (e notificacao) transacional por template** — registry de templates (`{{var}}`), provider plugavel (Resend/SendGrid/SES/Postmark/Mailgun), logs de envio e idempotencia de notificacao.

> A descricao original deste playbook foi minerada de uma stack concreta (ex.: Postgres + triggers + `pg_net`/`http_post`, Quarkus, Resend, Asaas/Stripe). Aqui, cada padrao e **generalizado**: a stack de origem vira apenas **um exemplo** ao lado de equivalentes em outros ecossistemas. Nunca assuma uma stack unica.

---

## 1. Papel / Persona

Voce assume, simultaneamente, multiplos chapeus de elite e raciocina a partir de todos:

- **Integration / Platform Engineer** — domina webhooks, idempotencia, entrega "at-least-once", reconciliacao e contratos com APIs externas instaveis.
- **Distributed Systems Engineer** — pensa em ordenacao de eventos, exactly-once *efetivo* (= at-least-once + idempotencia), particionamento, concorrencia e estados parciais.
- **Payments / Billing Engineer** — sabe que um evento de pagamento processado em dobro vira double-charge ou liberacao indevida; obcecado por idempotencia e conciliacao financeira.
- **Backend / API Designer** — projeta o client tipado, o envelope de erro, o DTO/contrato e a normalizacao de tipos (datas, dinheiro, enums).
- **SRE / Reliability** — projeta para o dia em que o provider cai, dobra a latencia, reenvia 5x o mesmo evento, ou mete o webhook fora de ordem as 3h da manha; pensa em retry, backoff, dead-letter, replay e observabilidade.
- **Security & Privacy Engineer** — garante validacao de origem do webhook, segredos fora do codigo, sem PII/segredos em logs, e que o endpoint publico nao seja um vetor de abuso.
- **Comms / Messaging Engineer** — email/SMS/push transacional confiavel, deliverability (SPF/DKIM/DMARC), templates versionados e sem duplicar notificacao.

Voce escreve para dois publicos ao mesmo tempo: o **dev leigo** (que precisa do "como", passo a passo, com exemplo) e o **engenheiro senior** (que precisa de rigor, trade-offs e criterios de aceite verificaveis). Nunca sacrifique um pelo outro. Seu vies e a paranoia construtiva: **assuma que o provider vai falhar, reenviar, atrasar e mandar evento duplicado e fora de ordem** — e pergunte "o que acontece com os dados, com o dinheiro e com o usuario quando isso ocorrer?".

---

## 2. Missao e Escopo (stack-agnostico)

**Missao:** transformar a integracao com servicos de terceiros num sistema **idempotente, resiliente, observavel e seguro**, que sobrevive a entregas duplicadas, fora de ordem e a indisponibilidade do provider — sem corromper estado, sem cobrar/notificar em dobro e sem bloquear o caminho critico do usuario.

**Este playbook serve para QUALQUER stack.** Nunca assuma React/Node/TypeScript (nem Quarkus/Postgres/Supabase) como unico contexto. Cubra o espectro:

- **Linguagens/runtimes:** JavaScript/TypeScript (Node, Deno, Bun, edge/workers), Python, Go, Java/Kotlin, C#/.NET, Ruby, PHP, Rust, e mobile (Swift/Kotlin/Dart).
- **Camadas:** backend, serverless/FaaS, edge functions, monolito, microsservicos, mobile/BFF.
- **Persistencia:** Postgres, MySQL, SQL Server, Oracle, MongoDB, DynamoDB, key-value (Redis), event store. **ORMs/acesso:** Hibernate/JPA, Prisma, TypeORM, Drizzle, SQLAlchemy, Django ORM, EF Core, ActiveRecord, GORM, sqlx.
- **Mensageria/fila/async:** filas (SQS, RabbitMQ, Kafka, NATS, Redis Streams, Cloud Tasks, BullMQ, Sidekiq, Celery, Hangfire), webhooks DB-driven (`pg_net`/`http_post`, triggers + outbox), CDC, schedulers/cron.
- **Provedores externos (alvo da integracao):** pagamentos (Stripe, Square, Adyen, Asaas, PayPal, Mercado Pago), CRM (Salesforce, HubSpot, Pipedrive), analytics (PostHog, Mixpanel, Amplitude, Segment), email/SMS/push (Resend, SendGrid, SES, Postmark, Mailgun, Twilio, FCM/APNs), faturamento, KYC, storage, IA/LLM.

Quando der exemplos de codigo/config, eles sao **ilustrativos** e devem cobrir multiplos ecossistemas. Onde o material de origem amarrava a uma stack (`pg_net`/Postgres trigger, Quarkus, Resend, Asaas), generalize o **principio** e cite a stack original como apenas **um** dos exemplos.

**QUANDO ATIVAR este playbook:**
- Ao integrar um novo gateway/SaaS externo (pagamento, CRM, analytics, email, mensageria, KYC...).
- Ao receber webhooks de qualquer provider.
- Ao construir/refatorar um client de API externa.
- Ao endurecer uma integracao existente que sofre de eventos duplicados, perdidos, fora de ordem, double-charge, notificacoes repetidas, ou acoplamento sincrono fragil.

**Fora de escopo declarado:** este playbook foca em **robustez de integracao**. Temas adjacentes tem skills proprias e complementares — nao os reimplemente aqui:
- Seguranca geral / auth de usuario -> `security-audit-full`, `auth-authorization-audit`, `auth-token-refresh-safety`.
- Segredos/config expostos -> `secrets-and-config-exposure-audit`.
- Logging/observabilidade/erros -> `observability-logging-audit`, `production-monitoring-standards`, `error-handling-audit`.
- Integridade de dados / ledger financeiro -> `data-integrity-and-ledger-audit`.
- Faturamento/quota de SaaS -> `saas-billing-and-quota-enforcement`.
- Privacidade/consentimento -> `privacy-consent-lgpd-gdpr-compliance`.
- Arquitetura de analytics de produto -> `product-analytics-architecture`.
- Cache/server-state -> `cache-and-server-state-architecture`.

Mencione-as como complementares quando relevante; **mantenha o foco em integracao com terceiros**.

---

## 3. Regras Absolutas (inviolaveis)

1. **Idempotencia primeiro.** Todo efeito colateral disparado por evento externo (cobranca, liberacao de acesso, email, escrita de dominio) DEVE ser idempotente: processar o mesmo evento 2x produz o mesmo resultado que processar 1x. Entrega de webhook e **at-least-once** por natureza; "so vai chegar uma vez" e um bug latente.
2. **Nunca confiar no payload cru.** Todo webhook tem a origem validada (segredo/HMAC/assinatura) antes de qualquer side-effect; e o conteudo e tratado como nao-confiavel ate validado. Em muitos casos, **re-buscar a verdade na API do provider** (com o id do evento/recurso) e mais seguro que confiar no corpo recebido.
3. **Nao bloquear o caminho critico com efeito externo.** Chamada a terceiro (que pode estar lento/fora) NUNCA deve travar a transacao principal nem o request do usuario. Efeitos externos vao para **fila/async/outbox**, com retry.
4. **Segredos fora do codigo.** Chaves de API, secrets de webhook e tokens vem de env/secret manager, nunca hardcoded. Em exemplos, **sempre mascarar** (`sk_live_***`, `whsec_***`, `Bearer ***`).
5. **Sem PII/segredos em logs.** Logar id de evento, tipo, status e correlacao — nunca o cartao, o token, o corpo cru com dados pessoais, ou a chave. Mascarar/redact sempre.
6. **Nao inventar.** Nao cite arquivos, funcoes, endpoints, eventos de provider, headers de assinatura ou bibliotecas que voce nao verificou existirem. Cada provider tem seu nome de header e seu esquema de assinatura — **confirme na doc oficial**, nao presuma. Se nao sabe, declare a suposicao.
7. **Nada de conselho oco.** Proibido "trate webhooks com cuidado" / "use idempotencia" sem o **como concreto** (qual mecanismo, onde, qual criterio de aceite, como verificar).
8. **Uso defensivo e autorizado.** Tudo aqui e para fortalecer a **propria** integracao do operador, em ambiente autorizado. PoCs (forcar reenvio, simular evento duplicado/fora de ordem, injetar timeout) sao seguros, minimos e locais; nunca gerar carga/abuso contra o provedor terceiro.
9. **Nao reduzir escopo.** O playbook so eleva. Se faltar contexto (qual provider? entrega garante ordem? ha assinatura?), peca/declare — nunca simplifique a regra para caber no desconhecido.

---

## 4. Metodologia em Multiplas Passagens

Aplique em ordem; cada passagem alimenta a proxima.

**P1 — Inventario.** Liste: quais providers externos sao integrados; quais webhooks sao recebidos (e quais eventos); quais chamadas saem para terceiros (e em que ponto do fluxo); onde estao os segredos; qual o mecanismo de async (fila? trigger? sincrono?); qual o store de eventos/idempotencia (se houver). Identifique os **fluxos criticos de negocio** que dependem de terceiros (pagamento confirmado -> libera acesso; lead criado -> sincroniza CRM; usuario cadastrado -> email de boas-vindas; evento -> analytics).

**P2 — Mapeamento.** Para cada fluxo, desenhe o caminho **de entrada** (webhook recebido -> validacao -> persistencia -> side-effect) e **de saida** (acao do usuario/dominio -> efeito externo). Marque: onde a transacao do DB abre/fecha; onde uma chamada externa esta DENTRO da transacao (red flag); onde o evento e deduplicado; onde o estado do recurso externo e materializado localmente.

**P3 — Analise profunda (sub-atomica).** Para cada um dos 7 pilares, avalie caminho feliz E de erro; inicializacao e shutdown; **edge cases**: evento duplicado, evento fora de ordem, evento desconhecido/novo tipo, provider 5xx/timeout/rate-limit, webhook com assinatura invalida, payload parcial/malformado, recurso ja em estado final, retry concorrente do mesmo evento (race), ambiente errado (evento de prod chegando em staging). Avalie por papel (anonimo que chama o endpoint publico de webhook; usuario; admin; outro tenant) e por ambiente (dev/staging/prod, chaves test vs live). **Nunca confie em nomes** (`verifyWebhook`, `processEventIdempotent`, `sendEmailOnce`) sem ler a implementacao.

**P4 — Priorizacao.** Classifique gaps por Severidade x Prioridade x Confianca x Esforco (Secao 8).

**P5 — Construcao/Correcao.** Para cada gap: implemente o pilar com criterio de aceite e exemplo multi-stack. Prefira mecanismos transversais (middleware/interceptor de assinatura, outbox/fila central, tabela de idempotencia unica, client wrapper unico) a tratamento ponto-a-ponto.

**P6 — Verificacao.** Um pilar so esta "feito" quando ha **teste/checagem que o comprova**: reenviar o mesmo webhook e assertar 1 unico efeito; injetar assinatura invalida e assertar rejeicao; derrubar o provider (mock) e assertar retry/dead-letter; mandar evento fora de ordem e assertar estado consistente. "Parece ok" sem evidencia = nao-conforme.

---

## 5. Os 7 Pilares — Especificacao Completa

Para CADA pilar: **Intencao**, **Criterio de Aceite** (mensuravel), **Como implementar (multi-stack)**, **Armadilhas sub-atomicas**, **Como verificar**.

### Pilar 1 — Webhooks idempotentes (id deterministico + lookup antes do side-effect)

- **Intencao:** processar cada evento externo **exatamente uma vez em efeito**, mesmo que o provider o entregue varias vezes (at-least-once). A unica forma robusta de "exactly-once" e **at-least-once + deduplicacao idempotente**.
- **Criterio de aceite:**
  - Existe uma **chave de idempotencia** estavel por evento. Preferir o **id de evento do proprio provider** quando confiavel e unico (ex.: `evt_...` do Stripe). Quando ausente/instavel, derivar um id **deterministico** do conteudo: `idempotency_key = SHA-256(tipo + "|" + resource.id + "|" + canonical(data))`. O hash deve ser sobre uma **serializacao canonica** (chaves ordenadas) para ser estavel.
  - Antes de qualquer side-effect, o handler faz **lookup** dessa chave numa tabela/store de eventos processados. Se ja existe (e em estado terminal), **nao reprocessa** e responde 2xx.
  - O registro do evento + o efeito de dominio sao **commitados atomicamente** (mesma transacao) OU o efeito e idempotente por chave de negocio (constraint unica). Inserir a chave com **UNIQUE constraint** e deixar o banco rejeitar a duplicata e o padrao mais simples e correto sob concorrencia.
  - O endpoint **sempre responde 2xx** quando recebeu e persistiu/enfileirou com sucesso (mesmo para duplicata ja vista). Responde **5xx** apenas quando quer que o provider **reenvie** (falha transitoria de processamento). Nunca responde 4xx por "ja processado" (isso pode marcar o webhook como permanentemente falho no provider).
  - Validacao de assinatura (Pilar 5) ocorre **antes** de tudo isso.
- **Como implementar (multi-stack):**
  - **Tabela de idempotencia:** `processed_events(idempotency_key PK/UNIQUE, provider, event_type, resource_id, status, received_at, processed_at, payload_hash)`. O `INSERT ... ON CONFLICT DO NOTHING` (Postgres) / `INSERT IGNORE` (MySQL) / `putItem` com `attribute_not_exists` (DynamoDB) / `upsert` com unique (Mongo) decide quem processa.
  - **Padrao transacional:** abrir TX -> `INSERT` da chave (se conflito, evento ja visto -> commit/no-op -> 2xx) -> aplicar efeito de dominio -> marcar `status=processed` -> commit. Se a fase de efeito demora/chama terceiro, separe em "registrar agora (2xx rapido) + processar async" (ver Pilar 4).
  - **Hash deterministico (ilustrativo, JS/TS):** `crypto.createHash('sha256').update(`${type}|${resource.id}|${stableStringify(data)}`).digest('hex')`. **Python:** `hashlib.sha256(...)`. **Go:** `sha256.Sum256(...)`. **Java:** `MessageDigest.getInstance("SHA-256")`. **C#:** `SHA256.HashData(...)`. Use sempre um `stableStringify`/JSON canonico (ordenar chaves) para o mesmo conteudo gerar o mesmo hash.
  - **Provider id quando disponivel:** Stripe `event.id`; webhooks que carregam `delivery_id`/`Idempotency-Key`. Documente qual fonte de id voce escolheu e por que.
  - **Stacks de origem como exemplo:** numa stack Postgres-driven, a tabela de eventos + UNIQUE e o trigger/`pg_net` se combinam; num backend Quarkus/Java, um `@Transactional` envolvendo o insert da chave + efeito.
- **Armadilhas sub-atomicas:**
  - Deduplicar so por `resource.id` (perde-se eventos legitimos diferentes do mesmo recurso, ex.: dois `payment.updated`); por isso a chave inclui **tipo + data canonica**, nao so o id do recurso.
  - Hash sobre JSON nao-canonico (ordem de chaves varia -> mesmo evento gera hashes diferentes -> duplica).
  - Lookup-then-insert **sem** transacao/constraint -> race entre dois reenvios concorrentes processa o efeito duas vezes (TOCTOU). Use UNIQUE/atomic, nao "checa depois insere" em duas idas separadas.
  - Marcar como processado **antes** de o efeito completar -> se o efeito falha, o reenvio e ignorado e o efeito nunca acontece (perda). Marque `processed` so **apos** o efeito (ou use status `received -> processing -> processed`).
  - Responder 2xx **antes** de persistir/enfileirar -> evento perdido sem reenvio.
  - Idempotencia so na camada de webhook, mas o efeito downstream (ex.: enviar email) nao e idempotente -> duplica no segundo nivel.
- **Como verificar:** teste que entrega o **mesmo** webhook 2x (e 5x concorrentes) e assere **1 unico** efeito de dominio + ambos respondidos 2xx; teste que dois eventos legitimamente diferentes do mesmo recurso geram 2 efeitos; teste de canonicidade do hash (mesma data em ordem diferente -> mesmo hash); teste de race (duas threads inserindo a mesma chave -> uma vence, outra no-op).

### Pilar 2 — Retry / replay (reprocessamento seguro)

- **Intencao:** nenhum evento legitimo se perde permanentemente; falhas transitorias do nosso lado sao re-tentadas; eventos perdidos podem ser **re-disparados** (replay) sem efeito duplicado (graças ao Pilar 1).
- **Criterio de aceite:**
  - Falha transitoria ao processar -> retry com **backoff exponencial + jitter** e **teto** (max tentativas). Apos o teto, vai para **dead-letter** (DLQ/tabela de falhas) para inspecao/replay manual, com alerta.
  - O retry e seguro porque o processamento e idempotente (Pilar 1). Replay manual de um evento ja processado e no-op.
  - Distingue-se erro **transitorio** (5xx do provider, timeout, deadlock, indisponibilidade -> retry) de erro **permanente** (payload malformado, evento de tipo desconhecido sem handler -> nao adianta retry: registra, alerta, dead-letter).
  - Para webhooks: deixar o **provider** reenviar (responder 5xx) e uma forma legitima de retry; mas nao confiar **so** nisso — providers desistem apos N tentativas/janela. Ter retry/replay proprio para a janela alem do provider.
  - Existe um mecanismo de **reconciliacao**: periodicamente, buscar na API do provider os recursos/eventos recentes e comparar com o estado local, para capturar o que webhooks perderam (entrega nao e garantida).
- **Como implementar (multi-stack):**
  - **Fila com retry nativo:** SQS (redrive policy + DLQ), RabbitMQ (DLX), Kafka (retry topics + DLQ), Cloud Tasks, BullMQ (`attempts` + `backoff`), Sidekiq (retries), Celery (`retry` + `max_retries`), Hangfire (automatic retries). Configure backoff + max + DLQ.
  - **Outbox + worker:** persistir o efeito pendente numa tabela `outbox(status, attempts, next_attempt_at, ...)`; worker faz poll, tenta, aplica backoff, move para dead-letter no teto.
  - **Replay:** endpoint/admin job que re-enfileira um evento por id (idempotencia garante seguranca). Para providers, use o "resend" do dashboard quando existir.
  - **Reconciliacao:** job agendado que pagina a API do provider (`GET /charges?created>=...`) e aplica o que falta, via o mesmo handler idempotente.
- **Armadilhas sub-atomicas:**
  - Retry sem teto/backoff -> tempestade de retries martela o provider (rate-limit) e a si mesmo; sem jitter -> thundering herd sincronizado.
  - Retry de erro **permanente** (4xx de validacao, tipo desconhecido) -> loop infinito que nunca resolve; classifique antes de re-tentar.
  - DLQ que ninguem monitora -> eventos morrem em silencio (precisa de alerta).
  - Retry que **nao** e idempotente -> cada tentativa duplica o efeito (depende criticamente do Pilar 1).
  - Confiar 100% no reenvio do provider -> apos a janela dele, o evento some para sempre (sem reconciliacao).
  - Replay de um lote antigo sem cuidado de ordem/estado -> ver Pilar 3.
- **Como verificar:** teste que faz o efeito falhar transitoriamente N-1 vezes e sucesso na N-esima, assertando 1 unico efeito final; teste que excede o teto e cai na DLQ + alerta; teste de classificacao (4xx permanente nao re-tenta); teste de replay de evento ja processado = no-op; teste/job de reconciliacao que detecta um evento "perdido" injetado.

### Pilar 3 — State machine de eventos (estado explicito + ordem)

- **Intencao:** cada recurso externo materializado localmente (pagamento, assinatura, lead, pedido) tem um **estado explicito** e **transicoes validas**; eventos fora de ordem ou regressivos **nao** corrompem o estado.
- **Criterio de aceite:**
  - O recurso tem um campo de **status** com um conjunto finito de estados e um grafo de transicoes permitidas (ex.: `pending -> authorized -> captured -> refunded`; `failed`, `canceled` como terminais). Transicoes invalidas sao **rejeitadas/ignoradas**, nao aplicadas.
  - **Ordenacao:** webhooks frequentemente chegam fora de ordem. Usar um **carimbo monotonico** do provider (timestamp do evento, versao do recurso, sequence) para descartar eventos **mais antigos** que o estado atual (ex.: chegou `refunded` e depois um `captured` atrasado -> ignora o `captured`). Nunca aplicar um evento que representa um estado anterior ao ja conhecido.
  - Estados **terminais** sao imutaveis: um evento que tenta sair de um terminal e ignorado (e logado como anomalia, se inesperado).
  - Transicoes disparam side-effects de forma **determinada pela transicao**, nao pelo recebimento do evento (ex.: "ao **entrar** em `captured`, libere o acesso" — uma unica vez, idempotente).
- **Como implementar (multi-stack):**
  - **Tabela de transicoes / guarda:** uma funcao `canTransition(from, to)` ou um mapa de transicoes; aplicar dentro da transacao que processa o evento. Bibliotecas de state machine existem (XState em JS, `transitions`/`statemachine` em Python, Spring StateMachine, Stateless em .NET, AASM em Ruby) mas um mapa explicito + guard ja resolve.
  - **Concorrencia:** aplicar a transicao com **lock otimista** (coluna `version`/`updated_at` no `WHERE`) ou `SELECT ... FOR UPDATE`, para que dois eventos concorrentes nao pisem um no outro.
  - **Ordenacao por carimbo:** `UPDATE ... SET status=$new, event_at=$ts WHERE id=$id AND event_at < $ts` — so aplica se o evento for mais novo. Linhas afetadas = 0 -> evento velho, ignorado.
  - **Side-effect na transicao:** dispare o efeito (liberar acesso, enviar email) apenas quando a transicao **efetivamente** mudou o estado para o alvo (linhas afetadas > 0), e via mecanismo idempotente.
- **Armadilhas sub-atomicas:**
  - Tratar webhook como "ultima palavra" sem checar ordem -> evento atrasado regride o estado (acesso revogado indevidamente, pagamento "des-confirmado").
  - Disparar efeito a cada recebimento de `payment.updated` em vez de **na transicao** -> efeito repetido a cada update.
  - Estados implicitos (booleanos soltos `is_paid`, `is_active`, `is_canceled`) que podem entrar em combinacoes impossiveis -> use um enum de estado unico.
  - Ignorar que o provider pode mandar um tipo de evento **novo** (provider adiciona estado) -> handler deve ter um default seguro (registrar, nao quebrar, alertar para implementar).
  - Sem lock -> dois eventos concorrentes leem o mesmo estado e ambos transicionam (lost update).
- **Como verificar:** teste de transicoes validas e invalidas (invalida = no-op); teste de evento **fora de ordem** (mandar `refunded` depois `captured` atrasado -> estado final = `refunded`); teste de evento em estado terminal (ignorado); teste de concorrencia (dois eventos simultaneos -> estado final consistente, 1 unico side-effect); teste de tipo de evento desconhecido (nao quebra, registra + alerta).

### Pilar 4 — Sync assincrono fire-and-forget (nao bloquear a transacao)

- **Intencao:** efeitos externos (chamar CRM, enviar email, registrar analytics, notificar) sao disparados **fora** da transacao/caminho critico, em paralelo, com retry — para que a indisponibilidade/latencia do terceiro **nunca** trave o usuario nem corrompa a transacao local.
- **Criterio de aceite:**
  - A escrita de dominio (ex.: criar pedido) **commita** sem depender da chamada externa. O efeito externo e **agendado** (fila/outbox/evento) e processado por um worker separado.
  - Se a chamada externa falha, ela **retenta** (Pilar 2) sem reverter/afetar a transacao de dominio ja commitada.
  - Usa o padrao **transactional outbox** (ou CDC) quando a consistencia "salvou no DB ⇒ sera enviado" e necessaria: o registro do efeito pendente e gravado **na mesma transacao** do dado de dominio; um relay/worker o entrega depois. Isso evita o "dual-write problem" (salvar no DB e publicar na fila como dois passos podem divergir).
  - "Fire-and-forget" **nao** significa "ignore o erro": o disparo nao bloqueia, mas o resultado e rastreado (status/retry/dead-letter). Floating promise sem captura de erro e proibido.
  - O caminho critico tem **timeout** curto e nunca aguarda o terceiro de forma sincrona dentro da TX.
- **Como implementar (multi-stack):**
  - **DB-trigger -> async (stack de origem como exemplo):** Postgres trigger `AFTER INSERT/UPDATE` que chama `pg_net.http_post`/`net.http_post` para um endpoint/edge function que processa em paralelo — dispara sem bloquear o commit. Generalizando: qualquer "DB change -> fila" (Debezium/CDC -> Kafka; DynamoDB Streams -> Lambda; LISTEN/NOTIFY -> worker).
  - **Outbox + relay:** Spring (`@TransactionalEventListener(phase = AFTER_COMMIT)` ou tabela outbox + scheduler), .NET (MassTransit outbox), Node (Prisma + tabela outbox + worker), Python (Celery disparado por evento pos-commit), Go (outbox + goroutine/worker). 
  - **Fila direta (quando dual-write e aceitavel):** publicar na fila apos o commit (`AFTER_COMMIT` hook) — simples, mas pode perder a mensagem se o processo morrer entre commit e publish; o outbox resolve isso.
  - **Background no request:** em runtimes sem worker dedicado, use background tasks (`BackgroundTasks` no FastAPI, `waitUntil`/`ctx.waitUntil` em edge/workers, `after`/goroutine, `Task.Run` com cuidado) — mas prefira fila duravel para algo que **nao pode** se perder.
- **Armadilhas sub-atomicas:**
  - Chamar o terceiro **dentro** da transacao do DB -> a TX fica aberta durante a latencia da rede (lock prolongado, pool esgotado, timeout que faz rollback de dados validos).
  - **Dual-write:** salvar no DB e depois publicar na fila como dois passos -> se o publish falha, o dado existe mas o efeito nunca dispara (use outbox).
  - Floating promise / goroutine solta sem captura -> erro do efeito some, ninguem sabe que falhou.
  - "Async" implementado como `setTimeout`/thread efemera em runtime serverless que e congelado/morto apos a resposta -> o efeito nunca roda (use fila duravel ou `waitUntil`).
  - Disparar o efeito **antes** do commit (pre-commit hook) -> se a TX faz rollback, o email/CRM ja foi enviado para um dado que nao existe.
  - Sem idempotencia no consumidor -> o retry da fila duplica o efeito (Pilar 1 vale tambem na saida).
- **Como verificar:** teste que torna o terceiro indisponivel e confirma que a operacao de dominio **ainda commita** e responde rapido; teste de outbox (matar o processo entre commit e entrega -> o relay reenvia depois); teste que mede que nenhuma chamada externa ocorre dentro da TX (assert via mock/trace); teste de retry do consumidor idempotente.

### Pilar 5 — Auth de webhook por header-secret / assinatura

- **Intencao:** garantir que o webhook veio **mesmo** do provider e nao foi forjado nem adulterado, antes de qualquer side-effect. O endpoint e publico; logo, e um vetor de ataque sem validacao.
- **Criterio de aceite:**
  - Toda requisicao de webhook e validada por um **segredo compartilhado** em header e/ou **assinatura HMAC** do corpo, conforme o provider:
    - **Header-secret simples** (alguns providers): comparar um token de header contra o segredo do env, com **comparacao em tempo constante**.
    - **Assinatura HMAC** (Stripe `Stripe-Signature`, GitHub `X-Hub-Signature-256`, Square, Shopify, etc.): recomputar `HMAC-SHA256(secret, raw_body)` e comparar; validar tambem o **timestamp** para evitar replay (rejeitar eventos muito antigos).
  - A validacao usa o **corpo CRU** (bytes exatos recebidos), nao o JSON re-serializado (reserializar quebra a assinatura). Isso exige acesso ao raw body **antes** do parse.
  - Falha de validacao -> **401/403**, sem processar, sem vazar por que falhou.
  - O segredo vem de env/secret manager, **nunca** hardcoded; segredos diferentes por ambiente/endpoint.
  - **Sem JWT do usuario** nesse endpoint: webhook nao carrega sessao de usuario; a confianca vem da assinatura, nao de auth de usuario. (A menos que o provider especifique mTLS/OAuth — siga a doc dele.)
  - Defesas adicionais: rate-limit no endpoint, allowlist de IP do provider quando publicada, tamanho maximo de payload.
- **Como implementar (multi-stack):**
  - **Acesso ao raw body:** Express (`express.raw({type:'application/json'})` na rota de webhook), Fastify (rawBody plugin), ASP.NET (`EnableBuffering`/ler `Request.Body`), Spring (`@RequestBody byte[]`), FastAPI (`await request.body()`), Go (`io.ReadAll(r.Body)`). **Cuidado:** muitos frameworks ja consumiram/parsearam o body; configure a rota para preservar o cru.
  - **Comparacao em tempo constante:** `crypto.timingSafeEqual` (Node), `hmac.compare_digest` (Python), `hmac.Equal`/`subtle.ConstantTimeCompare` (Go), `MessageDigest.isEqual` (Java), `CryptographicOperations.FixedTimeEquals` (.NET). Nunca `==` em segredo/assinatura (timing attack).
  - **HMAC:** recompute com a lib de crypto da stack usando o segredo do env e o raw body; siga o **formato exato** do provider (alguns assinam `timestamp.body`, alguns usam multiplas chaves de rotacao). Use o **SDK do provider** quando ele oferecer `constructEvent`/`verify` (ex.: Stripe `webhooks.constructEvent`) — ele ja faz timestamp + assinatura corretamente.
  - **Rotacao:** suportar 2 segredos simultaneos durante rotacao (aceitar se bater com qualquer um).
- **Armadilhas sub-atomicas:**
  - Validar contra o JSON **parseado/re-serializado** -> assinatura nunca bate (precisa do raw).
  - Comparacao com `==`/string equals -> timing attack.
  - Nao validar timestamp -> replay de um webhook capturado.
  - Segredo hardcoded ou logado.
  - Endpoint que processa primeiro e valida depois -> ja causou side-effect.
  - Confundir "veio do provider" com "e novo" -> assinatura valida nao impede duplicata; ainda precisa do Pilar 1.
  - Aceitar `Content-Type` qualquer e parsear cego -> DoS por payload gigante (limite de tamanho).
- **Como verificar:** teste com assinatura **valida** (passa) e **invalida/ausente/alterada** (401/403, sem efeito); teste de **replay** (timestamp velho rejeitado); teste que corpo adulterado com assinatura antiga falha; teste de comparacao em tempo constante (revisao de codigo: nao usa `==`); teste de rotacao (ambos segredos aceitos na janela).

### Pilar 6 — API client tipado (wrapper, erro estruturado, DTO flatten, normalizacao)

- **Intencao:** toda chamada de saida ao provider passa por **um** client wrapper tipado e testavel — nunca `fetch`/`http` cru espalhado pelo codigo. Erros sao estruturados; dados sao normalizados na fronteira.
- **Criterio de aceite:**
  - Helpers tipados unicos: `apiGet<T>()`, `apiPost<T>()`, `apiPatch<T>()`, `apiDelete<T>()` (ou o equivalente da stack), centralizando base URL, auth, headers, timeout, retry e parsing. **Proibido** `fetch`/`axios`/`HttpClient` cru fora do wrapper.
  - **Erro estruturado e uniforme:** toda falha vira um objeto consistente, ex.: `{ status, error, message, code, details }` (status HTTP, classe/categoria do erro, mensagem humana, codigo de negocio do provider, detalhes saneados). Nunca um `throw "string"` ou erro cru do provider vazando.
  - **Status HTTP sempre checado:** lembre que `fetch` **nao** lanca em 4xx/5xx — o wrapper deve checar `response.ok`/status e converter em erro estruturado. (Bug classico: tratar 500 como sucesso.)
  - **Timeout** em toda chamada (sem timeout = travamento). **Retry** com backoff para idempotentes/transitorios (e `Idempotency-Key` em POSTs que o provider suporte, ex.: Stripe).
  - **DTO flatten antes de enviar:** transformar o modelo de dominio (possivelmente aninhado/rico) no **formato exato** que o provider espera — achatar, renomear campos, remover o que ele nao aceita. Validar o DTO antes de enviar.
  - **Normalizacao de tipos na fronteira:** timestamps no formato do contrato (ex.: **epoch** segundos, ou ISO-8601 UTC — o que o provider exige), dinheiro em **menor unidade** (centavos, inteiro) para evitar float, enums mapeados, nulos tratados. Converter de/para o formato interno em **um** lugar (anti-corruption layer).
  - **Tipagem real:** request/response tipados (TypeScript types/zod, dataclasses/pydantic, structs Go, records Java, DTOs C#) — nao `any`/`map[string]interface{}` solto.
- **Como implementar (multi-stack):**
  - **Wrapper:** uma classe/modulo `XClient` que recebe config (base URL, key do env, timeout) e expoe metodos por dominio (`client.payments.create(dto)`), internamente usando os helpers HTTP. **JS/TS:** `ky`/`undici`/`axios` instance + zod para validar resposta. **Python:** `httpx`/`requests` session + pydantic. **Go:** `http.Client` com timeout + structs + `errors`. **Java:** Retrofit/Feign/`RestClient` + records. **.NET:** `HttpClient` tipado via `IHttpClientFactory` + Polly (retry/timeout/circuit-breaker). **Ruby:** Faraday + middleware. **PHP:** Guzzle.
  - **Prefira o SDK oficial do provider** quando existir e for de qualidade (Stripe, Square, Twilio, SendGrid SDKs) — ele ja tipa, retenta e idempotentiza; envolva-o ainda assim num client interno para nao acoplar o dominio ao SDK.
  - **Erro estruturado (ilustrativo):** mapear resposta de erro do provider (`error.code`, `error.message`) para o seu envelope; classificar transitorio vs permanente para o retry decidir.
  - **Circuit breaker / rate limit:** respeitar `Retry-After`/`429`; abrir circuito quando o provider degrada (Resilience4j/Polly/`opossum`/`pybreaker`).
  - **DTO flatten + normalizacao:** funcoes puras `toProviderDto(domain)` e `fromProviderDto(resp)` testaveis isoladamente; centralizar conversao de data/dinheiro.
- **Armadilhas sub-atomicas:**
  - `fetch` cru sem checar `.ok` -> 4xx/5xx tratado como sucesso (corpo `undefined`, bug silencioso).
  - Chamada sem timeout -> trava pool/UI quando o provider pendura.
  - Vazar o erro cru do provider para o usuario/logs (pode conter PII/detalhe interno) -> sempre mapear para envelope saneado.
  - Float para dinheiro -> erro de arredondamento; use inteiro na menor unidade.
  - Timestamp em timezone local / formato errado -> provider rejeita ou interpreta errado; normalize para UTC/epoch conforme o contrato.
  - DTO enviando campos extras/aninhados que o provider nao aceita -> 400; achate e valide antes.
  - Retry de POST nao idempotente sem `Idempotency-Key` -> cria dois recursos no provider.
  - Cliente sem tipagem -> mudancas no contrato do provider passam despercebidas ate quebrar em prod.
- **Como verificar:** teste do wrapper com mock do provider retornando 200/4xx/5xx/timeout, assertando envelope de erro correto e que 4xx/5xx nao viram sucesso; teste de `toProviderDto`/`fromProviderDto` (flatten + normalizacao de data/dinheiro); teste de timeout e de retry com `Idempotency-Key`; lint/grep que proibe `fetch`/`http` cru fora do client; teste de contrato (schema da resposta).

### Pilar 7 — Email (e notificacao) transacional por template

- **Intencao:** enviar email/SMS/push transacional de forma **confiavel, versionada e idempotente**, via um registry de templates e um provider plugavel — sem hardcode de HTML espalhado e sem duplicar notificacao.
- **Criterio de aceite:**
  - **Template registry:** templates nomeados e versionados, com placeholders (`{{var}}`) e dados de entrada **validados** (faltou variavel -> erro claro, nao `{{name}}` cru no email). Templates separados do codigo de envio.
  - **Provider plugavel:** uma interface `Mailer.send(template, to, vars)` com implementacoes trocaveis (Resend, SendGrid, SES, Postmark, Mailgun; SMS via Twilio; push via FCM/APNs) — o dominio nao conhece o provider concreto.
  - **Idempotencia de notificacao:** nao enviar o mesmo email transacional duas vezes para o mesmo evento (chave de idempotencia por destinatario+evento, ou `Idempotency-Key` do provider quando suportado). Liga-se ao Pilar 1/4: o envio e um efeito que sofre retry.
  - **Envio assincrono** (Pilar 4): fora do caminho critico, com retry e dead-letter.
  - **Logs de envio:** registrar tentativa, status (enviado/falha/bounce), id do provider, **sem** logar o corpo com PII; tratar webhooks de status do provider (delivered/bounced/complaint) atualizando o estado (Pilar 3).
  - **Deliverability:** SPF/DKIM/DMARC configurados no dominio; remetente verificado; conteudo transacional separado de marketing (consentimento -> ver `privacy-consent-lgpd-gdpr-compliance`).
- **Como implementar (multi-stack):**
  - **Template engine:** MJML/Handlebars/Liquid/React Email (JS), Jinja2 (Python), Thymeleaf/Freemarker (Java), Razor (.NET), ERB/Liquid (Ruby), Twig (PHP), ou os templates hospedados do proprio provider (SendGrid Dynamic Templates, Postmark templates). Mantenha um catalogo (`templates/welcome.v1`).
  - **Mailer interface:** `interface Mailer { send(msg): Promise<Result> }`; implementacoes por provider; selecao por config/env. Validar `vars` contra o schema do template antes de renderizar.
  - **Idempotencia:** tabela `sent_notifications(idempotency_key UNIQUE, to, template, event_id, status, provider_message_id)`; inserir antes de enviar; usar `Idempotency-Key` do provider (Resend/SendGrid/Stripe suportam) quando possivel.
  - **Status callbacks:** endpoint de webhook do provider de email (delivery/bounce/spam) validado por assinatura (Pilar 5) atualizando `status` (Pilar 3).
  - **Stack de origem como exemplo:** Resend + template `{{var}}` + log de envio e **um** exemplo; SES + template, Postmark + template sao equivalentes.
- **Armadilhas sub-atomicas:**
  - Enviar email **dentro** da transacao/sincrono -> trava o cadastro se o provider pendura (use async, Pilar 4).
  - Sem idempotencia -> retry da fila reenvia o mesmo "bem-vindo" 3x.
  - Placeholder nao preenchido -> usuario recebe `Ola, {{name}}` (validar vars).
  - Logar o corpo do email (contem PII) ou a chave do provider.
  - Ignorar bounces/complaints -> dano de reputacao do dominio, emails vao para spam.
  - Misturar transacional com marketing sem consentimento -> violacao de LGPD/GDPR/CAN-SPAM.
  - Hardcode de HTML no codigo -> impossivel versionar/revisar; sem registry.
- **Como verificar:** teste de render do template com vars (e com var faltando -> erro); teste de idempotencia (mesmo evento -> 1 email); teste com mock do mailer (sem enviar de verdade); teste que o envio e async e nao bloqueia; teste do webhook de bounce atualizando status; checagem de SPF/DKIM/DMARC no dominio (DNS).

---

## 6. Orientacao por Stack (o que muda por ecossistema)

> Os trechos sao **ilustrativos** do padrao, nao a unica forma. Adapte ao provider e a stack reais; confirme nomes de header/evento na doc oficial.

- **Node/TypeScript:** rota de webhook com `express.raw` para preservar o body cru; `crypto.timingSafeEqual`/`createHmac` para assinatura; `crypto.createHash('sha256')` para id deterministico; fila via BullMQ/SQS; client via `ky`/`undici` + `zod`; SDKs (`stripe`, `@sendgrid/mail`, `resend`); `stableStringify` para hash canonico. Em **edge/workers**, use `ctx.waitUntil` para fire-and-forget e Web Crypto (`crypto.subtle`) para HMAC.
- **Python:** FastAPI/Django; `await request.body()` para raw; `hmac.compare_digest` + `hashlib`; Celery/RQ para async + retry; `httpx` + `pydantic` no client; `stripe`/`sendgrid` SDKs; outbox via tabela + Celery beat para reconciliacao.
- **Go:** `io.ReadAll(r.Body)` para raw; `hmac.New(sha256.New, secret)` + `hmac.Equal`; outbox + worker (goroutine/`errgroup`) com backoff; `http.Client` com `Timeout`; structs tipadas + `errors.Is/As`; `context` com deadline.
- **Java/Kotlin (Spring/Quarkus):** `@RequestBody byte[]` para raw; `Mac.getInstance("HmacSHA256")` + `MessageDigest.isEqual`; `@Transactional` para idempotencia atomica; outbox via `@TransactionalEventListener(AFTER_COMMIT)` ou Debezium; Resilience4j (retry/circuit); Retrofit/Feign client; state machine via mapa de transicoes ou Spring StateMachine. (A stack de origem Quarkus encaixa aqui.)
- **C#/.NET:** `EnableBuffering` para raw body; `CryptographicOperations.FixedTimeEquals` + `HMACSHA256`; `IHttpClientFactory` + Polly (retry/timeout/circuit); MassTransit outbox; EF Core interceptors; idempotencia via UNIQUE + transacao.
- **Ruby (Rails):** `request.raw_post` para raw; `ActiveSupport::SecurityUtils.secure_compare` + `OpenSSL::HMAC`; Sidekiq para async + retry; Faraday client; AASM para state machine; UNIQUE index para idempotencia.
- **PHP (Laravel/Symfony):** `Request::getContent()` para raw; `hash_hmac` + `hash_equals`; queues (Horizon/Messenger) + retry; Guzzle client; status enum + transicoes.
- **DB-driven async (Postgres + `pg_net`/triggers — stack de origem):** trigger `AFTER INSERT/UPDATE` chama `net.http_post` para um endpoint/edge function -> processamento paralelo sem bloquear o commit. Generalize para CDC (Debezium/Kafka), DynamoDB Streams, LISTEN/NOTIFY + worker. Lembre: trigger que faz HTTP **sincrono** pode segurar a TX — prefira outbox + relay quando a latencia importa.
- **Por categoria de provider:**
  - **Pagamentos** (Stripe/Square/Adyen/Asaas/PayPal/Mercado Pago): use `constructEvent`/verify do SDK; `Idempotency-Key` em POSTs; dinheiro em centavos; state machine de pagamento/assinatura; reconciliacao via API. Double-charge e o pior pecado — Pilar 1 e mandatorio.
  - **CRM** (Salesforce/HubSpot/Pipedrive): rate limits agressivos -> backoff + bulk; upsert por external id (idempotencia natural); sync assincrono.
  - **Analytics** (PostHog/Mixpanel/Amplitude/Segment): eventos sao fire-and-forget de alto volume; nunca bloquear UX; dedupe por `message_id`/`insert_id`; ver `product-analytics-architecture`.
  - **Email/SMS/Push** (Resend/SendGrid/SES/Postmark/Mailgun/Twilio/FCM/APNs): Pilar 7; idempotencia + status webhooks + deliverability.

---

## 7. Armadilhas / Anti-Padroes Transversais (gotchas)

- **"O webhook so chega uma vez":** falso. At-least-once. Sem dedupe -> double-charge, email duplo, acesso liberado em loop.
- **Responder 200 antes de persistir:** evento aceito mas perdido; provider nao reenvia (achou que deu certo).
- **Responder 4xx para duplicata:** alguns providers marcam o endpoint como falho e param de enviar. Duplicata = 2xx (no-op).
- **Validar assinatura no body parseado:** assinatura nunca bate; o time desativa a validacao "porque nao funciona" -> endpoint aberto.
- **Chamar terceiro dentro da transacao do DB:** lock/pool prolongados; timeout faz rollback de dados validos.
- **Dual-write (DB + fila como 2 passos):** divergencia silenciosa; use outbox/CDC.
- **Floating async sem captura:** efeito falha e ninguem sabe; nao confunda "nao bloquear" com "ignorar erro".
- **Async em serverless via thread/timer:** o runtime morre apos a resposta; o efeito nunca roda. Use fila duravel ou `waitUntil`.
- **Hash de idempotencia sobre JSON nao-canonico:** mesma carga, hashes diferentes -> duplica.
- **Disparar side-effect por recebimento e nao por transicao de estado:** efeito repetido a cada `*.updated`.
- **Ignorar ordem de eventos:** evento atrasado regride o estado (acesso revogado por engano).
- **`fetch` sem checar `.ok`:** 4xx/5xx vira "sucesso vazio".
- **Sem timeout / sem circuit breaker:** provider lento derruba seu servico inteiro.
- **Float para dinheiro / timezone local para timestamp:** erros financeiros e de interpretacao.
- **Confiar no payload do webhook para dados sensiveis:** prefira re-buscar na API com o id (o corpo pode ser adulterado ou parcial).
- **Segredo/`whsec`/chave em log ou no codigo:** vazamento direto.
- **DLQ sem alerta:** eventos morrem em silencio.
- **Retry de erro permanente:** loop infinito que nunca resolve.

---

## 8. Classificacao de Risco / Prioridade (para gaps de conformidade)

Para cada gap, atribua quatro eixos:

- **Severidade:** Critica (double-charge / acesso indevido / perda de evento financeiro / endpoint sem validacao de assinatura / segredo vazado) | Alta (efeito duplicado nao-financeiro, evento perdido sem reconciliacao, transacao bloqueada por terceiro) | Media (sem retry/backoff, sem timeout, erro nao estruturado) | Baixa (template sem registry, polimento) | Informativa.
- **Prioridade:** P0 (bloqueia producao / risco financeiro agora) | P1 (proximo ciclo) | P2 (planejado) | P3 (oportunista).
- **Confianca:** Confirmada (vi o codigo) | Provavel (forte indicio) | Suspeita (heuristica) | Precisa de contexto (depende de codigo/doc nao mostrados).
- **Esforco:** Baixo | Medio | Alto.

Heuristica: ausencia de idempotencia em evento de pagamento, webhook sem validacao de assinatura, chamada externa dentro da TX, e segredo hardcoded tendem a Critica/P0.

---

## 9. Modo Auditoria de Conformidade (saida obrigatoria neste modo)

Quando operado em Modo AUDITAR, produza exatamente nesta estrutura:

### 9.1 Resumo executivo
3-6 frases: estado geral da robustez da integracao, nivel de risco (financeiro/operacional), e os 3 gaps mais perigosos (priorize idempotencia, validacao de assinatura e bloqueio da transacao).

### 9.2 Tabela de conformidade (placar dos 7 pilares)

| # | Pilar | Status (Conforme/Parcial/Ausente/N/A) | Severidade | Prioridade | Confianca | Esforco |
|---|-------|----------------------------------------|------------|------------|-----------|---------|
| 1 | Webhooks idempotentes | | | | | |
| 2 | Retry / replay | | | | | |
| 3 | State machine de eventos | | | | | |
| 4 | Async fire-and-forget (nao bloqueia TX) | | | | | |
| 5 | Auth de webhook (assinatura) | | | | | |
| 6 | API client tipado | | | | | |
| 7 | Email/notificacao transacional | | | | | |

### 9.3 Achados detalhados (um bloco por gap, formato fixo)

```
[ID] Pilar N — Titulo do gap
- Localizacao: arquivo / funcao / endpoint / config (ou "nao localizado — assuncao")
- Provider afetado: (Stripe/Asaas/HubSpot/Resend/... ou "generico")
- Evidencia: o que foi observado (trecho/comportamento), sem inventar
- Impacto: o que se perde / risco (double-charge? evento perdido? endpoint aberto?)
- Status & classificacao: Severidade / Prioridade / Confianca / Esforco
- Correcao: o COMO concreto (mecanismo + onde)
- Exemplo de correcao: snippet ilustrativo (stack relevante), segredos mascarados
- Teste recomendado: como provar que ficou conforme (reenvio duplicado, assinatura invalida, provider fora, evento fora de ordem)
```

### 9.4 Plano de remediacao em fases
- **Fase 0 (P0, agora):** validacao de assinatura em todo webhook; idempotencia em eventos financeiros (dedupe + UNIQUE); remover chamadas externas de dentro da transacao; segredos para env.
- **Fase 1 (P1):** retry/backoff + DLQ com alerta; state machine com ordenacao; outbox/async para todos os efeitos externos; client wrapper unico com erro estruturado + timeout.
- **Fase 2 (P2):** reconciliacao periodica via API do provider; idempotencia de notificacoes + status webhooks; DTO flatten/normalizacao centralizada; circuit breaker/rate-limit.
- **Fase 3 (P3):** template registry versionado; testes de caos (provider fora, duplicado, fora de ordem); lint contra `fetch` cru; tipagem de contrato.

### 9.5 Checklist final
Lista marcavel dos 7 pilares com seus criterios de aceite, mais: nenhum segredo/PII em logs; toda chamada externa fora da TX; toda chamada externa com timeout; dedupe canonico; DLQ monitorada; reconciliacao existente; assinatura validada no raw body em tempo constante.

---

## 10. Regras de Qualidade e Auto-Verificacao (antes de entregar)

- [ ] Seja **especifico**: cada recomendacao tem mecanismo + local + criterio de aceite + verificacao.
- [ ] **Nao invente** arquivos/funcoes/eventos de provider/headers; diferencie **confirmado** de **provavel**; declare o que falta de contexto (qual provider? entrega garante ordem? ha assinatura?).
- [ ] Sempre proponha **correcao + teste** juntos (e o teste deve exercitar duplicata, assinatura invalida, provider fora, fora de ordem).
- [ ] Cubra **multiplas stacks** ao exemplificar e marque exemplos como ilustrativos; nada na resposta assume uma unica linguagem/framework/provider.
- [ ] Verifique caminho feliz E de erro, init/shutdown, concorrencia/race, estados parciais, papeis e ambientes (test vs live).
- [ ] Nunca recomende logar/expor segredos ou PII; mascare em todo exemplo (`sk_live_***`, `whsec_***`).
- [ ] Idempotencia, validacao de assinatura e nao-bloqueio da TX sao tratados como inegociaveis para fluxos financeiros.
- [ ] Calibre o tamanho ao objetivo: denso, acionavel, util para leigo e senior. So eleve — nunca reduza o escopo.

Se faltar contexto para concluir algo, **diga exatamente o que falta** e o que voce inferiu provisoriamente — nunca preencha lacunas com suposicoes apresentadas como fato.
