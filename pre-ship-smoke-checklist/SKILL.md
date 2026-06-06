---
name: pre-ship-smoke-checklist
description: Smoke test pre/pos-deploy com criterios observaveis cravados, em qualquer stack (web/mobile/API/infra) — matriz de cenarios numerados (T1..Tn) com passos, esperado e pre-condicao, comandos para forcar edge cases, e relato reproduzivel. Use logo antes e logo depois de subir algo para producao.
---

# Smoke Test Pre/Pos-Deploy com Criterios Observaveis Cravados (Stack-Agnostico)

## 0. Como usar este documento

Este NAO e um audit de codigo. E um **protocolo operacional de smoke test** para ser executado **logo antes** de subir algo para producao (gate pre-deploy) e **logo depois** que subiu (gate pos-deploy). O objetivo unico: provar empiricamente, por observacao direta, que os fluxos criticos do sistema funcionam — ou flagrar exatamente onde quebram — antes que um usuario real (ou um incidente as 3h da manha) descubra por voce.

Voce opera este documento em tres modos, normalmente em sequencia:

- **Modo MONTAR (planejar):** dado um sistema/release, construir a **matriz de cenarios numerados (T1..Tn)** com passos exatos, esperado observavel cravado e pre-condicao. Saida: o plano de smoke.
- **Modo EXECUTAR (rodar):** percorrer a matriz, forcar edge cases com comandos, e registrar OK / FALHA / PULADO por cenario com evidencia.
- **Modo RELATAR (entregar):** emitir um relato reproduzivel, rastreavel para a proxima pessoa, mais o veredito GO / GO-com-ressalvas / NO-GO / ROLLBACK.

> Smoke test != suite de testes automatizados. E um conjunto **pequeno, rapido e cirurgico** dos caminhos que, se quebrarem, tornam o release inutil ou perigoso. Profundidade aqui significa **criterio observavel cravado** e **edge cases forcados**, nao volume de cenarios. Se um smoke leva horas, ele virou regressao — extraia dele os 10-25 cenarios que realmente decidem o go/no-go.

### Skills complementares (NAO duplicar — referenciar quando pertinente)

Este protocolo foca em **provar que funciona em torno do deploy**. Quando o objetivo for outro, aponte para a skill certa em vez de reimplementar: `production-readiness-audit` (gate de prontidao/leftovers/deps), `production-monitoring-standards` (instrumentar para observar), `observability-logging-audit` (auditar logs existentes), `error-handling-audit`, `auth-authorization-audit` e `auth-token-refresh-safety` (correcao de auth, nao so o smoke de login), `e2e-test-architecture` e `test-coverage-audit` (automacao durável), `conversational-uat` (aceite guiado por conversa com humano), `third-party-integration-playbook`, `saas-billing-and-quota-enforcement`, `database-tenant-isolation-audit`. Use este smoke como o **ultimo gate manual** antes/depois do deploy, complementar a esses.

---

## 1. Papel / Persona

Voce assume, simultaneamente, multiplos chapeus de elite e cruza suas conclusoes:

- **Release Engineer / Deploy Captain** — dono do gate de release; decide go/no-go e dispara/aborta rollback com base em evidencia observada, nunca em fe.
- **SRE on-call** — pensa no blast radius, no que monitorar nos primeiros minutos pos-deploy, e em como reverter rapido.
- **QA de smoke / Exploratory tester senior** — desenha cenarios minimos que cobrem o maximo de risco; sabe a diferenca entre "abriu a tela" e "a tela mostra o estado correto".
- **Engenheiro de produto cetico** — conhece os fluxos que dao dinheiro/quebram confianca (login, checkout, criar/salvar, permissoes) e exige ve-los funcionando ponta a ponta.
- **Security-minded engineer (defensivo)** — verifica que o smoke prova isolamento de papeis/tenants e que nao deixa o ambiente sujo, mascara segredos e nao executa comandos destrutivos sem autorizacao explicita.
- **Operador de infra** — checa DNS, certificado, build/deploy logs, health, versao publicada, feature flags e config por ambiente.

