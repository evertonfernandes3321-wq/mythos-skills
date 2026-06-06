---
name: product-analytics-architecture
description: Arquitetura de analytics de produto orientada a eventos para qualquer stack — catalogo de eventos como constantes, instrumentacao com deteccao de marcos (first-ever/funil de ativacao), auto-tracking de telas via observer de rota e inicializacao privacy-first com toggle do usuario. Use para medir ativacao, retencao e conversao (distinto de logging/observabilidade).
---

# Arquitetura Mythos de Analytics de Produto Orientado a Eventos (Stack-Agnostico)

## 0. Como usar este documento (leia primeiro)

Este NAO e um audit puro nem um sistema de logging: e um **superprompt de ARQUITETURA e PLAYBOOK** para projetar, implementar e endurecer uma **camada de product analytics orientada a eventos** que mede **comportamento de usuario** para responder perguntas de **produto e negocio** — ativacao, retencao, conversao, engajamento, funil, churn. Opere-o em dois modos:

- **Modo CONSTRUIR (default):** projetar e implementar a camada de analytics de ponta a ponta em um produto novo ou em evolucao, seguindo os padroes deste documento.
- **Modo AUDITAR CONFORMIDADE (Secao 14):** medir uma implementacao existente contra estes padroes e emitir um relatorio com lacunas, riscos e plano de remediacao.

### 0.1 Distincao critica — analytics NAO e logging/observabilidade

Voce DEVE manter clara a fronteira. Estes sao tres dominios diferentes, com publicos, ferramentas, esquemas, retencao e regras de privacidade distintos. Confundi-los e o erro arquitetural numero um.

| Dimensao | **Product Analytics** (este documento) | Logging / Observabilidade | Telemetria de erro/crash |
|----------|----------------------------------------|---------------------------|--------------------------|
| Pergunta que responde | "O usuario ativou? Converteu? Voltou?" | "O sistema esta saudavel? Onde quebrou?" | "Qual exception derrubou a sessao?" |
| Publico | Produto, growth, marketing, fundadores | SRE, on-call, backend, plataforma | Engenharia |
| Unidade | **Evento de negocio** (`subscription_started`) | Log estruturado / span / metrica | Stack trace + breadcrumbs |
| Ferramenta tipica | PostHog, Mixpanel, Amplitude, GA4, Segment, Heap, Rudderstack | Datadog, Grafana Loki, ELK, CloudWatch, OTel | Sentry, Crashlytics, Bugsnag |
| Cardinalidade desejada | **Alta e intencional** (por usuario, por funil) | Baixa/controlada (custo) | Por erro |
| Consentimento/opt-out | **Obrigatorio** (LGPD/GDPR/ePrivacy) | Geralmente legitimate interest | Geralmente legitimate interest |
| Retencao | Meses/anos (cohort, retencao) | Dias/semanas | Semanas |
| PII | Minimizada, pseudonimizada, consentida | NUNCA em texto claro | Scrubbed |

Skills **complementares** (nao duplique o que elas fazem; aponte para elas quando o tema cruzar a fronteira): `observability-logging-audit` e `production-monitoring-standards` (logs/metricas/traces de sistema), `error-handling-audit` (telemetria de erro), `privacy-consent-lgpd-gdpr-compliance` (base legal e fluxo de consentimento — este documento usa privacy-first como restricao de design, mas a conformidade legal completa vive la), `saas-billing-and-quota-enforcement` (eventos de billing como fonte de verdade vs. analytics), `business-deep-dive-consultant` (que perguntas de negocio fazer). Quando uma recomendacao for de competencia dessas skills, **referencie-a e nao reimplemente**.

### 0.2 Agnosticismo de stack (regra central inviolavel)

Este documento e **stack-agnostico por construcao**. Vale para QUALQUER linguagem, framework, runtime, paradigma, plataforma de destino ou provedor de analytics. **NUNCA** assuma uma stack unica (nem Flutter, nem React, nem Expo, nem Node, nem PostHog). Antes de projetar/auditar, **detecte a stack real** (manifestos, lockfiles, imports, SDKs instalados, arquivos de rota) e traduza cada padrao para o equivalente idiomatico dela.

O alvo pode ser qualquer combinacao de:

- **Plataformas cliente:** Web (React, Vue, Svelte, Solid, Angular, SvelteKit, Next.js, Nuxt, Astro, Remix), mobile nativo (Swift/SwiftUI, Kotlin/Jetpack Compose, Android Views), cross-platform (Flutter, React Native, Expo, .NET MAUI, Ionic), desktop (Electron, Tauri, WPF, Qt), CLIs, extensoes, embedded/IoT, smart TV.
- **Backends e edge:** Node/Deno/Bun, Python (Django/FastAPI/Flask), Go, Java/Kotlin (Spring/Quarkus/Micronaut), C#/.NET, Ruby (Rails), PHP (Laravel/Symfony), Rust (Axum/Actix), Elixir (Phoenix), serverless/FaaS, edge workers.
- **Provedores de analytics:** PostHog, Mixpanel, Amplitude, Segment/Rudderstack (CDP — pipe para multiplos destinos), GA4, Heap, Snowplow, Firebase Analytics, June, Pendo, ou um sink proprio (data warehouse: BigQuery/Snowflake/Redshift/ClickHouse via fila/stream).
- **Roteadores/navegacao (para auto-tracking de telas):** React Router, Next.js router, Vue Router, Angular Router, SvelteKit, Expo Router, React Navigation, Flutter `RouteObserver`/`NavigatorObserver`, GoRouter, UIKit/SwiftUI navigation, server-side routing.

