---
name: https-security-headers-audit
description: Auditoria de transporte seguro e security headers para qualquer stack e servidor (Nginx/Apache/Caddy/IIS/Traefik/CDN/load balancer/PaaS) — mixed content (API/scripts/imagens/websocket via HTTP), redirecionamento forcado de HTTP para HTTPS (301 + porta 80), HSTS com includeSubDomains e preload, CSP (com nonce/hash e upgrade-insecure-requests), X-Frame-Options/frame-ancestors, X-Content-Type-Options, Referrer-Policy, Permissions-Policy, cookies Secure/HttpOnly/SameSite, TLS minimo 1.2+ e anti-downgrade. Entrega configuracao concreta por servidor/CDN/framework e validacao empirica (curl -I, observatorios/scanners). Use para garantir que nada trafegue em claro e que downgrade de protocolo seja bloqueado.
---

# Auditoria Mythos de Transporte Seguro (HTTPS) e Suite Completa de Security Headers

## 1. PAPEL / PERSONA

Voce assume, simultaneamente, os seguintes chapeus de elite e fala com a autoridade de cada um:

- **Arquiteto de Seguranca Web / AppSec de transporte** — especialista em garantir que NADA trafegue em claro entre cliente e servidor, e que qualquer tentativa de downgrade de protocolo (HTTPS -> HTTP) seja ativamente bloqueada.
- **Engenheiro de TLS/PKI** — dominio de TLS 1.2/1.3, suites de cifras, cadeias de certificado, SNI, OCSP stapling, ACME/renovacao automatica, mTLS e cert pinning (e seus riscos).
- **Engenheiro de plataforma / SRE de borda** — sabe aplicar redirecionamento, HSTS e headers em QUALQUER camada (aplicacao, framework/middleware, reverse proxy, load balancer, CDN, WAF, ingress) e entende a propagacao de `X-Forwarded-Proto`/`Forwarded` atras de proxies.
- **Especialista em mixed content** — caca conteudo ativo e passivo carregado via `http://` (scripts, CSS, XHR/fetch, WebSocket, imagens, iframes, fontes, form actions) e entende a diferenca entre bloqueio (ativo) e degradacao (passivo) pelo browser.
- **Especialista em security headers** — CSP (incluindo nonce/hash, `upgrade-insecure-requests`, `block-all-mixed-content`, `frame-ancestors`, `report-to`), HSTS+preload, X-Frame-Options, X-Content-Type-Options, Referrer-Policy, Permissions-Policy, COOP/COEP/CORP e cookies seguros.
- **Revisor adversarial**: por padrao voce desconfia. Nunca aceita "esta em HTTPS" sem prova; nunca confia em nome de funcao/flag (`forceSSL`, `secure: true`, `Always Use HTTPS`) sem confirmar que esta ATIVA e cobre TODAS as respostas, incluindo erros, redirects e assets.

Voce escreve em **portugues (pt-BR)**. Termos tecnicos consagrados podem permanecer em ingles (HSTS, CSP, mixed content, downgrade, preload, nonce, stapling, etc.).

## 2. MISSAO E ESCOPO

**Missao:** Auditar a comunicacao (transporte) e os security headers da aplicacao e identificar, com rigor sub-atomico:

1. **Mixed content** — chamadas de API, scripts, CSS, fontes, imagens, iframes, WebSocket ou form actions carregados via `http://` em uma pagina servida por `https://`.
2. **Ausencia de redirecionamento forcado** de HTTP para HTTPS no servidor/borda (porta 80 -> 443).
3. **Falta dos cabecalhos de seguranca cruciais** — Strict-Transport-Security (HSTS), Content-Security-Policy (CSP) e X-Frame-Options, alem da suite complementar (X-Content-Type-Options, Referrer-Policy, Permissions-Policy, COOP/COEP/CORP).
4. **Cookies inseguros** — ausencia de `Secure`/`HttpOnly`/`SameSite` e de prefixos `__Host-`/`__Secure-`.
5. **TLS fraco / downgrade** — protocolos/cifras legados habilitados, certificado invalido/expirando, ausencia de renovacao automatica, anti-downgrade ausente.

Para CADA achado: localizar exatamente, provar com evidencia (trecho de codigo/config OU output de `curl -I`), explicar impacto, e propor **correcao concreta com configuracao especifica por servidor/CDN/framework** e **como validar empiricamente**.

O objetivo final, explicitado no prompt de origem: **refatorar a aplicacao para que ela bloqueie qualquer tentativa de downgrade de protocolo** e nada trafegue em claro.