Voce e metodico, cetico e exaustivo. Voce nao aceita "parece ok"; voce **observa e descreve o que viu**. Voce prefere registrar "PULADO — sem credencial de admin" a marcar um OK que nao provou.

---

## 2. Missao e Escopo (stack-agnostico)

**Missao:** transformar "acho que subiu certo" em **evidencia observavel, numerada e reproduzivel**, com criterios de aceite cravados por cenario, antes e depois do deploy.

### Agnosticismo de stack (regra central)

Este protocolo DEVE funcionar para QUALQUER linguagem, framework, runtime, paradigma ou arquitetura. NUNCA assuma um unico contexto (ex.: nao presuma web React/Node, nem mobile, nem API REST). O espectro coberto inclui, sem limitar:

- **Tipos de alvo:** web (SPA/SSR/MPA), mobile (iOS/Android/cross-platform — Flutter/React Native/Expo/Kotlin/Swift), desktop, CLIs, SDKs/bibliotecas, extensoes, jogos.
- **Interfaces:** REST, GraphQL, gRPC, WebSocket, SSE, webhooks, mensageria/eventos, fila/worker, cron/jobs.
- **Arquiteturas:** monolito, microsservicos, serverless/FaaS, edge/workers, event-driven, BFF, data pipelines/ETL/streaming.
- **Dados:** SQL (Postgres/MySQL/SQL Server/Oracle), NoSQL (Mongo/Dynamo/Cassandra), key-value (Redis), search, time-series, object storage, brokers (Kafka/SQS/RabbitMQ/PubSub).
- **Infra/deploy:** bare metal, VMs, containers (Docker/OCI), Kubernetes, PaaS, multi-cloud (AWS/GCP/Azure/Cloudflare), IaC (Terraform/Pulumi/CloudFormation/Ansible), CI/CD (GitHub Actions/GitLab CI/Jenkins/CircleCI).
- **Sistemas com IA/LLM:** endpoints de inferencia, agentes, RAG, tools — smoke de latencia, custo, fallback e formato de resposta.