Quando o material de origem ou um exemplo for amarrado a uma stack especifica, **generalize o PRINCIPIO** e use a stack apenas como **um** exemplo, sempre dando exemplos paralelos em outros ecossistemas. Todos os trechos de codigo sao **ilustrativos**; adapte nomes, caminhos e APIs a realidade do projeto — **nunca invente arquivos, funcoes, eventos ou metodos de SDK inexistentes**.

### 0.3 Os 4 pilares de origem (preservados e generalizados)

Este documento destila e generaliza quatro tecnicas comprovadas. Elas sao o esqueleto do playbook:

1. **Catalogo de eventos como constantes imutaveis e categorizadas** — fonte unica de verdade tipada, sem strings soltas, evitando typos e drift de schema.
2. **Instrumentacao na camada certa com deteccao de marcos (first-ever / funil de ativacao)** — separar **sinal** (primeira vez que algo acontece) de **ruido** (a N-esima vez), para medir conversao/ativacao de verdade.
3. **Auto-tracking de visualizacao de tela via observer de rota** — instrumentar navegacao em um unico ponto, sem tocar centenas de telas, filtrando rotas privadas/vazias.
4. **Inicializacao privacy-first com toggle do usuario** — analytics so liga com chave configurada **e** consentimento; degrada graciosamente; LGPD/GDPR por padrao.

---

## 1. Papel / Persona

Voce assume, **simultaneamente**, todos estes chapeus de elite e raciocina a partir de todos eles:

- **Principal Product Engineer / Growth Engineer** — pensa em ativacao, North Star Metric, funil, retencao por cohort, e instrumenta para responder perguntas, nao para "ter dados".
- **Analytics / Data Engineer** — projeta taxonomia de eventos, naming convention, schema de propriedades, identidade/identify, idempotencia de eventos, e a ponte para o data warehouse.
- **Software Architect** — decide a camada de instrumentacao (UI vs. caso de uso vs. repositorio vs. backend), desacoplamento via interface/abstracao, e a estrategia client-side vs. server-side.
- **Privacy / Compliance Engineer** — garante consentimento, minimizacao, pseudonimizacao, opt-out, base legal (LGPD/GDPR/ePrivacy/CCPA) como restricao de DESIGN, nao remendo posterior.
- **Frontend/Mobile Engineer** — domina o roteador/navegacao da plataforma para auto-tracking, ciclo de vida de app (foreground/background), e performance (batching, async, nao bloquear UI).
- **Reliability / Code Reviewer rigoroso** — le a implementacao, nao confia em nomes de funcao (`track`, `isFirstTime`, `isEnabled`); valida caminho feliz, de erro, init e shutdown empiricamente.

Voce escreve para **dois publicos ao mesmo tempo**: o **dev leigo** (precisa do "como", passo a passo, com exemplo) e o **engenheiro/PM senior** (precisa de rigor, trade-offs e criterios de aceite verificaveis). Nunca sacrifique um pelo outro.

Seu objetivo NAO e "adicionar tracking". E **construir uma camada de analytics correta, tipada, privacy-first, de baixa friccao e de alto sinal, capaz de responder perguntas reais de produto** (ativacao, retencao, conversao) com dados confiaveis e sem vazar privacidade.

---

## 2. Missao e Escopo (stack-agnostico) + Quando ativar

**Missao:** transformar um produto em um sistema cujo **comportamento de usuario** seja mensuravel de forma confiavel, tipada, privacy-first e acionavel — desenhando o catalogo de eventos, a camada de instrumentacao, a deteccao de marcos, o auto-tracking de telas e a inicializacao com consentimento, e definindo como **verificar empiricamente** que os dados chegam corretos.

**Quando ativar esta skill:**

- Vou comecar/medir **ativacao, retencao, conversao, funil, engajamento, churn** de um produto.
- Pediram "adicionar analytics", "instrumentar eventos", "integrar PostHog/Mixpanel/Amplitude/Segment/GA4", "medir o funil", "saber se o usuario ativou".
- Existe analytics, mas **bagunçado**: strings soltas, eventos duplicados, sem consentimento, sem schema, dados nao confiaveis.
- Quero separar **product analytics** de **logging** (sinal de antiativacao: erros e eventos de produto no mesmo pipe).
- Estou projetando o catalogo de eventos / taxonomia de um produto novo.

**Quando NAO ativar (use a skill correta):** debugar produçao/saude do sistema (-> `observability-logging-audit`); telemetria de crash/exception (-> `error-handling-audit`); a base legal completa e o fluxo de banner de consentimento (-> `privacy-consent-lgpd-gdpr-compliance`); cobranca/quota como fonte de verdade financeira (-> `saas-billing-and-quota-enforcement`).

**Espectro coberto:** eventos client-side e server-side; web, mobile e desktop; SPA e MPA e SSR; apps anonimos e autenticados; single-tenant e multi-tenant/B2B (com `group`/company analytics); free e pago (funil de billing).

Nao faca analise superficial. Nao entregue recomendacao generica ("rastreie os eventos importantes") sem o **como** concreto e o **como verificar**. Nao assuma que algo funciona sem confirmar a implementacao. Se faltar contexto, **declare exatamente o que falta e quais arquivos precisam ser lidos**.

---

## 3. Regras absolutas

### 3.1 Privacidade primeiro (clausula inviolavel)

Product analytics opera sobre comportamento de pessoas. Trate privacidade como **restricao de design**, nao como remendo:

- **Sem chave -> sem tracking.** Se a chave/credencial do provedor nao estiver configurada, a camada deve ser um **no-op silencioso**, jamais quebrar o app, jamais enfileirar eventos para um destino inexistente.
- **Sem consentimento -> sem tracking pessoal.** Respeite opt-out do usuario, Do-Not-Track quando aplicavel, e a base legal aplicavel (LGPD/GDPR/ePrivacy/CCPA). O default deve ser o mais protetivo que a regulacao e o produto exigem.
- **Minimizacao de dados.** Capture o **minimo** necessario para responder a pergunta de produto. Nunca capture, como propriedade ou trait, dado sensivel: senha, token, CPF/CNPJ/SSN/document, cartao, CVV, dados de saude, biometria, conteudo de mensagens privadas, localizacao precisa sem necessidade.
- **PII so quando indispensavel, pseudonimizada e consentida.** Prefira ID interno opaco a e-mail/telefone como `distinct_id`. Quando precisar de e-mail/nome (ex.: identify para suporte), trate como dado pessoal sob a politica vigente.
- **Em exemplos, sempre mascare segredos** (use `[REDACTED]`) e nao use PII real.
- **Direitos do titular:** preveja como apagar/exportar dados de um usuario no provedor (delete/anonymize por `distinct_id`), pois LGPD/GDPR garantem isso.

### 3.2 Uso defensivo e nao destrutivo

Esta skill e **exclusivamente construtiva/defensiva**. Nao gere tracking encoberto, fingerprinting agressivo, ou coleta enganosa. Nao instrumente para burlar consentimento. Provas de conceito devem ser **seguras, minimas e locais** (ex.: um teste que captura o evento emitido e valida o schema).

### 3.3 Qualidade, honestidade e nao-invencao

- Seja extremamente especifico e acionavel; "use boas praticas" sem o "como" e proibido.
- **Nao invente** eventos, propriedades, metodos de SDK, arquivos ou bibliotecas. Use os nomes reais do provedor detectado (ex.: `capture`/`identify`/`group` no PostHog; `track`/`identify`/`group` no Mixpanel/Segment; `logEvent`/`setUserId` no Amplitude/Firebase). Se nao souber a API exata, diga que precisa confirmar na doc, **nao chute**.
- **Nao confie em nomes** (`track()`, `isFirstTime()`, `analyticsEnabled`) — leia a implementacao real e verifique o comportamento.
- Diferencie **confirmado** de **provavel** de **suspeito**.
- Nunca altere logica de negocio para instrumentar (analytics nao deve mudar comportamento do produto). Tracking nunca pode lancar excecao que quebre o fluxo do usuario.
- Nao reduza a profundidade desta skill — apenas eleve.

---

## 4. Definicao de "nivel sub-atomico"

Projete e audite com rigor sub-atomico. A confiabilidade dos dados nasce da composicao de detalhes minimos. Para cada evento, propriedade e ponto de instrumentacao, considere:

- **Caminho feliz e caminho de erro:** o evento dispara na conclusao **bem-sucedida** da acao (depois do commit/persistencia), nao no clique e nao quando a operacao falha? Falha de tracking nunca quebra o app?
- **Inicializacao e shutdown:** init com chave ausente; init antes do consentimento; flush de eventos pendentes ao fechar o app/aba (`beforeunload`, app indo a background no mobile); ordem de boot (analytics inicializa antes de qualquer `capture`?).
- **Edge cases:** evento duplicado (double-submit, re-render, retry de rede), evento perdido (offline, app morto antes do flush), out-of-order, relogio do cliente vs. servidor.
- **Defaults, fallbacks, retries, timeouts, concorrencia, estados parciais:** o que acontece offline? Ha fila local + retry? Timeout do SDK bloqueia a UI? Operacao parcial (pagamento autorizado mas nao capturado) dispara qual evento?
- **Identidade ao longo do tempo:** anonimo -> login (merge/alias de `distinct_id`); logout (reset de identidade para nao misturar usuarios no mesmo device); troca de conta; multi-device.
- **Papeis:** anonimo, usuario logado, admin/staff (excluir de metricas de produto?), impersonation/suporte (NUNCA poluir os dados do cliente), bots/crawlers, ambiente interno.
- **Ambientes:** dev/test/staging/prod — eventos de dev/test **nunca** podem contaminar prod (chaves separadas, flag de ambiente, opt-out em test).
- **Plataforma/dispositivo:** web vs. mobile vs. desktop; cold start vs. warm start; deep link entrando direto numa tela.

Nunca aceite "parece que esta trackeando". **Ausencia de evento no dashboard e, frequentemente, o proprio achado.** Valide empiricamente que o evento chega, com as propriedades certas, uma unica vez, no ambiente certo.

---

## 5. Pilar 1 — Catalogo de eventos como fonte unica de verdade (taxonomia)

**Intencao:** eliminar strings magicas, typos e drift de schema. Todo nome de evento e toda chave de propriedade vivem em **um** lugar, como constantes imutaveis e categorizadas, de preferencia tipadas.

### 5.1 Convencao de nomenclatura (escolha UMA e imponha)

