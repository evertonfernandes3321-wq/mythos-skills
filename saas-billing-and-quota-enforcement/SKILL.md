---
name: saas-billing-and-quota-enforcement
description: Cobranca e enforcement de quotas de SaaS em qualquer stack — quota em duas camadas (enforcement no banco que o app nao contorna + UX no cliente), catalogo de planos, metricas de uso, e maquinas de estado de assinatura (trialing/active/past_due/canceled) via jobs agendados. Generaliza padroes reais (RLS WITH CHECK, usage_metrics por date_trunc, pg_cron, billing_events, gateways estilo Stripe/Asaas) para qualquer banco/ORM/gateway/scheduler. Use ao construir ou auditar planos pagos, limites de uso e trials.
---

# Mythos Playbook — Cobranca, Quotas e Maquinas de Estado de Assinatura em SaaS (Stack-Agnostico)

## 0. Como usar este documento

Este NAO e apenas uma auditoria: e um **playbook/ruleset de engenharia para CONSTRUIR** o subsistema de monetizacao de um SaaS — planos pagos, limites/quotas, trials, contadores de uso e o ciclo de vida da assinatura — e tambem para **AUDITAR** um subsistema existente. Opere-o em dois modos, frequentemente combinados:

- **Modo CONSTRUIR (default):** projetar e implementar enforcement de quota em duas camadas, catalogo de planos, metricas de uso e a maquina de estados de assinatura com jobs agendados.
- **Modo AUDITAR (Secao 12):** medir um subsistema existente contra os invariantes deste documento e emitir um relatorio de conformidade com plano de remediacao priorizado.

Os **cinco pilares** (preservados integralmente e na ordem) sao:

1. **Quota em duas camadas** — enforcement no armazenamento de dados (que o app NAO contorna) + UX de quota no cliente. As duas camadas SEMPRE coexistem; nenhuma substitui a outra.
2. **Catalogo de planos** — definicao declarativa de planos, precos, features e limites por dimensao (com `null` = ilimitado).
3. **Metricas de uso** — contadores periodicos (tipicamente por mes-calendario via truncamento de data) que alimentam o enforcement e a UX.
4. **Maquina de estados de assinatura** — `trialing -> active -> past_due -> canceled` (e variantes), com transicoes deterministicas e auditaveis.
5. **Jobs agendados (cron/scheduler)** — varreduras periodicas para avisar trials a expirar, fazer auto-downgrade de inadimplencia, reconciliar com o gateway e registrar tudo em um log de eventos de cobranca.

> **Aviso de origem:** este playbook foi destilado de padroes reais (ex.: enforcement de quota via funcao `check` em RLS `WITH CHECK` no Postgres/Supabase, `usage_metrics` agregada por `date_trunc('month', ...)`, jobs `pg_cron`/`pg_net`, eventos em `billing_events`, gateway estilo Asaas/Stripe). Tudo isso e tratado como **UM exemplo** de uma classe geral. O documento generaliza o **principio** para qualquer linguagem, banco, ORM, gateway e scheduler.

---

## 1. Papel / Persona

Voce assume, **simultaneamente**, multiplos chapeus de elite e raciocina a partir de todos eles:

- **Staff Billing / Monetization Engineer** — ja construiu cobranca recorrente em producao; conhece prorating, dunning, downgrade/upgrade, grace periods, idempotencia de webhook e reconciliacao com gateway.
- **Database / Data Integrity Engineer** — projeta o enforcement no nivel do dado (constraints, triggers, policies, funcoes `check`, transacoes) de modo que **nenhum caminho de aplicacao** consiga ultrapassar a quota.
- **Distributed Systems Engineer** — pensa em concorrencia, condicoes de corrida no incremento de contadores, idempotencia, exactly/at-least-once de webhooks e jobs, relogio/timezone e reentrancia.
- **Product / Growth Engineer** — projeta a UX de limite (banners, dialogs, progress, thresholds, upsell) que converte sem enganar nem irritar; entende trial-to-paid e involuntary churn.
- **SRE / Reliability Engineer** — cuida dos jobs agendados: o que acontece se um job falha, roda duas vezes, atrasa, ou o gateway esta fora do ar.
- **Security & Privacy Engineer** — garante isolamento por tenant, que limites de um cliente nao vazem para outro, e que dados financeiros/PII nao sejam logados em texto claro.
- **FinOps / Revenue Assurance** — preocupa-se com receita perdida (limites que vazam) e cobranca indevida (estados inconsistentes), e exige auditabilidade fim a fim.
- **Revisor de codigo senior poliglota** — le a implementacao em qualquer linguagem e NAO confia em nomes (`canCreate`, `checkQuota`, `isActive` so valem se o corpo confirmar).

Voce escreve para dois publicos ao mesmo tempo: o **dev leigo**, que precisa do "como" passo a passo com exemplo, e o **engenheiro senior**, que precisa de rigor, trade-offs e criterios de aceite verificaveis. Nunca sacrifique um pelo outro.

---

## 2. Missao e Escopo (stack-agnostico)

**Missao:** projetar (ou endurecer) um subsistema de cobranca e enforcement de quotas que seja **inviolavel no dado**, **claro na UX**, **deterministico na maquina de estados** e **auditavel ponta a ponta**, de modo que: nenhum tenant exceda seu plano por nenhum caminho; todo cliente saiba onde esta no limite; toda transicao de assinatura seja correta, reversivel quando devido e registrada; e nenhuma receita seja perdida ou cobrada indevidamente.

**Este playbook serve para QUALQUER stack.** NUNCA assuma uma stack unica (nao presuma Supabase/Postgres/Flutter/React). O espectro coberto inclui, sem limitar:

- **Camadas:** frontend web, backend, fullstack, mobile (iOS/Android/cross-platform), desktop, CLIs, SDKs/bibliotecas, extensoes.
- **Interfaces:** REST, GraphQL, gRPC, WebSocket, SSE, webhooks, mensageria/eventos.
- **Topologias:** monolitos, microsservicos, serverless/FaaS, edge/workers, jobs/filas/cron, event-driven, BFF.
- **Bancos/armazenamento:** Postgres, MySQL/MariaDB, SQL Server, Oracle, SQLite, CockroachDB; MongoDB, DynamoDB, Cassandra, Firestore; Redis (contadores/limites); data warehouses para usage analitico.
- **ORMs/camadas de acesso:** Hibernate/JPA, Prisma, Drizzle, TypeORM, Sequelize, SQLAlchemy, Django ORM, Entity Framework, ActiveRecord, Ecto, GORM, ou SQL puro.
- **Gateways de pagamento:** Stripe, Square, Braintree, Adyen, PayPal, Asaas, Mercado Pago, Paddle, Chargebee, RevenueCat (mobile/IAP), Apple App Store / Google Play Billing.
- **Schedulers:** cron do SO, `pg_cron`, cloud schedulers (AWS EventBridge/Cloud Scheduler/Azure Scheduler), filas com delay (SQS/Sidekiq/Celery/BullMQ/Quartz/Hangfire/Temporal), Kubernetes CronJob, Cloudflare Cron Triggers.
- **Frontends reativos:** React, Vue, Svelte, Solid, Angular, Flutter, SwiftUI, Jetpack Compose.

Quando der exemplos de codigo/SQL/config, eles sao **ilustrativos** e devem cobrir **multiplos ecossistemas** — deixe explicito que sao ilustrativos e **adapte ao projeto real; nunca invente caminhos, tabelas ou funcoes inexistentes**.

**Fora de escopo declarado:** contabilidade fiscal/emissao de notas, calculo de impostos por jurisdicao, e a integracao especifica byte-a-byte com um gateway (cada gateway tem seu SDK). Esses temas entram apenas onde tocam quota, estado de assinatura ou auditoria de receita.

### Quando ATIVAR esta skill

- Ao **construir** planos pagos, limites de uso, trials, paywalls ou contadores de consumo.
- Ao **auditar** um subsistema de billing/quota existente antes de cobrar dinheiro real, escalar, ou apos um incidente de "cliente passou do limite" / "cliente cobrado errado".
- Ao **migrar** de "tudo gratis" para tiers pagos, ou ao **adicionar uma nova dimensao de limite** (ex.: novo recurso contavel).
- Ao **revisar** a maquina de estados de assinatura, jobs de cobranca, dunning ou reconciliacao com gateway.

---

## 3. Regras absolutas (invioláveis)

1. **Enforcement no dado e a fonte de verdade.** A camada de armazenamento DEVE rejeitar a operacao que excede a quota, de forma que **nenhum caminho de aplicacao** (API publica, job interno, console admin, script de migracao, integracao de terceiro, query manual) consiga contornar. A checagem no cliente/UX e **conveniencia e nunca seguranca**. Tratar UX como enforcement e um achado **critico**.
2. **Isolamento por tenant e absoluto.** A quota, o uso e o estado de um tenant/usuario/organizacao JAMAIS podem ser lidos, contados ou alterados por outro. Vazamento cruzado de limite/uso = **critico**. (Complementa, mas nao substitui, uma auditoria dedicada de isolamento de tenant.)
3. **Idempotencia obrigatoria** em webhooks de gateway, jobs agendados e transicoes de estado. Reprocessar o mesmo evento/ciclo NAO pode cobrar duas vezes, duplicar downgrade, nem corromper contadores. Toda operacao financeira/transicional precisa de chave de idempotencia e/ou ser naturalmente idempotente.
4. **Fail-closed em ambiguidade de quota; fail-aberto-com-alerta apenas onde a receita exige.** Se nao da para determinar com seguranca o uso atual, a operacao de consumo deve **bloquear** por padrao (proteger o limite), salvo decisao de produto explicita e registrada para nao bloquear (ex.: nao impedir login por causa de billing). NUNCA "na duvida, libera tudo" silenciosamente.
5. **Auditabilidade total.** Toda transicao de assinatura, mudanca de plano, cobranca, falha, downgrade e reset de contador DEVE gerar um evento imutavel (append-only) em um log de eventos de cobranca, com ator, antes/depois, motivo, correlacao e timestamp.
6. **Nunca exponha segredos nem dados financeiros sensiveis.** Em exemplos e logs, MASCARE chaves de gateway (`sk_live_…`), webhook secrets, e dados de cartao/PIX/conta. Trate qualquer segredo encontrado como ja comprometido (recomende rotacao). Numero de cartao completo, CVV e dados bancarios brutos JAMAIS sao logados.
7. **Nao confie em nomes.** `enforceLimit`, `checkQuota`, `isSubscriptionActive`, `withinPlan` so valem se a implementacao confirmar. Leia o corpo; verifique empiricamente.
8. **Nao invente.** Nao cite tabelas, colunas, funcoes, jobs, planos, eventos ou campos que voce nao viu ou nao pode justificar. Se nao ha enforcement no banco, **diga isso**; nao presuma que existe porque ha uma funcao chamada `check`.
9. **Diferencie confirmado de provavel de suspeito.** Marque cada afirmacao/achado com confianca.
10. **Nada de conselho generico.** Proibido "use boas praticas" sem o "como" concreto (constraint/trigger/policy, snippet, comando, teste). Toda recomendacao traz **implementacao + como verificar**.
11. **Nao reduzir profundidade nem escopo** — apenas elevar.

---

## 4. Definicao de "nivel sub-atomico"

Projete e audite com rigor sub-atomico. Falhas reais de billing nascem da **composicao** de pequenas brechas. Para cada decisao, considere:

- **Caminho feliz e caminho de erro**: criar dentro do limite; criar exatamente no limite; criar um alem do limite; criar quando o gateway esta fora; criar durante uma transicao de estado em andamento.
- **Inicializacao e shutdown**: o que acontece com contadores no primeiro dia do ciclo; o que acontece se o job de reset nao roda; bootstrap de um tenant novo sem linha de uso ainda.
- **Concorrencia e corrida**: duas requisicoes simultaneas no limite `N-1` -> ambas podem passar se o `check` for "ler-depois-escrever" sem atomicidade. Este e o bug classico de quota.
- **Estados parciais**: assinatura criada no gateway mas webhook ainda nao chegou; downgrade aplicado no plano mas contador nao reconciliado; pagamento aprovado mas job de ativacao falhou.
- **Defaults, fallbacks, retries, timeouts**: default de plano para tenant novo; fallback quando o gateway nao responde; retries de webhook (idempotencia!); timeout no job que processa milhares de tenants.
- **Papeis**: anonimo, usuario comum, admin (pode admin furar limite? deve ser auditado), owner do tenant, outro tenant, conta de servico/integracao.
- **Ambientes**: dev/staging/prod; sandbox vs live do gateway; jobs habilitados so em prod; planos de teste que nao podem existir em prod.
- **Tempo**: timezone e DST no truncamento mensal; "now+3d" cruzando virada de mes; relogio do banco vs do app vs do gateway; ciclos de cobranca ancorados na data de assinatura vs no calendario.
- **Semantica de `null`/ilimitado**: `null` significa ilimitado, ausente, ou erro? Confundir isso e como `0` vs `null` em SQL — um classico que libera ou bloqueia tudo por engano.

Nunca aceite "parece ok" por ausencia de evidencia. Ausencia de um teste de corrida NAO prova que a quota e atomica — frequentemente e o proprio achado.

---

## 5. Pilar 1 — Quota em DUAS CAMADAS

A regra mestra: **enforcement no dado** (autoridade) + **UX no cliente** (conveniencia). As duas SEMPRE coexistem.

### 5.1 Camada A — Enforcement no armazenamento (a que o app NAO contorna)

**Intencao:** mover a decisao "esta operacao excede a quota?" para o ponto mais proximo do dado, dentro da mesma fronteira transacional da escrita, de modo que toda via de gravacao passe obrigatoriamente por ela.

**Como implementar (espectro de mecanismos, do mais forte ao mais fraco):**

1. **Policy/constraint declarativa no banco com funcao de checagem** (mais forte quando suportado).
   - *Postgres + RLS (exemplo de origem, generalizavel):* uma `POLICY ... WITH CHECK (public.check_within_quota(tenant_id, 'projects'))` em `INSERT`/`UPDATE`, onde a funcao conta o uso atual e compara com o limite do plano. Como a policy roda no proprio engine, **nenhuma query do app a contorna** (exceto roles que ignoram RLS — ver armadilhas).
   - *Generalizacao:* qualquer banco que permita expressar a invariante no proprio engine. Onde RLS nao existe, use **trigger `BEFORE INSERT/UPDATE`** que faz `RAISE`/aborta a transacao ao exceder; ou **constraint via tabela de contadores + `CHECK`/unique**; ou **stored procedure** como unico caminho de escrita.
2. **Transacao atomica com bloqueio/contador** (forte e portavel).
   - Incremente um contador e valide o limite na **mesma transacao**, usando `SELECT ... FOR UPDATE`, `UPDATE ... WHERE counter < limit RETURNING` (sucesso so se afetou linha), ou um `INSERT` condicional. A atomicidade elimina a corrida `N-1`.
   - *Redis (alta frequencia):* `INCR`/`INCRBY` + comparacao, idealmente em **script Lua** atomico para "checar-e-incrementar"; com expiracao alinhada ao ciclo. Reconciliar periodicamente com a fonte de verdade duravel.
3. **Enforcement no servidor de aplicacao** (camada minima aceitavel **somente** se 1/2 forem impossiveis): a checagem ocorre em um ponto unico e obrigatorio (ex.: um repositorio/gateway por onde TODA escrita passa), com transacao e lock. Risco: qualquer caminho que pule esse ponto (job, console, outra service) fura. Documente o risco e mitigue fechando todas as portas.

**Anti-padrao proibido:** "checo no controller antes de salvar" sem transacao/lock e sem barreira no dado. Isso e UX disfarcada de enforcement; sofre corrida e e contornavel.

**Como implementar a funcao de checagem (independente do mecanismo):**

```sql
-- Ilustrativo (Postgres). Adapte nomes reais; nao copie cegamente.
create or replace function check_within_quota(p_tenant uuid, p_dimension text)
returns boolean language plpgsql stable as $$
declare
  v_limit  bigint;   -- null = ilimitado
  v_used   bigint;
begin
  select limit_value into v_limit
    from plan_limits pl
    join subscriptions s on s.plan_id = pl.plan_id
   where s.tenant_id = p_tenant
     and pl.dimension = p_dimension
     and s.status in ('trialing','active');     -- estados que concedem direito
  if v_limit is null then
    return true;                                -- ilimitado (distinga de "sem plano")
  end if;
  select coalesce(count(*),0) into v_used
    from quota_consumers
   where tenant_id = p_tenant and dimension = p_dimension;
  return v_used < v_limit;                       -- '<' porque a linha nova ainda nao existe
end $$;
```

> Cuidados sub-atomicos nesta funcao: (a) o `<` vs `<=` depende de quando a linha e contada — defina e teste o "exatamente no limite"; (b) sob concorrencia, `count(*)` + `INSERT` em policies separadas ainda pode correr — prefira contador transacional ou serializacao; (c) `null` de "ilimitado" vs `null` de "tenant sem assinatura" devem ter ramos distintos; (d) a funcao deve ser segura quanto a tenant (so conta o tenant do parametro).

**Equivalentes por stack (ilustrativo):**
- *Prisma/Drizzle (TS):* `prisma.$transaction` com `SELECT ... FOR UPDATE` (via `$queryRaw`) ou `updateMany({ where: { id, counter: { lt: limit } } })` e checar `count`.
- *SQLAlchemy/Django (Python):* `with_for_update()` na transacao; ou `F()` expression para incremento atomico com `update(... )` condicional.
- *Hibernate/JPA (Java):* `@Version` (optimistic lock) ou `LockModeType.PESSIMISTIC_WRITE`; trigger no banco como rede de seguranca.
- *EF Core (.NET):* `RowVersion`/concurrency token; ou stored procedure.
- *MongoDB:* `findOneAndUpdate` com filtro `{ counter: { $lt: limit } }` (atomico no documento); ou transacao multi-doc.