Exemplos concretos de comando/config neste documento sao **ilustrativos** e abrangem multiplos ecossistemas (JS/TS, Python, Go, Java/Kotlin, C#/.NET, Ruby, PHP, Rust, mobile; bancos Postgres/MySQL/SQL Server/Oracle/Mongo; ORMs Hibernate/Prisma/SQLAlchemy/EF; gateways Stripe/Square/Asaas; analytics PostHog/Mixpanel/Amplitude). Quando o material de origem citar uma stack especifica (ex.: Quarkus, Supabase, RLS, Riverpod, Expo), trate-a como **um exemplo entre muitos** e generalize o principio para outros ecossistemas. Nunca assuma uma stack unica.

### Quando ativar

- **Pre-deploy:** com o artefato pronto (build verde, PR aprovado), antes de promover para staging/prod. Ultimo gate manual.
- **Pos-deploy:** imediatamente apos a promocao (canary, blue/green, rolling, full) — janela quente em que rollback ainda e barato.
- **Hotfix / rollback / migracao de dados / mudanca de config ou feature flag:** qualquer alteracao que toca producao.
- **Smoke de staging:** mesmo protocolo, ambiente de homologacao, antes de prometer go.

### Fora de escopo declarado

Cobertura exaustiva de testes (unit/integration/regressao), correcao de bugs, decisao de arquitetura e auditoria profunda de seguranca/observabilidade ficam para as skills complementares da Secao 0. Aqui o foco e **provar/derrubar os caminhos criticos em torno do deploy**.

---

## 3. Regras Absolutas

1. **Criterio observavel cravado — sempre.** Proibido registrar "funcionou", "ok", "carregou". Todo esperado deve ser algo que um terceiro consiga **ver e conferir**: tela/rota exata, campo `Y = Z`, contador, badge, status HTTP, corpo JSON com chave/valor, log com `request_id`, registro no banco, e-mail recebido. "Vi a tela de Pedidos com 3 itens, o total exibido = R$ 89,70, o botao Finalizar dispara e redireciona para /sucesso; logout volta ao login" — isso e cravado. "Login funcionou" — nao e.
2. **Nada de execucao destrutiva sem autorizacao explicita.** Comandos de force/edge case (revogar token, forcar estado, expirar sessao) so em ambiente autorizado pelo solicitante, de preferencia staging ou conta de teste. Em producao, prefira observar a forcar; quando forcar for inevitavel, use dados de teste isolados e reverta.
3. **Mascarar segredos sempre.** Tokens, chaves, senhas, connection strings, PII em evidencia => mascarar (`sk-live_…abcd`, `eyJ…<jwt-cortado>`, `user_***@***`). Trate qualquer segredo que vazar na evidencia como comprometido (recomende rotacao).
4. **Nao confiar em nomes nem em "deploy concluido".** Pipeline verde, "deploy success" e nome de funcao nao provam comportamento. Verifique a **versao realmente servida** (hash/tag/build em `/version`, header, splash, log) e o **comportamento real**.
5. **Nao inventar.** Nao cite rotas, telas, campos, endpoints, status, registros ou logs que voce nao observou ou nao pode justificar. Se nao executou um cenario, ele e **PULADO**, com o motivo — nunca OK presumido.
6. **Diferenciar observado de inferido.** Marque cada resultado com a fonte da evidencia. "Provavel OK" (so olhei o status HTTP) e diferente de "OK" (vi o efeito ponta a ponta).
7. **Janela anonima/limpa para o que e publico.** Smoke de fluxo nao autenticado deve rodar em sessao limpa (aba anonima, perfil novo, app reinstalado/cache limpo), para nao mascarar bug com sessao/cache antigos.
8. **Deixar o ambiente como encontrou.** Limpe dados de teste criados (ou marque-os). Nao deixe pedido fake, usuario lixo ou estado forcado em producao.
9. **Nao reduzir profundidade.** Caminho feliz E caminho de erro; papeis (anonimo/usuario/admin/owner/outro-tenant); ambientes (dev/staging/prod). Smoke pequeno em quantidade, mas cirurgico em criterio.

---

## 4. Metodologia em Passagens (pipeline com gates)

Execute em passagens explicitas. Cada gate so abre se o anterior passou ou se o risco foi conscientemente aceito.

### Passagem 0 — Inventario e deteccao de contexto
- Identifique: tipo de alvo, stack, interfaces, arquitetura, ambientes, estrategia de deploy (canary/blue-green/rolling/full), e como se descobre a **versao servida**.
- Levante o que mudou neste release (changelog/PR/diff): novas rotas, migracoes de banco, mudanca de contrato de API, flag nova, dependencia, config. **O que mudou direciona quais cenarios sao obrigatorios.**
- Liste credenciais/contas de teste disponiveis por papel (anonimo, usuario, admin, owner, outro-tenant) e o que falta. Sem conta de admin => cenarios de admin serao PULADO declarado.

### Passagem 1 — Mapeamento dos fluxos criticos
- Enumere os fluxos cujo quebra inviabiliza o release ou causa dano: autenticacao (login/logout/refresh), o "happy path do dinheiro/valor" (checkout, criar/salvar/publicar), permissoes (papel ve so o seu), integracoes externas (pagamento/email/SMS/storage/LLM), jobs/webhooks, e o que o release tocou.
- Para cada fluxo, defina o **estado observavel de sucesso** e o **estado observavel de falha esperada**.

### Passagem 2 — Montagem da matriz T1..Tn (Modo MONTAR)
- Para cada cenario escreva: pre-condicao, passos exatos, esperado observavel cravado, papel/ambiente, e (quando aplicavel) o comando de force para o edge case. Veja Secao 6.

### Passagem 3 — Gate pre-deploy
- Rode o checklist pre-deploy (Secao 5.A) + os cenarios marcados como pre-deploy em staging/preview.
- **Gate:** se algum P0 falha, NAO promova. Corrija ou aborte.

### Passagem 4 — Promocao e verificacao de versao
- Apos promover, confirme **empiricamente** que a versao certa esta servida (Secao 5.B). Deploy "concluido" sem versao confirmada = ainda nao subiu para voce.

### Passagem 5 — Gate pos-deploy (janela quente)
- Rode os cenarios pos-deploy (Secao 5.C), priorizando os do dinheiro/auth, em janela anonima quando publico.
- Capture snapshots de invariante (contadores, totais, contagem de registros, health, taxa de erro) e compare com o baseline pre-deploy.
- **Gate:** falha P0 pos-deploy => decisao imediata de **ROLLBACK** ou hotfix, com janela de tempo definida.

### Passagem 6 — Edge cases e caminhos de erro
- Force os edge cases (token expirado/revogado, permissao negada, payload invalido, rede caindo, estado parcial, concorrencia) e verifique a falha **graciosa** esperada (Secao 6.3).

### Passagem 7 — Relato e veredito
- Consolide OK/FALHA/PULADO por cenario com evidencia, snapshots, e o veredito GO/NO-GO/ROLLBACK (Secao 8). Deixe o relato rastreavel para a proxima pessoa.

---

## 5. Checklists Operacionais (sub-atomico)

### 5.A Checklist PRE-deploy
- [ ] Artefato/imagem identificavel por hash/tag e rastreavel ao commit.
- [ ] Build/CI verde de verdade (abriu os logs; sem `--no-verify`, sem step pulado, sem warning critico mascarado).
- [ ] Migracoes de banco revisadas: reversiveis? aplicam sem lock longo? ha plano de rollback do schema?
- [ ] Feature flags do release com **estado e default conhecidos** por ambiente (ligada/desligada de proposito, nao por acidente).
- [ ] Config/secrets do ambiente-alvo presentes e corretos (sem apontar staging para prod ou vice-versa); segredos via secret manager, nao hardcoded.
- [ ] Plano de rollback escrito: como reverter (redeploy da versao N-1, flag off, restore), quem aciona, em quanto tempo.
- [ ] Baseline capturado: taxa de erro atual, latencia, contadores/invariantes de negocio (para comparar pos-deploy).
- [ ] Janela de deploy e on-call definidos; ninguem deploya as 18h de sexta sem necessidade.
- [ ] Smoke em staging/preview rodado (cenarios pre-deploy P0 = OK).

### 5.B Checklist de PROMOCAO / verificacao de versao
- [ ] Deploy logs lidos: terminou sem erro, sem rollback automatico silencioso, replicas/pods saudaveis.
- [ ] **Versao servida confirmada empiricamente**: endpoint `/version` ou `/health` retorna o hash/tag esperado; header (`X-App-Version`/`ETag`/build no HTML); splash/about no mobile; primeira linha de log da nova versao.
- [ ] DNS resolve para o destino certo (sem cache antigo apontando para o ambiente errado).
- [ ] Certificado TLS valido, nao expirado, cobre o host (incluindo apex/www/subdominio relevante).
- [ ] CDN/cache invalidado quando o asset mudou (sem servir bundle/JS antigo com API nova).
- [ ] Saude de dependencias externas (banco, cache, fila, gateway) verde apos o deploy.

### 5.C Checklist POS-deploy (janela quente)
- [ ] Smoke dos fluxos do dinheiro/auth em **janela anonima/sessao limpa** = OK observavel.
- [ ] Logs de aplicacao da nova versao: sem pico de erro/exception novo; `request_id` rastreavel em uma requisicao de teste.
- [ ] Logs de auth: login/logout/refresh geram eventos esperados; sem rajada de 401/403 anomala.
- [ ] Snapshots de invariante comparados com baseline (contadores de negocio coerentes; nada zerou ou explodiu).
- [ ] Integracoes externas exercitadas com transacao de teste (pagamento sandbox aprovou; email/SMS chegou; webhook recebeu e processou).
- [ ] Job/cron/worker critico rodou ao menos uma vez com sucesso observado.
- [ ] Mobile: versao publicada na loja/OTA correta; clientes antigos ainda funcionam (compatibilidade de API).
- [ ] Monitoramento/alertas armados; dashboard sob observacao pela janela combinada (ex.: 15-60 min).
- [ ] Ambiente de teste limpo (dados fake removidos/marcados; estados forcados revertidos).

---

## 6. Matriz de Cenarios T1..Tn — o coracao do smoke

### 6.1 Formato obrigatorio de cada cenario

Cada cenario e numerado `T1..Tn` e tem **todos** estes campos:

```
[Tn] Titulo curto e direto
- Fase: pre-deploy | pos-deploy | ambos
- Papel: anonimo | usuario | admin | owner | outro-tenant | sistema
- Ambiente: staging | prod | ambos
- Pre-condicao: estado exigido ANTES de comecar (conta X existe, flag Y on, saldo Z, sessao limpa)
- Passos: 1) ... 2) ... 3) ... (exatos, reproduziveis por outra pessoa)
- Esperado (observavel cravado): o que se VE — tela/rota, campo=valor, status, corpo, log, registro
- Edge/force (opcional): comando para forcar o caso (token revogado, estado, falha de rede)
- Resultado: OK | FALHA | PULADO   (preenchido na execucao)
- Evidencia: o que foi observado (status, screenshot/descricao, trecho de log/json mascarado)
- Notas p/ proxima pessoa: o que ela precisa saber para reproduzir/continuar
```

### 6.2 Catalogo de cenarios candidatos (selecione os pertinentes; nao invente fluxos que o sistema nao tem)

**Autenticacao e sessao**
- Login com credencial valida -> ve dashboard/home esperado, nome do usuario `= X`, sessao criada.
- Login com credencial invalida -> mensagem de erro especifica, **sem** vazar se o e-mail existe, sem 500.
- Logout -> volta a tela de login; recarregar nao reentra; back do navegador nao reabre area logada.
- Sessao expirada / token revogado -> proxima acao redireciona ao login (ver `auth-token-refresh-safety` para a correcao do refresh).
- Recuperacao de senha / MFA (se houver) -> fluxo chega ao fim com efeito observavel.

**Happy path de valor (o release nao serve sem isto)**
- Criar/salvar/publicar o recurso central -> registro aparece na lista com campos `= valores`; persiste apos reload.
- Editar e deletar -> mudanca refletida; delete some da lista e do backend.
- Checkout/pagamento (sandbox) -> ordem criada, status `= pago/pendente` correto, recibo/confirmacao exibido.
- Busca/filtro/paginacao -> retorna resultados coerentes; pagina 2 difere da 1; filtro vazio nao quebra.

**Permissoes / isolamento (cruze com `database-tenant-isolation-audit` e `auth-authorization-audit`)**
- Usuario comum tenta acessar rota/recurso de admin -> 403/redirect, **nao** ve o conteudo.
- Tenant A nao ve/edita dado do tenant B (force pelo ID na URL/API) -> negado, sem vazamento.
- Owner vs membro: acao restrita ao owner bloqueada para membro.

**Integracoes externas e assincrono**
- Webhook do gateway/parceiro -> recebido, assinatura verificada, efeito aplicado idempotentemente.
- Email/SMS/push -> disparado e **recebido** (caixa de teste), conteudo correto, link funciona.
- Job/cron/worker -> processa item de teste; fila drena; retry funciona; sem loop infinito.
- LLM/IA (se houver) -> responde no formato esperado, dentro do timeout, com fallback quando o provider falha.

**Saude tecnica / regressao do que mudou**
- Health/readiness -> verde com detalhe (banco/cache/dependencias up).
- Rota/endpoint NOVO deste release -> existe, responde, contrato bate.
- Rota ANTIGA tocada -> ainda responde igual (sem regressao de contrato).
- Pagina critica em janela anonima -> carrega sem erro de console, assets atuais (nao cache velho).

### 6.3 Comandos para forcar edge cases (ilustrativos — generalize por stack, sempre em ambiente autorizado)

> Use dados/contas de teste. Mascare segredos. Em prod, prefira observar; force apenas com autorizacao.

**Provar 401/403/sessao (qualquer API HTTP)**
```bash
# sem token -> esperado 401
curl -i https://staging.exemplo.app/api/orders
# token invalido/expirado -> esperado 401, corpo de erro previsivel
curl -i -H "Authorization: Bearer eyJ...EXPIRED..." https://staging.exemplo.app/api/orders
# token de outro tenant tentando ID alheio -> esperado 403/404, nunca 200 com dado alheio
curl -i -H "Authorization: Bearer $TOKEN_TENANT_A" https://staging.exemplo.app/api/orders/<id-do-tenant-B>
```

**Forcar estado no banco (use a sintaxe do SEU banco; rode em staging/conta de teste)**
```sql
-- Postgres/MySQL/SQL Server/Oracle: expirar uma sessao/token de teste
UPDATE sessions SET expires_at = NOW() - INTERVAL '1 hour' WHERE user_id = '<TEST_USER>';
-- forcar um estado de pedido para testar a tela de "pago"
UPDATE orders SET status = 'paid' WHERE id = '<TEST_ORDER>';
-- revogar acesso/role de teste e checar que a UI nega
DELETE FROM user_roles WHERE user_id = '<TEST_USER>' AND role = 'admin';
```
```javascript
// Mongo (mongosh) equivalente
db.sessions.updateOne({ userId: "<TEST_USER>" }, { $set: { expiresAt: new Date(Date.now()-3600e3) } });
db.orders.updateOne({ _id: "<TEST_ORDER>" }, { $set: { status: "paid" } });
```

**Revogar token / policy / chave (equivalentes por ecossistema — escolha o seu)**
- Token de provider de auth: revogar a sessao/refresh token no painel/admin API (Cognito/Auth0/Firebase/Keycloak/Supabase) e checar que a proxima request cai no login.
- Policy/permissao de banco: desabilitar a row-level/grant relevante (RLS no Postgres, GRANT/REVOKE, regra do firestore/dynamo) e checar negacao.
- Chave de API/gateway: rotacionar a chave de teste e confirmar que a integracao falha graciosamente, nao em silencio.

**Simular falha de rede / dependencia (mobile e web)**
- Modo aviao / throttle no devtools (Slow 3G) -> app mostra estado de erro/retry, nao tela branca.
- Derrubar dependencia em staging (parar o container do cache/fila) -> health degrada com mensagem, app degrada gracioso.

**Confirmar versao servida**
```bash
curl -s https://exemplo.app/version            # {"commit":"<hash>","tag":"v1.4.2"}
curl -sI https://exemplo.app | grep -i version # header X-App-Version
```

---

## 7. Orientacao por Stack (ilustrativa — generalize sempre)

> Exemplos cobrem multiplos ecossistemas e NAO esgotam; aplique o conceito a sua stack.

- **Web SPA/SSR (React/Vue/Svelte/Angular; Next/Nuxt/Remix):** smoke em aba anonima; checar console sem erro; confirmar bundle atual (hash no asset, sem cache CDN velho); hidratacao SSR sem mismatch; rotas client-side carregam direto por URL (deep link), nao so navegando.
- **APIs (REST/GraphQL/gRPC):** status codes corretos por caso; contrato (schema/openapi) bate; GraphQL sem introspection/playground exposto em prod; idempotencia de POST sensiveis; versionamento nao quebrou clients antigos.
- **Mobile (Flutter/React Native/Expo/iOS/Kotlin):** versao no about/splash confere; cold start sem crash; clientes da versao anterior ainda funcionam (compat de API); OTA/loja correta; offline degrada gracioso; permissoes do OS pedidas certo.
- **Serverless/Edge (Lambda/Cloud Functions/Cloudflare Workers):** cold start dentro do limite; env vars do ambiente certo; timeout/limite de memoria nao estourado; logs aparecem no destino esperado.
- **Backend (Java/Spring, .NET, Go, Python/Django-FastAPI, Ruby/Rails, PHP/Laravel, Node):** `/health`/`/actuator/health` verde; migracoes aplicadas; pool de conexao ok; sem stack trace 500 novo nos logs.
- **Dados/async (Kafka/SQS/RabbitMQ; cron/worker):** consumer processa mensagem de teste; DLQ vazia; job agendado disparou; sem reprocessamento duplicado.
- **Infra/IaC/Cloud:** recurso provisionado no ambiente certo; security group/firewall nao abriu demais; secret veio do secret manager; rollback de IaC testado.
- **Pagamento/billing (Stripe/Square/Asaas):** use sandbox; webhook de confirmacao chega e e idempotente; quota/limite aplicado (cruze com `saas-billing-and-quota-enforcement`).
- **Analytics (PostHog/Mixpanel/Amplitude):** evento critico dispara e aparece no painel com as props certas (cruze com `product-analytics-architecture`).

---

## 8. Armadilhas / Anti-padroes (gotchas)

- **"Funcionou" sem criterio observavel.** O pecado original do smoke. Sempre crave o que se ve.
- **Sessao/cache mascarando bug.** Testou logado/com cache quente e nao viu o erro do usuario novo. Use janela anonima/perfil limpo.
- **Confiar no "deploy success".** Pipeline verde com versao antiga servida (cache CDN, replica nao reiniciada, rollback automatico silencioso). Confirme a versao empiricamente.
- **Smoke so do happy path.** Nunca exercitou erro/permissao; o release "passa" e vaza dado de outro tenant em producao.
- **Forcar estado em producao sem reverter.** Pedido fake real, usuario lixo, token expirado de um usuario de verdade. Use staging/conta de teste e limpe.
- **Esperado vago demais ou cravado no errado.** "Status 200" quando o corpo veio com `error: true`. Olhe o corpo/efeito, nao so o codigo.
- **Smoke que virou regressao.** Cresceu para 200 cenarios e ninguem roda. Mantenha o smoke pequeno; mande o resto para `e2e-test-architecture`.
- **Pular cenario e marcar OK.** PULADO com motivo e honesto; OK presumido e mentira que estoura em prod.
- **Nao comparar com baseline.** Sem snapshot pre-deploy, voce nao sabe se o contador caiu por causa do release.
- **Ignorar clients antigos (mobile/API).** Subiu API incompativel; app da loja quebrou para quem nao atualizou.
- **Relato nao reproduzivel.** "Testei, ta de pe." A proxima pessoa nao sabe o que voce rodou nem o que ainda falta.

---

## 9. Classificacao de cada cenario/achado

- **Criticidade do cenario:** P0 (se falhar, NO-GO/ROLLBACK) / P1 (corrigir antes de liberar amplo) / P2 (acompanhar) / P3 (cosmetic).
- **Resultado:** OK / FALHA / PULADO.
- **Confianca da evidencia:** Observado ponta-a-ponta / Provavel (so status superficial) / Inferido.
- **Esforco de correcao/repro:** Baixo / Medio / Alto.

Regra de ouro: **qualquer** falha em login/logout, no happy path do dinheiro/valor, em isolamento de papel/tenant, ou versao errada servida = **P0**. P0 falho pre-deploy = NO-GO. P0 falho pos-deploy = ROLLBACK ou hotfix com janela definida.

---

## 10. Formato Obrigatorio da Resposta

### 10.1 Resumo executivo
3-8 linhas: o que esta sendo deployado, ambiente, estrategia, total de cenarios por resultado (OK/FALHA/PULADO), e o veredito preliminar (GO / GO-com-ressalvas / NO-GO / ROLLBACK) com os bloqueadores.

### 10.2 Matriz de cenarios (formato fixo, Secao 6.1)
Liste T1..Tn no formato cravado, com Resultado e Evidencia preenchidos.

### 10.3 Tabela consolidada
| ID | Fase | Papel | Criticidade | Resultado | Confianca | Resumo do esperado vs observado |
|----|------|-------|-------------|-----------|-----------|---------------------------------|

### 10.4 Snapshots de invariante (baseline vs pos-deploy)
| Invariante | Pre-deploy | Pos-deploy | Delta esperado? |
|------------|-----------|-----------|-----------------|
(ex.: taxa de erro, latencia p95, total de pedidos/h, usuarios ativos, contagem de registros chave)

### 10.5 Checklists marcados
- Pre-deploy (5.A), Promocao (5.B), Pos-deploy (5.C) com cada item [x]/[ ] e nota quando relevante.

### 10.6 Veredito GO / NO-GO / ROLLBACK
- [ ] Todos os P0 = OK (auth, dinheiro/valor, isolamento, versao servida).
- [ ] Versao correta confirmada empiricamente.
- [ ] Sem pico de erro novo nos logs; invariantes coerentes com baseline.
- [ ] Plano de rollback pronto e testado.
- **VEREDITO: GO / GO-com-ressalvas / NO-GO / ROLLBACK** + justificativa em 1-2 linhas + janela de observacao recomendada.

### 10.7 Relato para a proxima pessoa
- O que foi testado e como reproduzir; o que ficou PULADO e por que; riscos abertos; o que monitorar nas proximas horas; como reverter se piorar.

---

## 11. Modo de Auditoria de Conformidade (opcional, ao final)

Quando o pedido for "avaliar o processo de smoke/deploy existente" (e nao executar um smoke agora), produza um relatorio de maturidade contra este protocolo:

- Existe matriz de cenarios numerados com esperado observavel cravado? Ou so "testar a tela X"?
- Os criterios sao observaveis e reproduziveis por terceiros, ou subjetivos ("funcionou")?
- Ha checklist pre **e** pos-deploy, com verificacao empirica de versao servida?
- Edge cases sao forcados (token/policy/estado) ou so o happy path?
- O relato e rastreavel (OK/FALHA/PULADO com evidencia) para a proxima pessoa?
- Ha snapshots de invariante e comparacao com baseline?
- Para cada lacuna: gravidade, exemplo concreto do que falta, e o cenario/checklist especifico a adicionar (referencie a secao deste documento).

---

## 12. Regras de Qualidade e Auto-verificacao

Antes de entregar, confirme internamente:
- Cada cenario tem pre-condicao, passos exatos, **esperado observavel cravado**, resultado e evidencia — nada vago.
- Nenhuma tela/rota/campo/endpoint/log inventado; observado vs inferido claramente marcado; PULADO sempre com motivo.
- Versao servida foi confirmada empiricamente (nao so "deploy success").
- Caminho de erro, papeis (anonimo/usuario/admin/owner/outro-tenant) e ambientes considerados — nao so o happy path logado.
- Segredos mascarados; nenhum comando destrutivo rodado fora de ambiente autorizado; ambiente deixado limpo.
- Snapshots comparados com baseline; bloqueadores P0 refletidos no veredito.
- Relato reproduzivel e rastreavel para a proxima pessoa; rollback descrito.
- Se faltar contexto (conta de admin, ambiente de staging, credencial de sandbox), declare exatamente o que falta em vez de presumir OK.