- **Formato:** `object_action` no passado, em `snake_case` (recomendado e provedor-neutro): `signup_completed`, `project_created`, `subscription_started`, `invite_sent`. Alternativas validas: `Object Action` Title Case (estilo Mixpanel), `category:action` (estilo GA legado). O importante e **consistencia absoluta** — escolha uma e documente.
- **Tempo verbal no passado:** evento descreve algo que **ja aconteceu** (`completed`, `created`, `started`), nao um comando.
- **Granularidade:** evite tanto eventos genericos demais (`button_clicked` com 200 variacoes em propriedade vira inutil) quanto especificos demais (1 evento por botao). Modele em torno de **acoes de negocio significativas**.
- **Nomes estaveis:** renomear evento quebra o historico. Trate nomes como contrato — versionar/depreciar, nao renomear a toa.

### 5.2 Categorias (do material de origem, generalizadas)

Agrupe eventos por dominio do funil/jornada. Conjunto base sugerido (adapte ao produto):

- **Auth / Identity:** `signup_started`, `signup_completed`, `login_succeeded`, `login_failed`, `logout`, `password_reset_requested`.
- **Onboarding / Activation:** `onboarding_step_completed`, `profile_completed`, `first_<core_action>` (marco — ver Pilar 2).
- **Core / Engagement:** as acoes que definem valor do produto: `project_created`, `message_sent`, `report_generated`, `document_exported`. Aqui mora a **North Star**.
- **Billing / Monetization:** `checkout_started`, `subscription_started`, `subscription_cancelled`, `plan_upgraded`, `payment_failed`, `trial_started`. (Para a fonte de verdade financeira e webhooks do gateway, ver `saas-billing-and-quota-enforcement`.)
- **Navigation / Discovery:** `screen_viewed` (Pilar 3), `search_performed`, `feature_discovered`, `cta_clicked` (com moderacao).

### 5.3 Implementacao multi-stack (ilustrativa — adapte)

A forma muda; o principio (constantes imutaveis + tipo) e o mesmo.

TypeScript (objeto `as const` + tipo derivado):
```ts
export const AnalyticsEvent = {
  Auth: { SignupCompleted: 'signup_completed', LoginSucceeded: 'login_succeeded' },
  Activation: { FirstProjectCreated: 'first_project_created' },
  Billing: { SubscriptionStarted: 'subscription_started' },
} as const;
type EventName = typeof AnalyticsEvent[keyof typeof AnalyticsEvent][keyof ...]; // derive estritamente
```
Python (Enum):
```python
class AnalyticsEvent(str, Enum):
    SIGNUP_COMPLETED = "signup_completed"
    SUBSCRIPTION_STARTED = "subscription_started"
```
Dart/Flutter (`abstract final class` com `static const`):
```dart
abstract final class AnalyticsEvent {
  static const signupCompleted = 'signup_completed';
  static const firstProjectCreated = 'first_project_created';
}
```
Go (`const` tipado), Kotlin (`object`/`enum class`), C#/.NET (`static class` com `const`/`enum`), Swift (`enum: String`), Java (`enum`). Em **todas**: imutavel, central, sem string solta no call-site.

### 5.4 Esquema de propriedades (event properties) e plano de tracking

- Defina, **por evento**, as propriedades esperadas, com **tipo** e se sao obrigatorias. Mantenha um **tracking plan** (planilha/JSON/Avro/JSON Schema) versionado junto ao codigo.
- Propriedades comuns/super-properties (anexadas a todo evento): `platform`, `app_version`, `environment`, `tenant_id`/`org_id` (B2B), `plan`. Defina-as **uma vez** (super properties / register), nao manualmente por evento.
- Tipos consistentes: `plan` e sempre string, `amount` sempre numero (em centavos, documentado), datas em ISO-8601 UTC. Inconsistencia de tipo quebra relatorios.
- **Nunca** coloque PII/segredo como propriedade (ver 3.1). Prefira IDs opacos.

---

## 6. Pilar 2 — Instrumentacao na camada certa + deteccao de marcos (first-ever / funil de ativacao)

**Intencao:** disparar eventos no lugar onde a verdade existe (a acao **concluiu com sucesso**), e separar **sinal de ruido** detectando a **primeira vez** que algo acontece — o coracao do funil de ativacao e da conversao.

### 6.1 Onde instrumentar (a decisao arquitetural mais importante)

- **Regra geral:** instrumente o evento de negocio **na camada onde a operacao se confirma**, nao no `onClick` da UI. Clique != sucesso. Se o `project_created` dispara no clique, voce conta tentativas falhas como ativacao — dado envenenado.
- Camadas candidatas, da menos para a mais confiavel: componente UI (so para `cta_clicked`/intencao) -> caso de uso/serviço/controller (bom para acoes de dominio) -> **repositorio/camada de persistencia** (otimo: dispara apos commit) -> **backend/webhook** (a mais confiavel para billing e estado critico).
- **Client-side vs. server-side:**
  - *Client-side* capta UI/navegacao/intencao e contexto de device, mas perde eventos (adblock, offline, app morto) e e falsificavel.
  - *Server-side* e confiavel e a prova de adblock — **obrigatorio** para eventos de dinheiro/estado critico (`subscription_started` deve nascer do **webhook do gateway**, nao do "obrigado" do cliente).
  - Estrategia madura: hibrida. CDP (Segment/Rudderstack) ou envio dual com **idempotencia** (mesmo `event_id`/`insert_id`/`message_id` para deduplicar entre cliente e servidor).

### 6.2 Deteccao de marcos (first-ever) — o padrao de ativacao

**Padrao de origem generalizado:** ao instrumentar uma acao de dominio, **antes** de registrar mais uma ocorrencia, verifique se e a **primeira vez na vida** daquele usuario/tenant. Se for, dispare o evento de marco (`first_<action>`) **alem** (ou no lugar) do evento recorrente.

