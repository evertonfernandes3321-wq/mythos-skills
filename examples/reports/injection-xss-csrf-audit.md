# injection-xss-csrf-audit — Report

- **Date:** 2026-06-07
- **Skill:** `injection-xss-csrf-audit` (defensive, authorized)
- **Target:** `examples/sample-target/` (synthetic, intentionally insecure demo)
- **Detected stack:** Node.js · Express · `mysql2` · MySQL
- **Scope:** `app.js`, `db.js`
- **Applicability:** Applicable (HTTP app with SQL sinks, an HTML response, and state-changing endpoints)

> This target is a deliberately vulnerable teaching artifact. Findings are real for this
> code but the app is synthetic. Example secrets are masked as `***`. Proofs of concept
> are described as safe, minimal mechanisms only — no operationalizable payloads.

---

## 8.1 Executive summary

Posture: **weak**. The five mission areas (injection, XSS, CSRF, double validation,
security headers) are largely unaddressed. There are **two confirmed SQL injection sinks**
(login via `db.js:14`, search via `app.js:36`) built with string concatenation, **one
confirmed reflected XSS** (`app.js:40`–`app.js:41`), **no input validation** on any source,
and **no security headers**. CSRF is **not currently applicable** because the app does not
use cookie-based sessions, but this would change the moment a cookie auth fallback is added.

- Findings by severity: Critical 2 · High 1 · Medium 1 · Informational 1.
- Three most urgent: (1) SQLi in login (`db.js:14`), (2) SQLi in search (`app.js:36`),
  (3) reflected XSS in search (`app.js:40`).
- Missing context: no `package.json`/lockfile, so library versions and any framework-level
  escaping defaults cannot be confirmed; no client/browser code is present to assess DOM XSS.

---

## 8.2 Findings (fixed block per finding)

```
[INJ-1] SQL injection in login (concatenated email)
Classe: SQLi
Severidade: Critica | Prioridade: P0 | Confianca: Confirmada | Esforco: Baixo
Localizacao: db.js:14 -> rawFindUserByEmail()  (called from app.js:22)
Source -> Sink: req.body.email (app.js:21) -> string-concatenated SQL passed to pool.query (db.js:14-15)
Evidencia: const sql = "SELECT id, email, pass_md5, role FROM users WHERE email = '" + email + "'";
Impacto: input is interpreted as SQL syntax, enabling authentication bypass and arbitrary
  reads of the users table (auth bypass + data disclosure).
Correcao: use parameter binding; pass values as the second argument to pool.query and never
  build the WHERE clause by concatenation.
Exemplo de correcao:
  pool.query('SELECT id, email, pass_md5, role FROM users WHERE email = ?', [email], cb);
Teste recomendado: unit test passing an email that contains a single quote; assert it is
  treated as a literal (zero rows / no SQL error), proving the value is bound as data.
```

```
[INJ-2] SQL injection in product search (concatenated LIKE)
Classe: SQLi
Severidade: Alta | Prioridade: P1 | Confianca: Confirmada | Esforco: Baixo
Localizacao: app.js:36 -> GET /search handler
Source -> Sink: req.query.q (app.js:35) -> string-concatenated SQL passed to pool.query (app.js:36-37)
Evidencia: const sql = "SELECT id, name FROM products WHERE name LIKE '%" + term + "%'";
Impacto: arbitrary read of the database (same class as INJ-1); user input alters the query
  structure inside the LIKE clause.
Correcao: parameterize the value, and escape LIKE metacharacters (%, _, \) in the term so they
  are matched literally.
Exemplo de correcao:
  const like = '%' + term.replace(/[%_\\]/g, (c) => '\\' + c) + '%';
  pool.query("SELECT id, name FROM products WHERE name LIKE ? ESCAPE '\\\\'", [like], cb);
Teste recomendado: regression test asserting metacharacters in q do not change the result set
  or raise a SQL syntax error.
```

```
[XSS-1] Reflected XSS on search results page (unescaped HTML output)
Classe: XSS-refletido
Severidade: Alta | Prioridade: P1 | Confianca: Confirmada | Esforco: Baixo
Localizacao: app.js:40-41 -> GET /search handler (Content-Type set text/html at app.js:39)
Source -> Sink: req.query.q (app.js:35) -> HTML response body via res.send (app.js:40);
  row name values also concatenated unescaped (app.js:41)
Evidencia: res.send('<h1>Results for ' + term + '</h1>...' + rows.map(r => '<li>' + r.name + '</li>')...)
Impacto: attacker-controlled markup runs in the victim's browser context (session theft,
  actions-on-behalf, defacement). Stored row names are also a stored-XSS vector if they
  contain markup.
Correcao: escape per output context (HTML-entity escaping for HTML body), or return JSON and
  render in a framework that auto-escapes. Add a Content-Security-Policy as defense-in-depth.
Exemplo de correcao:
  const escapeHtml = (s) => String(s).replace(/[&<>"']/g, (c) =>
    ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  res.send('<h1>Results for ' + escapeHtml(term) + '</h1>');
  // and escape r.name the same way, or return res.json({ term, results })
Teste recomendado: submit a benign marker containing angle brackets in q and assert the
  response contains the escaped entities (text), not live tags.
```