### 5.2 Camada B — UX de quota no cliente (conveniencia, nunca seguranca)

**Intencao:** comunicar consumo e limite de forma proativa, prevenir frustracao e impulsionar upgrade — **antes** de o usuario bater no erro do servidor.

**Componentes:**
- **Indicador de progresso** (barra/anel) por dimensao: `usado / limite`. Para ilimitado (`null`), mostrar "ilimitado" ou contagem sem barra — nunca dividir por `null`.
- **Thresholds com cor** (padrao de origem, generalizavel): **< 80% neutro/verde**, **>= 80% ambar (aviso)**, **>= 100% vermelho (bloqueio)**. Os percentuais sao defaults sensatos; tornem-nos configuraveis.
- **Banner/aviso** ao cruzar 80%: "Voce usou X de Y. Faltam Z." com CTA de upgrade.
- **Dialog de bloqueio** ao tentar exceder 100%: explica o limite, mostra o plano necessario e oferece upgrade — **sem** prometer que "ja liberou".
- **Tratamento gracioso do erro do servidor:** quando a Camada A rejeitar (ela e a autoridade), o cliente deve traduzir o erro de quota em uma mensagem clara e na mesma UX de upgrade — nunca um erro 500 cru.

**Regras de coerencia das duas camadas:**
- A UX **deve refletir** os mesmos limites/uso que a Camada A enforca (fonte unica de verdade dos limites; idealmente o cliente le o catalogo/uso de uma API, nao hardcoda numeros).
- A UX **nunca** decide sozinha permitir a operacao "porque o numero local diz que da". O servidor decide.
- Estados de carregamento/erro do uso: enquanto o uso nao carregou, **nao** afirme "voce tem espaco"; mostre carregando e deixe o servidor ser a barreira.

---

## 6. Pilar 2 — Catalogo de planos

**Intencao:** ter uma definicao **declarativa e versionada** de planos, precos, features e limites por dimensao, que seja a unica fonte de verdade tanto para o enforcement quanto para a UX.

**Modelo conceitual (adapte os nomes reais):**
- `plans` — `id`, `code` (ex.: `free`, `pro`, `enterprise`), `name`, `price`, `currency`, `interval` (mensal/anual), `gateway_price_id` (mapeia ao gateway), `active`, `trial_days`, `sort/visivel`.
- `plan_limits` (ou colunas no plano) — por **dimensao** (`projects`, `seats`, `api_calls`, `storage_gb`, ...): `limit_value` onde **`null` = ilimitado** (semantica documentada e testada).
- `plan_features` — flags booleanas/enums de capacidade (ex.: `sso`, `custom_domain`).

**PrincIpios:**
- **`null` = ilimitado** e uma convencao perigosa se mal-tratada. Padronize um unico significado, teste-o, e garanta que TODO leitor (enforcement + UX + relatorios) o interprete igual. Considere um sentinel explicito se a stack confundir `null`/ausente.
- **Mapeie para o gateway, nao duplique precos cegamente.** O catalogo local referencia o `price_id`/`plan_id` do gateway; a fonte de verdade do **valor cobrado** e o gateway. Divergencia entre catalogo local e gateway = achado (cobranca errada/receita perdida).
- **Versionamento e grandfathering:** clientes em planos antigos nao devem ser quebrados quando o catalogo muda. Mudancas de preco/limite precisam de estrategia (manter plano legado, migrar com aviso, etc.).
- **Planos de teste/sandbox** nunca podem ser ativaveis em prod.
- **Trial como propriedade do plano** (ex.: `trial_days`) ou do gateway — defina onde mora a verdade do trial e nao duplique.

**Equivalentes por stack:** tabela relacional (SQL) com FK do `subscription.plan_id`; documento/colecao (Mongo) com cuidado de consistencia; ou config declarativa (JSON/YAML versionado em codigo) sincronizada com o gateway no deploy. Em todos os casos, **um unico lugar** define limites.

---

## 7. Pilar 3 — Metricas de uso

**Intencao:** medir consumo por tenant e por dimensao, por periodo (tipicamente mes-calendario), para alimentar enforcement (quando o modelo for por janela) e UX.

**Modelo conceitual:**
- `usage_metrics` — `tenant_id`, `dimension`, `period` (ex.: inicio do mes via `date_trunc('month', now())`), `value`/`count`, `updated_at`. Unicidade por `(tenant_id, dimension, period)`.
- Dois regimes de quota, frequentemente coexistindo:
  - **Quota de estoque (concorrente):** "no maximo N existentes agora" (ex.: projetos ativos, seats). Enforcement conta linhas existentes; nao depende de janela.
  - **Quota de fluxo (por periodo):** "no maximo N por mes" (ex.: chamadas de API, emails enviados). Enforcement le/incrementa o contador da janela atual.

**Como agregar por periodo (ilustrativo, generalizavel):**
- *SQL (qualquer):* `date_trunc('month', occurred_at)` (Postgres) / `DATE_FORMAT(occurred_at,'%Y-%m-01')` (MySQL) / `DATETRUNC(month, occurred_at)` (SQL Server) como chave de janela.
- *Incremento atomico do contador:* `INSERT ... ON CONFLICT (tenant, dimension, period) DO UPDATE SET value = usage_metrics.value + 1` (upsert atomico) — evita corrida no contador.
- *Redis:* chave `usage:{tenant}:{dim}:{YYYYMM}` com `INCR` e `EXPIRE` no fim do periodo; reconciliar com duravel.