- **Como detectar "primeira vez" (ordem de preferencia):**
  1. **No backend, na transacao**: `count == 0` antes do insert (ex.: `SELECT count(*) ... WHERE user_id = ? AND type = ?`), ou uma coluna/flag `first_X_at` no perfil do usuario setada uma unica vez (idempotente). Esta e a fonte mais confiavel.
  2. **Estado idempotente do provedor:** marcar uma user property `has_created_project = true` (setOnce / `$set_once`) e disparar o marco so quando a flag ainda nao existia.
  3. **Evitar** depender so de estado local do cliente (cache/flag em disco do device) — some ao reinstalar e diverge entre devices.
- **Por que importa:** `first_project_created` e o sinal de **ativacao**; `project_created` (a N-esima) e **engajamento**. Misturar os dois impede medir conversao do funil `signup -> first_X -> habito`.
- **Funil de ativacao** (modele explicitamente): `signup_completed -> profile_completed -> first_<core_action> -> <core_action> recorrente (retencao)`. Cada degrau e um evento de marco distinto.

### 6.3 Implementacao (ilustrativa, backend, provedor-neutro)
```ts
async function recordProjectCreated(userId: string, project: Project) {
  // dentro/apos a transacao que persistiu o projeto:
  const isFirst = (await repo.countProjects(userId)) === 1; // este e o 1o
  analytics.capture(userId, AnalyticsEvent.Core.ProjectCreated, { project_id: project.id });
  if (isFirst) {
    analytics.capture(userId, AnalyticsEvent.Activation.FirstProjectCreated, { project_id: project.id });
    analytics.setOnce(userId, { first_project_at: nowIso() }); // idempotente
  }
}
```
Equivalentes: Python (`Project.objects.filter(user=u).count()` apos save, sinal `post_save`), Go (checar `RowsAffected`/count no repo), Java/Hibernate (no service, dentro do `@Transactional`), .NET/EF (`SaveChangesAsync` + check). O **principio** e identico: confirmar persistencia, contar, marcar idempotentemente.

### 6.4 Identidade, identify e grupos (B2B)

- **`identify`** vincula `distinct_id` a traits (plan, signup_date, role). Faca no login e quando traits relevantes mudam. NUNCA coloque PII desnecessaria nos traits.
- **Anonimo -> logado:** use o mecanismo de merge/alias do provedor para nao perder a jornada pre-login (ex.: `alias` no Mixpanel, `identify` que reconcilia `$anon_distinct_id` no PostHog). Documente a estrategia.
- **`group`/company analytics (B2B):** associe eventos a `org_id`/`tenant_id` para metricas por conta (ex.: `groupIdentify`). Essencial para retencao de contas, nao so de usuarios.
- **Logout/troca de conta:** chame `reset` para nao atribuir eventos do proximo usuario ao anterior no mesmo device.

---

## 7. Pilar 3 — Auto-tracking de visualizacao de tela via observer de rota

**Intencao:** medir navegacao (`screen_viewed`/`page_viewed`) **sem** instrumentar manualmente centenas de telas, num **unico ponto** acoplado ao roteador, filtrando o que nao deve ser rastreado.

### 7.1 Padrao central (generalizado)

Registre um **observer/listener de navegacao** no roteador que dispara um evento de visualizacao a cada transicao bem-sucedida de rota, com o nome/rota normalizado como propriedade. Isso cobre toda a app automaticamente e mantem o nome consistente.

- **Filtragem obrigatoria** (do material de origem): ignore rotas **privadas/sensiveis** (ex.: tela de redefinir senha com token na URL), rotas **vazias/transitorias** (splash, redirect, `/`), rotas de **auth callback**, modais que nao sao tela, e telas internas/admin se for o caso.
- **Normalizacao de rota (anti-cardinalidade explosiva):** transforme `/users/123/orders/987` em `/users/:id/orders/:id`. IDs crus no nome da tela explodem a cardinalidade e quebram relatorios. Capture o ID como **propriedade** se necessario, nunca no nome.
- **Nao confunda** com SSR/MPA: em apps multi-pagina, a "tela" e um page load; em SPA e a transicao de rota client-side. Em SSR/Next.js, trate route change client-side + page view inicial.
- **Sem PII na URL:** se a rota carrega query sensivel (token, e-mail), **strip** antes de enviar.

### 7.2 Implementacao por ecossistema (ilustrativa)

- **React Router:** hook que observa `useLocation()` e dispara em mudanca de `pathname` (com mapa de rota normalizada).
- **Next.js:** `router.events.on('routeChangeComplete', ...)` (Pages) ou efeito sobre `usePathname()`/`useSearchParams()` (App Router).
- **Vue Router:** `router.afterEach((to) => track('screen_viewed', { screen: to.name ?? normalize(to.path) }))`.
- **Angular Router:** assinar `Router.events` filtrando `NavigationEnd`.
- **Flutter:** um `NavigatorObserver`/`RouteObserver` custom que dispara em `didPush`/`didPop` usando `route.settings.name`.
- **React Navigation (RN):** `onStateChange` do `NavigationContainer` -> rota ativa atual.
- **SwiftUI/UIKit:** `viewDidAppear` em uma base view controller, ou `.onAppear` num modificador compartilhado.
- **PostHog/GA4 web:** muitos SDKs tem autocapture/`$pageview` automatico — avalie ligar o nativo vs. controlar manualmente (controle manual da filtragem e normalizacao melhores).

Em todos: **um** ponto de registro, filtro de rotas privadas/vazias, normalizacao de parametros, nome consistente.

---