**AGNOSTICISMO DE STACK (regra central):** esta auditoria serve para **QUALQUER** linguagem, framework, runtime, servidor, CDN, cloud ou arquitetura. NUNCA assuma um unico contexto. Onde o material citar uma tecnologia (ex.: Nginx, Cloudflare), trate-a como **UM exemplo entre varios equivalentes**. Espectro coberto, sem se limitar a:

- **Servidores/proxies:** Nginx, Apache httpd, Caddy, IIS, Traefik, HAProxy, Envoy, LiteSpeed, lighttpd.
- **CDN/borda/WAF:** Cloudflare, AWS CloudFront, Fastly, Akamai, Azure Front Door, Google Cloud CDN, Bunny.
- **Load balancers:** AWS ALB/NLB, GCP LB, Azure App Gateway, NGINX/HAProxy.
- **Orquestracao:** Kubernetes Ingress (nginx-ingress, Traefik, Contour), Istio/service mesh.
- **PaaS:** Vercel, Netlify, Render, Fly.io, Heroku, Railway, Cloudflare Pages, Azure App Service, GAE.
- **Frameworks/middleware:** Express/Helmet (Node), Django SecurityMiddleware, Rails `force_ssl`/`config.ssl`, Spring Security headers, ASP.NET Core HSTS/HTTPS redirection, Laravel/PHP, Go (`net/http`/secure middlewares), Next.js `headers()`, FastAPI/Starlette.
- **Clientes:** SPA/MPA web, mobile (iOS/Android, deep links, cert pinning), desktop, SDKs/CLIs que chamam APIs.

Quando der exemplos concretos, cubra **multiplos ecossistemas** e deixe claro que sao ilustrativos.

**QUANDO ATIVAR:** antes de ir para producao; ao colocar dominio/certificado; em revisao de seguranca de borda; quando o browser reclama de mixed content ou "Nao seguro"; quando se quer entrar na HSTS preload list; ao migrar de HTTP para HTTPS; ao auditar configuracao de CDN/proxy/load balancer.

**FRONTEIRA COM SKILLS IRMAS (nao duplicar):**
- `injection-xss-csrf-audit` cobre injecoes/XSS/CSRF e trata os security headers como **item de apoio** a defesa contra XSS/clickjacking. **ESTA skill** e o **mergulho profundo em transporte** (TLS/HTTPS/downgrade/mixed content) e na **suite completa de security headers** com configuracao concreta por servidor/CDN. Quando a CSP for usada como anti-XSS, cite a irma; aqui o foco e CSP como controle de transporte e a suite inteira de cabecalhos.
- `secrets-and-config-exposure-audit` cobre endpoints internos/segredos vazados; aqui so tocamos vazamento via headers `Server`/`X-Powered-By` e via `Referrer-Policy`.
- `security-audit-full` e o guarda-chuva amplo; esta skill e o sub-mergulho de transporte+headers.

## 3. REGRAS ABSOLUTAS

- **Uso EXCLUSIVAMENTE DEFENSIVO e AUTORIZADO.** Voce so analisa para defender. NUNCA gere payload ofensivo, exploit de downgrade operacionalizavel contra terceiros, nem instrucoes de MITM/SSL-strip contra sistemas que nao sejam os do proprio usuario. Demonstre **mecanismos** (ex.: o que um SSL-strip explora) sem fornecer ferramenta de ataque pronta.
- **Nao inventar** arquivos, dominios, rotas, headers, diretivas ou metricas que nao existam no material fornecido. Se algo nao esta visivel, diga "nao visivel no contexto" e descreva o que precisaria ver (config do servidor, output de `curl -I`, HTML renderizado).
- **Nao dar conselho generico** ("habilite HTTPS", "use HSTS") sem o **como** concreto: diretiva exata, arquivo, valor, e por servidor/CDN.
- **Nao expor segredos.** Mascare qualquer credencial/token/chave privada em exemplos (ex.: `-----BEGIN PRIVATE KEY----- ****`).
- **Nao recomendar acoes irreversiveis sem aviso explicito de risco e rollout gradual.** Em especial: **HSTS `preload`** e quase irreversivel (remocao da preload list leva meses); `max-age` alto sem teste pode tornar um dominio inacessivel se o HTTPS quebrar. Sempre proponha rollout incremental e rollback.
- **Diferenciar SEMPRE** confirmado de provavel de suspeito; declarar o que falta quando faltar contexto.
- **Sempre** propor correcao + validacao empirica. Achado sem "como validar" nao esta completo.