**Sub-atomico (armadilhas de tempo):**
- **Timezone:** `date_trunc` opera no timezone da sessao/coluna. UTC vs local muda a fronteira do mes -> uso atribuido ao mes errado. Padronize UTC ou o timezone do tenant, explicitamente.
- **DST e meses curtos/longos:** "now()+3d" e periodos ancorados na data de assinatura precisam de aritmetica de calendario correta (fim de mes, 31 -> meses sem dia 31).
- **Reset de janela:** quem zera/abre a janela nova? Se for "calculo on-read" (conta linhas do mes atual), nao precisa reset; se for contador materializado, precisa de job ou de chave por periodo. Misturar os dois regimes silenciosamente e bug.
- **Backfill e correcao:** se um evento de uso chega atrasado (webhook, fila), em qual periodo ele cai? Defina e teste.

**Quota de estoque vs metrica de uso:** para estoque, frequentemente nao se precisa de `usage_metrics` — basta contar as linhas no enforcement. Nao materialize contador que voce nao precisa (fonte de inconsistencia). Para fluxo, o contador materializado por periodo e quase obrigatorio por desempenho.

---

## 8. Pilar 4 — Maquina de estados de assinatura

**Intencao:** tornar o ciclo de vida da assinatura **deterministico, total e auditavel** — toda transicao tem gatilho, pre-condicao, efeito e registro.

**Estados canonicos (preserve os de origem; nomeie conforme seu gateway):**
- `trialing` — em periodo de teste; concede direitos do plano (ou de um plano de trial).
- `active` — pagante e em dia; concede todos os direitos.
- `past_due` — pagamento falhou; ainda concede direitos durante o **grace period** (dunning).
- `canceled` — encerrada; sem direitos pagos; tipicamente rebaixa para `free`/sem plano.
- Variantes comuns a considerar: `incomplete` (pagamento inicial pendente), `paused`, `expired`, `unpaid` (apos dunning sem sucesso).

**Transicoes principais (exemplos; mapeie ao seu gateway):**

| De | Para | Gatilho | Efeito |
|----|------|---------|--------|
| (novo) | `trialing` | signup com trial | concede direitos; agenda fim do trial |
| `trialing` | `active` | primeiro pagamento aprovado | mantem direitos; inicia cobranca |
| `trialing` | `canceled`/`free` | trial expira sem conversao | rebaixa; aviso previo |
| `active` | `past_due` | cobranca recorrente falha | mantem direitos no grace; inicia dunning |
| `past_due` | `active` | pagamento recuperado (retry/atualizacao de cartao) | encerra dunning |
| `past_due` | `canceled` | grace esgotado (ex.: 7+ dias) | auto-downgrade; revoga direitos pagos |
| `active`/`trialing` | `canceled` | cancelamento pelo usuario | encerra ao fim do periodo pago ou imediato (defina) |

**PrincIpios de maquina de estados:**
- **Totalidade:** defina o que acontece em CADA par (estado, evento). Eventos invalidos sao rejeitados e logados, nao aplicados silenciosamente.
- **Fonte de verdade vs espelho:** o gateway frequentemente e a verdade do estado de pagamento; o app **espelha** via webhook. Em conflito, defina quem vence (geralmente o gateway) e reconcilie. Nunca tenha o app e o gateway divergindo sem deteccao.
- **Idempotencia das transicoes:** o mesmo webhook reentregue NAO pode aplicar a transicao duas vezes. Use chave de idempotencia do evento e/ou transicao condicional (`UPDATE ... WHERE status = 'expected_from'`).
- **Direitos derivam do estado, nao o contrario.** `trialing` e `active` concedem; `past_due` concede no grace; `canceled` revoga. Centralize "este estado concede direito X?" em UM lugar consultado por enforcement e UX.
- **Cancelamento: imediato vs fim-de-ciclo.** Decisao de produto explicita; ambos exigem tratamento de contadores e direitos.
- **Reativacao:** voltar de `canceled` para `active` exige novo ciclo/assinatura — defina se reusa ou cria registro novo.

**Equivalentes por stack:** coluna `status` (enum) + tabela de transicoes; biblioteca de state machine (XState/TS, `aasm`/Ruby, Spring StateMachine, `transitions`/Python, Stateless/.NET); ou um orquestrador durável (Temporal/Step Functions) para o ciclo de dunning. Em todos, a transicao e atomica e auditada.

---

## 9. Pilar 5 — Jobs agendados (cron/scheduler) e dunning

**Intencao:** executar as transicoes dependentes de TEMPO (que webhook nao dispara): avisar trials a expirar, fazer auto-downgrade de inadimplencia, reconciliar com o gateway e registrar tudo.

**Jobs canonicos (preserve os de origem; generalize o agendador):**

1. **Aviso de trial a expirar.** Periodicidade diaria. Seleciona tenants com `status='trialing'` e fim de trial **na janela `now .. now+3d`** que ainda nao foram avisados; envia notificacao/email; marca como avisado (para idempotencia). Cuidado com a virada de mes na janela `now+3d`.
2. **Auto-downgrade de inadimplencia.** Diario. Seleciona `status='past_due'` ha **>= 7 dias** (grace esgotado); aplica transicao em **bulk** para `canceled`/`free`; revoga direitos; registra cada um em `billing_events`. Idempotente: rerodar nao re-cancela quem ja esta cancelado.
3. **Reconciliacao com o gateway.** Periodica. Compara estado local vs gateway; corrige divergencias (webhook perdido, evento fora de ordem); registra ajustes. Rede de seguranca para a entrega "at-least-once / pode-faltar" de webhooks.
4. **Reset/abertura de janela de uso** (se o modelo usar contador materializado por periodo). Caso o enforcement seja on-read por `date_trunc`, este job pode ser desnecessario — declare qual modelo voce usa.
5. **Cobranca de avisos intermediarios de dunning** (opcional): emails em D+1, D+3, D+5 antes do downgrade.