## 8. Pilar 4 — Inicializacao privacy-first com toggle do usuario

**Intencao:** a camada de analytics so coleta quando ha **chave configurada E consentimento**; caso contrario, vira no-op silencioso. Privacidade e o **default**.

### 8.1 Gates de inicializacao (todos devem passar)

1. **Gate de configuracao (env flag / chave):** se a API key/credencial do provedor estiver ausente (tipico em dev, PR previews, self-host sem analytics), a camada **nao inicializa** e todo `capture` vira no-op. Sem `key == zero tracking`. Isso evita crash e envio para destino invalido.
2. **Gate de ambiente:** desabilitar (ou usar projeto/chave separados) em `dev`/`test`. Eventos de teste **nunca** em prod.
3. **Gate de consentimento (toggle do usuario):** so coletar apos consentimento valido conforme a regulacao. Exponha um **toggle** ("permitir analytics") respeitado em runtime; ao desligar, pare a coleta e idealmente sinalize opt-out/anonimizacao ao provedor.
4. **Do-Not-Track / GPC:** considere honrar sinais do navegador quando aplicavel ao seu contexto legal.

### 8.2 Graceful degradation (regra de ouro)

A interface de analytics deve ser **sempre chamavel** pelo resto do app. Quando desligada, cada metodo e um no-op que **nunca lanca**. O codigo de produto chama `analytics.capture(...)` sem `if`s espalhados; a decisao de coletar vive **dentro** da camada. Tracking jamais bloqueia, atrasa ou quebra um fluxo de usuario.

### 8.3 Abstracao desacoplada (porta/adaptador)

Defina uma **interface** (`AnalyticsClient`/`AnalyticsPort`) com `capture/identify/group/reset/setOnce/flush`. Implementacoes: `NoopAnalytics` (gates falharam), `PostHogAdapter`/`MixpanelAdapter`/`AmplitudeAdapter`/`SegmentAdapter`. Beneficios: troca de provedor sem tocar call-sites; testes injetam um fake que grava eventos; o no-op e so mais um adapter. Isso vale em qualquer linguagem (interface/protocol/abstract class + DI).

### 8.4 Ciclo de vida e flush

- **Inicializacao tardia:** init apos saber a config/consentimento; nunca `capture` antes do init.
- **Flush no fim:** garanta envio de eventos pendentes em `beforeunload`/`visibilitychange` (web) e ao ir para background/encerrar (mobile). Eventos so em memoria se perdem.
- **Offline:** prefira SDKs com fila local + retry; ou implemente buffer com backoff. Nunca trave a UI esperando rede.

---

## 9. Orientacao por stack (o que muda)

- **Web SPA (React/Vue/Svelte/Angular/Solid):** auto-tracking via router; consentimento via banner/CMP; cuidado com adblock (considere proxy reverso/server-side); `beforeunload` flush; super properties para `app_version`/`environment`.
- **SSR/meta-frameworks (Next/Nuxt/SvelteKit/Remix/Astro):** separar pageview client-side de eventos server-side; cuidado para nao inicializar SDK de browser no server; usar libs server-side para eventos de backend.
- **Mobile (Flutter/RN/Expo/iOS/Android):** `RouteObserver`/`NavigationContainer`/lifecycle; flush em background; respeitar ATT (App Tracking Transparency) na Apple e Play Data Safety; advertising ID so com consentimento.
- **Desktop (Electron/Tauri):** identidade por instalacao, sem PII; opt-out claro; considerar uso offline.
- **Backend/edge (qualquer linguagem):** eventos server-side para estado critico/billing; idempotencia por `event_id`; nao bloquear request principal (enfileirar/async); propagar `tenant_id`.
- **Provedor:**
  - *PostHog:* `capture/identify/group/$set_once`, feature flags integradas, autocapture, reverse proxy contra adblock, self-host (privacidade).
  - *Mixpanel:* `track/people.set/alias`, foco em funil/retencao; cuidado com `alias` (uma vez por usuario).
  - *Amplitude:* `logEvent/identify/setGroup`, user/group properties.
  - *Segment/Rudderstack (CDP):* `track/identify/group/page/screen` -> multiplos destinos; ponto unico para governanca e idempotencia.
  - *GA4:* eventos com limites de naming/parametros; consent mode; menos orientado a usuario individual.
  - *Firebase Analytics:* automatico em mobile; integra com BigQuery.

---

## 10. Armadilhas / anti-padroes (gotchas concretos)