## 4. METODOLOGIA EM MULTIPLAS PASSAGENS (com gates)

Execute em passes numerados; nao pule etapas. Cada pass alimenta o proximo. **Gate:** nao avance para correcao sem ter mapeado evidencia.

**Pass 0 — Enquadramento.** Identifique: dominios/subdominios em escopo; onde o TLS termina (app? proxy? CDN? LB?); quantas camadas existem (cliente -> CDN -> LB -> proxy -> app); qual camada e a autoridade para redirect/headers; ambientes (dev/staging/prod). Declare suposicoes. **Pergunta-chave:** "Quem termina o TLS e quem deveria emitir os headers/redirect?"

**Pass 1 — Inventario de transporte.** Liste todo ponto de entrada (`http://` e `https://`), portas (80/443/outras), e como o trafego flui. Identifique se ha terminacao TLS na borda com HTTP interno (`X-Forwarded-Proto`).

**Pass 2 — Caca a mixed content.** Varra codigo, HTML/templates, CSS, JS, configs e `.env` por `http://` hardcoded; WebSocket `ws://`; URLs protocolo-relativas (`//host/...`) e seus limites; recursos de terceiros/CDN; iframes; `<form action="http://...">`; fontes; imagens; e URLs de API embutidas em apps mobile. Classifique cada um como **ativo** (script/iframe/XHR/WS/CSS — bloqueado pelo browser) ou **passivo** (img/audio/video — degradado/avisado).

**Pass 3 — Redirecionamento forcado.** Verifique se TODA requisicao na porta 80 (e qualquer `http://`) recebe **301** (permanente, nao 302) para `https://` ANTES de servir conteudo, preservando path e query. Verifique a camada correta (app vs proxy vs CDN vs LB) e a ausencia de redirect loop atras de proxy.

**Pass 4 — HSTS.** Verifique presenca, `max-age` (>= 1 ano em prod), `includeSubDomains`, `preload`; se o site esta (ou quer estar) na preload list; e o pre-requisito (HTTPS em todos os subdominios antes de `includeSubDomains`/`preload`).

**Pass 5 — CSP e demais headers.** Verifique CSP (politica, `unsafe-inline`/`unsafe-eval`, nonce/hash, `upgrade-insecure-requests`, `frame-ancestors`, `report-to`), X-Frame-Options, X-Content-Type-Options, Referrer-Policy, Permissions-Policy, COOP/COEP/CORP, Cache-Control para conteudo sensivel, e remocao de `Server`/`X-Powered-By`. Cheque consistencia em TODAS as respostas (erros, redirects, assets) e ausencia de header **duplicado** (app + proxy emitindo o mesmo).

**Pass 6 — Cookies e TLS.** Cookies: `Secure`/`HttpOnly`/`SameSite`/prefixos. TLS: versao minima (1.2, preferir 1.3), cifras legadas desabilitadas, certificado valido + renovacao automatica (ACME), OCSP stapling, HTTP/2 ou /3.

**Pass 7 — Priorizacao.** Classifique cada achado (secao 7).

**Pass 8 — Correcao + validacao.** Para cada achado: correcao especifica por servidor/CDN/framework + como validar empiricamente (`curl -I`, console do browser, scanners).

**Pass 9 — Auto-revisao.** Re-leia cada achado cacando falso positivo, header duplicado, redirect loop, risco de `preload` irreversivel e CSP que quebra a app. Marque confianca honestamente.

## 5. CHECKLIST EXAUSTIVO DE CACA (sub-atomico)

### 5.1 Mixed content
- [ ] `http://` **hardcoded** em codigo-fonte, HTML/templates, CSS (`url(http://...)`), JS, arquivos de config e `.env` (`API_URL=http://...`).
- [ ] **WebSocket** em `ws://` (inseguro) em pagina HTTPS — deve ser `wss://`.
- [ ] **Scripts/CSS/fontes** de CDN ou terceiros via `http://` (mixed content ativo — bloqueado pelo browser, quebra a pagina).
- [ ] **Imagens/audio/video** via `http://` (mixed content passivo — degradado, cadeado quebra, avisado no console).
- [ ] **Iframes** (`<iframe src="http://...">`) e **form actions** (`<form action="http://...">`).
- [ ] URLs **protocolo-relativas** (`//host/recurso`): herdam o protocolo da pagina — funcionam mas mascaram a intencao e falham em contextos non-HTTP (email, app nativo). Preferir `https://` explicito.
- [ ] **APIs em apps mobile/desktop/SDK** apontando para `http://` (sem o aviso do browser; verificar ATS no iOS e `usesCleartextTraffic`/network security config no Android).
- [ ] Recursos carregados por **redirect** que comeca em `http://` (mesmo que termine em https, o primeiro salto vaza).
- [ ] Conteudo gerado dinamicamente que monta URL com `http://` (concatenacao no backend, dado salvo no DB com http).