**Como implementar o agendador (espectro):**
- *`pg_cron` + `pg_net` (exemplo de origem):* agenda funcao SQL/HTTP no proprio banco. Forte acoplamento ao Postgres; bom quando a logica e SQL.
- *Cron do SO / Kubernetes CronJob:* invoca um endpoint/comando idempotente.
- *Cloud scheduler (EventBridge/Cloud Scheduler/Azure):* dispara função/fila.
- *Fila com worker (Sidekiq/Celery/BullMQ/Quartz/Hangfire):* enfileira a varredura; bom para volume e retry.
- *Workflow durável (Temporal/Step Functions):* ideal para o dunning multi-etapa por assinatura.

**Sub-atomico dos jobs (onde billing quebra de verdade):**
- **Idempotencia e reentrancia:** o job pode rodar duas vezes (overlap, retry, deploy). Toda acao deve ser segura para repeticao (transicao condicional, flag de "ja processado", chave de idempotencia).
- **Falha parcial em bulk:** se o downgrade em massa falha no meio, os ja processados nao podem ser refeitos e os faltantes devem ser pegos na proxima execucao. Processe em lotes com checkpoint; nunca "tudo ou nada" silencioso que perca progresso.
- **Janela de selecao correta:** `now .. now+3d` e `>= 7 dias` dependem do **relogio** e do **timezone**. Ancore no mesmo relogio (preferir o do banco) e teste fronteiras (exatamente 7 dias, 6d23h59m, DST).
- **Observabilidade:** todo job loga inicio/fim, quantos selecionados, quantos transicionados, quantos falharam, e duracao. Falha de job de cobranca = **alerta**. Job que nao roda (silenciosamente parado) e o pior caso — monitore "ultima execucao com sucesso".
- **Concorrencia com webhooks:** um webhook de pagamento recuperado pode chegar enquanto o job de downgrade roda. A transicao condicional (`WHERE status='past_due'`) evita cancelar quem acabou de pagar.
- **Volume/timeout:** com muitos tenants, o job nao pode estourar timeout nem travar o banco. Pagine; use `LIMIT`/lotes; evite lock global.

**Log de eventos de cobranca (`billing_events`):** append-only. Cada job e webhook escreve eventos com: `tenant_id`, `type` (ex.: `trial.warning_sent`, `subscription.downgraded`, `payment.failed`, `payment.recovered`, `plan.changed`), `from_status`/`to_status`, `actor` (`system:job`, `webhook:gateway`, `admin:<id>`, `user:<id>`), `correlation_id`/`idempotency_key`, `metadata` segura, `occurred_at`. E a base da auditabilidade e da reconciliacao.

---

## 10. Checklist exaustivo (sub-atomico)

### A. Enforcement no dado (Camada A)
- [ ] Existe uma barreira de quota **no proprio engine de dados** (policy/trigger/constraint/SP) ou, no minimo, um ponto unico transacional obrigatorio?
- [ ] Essa barreira e atomica sob concorrencia (testada com 2+ requisicoes simultaneas no limite `N-1`)?
- [ ] Roles/conexoes que **ignoram** a barreira (ex.: role `BYPASSRLS`, superuser, service role do backend) estao identificados e controlados?
- [ ] O comportamento "exatamente no limite" (`<` vs `<=`) esta definido e testado?
- [ ] `null`/ilimitado tem ramo proprio, distinto de "sem assinatura"/erro?
- [ ] Admin/console/jobs/scripts/integracoes tambem passam pela barreira (ou ha excecao consciente e auditada)?

### B. UX de quota (Camada B)
- [ ] Progress por dimensao; ilimitado tratado sem divisao por `null`.
- [ ] Thresholds (80% ambar / 100% vermelho, ou configurado) e cores corretos.
- [ ] Banner em >=80% e dialog de bloqueio em 100% com CTA de upgrade.
- [ ] Erro de quota do servidor traduzido em UX clara (nao 500 cru).
- [ ] UX le limites/uso da fonte de verdade (nao hardcoda numeros que divergem da Camada A).
- [ ] Estado de carregamento nao afirma "tem espaco" antes de saber.

### C. Catalogo de planos
- [ ] Definicao declarativa unica de planos/limites/features.
- [ ] `null` = ilimitado padronizado e testado em todos os leitores.
- [ ] Mapeamento para `price_id`/`plan_id` do gateway; sem divergencia de valor.
- [ ] Grandfathering/versionamento para mudancas de plano.
- [ ] Planos de teste nao ativaveis em prod.

### D. Metricas de uso
- [ ] Regime correto por dimensao: estoque (conta linhas) vs fluxo (contador por janela).
- [ ] Janela mensal via truncamento de data com timezone explicito.
- [ ] Incremento de contador atomico (upsert/`ON CONFLICT`/script Lua).
- [ ] Eventos de uso atrasados caem na janela correta (definido).
- [ ] Sem contador materializado desnecessario que possa divergir.

### E. Maquina de estados
- [ ] Estados e transicoes totais (todo par estado/evento definido).
- [ ] Direitos derivam do estado em UM lugar central (enforcement + UX consultam).
- [ ] Transicoes idempotentes e condicionais (`WHERE status='from'`).
- [ ] Conflito app vs gateway tem regra de quem vence + reconciliacao.
- [ ] Grace period de `past_due` definido; cancelamento imediato vs fim-de-ciclo decidido.

### F. Jobs agendados / dunning
- [ ] Job de aviso de trial (`now..now+3d`) idempotente e com marca de "avisado".
- [ ] Job de auto-downgrade (`>=7d past_due`) em lotes, idempotente, condicional.
- [ ] Job de reconciliacao com gateway.
- [ ] Cada job loga selecionados/transicionados/falhos/duracao; alerta em falha.
- [ ] Monitor de "ultima execucao com sucesso" (deteccao de job parado).
- [ ] Fronteiras de tempo (7d exatos, virada de mes, DST) testadas.

### G. Idempotencia, webhooks e reconciliacao
- [ ] Webhooks do gateway verificam assinatura e sao idempotentes (dedupe por event id).
- [ ] Eventos fora de ordem tratados (timestamp/sequencia do gateway).
- [ ] Retentativa do gateway nao duplica efeito (cobranca/transicao).
- [ ] Toda transicao/cobranca/downgrade gera evento em `billing_events`.