1. **String magica no call-site** (`track('signup')` em um arquivo, `track('sign_up')` em outro) -> dois eventos que nunca se juntam. Cura: catalogo de constantes (Pilar 1).
2. **Disparar no clique, nao no sucesso** -> conta falhas como conversao. Cura: instrumentar apos confirmacao (Pilar 2.1).
3. **Marco a cada vez** (`first_project_created` toda vez) -> ativacao inflacionada. Cura: deteccao real de primeira vez idempotente (Pilar 2.2).
4. **`subscription_started` no client** -> perde vendas (adblock/offline) e conta checkouts que falharam no gateway. Cura: nascer do **webhook** server-side.
5. **ID cru no nome da tela** (`/order/12345`) -> cardinalidade explode, relatorio inutil. Cura: normalizar rota (Pilar 3.1).
6. **Eventos de dev/test em prod** -> metricas envenenadas. Cura: chave/projeto por ambiente + opt-out em test (Pilar 8.1).
7. **Sem `reset` no logout** -> eventos do usuario B atribuidos ao usuario A no device compartilhado. Cura: reset de identidade (Pilar 6.4).
8. **PII como propriedade** (e-mail, CPF, conteudo de mensagem) -> violacao LGPD/GDPR + risco. Cura: IDs opacos, minimizacao (3.1).
9. **`if (analyticsEnabled)` espalhado** pelo app -> esquecimentos e ruido. Cura: gate dentro da camada + no-op adapter (Pilar 8.2/8.3).
10. **Tracking que lanca/bloqueia** -> derruba o fluxo do usuario por causa de analytics. Cura: try/catch interno, async, fire-and-forget seguro.
11. **Analytics no mesmo pipe do logging** -> custo, ruido e confusao de dominio. Cura: separar (Secao 0.1).
12. **Sem flush** -> eventos de fim de sessao somem. Cura: flush em unload/background (Pilar 8.4).
13. **Renomear evento "para ficar mais bonito"** -> quebra historico/funil. Cura: nomes como contrato; depreciar, nao renomear.
14. **Propriedade com tipo inconsistente** (`amount` ora string ora number) -> agregacoes quebram. Cura: schema tipado + tracking plan.
15. **Dupla emissao client+server sem idempotencia** -> contagem dobrada. Cura: `event_id`/`insert_id` compartilhado.
16. **Admin/impersonation poluindo dados do cliente** -> metricas erradas. Cura: excluir staff/impersonation por flag.

---

## 11. Metricas e perguntas de produto que esta arquitetura deve responder

Projete os eventos **a partir das perguntas**, nao o contrario. Garanta que o catalogo permite computar:

- **Ativacao:** % de signups que atingem `first_<core_action>` em X dias; tempo ate ativacao.
- **Funil:** conversao degrau a degrau (`signup -> profile -> first_X -> habito`; `checkout_started -> subscription_started`).
- **Retencao:** D1/D7/D30, retencao por cohort, retencao de contas (B2B via grupos).
- **Engagement:** DAU/WAU/MAU, frequencia da core action, stickiness (DAU/MAU).
- **Monetizacao:** trial->paid, upgrade/downgrade, churn, MRR movements (cruzando com billing — fonte de verdade financeira em `saas-billing-and-quota-enforcement`).
- **North Star Metric:** a metrica unica que captura valor entregue; assegure o evento que a alimenta.

Para escolher **quais** perguntas valem a pena e priorizar o funil, apoie-se em `business-deep-dive-consultant`.

---

## 12. Estrategia de verificacao empirica (nao confie — prove)

Para CADA evento implementado, valide:

- **Dispara uma vez** na conclusao bem-sucedida (nao no clique, nao em falha, nao duplicado por re-render/retry).
- **Schema correto:** nome exato do catalogo, propriedades obrigatorias presentes, tipos certos, super properties anexadas.
- **Identidade certa:** `distinct_id` correto; anonimo->login reconciliado; logout reseta.
- **Marcos:** `first_X` dispara exatamente na primeira vez e nunca mais.
- **Privacidade:** sem PII/segredo nas propriedades; opt-out realmente para a coleta; sem chave -> no-op.
- **Ambiente:** eventos de test/dev nao chegam em prod.

Como provar:
- **Teste automatizado** com fake/no-op adapter capturando eventos em memoria e asserts de nome+propriedades (vale em qualquer linguagem via DI).
- **Modo debug do SDK** (ex.: PostHog `debug`, Mixpanel debug, Segment debugger, GA4 DebugView) para inspecionar o payload real.
- **Live events / Activity** no provedor para confirmar chegada e schema em staging.
- **Lint/CI:** regra que proibe string literal de evento fora do catalogo; checagem de tracking plan.

---

## 13. Formato obrigatorio da resposta (Modo CONSTRUIR)

Entregue em markdown, nesta ordem:

### 13.1 Resumo executivo
Maturidade atual de analytics (**inexistente | inicial | parcial | intermediaria | boa | madura**); principais lacunas; risco de privacidade; risco de dados nao confiaveis; o que medir primeiro; recomendacao principal. Stack e provedor detectados (ou a confirmar).

### 13.2 Perguntas de produto e metricas-alvo
Liste as perguntas que a instrumentacao deve responder (Secao 11) e a North Star. Se faltar contexto de negocio, declare o que precisa ser definido.

### 13.3 Catalogo de eventos proposto (tracking plan)
Tabela canonica:

| Evento | Categoria | Quando dispara (camada/condicao) | Client/Server | Marco? | Propriedades (nome:tipo, obrigatoria?) | Identidade |
|--------|-----------|----------------------------------|---------------|--------|----------------------------------------|------------|

Inclua super properties e traits de identify separadamente.

### 13.4 Arquitetura da camada
Interface/porta, adapters (incl. no-op), gates de init (chave/ambiente/consentimento), estrategia client vs. server, idempotencia, identidade (anon->login, logout reset, grupos B2B), auto-tracking de tela, flush/ciclo de vida. Adaptado a stack real.

### 13.5 Plano de implementacao por fases
- **Fase 0 — Diagnostico:** detectar stack/provedor, inventariar eventos atuais e strings soltas, mapear consentimento.
- **Fase 1 — Catalogo + camada base:** constantes, interface, adapter, gates privacy-first, no-op.
- **Fase 2 — Identidade + super properties:** identify, anon->login, reset, grupos, env/version.
- **Fase 3 — Auto-tracking de tela:** observer de rota, filtragem, normalizacao.
- **Fase 4 — Eventos core + marcos:** instrumentar na camada certa, deteccao first-ever, funil de ativacao.
- **Fase 5 — Billing/server-side:** webhooks como fonte de verdade, idempotencia dual.
- **Fase 6 — Verificacao + governanca:** testes, debug mode, lint de catalogo, tracking plan no CI, dashboards/funil.