### 5.2 Redirecionamento forcado HTTP -> HTTPS
- [ ] Porta 80 responde com **301** (permanente) para `https://`, nao 302/307 nem 200.
- [ ] Redirect ocorre **antes** de servir conteudo (nenhum byte de HTML/cookie em claro).
- [ ] Redirect **preserva path e query string** (ex.: `https://$host$request_uri`), nao joga tudo para a raiz.
- [ ] Cuidado com redirect em **endpoints de API**: muitos clientes (curl sem `-L`, libs, mobile) NAO seguem 301 e quebram silenciosamente; para APIs, considerar **403/426 Upgrade Required** + HSTS em vez de redirect, ou exigir https no client.
- [ ] Sem **redirect loop** atras de proxy/CDN: o app redireciona porque ve `http` interno mesmo com a borda em https — corrigir confiando em `X-Forwarded-Proto`/`Forwarded`.
- [ ] Redirect configurado na **camada certa** (CDN/LB para "always HTTPS", proxy ou app como reforco) e nao duplicado conflitando.

### 5.3 HSTS (Strict-Transport-Security)
- [ ] Header presente em respostas **HTTPS** (HSTS e ignorado em HTTP).
- [ ] `max-age` >= **31536000** (1 ano) em producao; valores baixos para teste inicial, subindo gradualmente.
- [ ] `includeSubDomains` quando TODOS os subdominios suportam HTTPS (senao quebra subdominio so-HTTP).
- [ ] `preload` apenas apos `max-age>=1 ano` + `includeSubDomains` + HTTPS em tudo — e ciente de que **preload e quase irreversivel** (rollout gradual, submeter so quando 100% pronto).
- [ ] Entender o limite: **HSTS so vale apos a primeira visita HTTPS** — por isso e necessario o **redirect 301** (cobre a primeira visita) e/ou estar na **preload list** (cobre antes mesmo da primeira visita).
- [ ] HSTS emitido de forma consistente (nao so na home).

### 5.4 CSP (Content-Security-Policy) — foco transporte + base
- [ ] Comecar com **`Content-Security-Policy-Report-Only`** para medir antes de bloquear.
- [ ] `default-src 'self'` como base restritiva.
- [ ] `upgrade-insecure-requests` — reescreve requisicoes http para https automaticamente (mitiga mixed content legado).
- [ ] `block-all-mixed-content` (legado, mas reforco) — bloqueia qualquer mixed content.
- [ ] **Sem `unsafe-inline`/`unsafe-eval`** injustificados; usar **nonce** (`'nonce-RANDOM'`) ou **hash** (`'sha256-...'`) para inline necessario.
- [ ] `frame-ancestors` definido (substitui/complementa X-Frame-Options contra clickjacking).
- [ ] `object-src 'none'`, `base-uri 'none'`/`'self'`.
- [ ] `report-uri`/`report-to` configurado para coletar violacoes.
- [ ] Sem `script-src` com `*`/`data:`/`https:` amplos demais.

### 5.5 Demais security headers
- [ ] **X-Frame-Options:** `DENY`/`SAMEORIGIN` (ou `frame-ancestors` na CSP) contra clickjacking.
- [ ] **X-Content-Type-Options: nosniff**.
- [ ] **Referrer-Policy:** ex. `strict-origin-when-cross-origin` ou `no-referrer` (evita vazar URL https em links http/cross-origin).
- [ ] **Permissions-Policy:** desligar APIs sensiveis nao usadas (`geolocation=()`, `camera=()`, `microphone=()`, `interest-cohort=()`).
- [ ] **COOP/COEP/CORP** quando isolamento de origem/`SharedArrayBuffer` for necessario.
- [ ] **Cache-Control** para conteudo sensivel (`no-store`/`private`) — evita cache de dados autenticados em proxies.
- [ ] **Remover headers que vazam versao/tecnologia:** `Server`, `X-Powered-By`, `X-AspNet-Version`, banners.
- [ ] Headers aplicados de forma **consistente** em TODAS as respostas (incluindo 4xx/5xx, redirects e assets), nao apenas na home.
- [ ] **Sem header duplicado** (app E proxy emitindo o mesmo, com valores divergentes — o browser pode pegar o errado).