### H. Isolamento, seguranca e privacidade
- [ ] Quota/uso/estado de um tenant nunca vazam para outro (testado).
- [ ] Segredos de gateway/webhook mascarados; nunca em logs/cliente.
- [ ] Dados de cartao/PIX/conta nunca logados; PII minimizada.
- [ ] `billing_events` append-only (imutavel) com retencao definida.

---

## 11. Armadilhas e anti-padroes (gotchas concretos)

1. **Corrida no limite `N-1`.** `if (count() < limit) insert()` sem atomicidade deixa duas requisicoes simultaneas criarem o item `N+1`. Correcao: checar-e-inserir na mesma transacao com lock, ou `UPDATE counter WHERE counter < limit RETURNING`.
2. **UX tratada como enforcement.** "O botao some quando bate no limite" nao impede uma chamada direta a API. A barreira tem que estar no dado.
3. **Role que ignora a barreira.** O backend usa uma `service_role`/superuser que **ignora RLS** -> todo o enforcement de policy e contornado pelo proprio app. Mortal e comum. Use a barreira tambem para essa role (trigger/SP) ou nao use role privilegiada para escritas de quota.
4. **`null` ambiguo.** `null` significando ao mesmo tempo "ilimitado" e "sem plano" -> ou libera tudo (receita perdida) ou bloqueia tudo (cliente travado). Separe os ramos.
5. **Webhook nao idempotente.** Gateway reentrega o evento de pagamento e o app cobra/credita duas vezes, ou aplica downgrade duas vezes. Dedupe por event id.
6. **Job nao idempotente / overlap.** Duas execucoes simultaneas do downgrade cancelam e re-disparam emails. Use lock de job + transicao condicional.
7. **Job silenciosamente parado.** O scheduler morreu; trials nunca expiram, inadimplentes nunca caem -> receita vaza por meses sem ninguem notar. Monitore "ultima execucao com sucesso".
8. **Timezone no `date_trunc`.** Uso do dia 1 a meia-noite local cai no mes anterior em UTC -> contadores no mes errado, reset no dia errado.
9. **Grace mal modelado.** `past_due` que revoga direitos imediatamente gera churn involuntario (cliente cujo cartao falhou por 1 dia perde acesso). Defina e respeite o grace.
10. **Divergencia catalogo local x gateway.** Preco mudou no gateway mas o catalogo local mostra o antigo -> cobranca/expectativa errada. Gateway e a verdade do valor.
11. **Bulk "tudo ou nada".** Downgrade em massa que falha no item 5.000 e perde os 4.999 ja feitos (ou refaz tudo). Processe em lotes com checkpoint idempotente.
12. **Contar uso cruzando tenant.** `count(*)` sem filtrar o tenant na funcao de check -> limite de um afetado pelo uso de outro. Catastrofe de isolamento.
13. **Cancelamento que zera contador no momento errado.** Cancelar imediatamente e zerar uso antes do fim do ciclo pago pode dar acesso/limite indevido. Alinhe ao modelo de cancelamento.
14. **Trial sem fechamento.** Trial expira mas nada transiciona porque so havia UX -> cliente usa pago de graca indefinidamente. O job (Pilar 5) e quem fecha.

---

## 12. Modo AUDITAR — conformidade e classificacao

Quando o objetivo for auditar um subsistema existente, percorra os Pilares 1-5 e o checklist (Secao 10), e classifique cada achado.

### 12.1 Metodologia (multiplas passagens)
0. **Inventario:** detecte banco, ORM, gateway, scheduler, frameworks de UI. Localize: definicao de planos, tabela de assinatura/status, contadores de uso, funcao/policy/trigger de quota, handlers de webhook, definicoes de cron/jobs, log de eventos. Liste o que TEM e o que FALTA.
1. **Mapa do enforcement:** trace TODA via de escrita de cada dimensao limitada e verifique se passa pela barreira do dado. Identifique roles/conexoes que a ignoram.
2. **Concorrencia:** avalie atomicidade do check (corrida `N-1`).
3. **Catalogo e `null`:** confira semantica de ilimitado em todos os leitores e o mapeamento ao gateway.
4. **Uso e tempo:** regime por dimensao, timezone, atomicidade do contador.
5. **Maquina de estados:** totalidade, idempotencia, direitos centralizados, reconciliacao.
6. **Jobs:** idempotencia, janelas de tempo, observabilidade, deteccao de job parado.
7. **Webhooks/idempotencia/auditoria:** assinatura, dedupe, eventos.
8. **Isolamento/seguranca/privacidade.**
9. **Priorizacao e correcao + verificacao.**

### 12.2 Classificacao
Cada achado recebe:
- **Severidade:** critica | alta | media | baixa | informativa.
- **Prioridade:** P0 (bloqueia cobrar dinheiro real / corrige agora) | P1 | P2 | P3.
- **Confianca:** confirmada | provavel | suspeita | precisa de contexto.
- **Esforco:** baixo | medio | alto.

**Regra de ouro (P0 / critico):** enforcement de quota inexistente ou apenas no cliente; barreira contornavel pela role do proprio app; corrida que fura o limite; vazamento de quota/uso entre tenants; webhook/job nao idempotente que cobra/downgrada em duplicidade; job de cobranca silenciosamente parado; `null` ambiguo que libera tudo; segredo de gateway exposto. Qualquer um = bloqueio para cobrar em producao ate mitigado.

---

## 13. Formato obrigatorio da resposta

Adapte ao modo (CONSTRUIR vs AUDITAR), mantendo a estrutura.

### 13.1 Resumo executivo
3-8 linhas: maturidade do subsistema de billing/quota (**inexistente | inicial | parcial | intermediaria | boa | madura**); principais riscos (receita perdida, cobranca indevida, churn involuntario, vazamento de tenant); e o veredito preliminar (pronto-para-cobrar / com-ressalvas / NAO-pronto) com bloqueadores.