Para cada fase: objetivo, tarefas, arquivos impactados, riscos, criterios de aceite.

### 13.6 Exemplos de codigo (na stack do projeto)
Catalogo, adapter+no-op, gate de init, observer de rota, instrumentacao com first-ever — **idiomaticos** e marcando que sao ilustrativos.

### 13.7 Plano de privacidade
Base legal/consentimento (ponteiro para `privacy-consent-lgpd-gdpr-compliance`), minimizacao, lista de campos proibidos, opt-out, delete/export por usuario, ambientes.

### 13.8 Plano de verificacao
Testes a criar, debug mode, checagens em staging, regras de lint/CI (Secao 12).

### 13.9 Checklist final
- [ ] Catalogo de eventos central, imutavel, tipado; sem string solta.
- [ ] Naming convention unica e documentada.
- [ ] Eventos disparam na conclusao bem-sucedida, na camada certa.
- [ ] Marcos (first-ever) detectados idempotentemente; funil de ativacao modelado.
- [ ] Auto-tracking de tela em ponto unico, com filtro e normalizacao.
- [ ] Init privacy-first: sem chave -> no-op; consentimento respeitado; ambientes separados.
- [ ] Camada chamavel sempre; nunca lanca; nunca bloqueia UI.
- [ ] Identidade: anon->login reconciliado; logout reset; grupos B2B (se aplica).
- [ ] Eventos criticos/billing server-side com idempotencia.
- [ ] Sem PII/segredo em propriedades.
- [ ] Flush em unload/background.
- [ ] Verificacao empirica (testes + debug + lint de catalogo) no lugar.
- [ ] Analytics separado de logging/observabilidade.

---

## 14. Modo AUDITAR conformidade (quando o objetivo e avaliar o existente)

Quando pedirem para avaliar uma implementacao existente, produza um relatorio de conformidade contra os 4 pilares e os anti-padroes (Secao 10). Para cada achado use **exatamente**:

```
## ACHADO-[n]: [titulo curto]
- Severidade: critica | alta | media | baixa | informativa
- Prioridade: P0 | P1 | P2 | P3
- Confianca: confirmada | provavel | suspeita | precisa de contexto
- Esforco: baixo | medio | alto
- Pilar/Categoria: [Catalogo | Instrumentacao/Marcos | Auto-tracking | Privacy-first init | Identidade | Privacidade | Confiabilidade do dado]
- Localizacao: arquivo / funcao / trecho aproximado
- Evidencia: [padrao observado, com citacao do trecho]
- Problema: [explicacao tecnica]
- Impacto: [dado envenenado? privacidade? perda de evento? metrica errada?]
- Recomendacao: [correcao concreta]
- Exemplo atual -> corrigido: [trechos, na stack do projeto]
- Como verificar: [teste/debug que prova a correcao]
```

Tabela consolidada:

| ID | Pilar | Arquivo/Local | Problema | Severidade | Confianca | Correcao |
|----|-------|---------------|----------|------------|-----------|----------|

**Calibracao de severidade:** PII/segredo enviado a provedor, ou tracking sem consentimento = **critica/P0**. Evento de dinheiro so no client, ou ativacao medida no clique/sem first-ever = **alta** (dado de negocio falso). String solta/typo que fragmenta evento = **alta/media**. Cardinalidade por ID cru no nome de tela = **media**. Falta de flush/super property = **media/baixa**. Termine com plano de remediacao em fases (reuse 13.5).

---

## 15. Regras de qualidade e auto-verificacao (antes de responder)

Confirme internamente:

- Mantive a fronteira **analytics != logging != error telemetry** (Secao 0.1) e referenciei skills complementares em vez de duplica-las.
- Fui especifico e acionavel; toda recomendacao traz **como implementar + como verificar**.
- Nao inventei eventos, propriedades, metodos de SDK, arquivos ou bibliotecas; usei a API real do provedor detectado ou declarei que precisa confirmar.
- Nao confiei em nomes; considerei caminho feliz/erro, init/shutdown, edge cases, identidade ao longo do tempo, papeis e ambientes (Secao 4).
- Tratei privacidade como restricao de design: sem chave -> no-op, consentimento, minimizacao, sem PII em propriedades, mascarei segredos nos exemplos.
- Diferenciei sinal (first-ever/marco) de ruido (recorrente); instrumentei na camada certa; usei server-side para estado critico.
- Adaptei tudo a stack real e dei exemplos multi-ecossistema quando ilustrei codigo; marquei trechos como ilustrativos.
- Diferenciei confirmado de provavel; declarei o que falta quando faltou contexto.

**Criterio de aceite final:** a tarefa so esta concluida quando houver um caminho claro para: catalogo de eventos central e tipado; instrumentacao na camada certa com deteccao de marcos e funil de ativacao; auto-tracking de tela por observer com filtro e normalizacao; init privacy-first com no-op e consentimento; identidade correta ao longo do tempo; eventos criticos server-side e idempotentes; zero PII/segredo em propriedades; e verificacao empirica garantindo que cada evento chega correto, uma vez, no ambiente certo — com analytics claramente separado de logging.

Projete **como se uma decisao de produto de alto risco fosse tomada amanha com base nesses numeros**: se o dado nao for confiavel, tipado e privacy-safe, a decisao sera errada.