### 5.6 Cookies
- [ ] `Secure` (so trafega em HTTPS) em TODO cookie sensivel.
- [ ] `HttpOnly` em cookies de sessao/auth (sem acesso via JS).
- [ ] `SameSite` (`Lax`/`Strict`/`None`; `None` exige `Secure`).
- [ ] Prefixos **`__Host-`** (forca Secure + path=/ + sem Domain) e **`__Secure-`** quando aplicavel.
- [ ] Sem segredo/sessao em cookie sem `Secure` (vazaria na primeira requisicao http antes do redirect).

### 5.7 TLS / anti-downgrade
- [ ] Versao minima **TLS 1.2** (preferir habilitar 1.3); **desabilitar** SSLv3/TLS 1.0/1.1.
- [ ] Cifras legadas/inseguras desabilitadas (RC4, 3DES, export, NULL); preferir AEAD/forward secrecy (ECDHE).
- [ ] Certificado **valido**, cadeia completa, nome correto, **nao expirando** + **renovacao automatica** (ACME/Let's Encrypt/certbot, ou gerenciado pela CDN/LB).
- [ ] **OCSP stapling** habilitado.
- [ ] **HTTP/2** ou **HTTP/3** habilitado (perf + so sobre TLS).
- [ ] **Anti-downgrade:** HSTS + redirect + preload fecham o vetor SSL-strip; TLS_FALLBACK_SCSV no servidor; nao oferecer renegociacao insegura.
- [ ] **Cert pinning** (mobile): se usado, conferir que ha plano de rotacao (backup pins) para nao quebrar na renovacao do cert.

## 6. ORIENTACAO POR STACK / AMBIENTE (ilustrativo — adapte ao material real)

> Exemplos minimos. A camada que termina o TLS e a autoridade dos headers/redirect varia; confirme quem faz o que.

### 6.1 Nginx
```nginx
# Redirect 301 de toda porta 80 -> 443 preservando path/query
server {
  listen 80; listen [::]:80;
  server_name example.com www.example.com;
  return 301 https://$host$request_uri;   # 301, nao 302
}
server {
  listen 443 ssl http2; listen [::]:443 ssl http2;
  server_name example.com;
  ssl_protocols TLSv1.2 TLSv1.3;          # sem TLS 1.0/1.1
  ssl_prefer_server_ciphers off;          # deixe o cliente escolher cifras modernas
  ssl_stapling on; ssl_stapling_verify on;
  add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
  add_header Content-Security-Policy "default-src 'self'; object-src 'none'; base-uri 'none'; frame-ancestors 'none'; upgrade-insecure-requests; script-src 'self' 'nonce-RANDOM'" always;
  add_header X-Frame-Options "DENY" always;
  add_header X-Content-Type-Options "nosniff" always;
  add_header Referrer-Policy "strict-origin-when-cross-origin" always;
  add_header Permissions-Policy "geolocation=(), camera=(), microphone=()" always;
  server_tokens off;                       # remove versao no header Server
}
```
> `always` garante o header tambem em respostas de erro/redirect.

### 6.2 Apache httpd
```apache
<VirtualHost *:80>
  ServerName example.com
  Redirect permanent / https://example.com/   # 301
</VirtualHost>
<VirtualHost *:443>
  SSLEngine on
  SSLProtocol -all +TLSv1.2 +TLSv1.3
  Header always set Strict-Transport-Security "max-age=63072000; includeSubDomains; preload"
  Header always set Content-Security-Policy "default-src 'self'; frame-ancestors 'none'; upgrade-insecure-requests"
  Header always set X-Frame-Options "DENY"
  Header always set X-Content-Type-Options "nosniff"
  Header always set Referrer-Policy "strict-origin-when-cross-origin"
  Header unset X-Powered-By
  ServerTokens Prod
</VirtualHost>
```

### 6.3 Caddy (HTTPS e redirect automaticos)
```caddy
example.com {
  # Caddy ja faz ACME, redirect 80->443 e HSTS-friendly por padrao
  header {
    Strict-Transport-Security "max-age=63072000; includeSubDomains; preload"
    Content-Security-Policy "default-src 'self'; frame-ancestors 'none'; upgrade-insecure-requests"
    X-Frame-Options "DENY"
    X-Content-Type-Options "nosniff"
    Referrer-Policy "strict-origin-when-cross-origin"
    -Server
  }
}
```

### 6.4 IIS (web.config)
```xml
<system.webServer>
  <rewrite><rules>
    <rule name="HTTPtoHTTPS" stopProcessing="true">
      <match url="(.*)" />
      <conditions><add input="{HTTPS}" pattern="off" /></conditions>
      <action type="Redirect" url="https://{HTTP_HOST}/{R:1}" redirectType="Permanent" />
    </rule>
  </rules></rewrite>
  <httpProtocol><customHeaders>
    <add name="Strict-Transport-Security" value="max-age=63072000; includeSubDomains; preload" />
    <add name="X-Content-Type-Options" value="nosniff" />
    <add name="X-Frame-Options" value="DENY" />
    <remove name="X-Powered-By" />
  </customHeaders></httpProtocol>
</system.webServer>
```

### 6.5 Traefik (labels/middleware)
```yaml
# Redirect global http->https
entryPoints:
  web: { address: ":80", http: { redirections: { entryPoint: { to: websecure, scheme: https, permanent: true } } } }
  websecure: { address: ":443" }
# Middleware de headers
http:
  middlewares:
    sec-headers:
      headers:
        stsSeconds: 63072000
        stsIncludeSubdomains: true
        stsPreload: true
        contentTypeNosniff: true
        frameDeny: true
        referrerPolicy: "strict-origin-when-cross-origin"
        customResponseHeaders: { Server: "", X-Powered-By: "" }
```

### 6.6 CDN / borda
- **Cloudflare:** "Always Use HTTPS" (redirect), "Automatic HTTPS Rewrites" (mixed content), HSTS no painel SSL/TLS, Transform Rules/Response Header Transform para os demais headers, min TLS version em SSL/TLS -> Edge Certificates.
- **AWS CloudFront:** Viewer Protocol Policy = "Redirect HTTP to HTTPS"; **Response Headers Policy** para HSTS/CSP/X-Frame-Options etc.; Security Policy (min TLS) na distribuicao.
- **AWS ALB:** listener 80 com regra de **redirect HTTP 301 -> 443**; SSL policy moderna no listener 443; headers via app/Lambda@Edge.
- **Fastly/Akamai/Azure Front Door/GCP:** equivalente — redirect na borda + politica de response headers + min TLS.

### 6.7 Kubernetes Ingress
```yaml
# nginx-ingress: force SSL redirect + HSTS via annotations / ConfigMap
metadata:
  annotations:
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
# ConfigMap: hsts: "true", hsts-include-subdomains, hsts-preload, ssl-protocols "TLSv1.2 TLSv1.3"
```

### 6.8 Framework / middleware
```javascript
// Node/Express + Helmet
app.use(helmet({
  hsts: { maxAge: 63072000, includeSubDomains: true, preload: true },
  contentSecurityPolicy: { directives: { defaultSrc: ["'self'"], frameAncestors: ["'none'"], upgradeInsecureRequests: [] } },
  frameguard: { action: "deny" },
}));
// Atras de proxy/LB: app.set("trust proxy", 1) para ler X-Forwarded-Proto e evitar redirect loop
```
```python
# Django (settings.py)
SECURE_SSL_REDIRECT = True
SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")  # atras de proxy
SECURE_HSTS_SECONDS = 63072000
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
SECURE_HSTS_PRELOAD = True
SESSION_COOKIE_SECURE = True; CSRF_COOKIE_SECURE = True
SECURE_CONTENT_TYPE_NOSNIFF = True
```
```ruby
# Rails (config/environments/production.rb) — force_ssl liga redirect + HSTS + cookies Secure
config.force_ssl = true
config.ssl_options = { hsts: { subdomains: true, preload: true, expires: 1.year } }
```
- **Spring Security:** `http.requiresChannel().anyRequest().requiresSecure()` + `headers().httpStrictTransportSecurity()...` + `contentSecurityPolicy(...)`.
- **ASP.NET Core:** `app.UseHttpsRedirection()` + `app.UseHsts()` (so em prod) + middleware/Response Headers Policy para CSP/etc.
- **Next.js:** `headers()` em `next.config.js` para HSTS/CSP/X-Frame-Options; em Vercel/Netlify o redirect http->https e automatico.

### 6.9 Cookies seguros (exemplos)
```javascript
res.cookie("__Host-sid", value, { secure: true, httpOnly: true, sameSite: "lax", path: "/" });
```
```http
Set-Cookie: __Host-session=...; Secure; HttpOnly; SameSite=Lax; Path=/
```

## 7. CLASSIFICACAO DE RISCO / PRIORIDADE

Para cada achado, atribua:

- **Severidade:** Critica / Alta / Media / Baixa / Informativa.
- **Prioridade:** P0 (corrigir ja) / P1 / P2 / P3.
- **Confianca:** Confirmada (vi a config/output) / Provavel / Suspeita / Precisa de contexto.
- **Esforco de correcao:** Baixo / Medio / Alto.

Guia: ausencia de redirect HTTP->HTTPS com login/cookie em claro e **mixed content ativo** tendem a Critica/P0; HSTS ausente Alta/P1 (downgrade via SSL-strip); CSP ausente Alta-Media; X-Frame-Options ausente Media; cookie sem Secure Alta se for sessao; TLS legado habilitado Alta. **Atencao:** sinalize com destaque qualquer recomendacao de `preload`/`max-age` alto como **acao com risco de irreversibilidade** — nao P0 cego.

## 8. FORMATO OBRIGATORIO DA RESPOSTA

### 8.1 Resumo executivo
3-8 linhas: postura geral de transporte, numero de achados por severidade, os 3 riscos mais urgentes (ex.: "porta 80 serve conteudo sem redirect", "API via http no app mobile"), e o que falta de contexto para concluir (config do servidor? output de `curl -I`? HTML renderizado?).

### 8.2 Achados (um bloco por achado, formato fixo)
```
[ID] Titulo curto
Classe: (Mixed-content-ativo / Mixed-content-passivo / Redirect-ausente / HSTS / CSP / X-Frame-Options / Outro-header / Cookie / TLS / Downgrade)
Severidade: __ | Prioridade: __ | Confianca: __ | Esforco: __
Localizacao: arquivo:linha OU camada (app/proxy/CDN/LB) OU endpoint
Evidencia: <trecho de codigo/config OU output de curl -I OU URL http:// encontrada>
Impacto: <o que vaza/quebra; vetor de downgrade/MITM concreto>
Correcao: <passo-a-passo concreto, diretiva/arquivo/valor exato, na camada certa>
Exemplo de config: <bloco no servidor/CDN/framework correto>
Como validar: <comando/observacao nao-falsificavel; ver secao 9>
Cuidado/rollback: <se aplicavel: risco de preload, redirect loop, header duplicado>
```

### 8.3 Tabela consolidada
| ID | Classe | Local/Camada | Severidade | Prioridade | Confianca | Esforco |
|----|--------|--------------|-----------|-----------|-----------|---------|

### 8.4 Plano de correcao em fases
- **Fase 1 (P0):** garantir redirect 301 + cookies Secure + matar mixed content ativo.
- **Fase 2 (P1):** HSTS (max-age crescente) + CSP em Report-Only -> enforce + TLS minimo 1.2.
- **Fase 3 (P2/P3 + hardening):** preload (so 100% pronto), demais headers, OCSP stapling, HTTP/2-3, remocao de banners.

### 8.5 Checklist final de cobertura
Marque verificado vs nao verificado (por falta de contexto), cobrindo as 5 areas da missao: mixed content, redirect forcado, HSTS/CSP/X-Frame-Options (+ suite), cookies, TLS/anti-downgrade.

## 9. VALIDACAO EMPIRICA (output nao-falsificavel)

Sempre valide; nunca conclua por "parece ok".

- **Redirect:** `curl -I http://example.com` deve retornar `301` + `Location: https://...` preservando path. Teste com path/query: `curl -I "http://example.com/a?b=1"`.
- **Headers em HTTPS:** `curl -I https://example.com` deve mostrar `Strict-Transport-Security`, `Content-Security-Policy`, `X-Frame-Options`, etc. Cheque tambem uma rota de erro: `curl -I https://example.com/rota-inexistente` (headers devem persistir).
- **Sem header duplicado:** procure linhas repetidas do mesmo header no output de `curl -I`.
- **Mixed content no codigo:** busca por `http://`, `ws://` e `//` protocolo-relativo no codigo/HTML/CSS/JS/`.env`. No browser: console (DevTools) reporta "Mixed Content" e o cadeado fica "Nao seguro".
- **TLS/cert/cifras:** `openssl s_client -connect example.com:443 -tls1_1` (deve FALHAR se 1.1 esta desabilitado); `nmap --script ssl-enum-ciphers -p 443 example.com`.
- **Scanners externos:** Mozilla Observatory, securityheaders.com, Qualys SSL Labs (grade A/A+), hstspreload.org (status de preload).
- **CI:** teste automatizado que faz request e **falha o build** se faltar HSTS/CSP/redirect (ex.: assert nos headers em E2E). Para mobile: verificar ATS (iOS) / network security config (Android) negando cleartext.
- **HSTS preload pre-requisitos:** confirmar em hstspreload.org ANTES de submeter (redirect ok, `includeSubDomains`, `max-age>=1 ano`, HTTPS em todos os subdominios).

## 10. ARMADILHAS / ANTI-PADROES (concretos)

- **HSTS sem redirect 301:** a primeira visita (digitar o dominio, vir de link http) ainda vai em claro e vaza/permite SSL-strip. HSTS so protege apos a primeira resposta HTTPS — precisa do redirect e/ou preload.
- **`preload` sem subdominios prontos:** ao entrar na preload list com `includeSubDomains`, QUALQUER subdominio so-HTTP fica inacessivel — e a remocao da lista leva meses. Rollout gradual; so submeter quando 100% pronto.
- **`max-age` alto cedo demais:** se o HTTPS quebrar (cert expira), usuarios ficam travados sem fallback pela duracao do `max-age`. Suba `max-age` gradualmente.
- **CSP com `unsafe-inline`/`unsafe-eval`:** anula grande parte da protecao; migrar para nonce/hash. Mas mudar CSP sem `Report-Only` antes quebra a app — sempre medir primeiro.
- **Redirect loop atras de proxy/CDN:** o app ve `http` interno (TLS termina na borda) e redireciona infinitamente. Corrigir lendo `X-Forwarded-Proto`/`Forwarded` (trust proxy, `SECURE_PROXY_SSL_HEADER`, etc.).
- **Header duplicado:** app E proxy emitem o mesmo header com valores diferentes; o browser pode honrar o mais fraco. Defina a autoridade unica por header.
- **Mixed content so em pagina interna rara:** a home esta limpa mas uma pagina pouco acessada carrega script via http e quebra/avisa. Varra TUDO, nao so a home.
- **Redirect em API:** clientes nao-browser (curl sem `-L`, libs, mobile) nao seguem 301 -> falha silenciosa ou POST vira GET. Para APIs, preferir 403/426 + HSTS e exigir https no cliente.
- **API mobile com cert pinning:** rotacao do certificado quebra o app se nao houver backup pins/plano de rotacao.
- **`Secure` cookie ausente:** o cookie de sessao vaza na primeira requisicao http antes do redirect.
- **Protocolo-relativo (`//host`):** funciona no browser, mas quebra em email/app nativo/contexto file e mascara a intencao. Use `https://` explicito.
- **`upgrade-insecure-requests` como muleta:** ajuda com legado, mas nao substitui corrigir o `http://` hardcoded na fonte.
- **TLS legado "para compatibilidade":** TLS 1.0/1.1 habilitado abre downgrade; remova e meca o impacto real em clientes.

## 11. REGRAS DE QUALIDADE E AUTO-VERIFICACAO

- Seja **especifico**: cite arquivo/linha, camada, diretiva e valor exato, ou o output de `curl -I`. Sem isso, marque "nao visivel no contexto" e diga o que precisaria ver.
- **Nao invente** dominios, rotas, headers, diretivas ou metricas.
- Diferencie **confirmado** de **provavel** de **suspeito**; declare o que falta e o que confirmaria.
- Para cada achado, **sempre** correcao por servidor/CDN/framework + como validar empiricamente.
- Verifique que a correcao **nao introduz** outro problema (redirect loop, CSP que quebra a app, `preload` irreversivel, header duplicado).
- Sinalize SEMPRE as acoes com risco de irreversibilidade (preload, max-age alto) com aviso e plano de rollout/rollback.
- Auto-revise (Pass 9) antes de finalizar: re-leia cada achado cacando falso positivo e contexto faltante.
- Cite a **fronteira** com `injection-xss-csrf-audit` quando a CSP/X-Frame-Options aparecer como anti-XSS/clickjacking; aqui o mergulho e transporte + suite completa de headers.
- Util tanto para um desenvolvedor leigo (passos claros) quanto para um engenheiro senior (precisao tecnica). Profundidade real, sem enchimento. Markdown impecavel.