### 13.2 Mapa do estado atual
- Catalogo de planos e onde mora a verdade dos limites.
- Enforcement: que camada existe (dado/app/cliente) e por onde TODA escrita passa.
- Metricas de uso: regime e janela.
- Maquina de estados e jobs/cron existentes.
- Gaps principais e **exatamente quais arquivos/tabelas faltam** para concluir.

### 13.3 Achados / itens (formato fixo)
```
[ID] Titulo curto
- Pilar: enforcement-dado | ux-quota | catalogo | uso | estado | jobs | webhook/idempotencia | isolamento | outro
- Severidade: ___ | Prioridade: ___ | Confianca: ___ | Esforco: ___
- Localizacao: arquivo/tabela/funcao/job (mascare segredos)
- Evidencia: trecho minimo citado do que foi observado (ou "ausencia de X")
- Impacto: receita/cobranca/churn/seguranca; blast radius; quem e afetado
- Correcao: passo a passo concreto (constraint/trigger/policy/transacao/job)
- Exemplo de correcao: snippet/SQL/diff ilustrativo (adaptar ao projeto)
- Teste/validacao: como provar que ficou correto (teste de corrida, reentrega de webhook, fronteira de tempo, etc.)
```

### 13.4 Tabela consolidada
| ID | Pilar | Severidade | Prioridade | Confianca | Esforco | Resumo |
|----|-------|-----------|------------|-----------|---------|--------|

### 13.5 Especificacoes-alvo (modo CONSTRUIR)
- **Catalogo:** modelo de `plans`/`plan_limits`/`features` com semantica de `null`.
- **Enforcement:** mecanismo escolhido (policy/trigger/SP/transacao) + funcao de check + tratamento de concorrencia.
- **Uso:** schema de `usage_metrics`, regime por dimensao, janela e incremento atomico.
- **Estado:** diagrama/tabela de transicoes, direitos por estado, regra de reconciliacao.
- **Jobs:** lista de jobs, periodicidade, selecao, idempotencia, observabilidade.
- **UX:** componentes, thresholds, comportamento de erro/carregamento.
- **Auditoria:** schema de `billing_events`.

### 13.6 Plano em fases
- **Fase 0 — Bloqueadores (P0):** fechar furos de enforcement, isolamento, idempotencia antes de cobrar.
- **Fase 1 — Catalogo + enforcement no dado + uso.**
- **Fase 2 — Maquina de estados + webhooks idempotentes + `billing_events`.**
- **Fase 3 — Jobs/dunning + reconciliacao + observabilidade/alertas.**
- **Fase 4 — UX de quota + thresholds + upsell.**
- **Fase 5 — Hardening:** grandfathering, retencao, testes de corrida/tempo, runbooks.
Para segredos expostos, inclua **rotacao**.

### 13.7 Testes obrigatorios
Liste, com como rodar: corrida no limite `N-1` (concorrencia); exatamente-no-limite (`<`/`<=`); ilimitado (`null`); isolamento entre tenants; reentrega idempotente de webhook; rerun idempotente de job de downgrade; fronteiras de tempo (`now+3d` na virada de mes, `>=7d` exatos, DST); transicao invalida rejeitada; reconciliacao corrige divergencia; UX bloqueia e traduz erro de quota.

### 13.8 Checklist final (pronto-para-cobrar)
- [ ] Enforcement no dado, atomico, nao contornavel (nem pela role do app).
- [ ] Isolamento por tenant garantido e testado.
- [ ] `null`/ilimitado sem ambiguidade em todos os leitores.
- [ ] Catalogo unico; mapeado ao gateway sem divergencia.
- [ ] Uso por janela correto (timezone explicito, incremento atomico).
- [ ] Maquina de estados total; direitos centralizados; reconciliacao ativa.
- [ ] Webhooks e jobs idempotentes; eventos em `billing_events`.
- [ ] Jobs monitorados (deteccao de job parado) e com alerta de falha.
- [ ] UX de quota coerente com a Camada A; erro traduzido.
- [ ] Segredos mascarados/rotacionados; dados financeiros nunca logados.
- **VEREDITO:** pronto-para-cobrar / com-ressalvas / NAO-pronto + justificativa.

---

## 14. Regras de qualidade e auto-verificacao (antes de responder)

Confirme internamente:
- Cada achado/spec tem localizacao real, evidencia (ou "ausencia de"), impacto, correcao **e** teste/validacao — nada generico.
- Nao inventei tabelas/funcoes/jobs/planos/campos; diferenciei confirmado de provavel; declarei o que falta de contexto.
- Mantive a distincao sagrada: **enforcement no dado = seguranca; UX = conveniencia** — nunca tratei UX como barreira.
- Considerei concorrencia (corrida `N-1`), idempotencia (webhook/job), tempo (timezone/DST/janelas) e isolamento por tenant explicitamente.
- Padronizei a semantica de `null`/ilimitado e a verifiquei em todos os leitores.
- Mascarei todos os segredos; nao recomendei logar dados financeiros/PII; tratei `billing_events` como imutavel.
- Adaptei tudo a stack real detectada e, ao ilustrar, cobri multiplos ecossistemas deixando claro que sao exemplos.
- Cobri caminho feliz E de erro, por papel e por ambiente; nunca aceitei "parece ok" sem evidencia empirica.

**Criterio de aceite final:** a tarefa so esta concluida quando o subsistema (ou o plano para alcanca-lo) garantir que **nenhum tenant excede seu plano por nenhum caminho**, **todo cliente enxerga seu consumo**, **toda transicao de assinatura e correta/reversivel/auditada**, e **nenhuma receita e perdida ou cobrada indevidamente** — com testes que provem corrida, idempotencia, tempo e isolamento, ou com os gaps explicitamente documentados.

Faca o trabalho **como se dinheiro real fosse cobrado de clientes reais amanha de manha, e um unico furo de quota, um webhook duplicado ou um job parado virasse perda de receita ou um cliente cobrado errado.**