```
[VAL-1] No server-side input validation on any untrusted source
Classe: Validacao
Severidade: Media | Prioridade: P1 | Confianca: Confirmada | Esforco: Medio
Localizacao: app.js:21 (email/password), app.js:35 (q), app.js:56 (id)
Source -> Sink: all request inputs flow to SQL/HTML sinks with no type, format, or size checks.
Evidencia: handlers read req.body / req.query / req.params and use them directly; no schema,
  no allow-list, no length/type coercion.
Impacto: enables the injection/XSS sinks above and leaves the app open to type-confusion and
  oversized-payload abuse; client validation (if any) would not be authoritative anyway.
Correcao: validate every input server-side with an allow-list schema (type, format, length,
  range), coerce types, and reject early. Keep client validation only for UX.
Exemplo de correcao:
  // with a schema validator (zod/joi/ajv-style):
  const Login = z.object({ email: z.string().email().max(254), password: z.string().min(1).max(200) });
  const { email, password } = Login.parse(req.body); // throws -> 400 on invalid input
Teste recomendado: tests asserting malformed/oversized inputs return 400 before reaching any sink.
```

```
[HDR-1] Security headers absent (CSP, X-Frame-Options, X-Content-Type-Options, HSTS, Referrer-Policy)
Classe: Header
Severidade: Media | Prioridade: P1 | Confianca: Confirmada | Esforco: Baixo
Localizacao: app.js:7-8 (app init; no header middleware)
Source -> Sink: every response is sent without protective headers.
Evidencia: no helmet() / no res.set of security headers anywhere in app.js.
Impacto: removes defense-in-depth against XSS (no CSP), clickjacking (no X-Frame-Options /
  frame-ancestors), and MIME sniffing (no nosniff); weakens transport posture (no HSTS).
Correcao: apply helmet() (or set headers at the gateway/CDN) consistently on all responses,
  including errors and redirects.
Exemplo de correcao:
  const helmet = require('helmet'); app.use(helmet());
  // Tighten CSP explicitly: default-src 'self'; object-src 'none'; frame-ancestors 'none'
Teste recomendado: header-presence test (curl -I) asserting CSP, X-Content-Type-Options:nosniff,
  X-Frame-Options/frame-ancestors, and HSTS (under HTTPS) are present.
```

```
[CSRF-0] CSRF not currently applicable (no cookie-based auth) — re-evaluate if cookies are added
Classe: CSRF
Severidade: Informativa | Prioridade: P3 | Confianca: Confirmada | Esforco: n/a
Localizacao: app.js (whole) — no cookie/session usage; token returned in JSON body (app.js:26)
Evidencia: the app does not set session cookies; the "token" is returned in the response body,
  so browser-driven CSRF does not apply to the current state-changing endpoints.
Impacto: none today. But DELETE /users/:id (app.js:55) is state-changing; if a cookie/session
  fallback is ever introduced, it becomes CSRF-able.
Correcao: if cookie auth is added later, protect state-changing requests with a synchronizer or
  double-submit token, SameSite=Lax/Strict cookies, and Origin/Referer checks.
Teste recomendado: when cookies are introduced, a cross-origin state-changing request without a
  valid CSRF token must be rejected.
```

---

## 8.3 Consolidated table

| ID | Classe | Local | Severity | Priority | Confidence | Effort |
|----|--------|-------|----------|----------|------------|--------|
| INJ-1 | SQLi | `db.js:14` | Critica | P0 | Confirmada | Baixo |
| INJ-2 | SQLi | `app.js:36` | Alta | P1 | Confirmada | Baixo |
| XSS-1 | XSS-refletido | `app.js:40` | Alta | P1 | Confirmada | Baixo |
| VAL-1 | Validacao | `app.js:21/35/56` | Media | P1 | Confirmada | Medio |
| HDR-1 | Header | `app.js:7` | Media | P1 | Confirmada | Baixo |
| CSRF-0 | CSRF | `app.js` (n/a) | Informativa | P3 | Confirmada | n/a |

---

## 8.4 Phased remediation plan

- **Phase 1 (P0):** Parameterize the login query (INJ-1). This is the single highest-leverage
  fix — it closes an unauthenticated, exploitable injection in the auth path.
- **Phase 2 (P1):** Parameterize the search query (INJ-2); add contextual HTML escaping or
  switch `/search` to JSON (XSS-1); add server-side validation schemas (VAL-1); add `helmet()`
  security headers (HDR-1).
- **Phase 3 (P2/P3) and hardening:** centralize a query layer that bans raw concatenation;
  add a Content-Security-Policy with nonces; revisit CSRF (CSRF-0) if cookie auth is ever added.

---

## 8.5 Coverage checklist

- [x] **Injection** — verified: 2 confirmed SQLi sinks (`db.js:14`, `app.js:36`); no NoSQL/OS/SSTI sinks present.
- [x] **XSS** — verified: 1 confirmed reflected XSS (`app.js:40-41`); stored-XSS vector via row names noted.
- [x] **CSRF** — verified not applicable today (no cookie sessions); flagged for re-evaluation.
- [x] **Double validation** — verified absent server-side (VAL-1); no client code present to compare.
- [x] **Security headers** — verified absent (HDR-1).
- [ ] **DOM-based XSS** — not verifiable: no client/browser JavaScript in the target (needs context).
- [ ] **Dependency-level escaping defaults** — not verifiable: no `package.json`/lockfile (needs context).
