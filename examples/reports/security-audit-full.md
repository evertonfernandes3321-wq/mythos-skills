# security-audit-full — Report

- **Date:** 2026-06-07
- **Skill:** `security-audit-full` (defensive, authorized, sub-atomic)
- **Target:** `examples/sample-target/` (synthetic, intentionally insecure demo)
- **Detected stack:** Node.js · Express · `mysql2` driver · MySQL
- **Scope:** `app.js`, `db.js` (full read; static defensive review)
- **Applicability:** Applicable (web backend with auth, an admin route, and a SQL data layer)

> Note: this target is a deliberately vulnerable teaching artifact. Findings are real
> for this code but the app is synthetic — no real data or secrets are involved. Any
> example secret is masked as `***`. No offensive/operationalizable payloads are included.

---

## 1. Executive summary

This is a ~90-line Express service that is **not safe to expose**. In two small files it
manages to stack most of the OWASP "classics": SQL injection via string concatenation,
a hardcoded database credential and a hardcoded token-signing secret, an administrative
endpoint with **no authorization at all**, a destructive `DELETE` endpoint with no auth
and no ownership check, password storage with **unsalted MD5**, reflected XSS on the
search endpoint, and a complete absence of rate limiting and security headers.

Several of these compose into a worst-case chain: an unauthenticated, unthrottled
`/login` backed by a concatenated SQL query (`db.js:14`) sits next to `/admin/users`
(`app.js:47`), which returns every user's email, role **and** password hash. Because the
hashes are unsalted MD5 (`app.js:15`), exposed hashes are effectively cleartext for
common passwords.

- **Critical findings:** 5  ·  **High:** 2  ·  **Medium:** 2  ·  **Informational:** 1
- **Biggest immediate risk:** full account/user-base compromise via `/admin/users`
  (no authz) combined with crackable MD5 hashes.
- **Data-leak possible:** yes (entire `users` table, including credential material).
- **Improper-access possible:** yes (admin data and destructive delete are open to anyone).
- **Security maturity:** **inexistente** (none). There is no authentication enforcement
  on protected routes, no authorization layer, no input handling discipline, no secret
  management, and no security headers.
- **Primary recommendation:** treat as **No-Go**. Close the open admin/delete routes and
  the SQLi first (Phase 0), then secrets, hashing, XSS, and platform hardening.

---

## 2. System map and attack surface

| Element | Detail |
|---|---|
| Entrypoint | `app.js` (Express app, listens on `:3000`, `app.js:62`) |
| Data layer | `db.js` (mysql2 pool) |
| Routes | `POST /login` · `GET /search` · `GET /admin/users` · `DELETE /users/:id` |
| Auth | None enforced anywhere (no session/JWT verification middleware) |
| Authorization | None (no role/ownership checks on any route) |
| Sensitive assets | DB credentials, token-signing secret, user emails, roles, password hashes |
| Untrusted inputs | `req.body.email`, `req.body.password`, `req.query.q`, `req.params.id` |
| Dangerous sinks | Concatenated SQL (`db.js:14`, `app.js:36`); HTML response (`app.js:40`) |
| Trust boundaries | HTTP request → handler → SQL sink / HTML sink (no validation layer between) |

---

## 3. Findings (critical first)

## ACHADO-01: Administrative endpoint has no authorization (mass data exposure)

- Severidade: critica
- Prioridade: P0
- Confianca: confirmada
- Categoria: autorizacao | IDOR/BOLA
- Localizacao:
  - arquivo: `app.js`
  - funcao/rota: `GET /admin/users` handler
  - trecho: `app.js:47`–`app.js:52`
- Evidencia: The handler runs `SELECT id, email, role, pass_md5 FROM users` and returns
  the rows directly (`app.js:48`, `app.js:50`). There is no authentication check and no
  role check anywhere before the query.
- Fluxo vulneravel:
  - source: any HTTP client hitting `/admin/users`
  - validacao: none
  - autorizacao: **none** (no `isAdmin`/session/JWT check)
  - sink: DB read returned verbatim to the caller
  - impacto: complete disclosure of every user's email, role, and password hash
- Por que isso e vulneravel: an "admin" path is protected only by being named `/admin`;
  nothing verifies the caller. This is Broken Function Level Authorization.
- Impacto real:
  - confidencialidade: full user table, including credential material
  - integridade: n/a directly (but enables follow-on takeover via cracked hashes)
  - privacidade: every user's email exposed (PII)
- Pre-condicoes: anonymous (no account needed)
- Como validar com seguranca: in a local throwaway instance, request `/admin/users`
  with no credentials and confirm it returns rows. Then add the guard and confirm `401/403`.
- Correcao recomendada: require authentication on the route and verify an admin role
  server-side from a validated token/session — never from client-supplied data.
- Exemplo de correcao:
  ```js
  function requireAdmin(req, res, next) {
    const user = verifySession(req); // verifies a signed token/session server-side
    if (!user) return res.status(401).json({ error: 'unauthenticated' });
    if (user.role !== 'admin') return res.status(403).json({ error: 'forbidden' });
    req.user = user;
    next();
  }
  app.get('/admin/users', requireAdmin, (req, res) => { /* ... */ });
  ```
  Also stop selecting `pass_md5` for this listing — credential material should never be returned.
- Teste recomendado: a test that calls `/admin/users` anonymously expects `401`; with a
  non-admin token expects `403`; with an admin token expects `200` and **no** hash field.
- Risco residual: ensure the same guard is applied to every future admin route.
- Status sugerido: corrigir agora.

## ACHADO-02: Destructive DELETE endpoint has no auth and no ownership check (BOLA)

- Severidade: critica
- Prioridade: P0
- Confianca: confirmada
- Categoria: autorizacao | IDOR/BOLA
- Localizacao:
  - arquivo: `app.js`
  - funcao/rota: `DELETE /users/:id` handler
  - trecho: `app.js:55`–`app.js:59`
- Evidencia: `DELETE FROM users WHERE id = ?` runs for any `:id` with no auth and no
  ownership verification (`app.js:56`). The query itself is parameterized (good), but the
  **authorization** is missing entirely.
- Fluxo vulneravel:
  - source: `req.params.id`
  - autorizacao: none
  - sink: destructive DB write
  - impacto: any anonymous caller can delete any user, including admins
- Por que isso e vulneravel: object-level authorization is absent — neither identity nor
  ownership of the target object is checked (Broken Object Level Authorization).
- Impacto real:
  - integridade: arbitrary destruction of user records
  - disponibilidade: an attacker can delete the entire user base
- Pre-condicoes: anonymous
- Como validar com seguranca: in a local instance with seed data, confirm an
  unauthenticated `DELETE /users/<seed-id>` removes the row; after the fix, confirm it is rejected.
- Correcao recomendada: require authentication, then authorize either by admin role or by
  resource ownership (`req.user.id === targetId`).
- Exemplo de correcao:
  ```js
  app.delete('/users/:id', requireAuth, (req, res, next) => {
    const targetId = req.params.id;
    if (req.user.role !== 'admin' && String(req.user.id) !== String(targetId)) {
      return res.status(403).json({ error: 'forbidden' });
    }
    pool.query('DELETE FROM users WHERE id = ?', [targetId], (err) => { /* ... */ });
  });
  ```
- Teste recomendado: anonymous delete → `401`; non-owner non-admin delete → `403`;
  owner/admin delete → `200`.
- Status sugerido: corrigir agora.

## ACHADO-03: SQL injection via string concatenation in the login data path

- Severidade: critica
- Prioridade: P0
- Confianca: confirmada
- Categoria: injecao
- Localizacao:
  - arquivo: `db.js`
  - funcao: `rawFindUserByEmail` (`db.js:13`)
  - trecho: `db.js:14` (query built with `"... WHERE email = '" + email + "'"`)
  - chamada: `app.js:22` (login passes `req.body.email` straight in)
- Evidencia: the email value is concatenated directly into the SQL string with no binding.
  An attacker controls part of the WHERE clause.
- Fluxo vulneravel:
  - source: `req.body.email` (`app.js:21`)
  - validacao: none
  - sink: concatenated SQL passed to `pool.query` (`db.js:14`–`db.js:15`)
  - impacto: authentication bypass and arbitrary read of the `users` table
- Por que isso e vulneravel: the driver receives an already-assembled string, so input is
  interpreted as SQL syntax, not as a value.
- Impacto real:
  - confidencialidade: read arbitrary rows/columns; auth bypass
  - integridade: depending on DB privileges, potential writes
- Pre-condicoes: anonymous (login is public)
- Como validar com seguranca: add a unit test that passes an email containing a single
  quote and assert the parameterized version treats it as a literal (no error, no extra rows).
  Demonstrate the *mechanism* (concatenation) without a destructive payload.
- Correcao recomendada: use parameter binding; never concatenate user input into SQL.
- Exemplo de correcao:
  ```js
  // db.js
  function findUserByEmail(email, cb) {
    pool.query(
      'SELECT id, email, pass_md5, role FROM users WHERE email = ?',
      [email],
      cb
    );
  }
  ```
- Teste recomendado: a regression test asserting that quote/escape characters in `email`
  are bound as data and return zero matching rows rather than altering the query.
- Risco residual: audit every other query builder for concatenation (see ACHADO-07).
- Status sugerido: corrigir agora.

## ACHADO-04: Hardcoded database credential committed to source

- Severidade: critica
- Prioridade: P0
- Confianca: confirmada
- Categoria: secrets | configuracao
- Localizacao:
  - arquivo: `db.js`
  - trecho: `db.js:8` (`password: '***'` — masked here)
- Evidencia: the MySQL pool is configured with an inline password literal at `db.js:8`.
  (The value is masked as `***` in this report.)
- Fluxo vulneravel:
  - source: source code committed to the repo
  - sink: anyone with repo/history read access obtains the credential
  - impacto: direct database access if the credential is real/reused
- Por que isso e vulneravel: secrets in source are exposed to everyone with repo access
  and persist in git history even after removal.
- Impacto real:
  - confidencialidade: DB credential disclosure
  - compliance: secret-in-repo is a common audit failure
- Pre-condicoes: read access to the repository or its history
- Como validar com seguranca: confirm the literal is present in `db.js`; confirm it is not
  read from `process.env`. (Do not print the value — keep it masked.)
- Correcao recomendada: load from environment / a secret manager and fail closed if absent.
- Exemplo de correcao:
  ```js
  const pool = mysql.createPool({
    host: process.env.DB_HOST,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD, // from env / secret manager
    database: process.env.DB_NAME,
  });
  if (!process.env.DB_PASSWORD) throw new Error('DB_PASSWORD is required'); // fail closed
  ```
- Teste recomendado: a startup test that the app throws when `DB_PASSWORD` is unset; a
  secret-scanning step in CI that fails on inline credentials.
- Risco residual: **rotate** the credential, since committed secrets must be treated as leaked.
- Status sugerido: corrigir agora.

## ACHADO-05: Hardcoded token-signing secret (and a non-cryptographic "token")

- Severidade: critica
- Prioridade: P0
- Confianca: confirmada
- Categoria: secrets | criptografia | autenticacao
- Localizacao:
  - arquivo: `app.js`
  - trecho: `app.js:11` (`const JWT_SECRET = '***'`), used at `app.js:26`
- Evidencia: a signing secret is hardcoded (`app.js:11`, masked as `***`) and the issued
  "token" is just `secret + ':' + user.id` (`app.js:26`) — no signature, no expiry.
- Fluxo vulneravel:
  - source: hardcoded constant
  - sink: returned to the client as an auth token
  - impacto: anyone who learns the constant can forge a token for any `user.id`
- Por que isso e vulneravel: the secret is in source (leak risk) and the "token" is not a
  verifiable signed artifact — it is a guessable string.
- Impacto real:
  - confidencialidade/integridade: account impersonation / takeover
- Pre-condicoes: knowledge of the constant (which is in the repo)
- Como validar com seguranca: confirm the constant exists in source and that the token has
  no signature/expiry. Do not publish the value.
- Correcao recomendada: load the secret from env/secret manager; issue real signed tokens
  (e.g., HS256/EdDSA JWT) with expiry, and verify them server-side on every protected route.
- Exemplo de correcao:
  ```js
  const SECRET = process.env.JWT_SECRET;
  if (!SECRET) throw new Error('JWT_SECRET is required');
  // issue:  jwt.sign({ sub: user.id, role: user.role }, SECRET, { expiresIn: '15m' })
  // verify: jwt.verify(token, SECRET) inside requireAuth middleware
  ```
- Teste recomendado: token forgery test (a crafted token without a valid signature is
  rejected); expired token is rejected.
- Risco residual: rotate the secret; the leaked constant must be considered compromised.
- Status sugerido: corrigir agora.

## ACHADO-06: Reflected XSS on the search endpoint (unescaped HTML response)

- Severidade: alta
- Prioridade: P1
- Confianca: confirmada
- Categoria: XSS
- Localizacao:
  - arquivo: `app.js`
  - funcao/rota: `GET /search`
  - trecho: `app.js:40`–`app.js:41` (the raw `term` and row names are concatenated into HTML)
- Evidencia: `term` (`app.js:35`) is reflected into an HTML response at `app.js:40` with no
  output escaping; row `name` values are also concatenated unescaped at `app.js:41`. The
  `Content-Type` is `text/html` (`app.js:39`).
- Fluxo vulneravel:
  - source: `req.query.q`
  - validacao/escaping: none
  - sink: HTML body sent to the browser
  - impacto: attacker-controlled markup/script executes in the victim's browser context
- Por que isso e vulneravel: HTML-context output requires HTML-entity escaping; raw
  concatenation lets input break out of text context.
- Impacto real:
  - confidencialidade/integridade: session theft, action-on-behalf, defacement
- Pre-condicoes: victim opens an attacker-crafted `/search?q=...` link (reflected)
- Como validar com seguranca: render a benign marker (a harmless string with angle
  brackets) and confirm it appears escaped as text after the fix, not as live markup.
- Correcao recomendada: escape per output context, or return JSON and render client-side
  with a framework that auto-escapes.
- Exemplo de correcao:
  ```js
  const escapeHtml = (s) => String(s).replace(/[&<>"']/g, (c) => (
    { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]
  ));
  res.send('<h1>Results for ' + escapeHtml(term) + '</h1>');
  // better: res.json({ term, results }) and escape in the view layer
  ```
  Add a Content-Security-Policy as defense-in-depth (see ACHADO-09).
- Teste recomendado: a test that submits markup in `q` and asserts the response contains
  the escaped entities, not raw tags.
- Status sugerido: corrigir antes do deploy.

## ACHADO-07: Second SQL injection sink in the search query

- Severidade: alta
- Prioridade: P1
- Confianca: confirmada
- Categoria: injecao
- Localizacao:
  - arquivo: `app.js`
  - trecho: `app.js:36` (`"... LIKE '%" + term + "%'"`)
- Evidencia: `term` from `req.query.q` is concatenated into a `LIKE` clause and executed at
  `app.js:37` without binding.
- Fluxo vulneravel:
  - source: `req.query.q`
  - validacao: none
  - sink: concatenated SQL (`app.js:36`)
  - impacto: arbitrary read of the database, same class as ACHADO-03
- Por que isso e vulneravel: user input alters SQL structure; `LIKE` is no exception.
- Impacto real:
  - confidencialidade: data exfiltration; integridade: possible writes per DB privileges
- Pre-condicoes: anonymous
- Como validar com seguranca: unit test confirming special characters are bound as data.
- Correcao recomendada: parameterize, and escape `LIKE` wildcards in the value itself.
- Exemplo de correcao:
  ```js
  const like = '%' + term.replace(/[%_\\]/g, (c) => '\\' + c) + '%';
  pool.query('SELECT id, name FROM products WHERE name LIKE ? ESCAPE \'\\\\\'', [like], cb);
  ```
- Teste recomendado: regression test asserting injected metacharacters do not change the
  result set or raise SQL syntax errors.
- Status sugerido: corrigir antes do deploy.

## ACHADO-08: Passwords hashed with unsalted MD5

- Severidade: critica
- Prioridade: P0
- Confianca: confirmada
- Categoria: criptografia | autenticacao
- Localizacao:
  - arquivo: `app.js`
  - funcao: `hashPassword` (`app.js:14`–`app.js:16`), compared at `app.js:25`
- Evidencia: `crypto.createHash('md5')` over the plaintext with no salt (`app.js:15`).
  Stored as `pass_md5` and compared directly.
- Fluxo vulneravel:
  - source: user password at registration/login
  - sink: stored MD5 digest
  - impacto: if hashes leak (see ACHADO-01), common passwords are recovered trivially via
    precomputed/rainbow tables; identical passwords produce identical hashes
- Por que isso e vulneravel: MD5 is fast and unsalted, exactly the opposite of what a
  password hash needs.
- Impacto real:
  - confidencialidade: large-scale credential recovery → account takeover, credential reuse
- Pre-condicoes: hash exposure (which ACHADO-01 provides) or DB compromise
- Como validar com seguranca: confirm `md5` is used and there is no per-user salt; after
  the fix, confirm hashes are Argon2/bcrypt with a per-user salt.
- Correcao recomendada: use a memory-hard password hash (Argon2id preferred, or bcrypt),
  compare with the library's verify function, and migrate existing hashes transparently on
  next successful login.
- Exemplo de correcao:
  ```js
  const argon2 = require('argon2');
  const hash = await argon2.hash(plain);          // store this
  const ok = await argon2.verify(user.pass_hash, plain); // compare on login
  ```
- Teste recomendado: a test asserting the same password yields different stored hashes
  (salted) and that verification succeeds/fails correctly.
- Risco residual: until migration completes, treat all MD5 hashes as compromised.
- Status sugerido: corrigir agora.

## ACHADO-09: No security headers and no rate limiting

- Severidade: media
- Prioridade: P1
- Confianca: confirmada
- Categoria: configuracao | observabilidade | business logic
- Localizacao:
  - arquivo: `app.js`
  - trecho: app initialization (`app.js:7`–`app.js:8`); login has no throttle (`app.js:20`)
- Evidencia: no middleware sets `Content-Security-Policy`, `X-Content-Type-Options`,
  `X-Frame-Options`/`frame-ancestors`, `Strict-Transport-Security`, or `Referrer-Policy`;
  no rate-limiting middleware guards `/login` or `/search`.
- Fluxo vulneravel:
  - source: any client
  - sink: unthrottled auth attempts; browser without protective headers
  - impacto: brute force / credential stuffing on `/login`; weaker XSS/clickjacking posture
- Por que isso e vulneravel: missing headers remove defense-in-depth; no throttle makes
  credential attacks cheap (and compounds the SQLi/MD5 issues).
- Impacto real:
  - confidencialidade: easier credential attacks; disponibilidade: trivial abuse
- Pre-condicoes: anonymous
- Como validar com seguranca: inspect response headers (e.g., `curl -I`) before/after;
  hammer `/login` in a local test and confirm throttling kicks in after the fix.
- Correcao recomendada: add `helmet()` (or set headers at the gateway/CDN) and a rate
  limiter on sensitive endpoints.
- Exemplo de correcao:
  ```js
  const helmet = require('helmet');
  const rateLimit = require('express-rate-limit');
  app.use(helmet());
  app.use('/login', rateLimit({ windowMs: 60_000, max: 10 }));
  ```
- Teste recomendado: header-presence test; rate-limit test asserting `429` after N attempts.
- Status sugerido: corrigir antes do deploy.

## ACHADO-10: Generic 500 error responses (low-signal, but acceptable)

- Severidade: informativa
- Prioridade: P3
- Confianca: confirmada
- Categoria: erro/falha silenciosa | observabilidade
- Localizacao: error branches across handlers (e.g., `app.js:23`, `app.js:38`, `app.js:49`, `app.js:57`)
- Evidencia: errors are caught and a generic message is returned (good — no stack leak),
  but they are not logged with context, so failures are invisible operationally.
- Impacto real: debuggability/observability gap; not a direct exploit.
- Correcao recomendada: log errors with a request id and structured context (without
  leaking sensitive data), keeping the generic client-facing message.
- Como validar: trigger a DB error locally and confirm a structured log line is emitted.
- Status sugerido: monitorar / planejar.

---

## 4. Consolidated findings table

| ID | Severity | Priority | Category | Location | Problem | Fix |
|----|----------|----------|----------|----------|---------|-----|
| 01 | Critical | P0 | AuthZ/BFLA | `app.js:47` | `/admin/users` open to anyone | Require auth + admin role; stop returning hashes |
| 02 | Critical | P0 | AuthZ/BOLA | `app.js:55` | `DELETE /users/:id` open, no ownership | Require auth + ownership/admin check |
| 03 | Critical | P0 | Injection | `db.js:14` | Concatenated SQL in login | Parameterize query |
| 04 | Critical | P0 | Secrets | `db.js:8` | Hardcoded DB password `***` | Move to env/secret manager + rotate |
| 05 | Critical | P0 | Secrets/Crypto | `app.js:11` | Hardcoded signing secret + fake token | Env secret + real signed JWT + verify |
| 06 | High | P1 | XSS | `app.js:40` | Reflected, unescaped HTML | Contextual escaping / JSON + CSP |
| 07 | High | P1 | Injection | `app.js:36` | Concatenated SQL in search | Parameterize + escape LIKE wildcards |
| 08 | Critical | P0 | Crypto | `app.js:15` | Unsalted MD5 password hashing | Argon2id/bcrypt + transparent re-hash |
| 09 | Medium | P1 | Config | `app.js:7` | No security headers / no rate limit | `helmet()` + rate limiter |
| 10 | Info | P3 | Error/Obs | `app.js:23` | Errors not logged with context | Structured logging w/ request id |

---

## 5. Authentication & authorization matrix

| Resource / Action | Anonymous | User | Owner | Admin | Other tenant | Observation |
|---|---|---|---|---|---|---|
| `POST /login` | allowed | allowed | — | — | — | No throttle (ACHADO-09); SQLi sink (ACHADO-03) |
| `GET /search` | allowed | allowed | — | — | — | XSS + SQLi (ACHADO-06/07) |
| `GET /admin/users` | **allowed (BUG)** | allowed (BUG) | — | should be only-admin | n/a | No authz at all (ACHADO-01) |
| `DELETE /users/:id` | **allowed (BUG)** | allowed (BUG) | should be owner | should be admin | n/a | No authz/ownership (ACHADO-02) |

Every row that should be restricted is currently open to anonymous callers.

---

## 6. Sensitive-data map

| Sensitive data | Origin | Stored where | Shown where | Logged where | Risk | Fix |
|---|---|---|---|---|---|---|
| DB password | `db.js:8` | source code | — | — | Critical (secret in repo) | env + rotate |
| Signing secret | `app.js:11` | source code | indirectly via token (`app.js:26`) | — | Critical | env + real JWT |
| Password hashes | `users.pass_md5` | DB | `/admin/users` (`app.js:50`) | — | Critical (MD5 + exposed) | Argon2id; never return |
| User emails (PII) | DB | DB | `/admin/users` | — | High (open route) | authz + minimize fields |

---

## 7. Source-to-sink analysis

| Source | Transform | Validation | AuthZ | Sink | Risk | Fix |
|---|---|---|---|---|---|---|
| `req.body.email` (`app.js:21`) | concat into SQL | none | n/a | `pool.query` (`db.js:14`) | SQLi | parameterize |
| `req.query.q` (`app.js:35`) | concat into SQL | none | n/a | `pool.query` (`app.js:37`) | SQLi | parameterize |
| `req.query.q` (`app.js:35`) | concat into HTML | none | n/a | `res.send` (`app.js:40`) | XSS | escape/JSON |
| `req.params.id` (`app.js:56`) | bound param (safe) | none | **none** | `DELETE` (`app.js:56`) | BOLA | authz/ownership |

---

## 8. Secrets and configuration

- Hardcoded DB password at `db.js:8` (masked `***`) — move to env, **rotate**.
- Hardcoded signing secret at `app.js:11` (masked `***`) — move to env, **rotate**, switch to real signed tokens.
- No env-var validation / fail-closed startup — add it.
- No `.env`/secret-manager usage detected.

## 9. Dependencies and supply chain

- Declared usage: `express`, `mysql2`, plus Node core `crypto`. No `package.json`/lockfile is
  present in the sample, so versions and transitive risk cannot be assessed — **needs context**.
- Recommendation: add a pinned lockfile and run dependency/secret scanning in CI.

## 10. Infrastructure, cloud and CI/CD

- Not present in the sample (no Dockerfile/IaC/CI). **Needs context** — out of scope for this target.

## 11. Privacy and compliance

- Personal data (emails) is exposed by an unauthenticated route (ACHADO-01); password hashes
  are returned in an API response. Both are reportable data-exposure issues under LGPD/GDPR if real.
- Recommendation: minimize returned fields, never expose credential material, gate by authz.

## 12. Silent failures and error handling

- No empty `catch` blocks; errors return generic messages (no stack leak — good).
- Gap: errors are not logged with context (ACHADO-10) → operational blindness.

---

## 13. Prioritized remediation plan

- **Phase 0 — Immediate containment (P0):**
  - Add authentication + authorization to `/admin/users` (ACHADO-01) and `DELETE /users/:id`
    (ACHADO-02). Until fixed, disable these routes.
  - Parameterize the login query (ACHADO-03) and the search query (ACHADO-07).
  - Move both secrets to env and **rotate** them (ACHADO-04, ACHADO-05).
  - Replace MD5 with Argon2id/bcrypt + transparent re-hash (ACHADO-08).
  - Acceptance: anonymous access to admin/delete returns 401/403; injected quotes are bound
    as data; no secret literals in source; new hashes are salted/memory-hard.
- **Phase 1 — Critical hardening (P1):**
  - Contextual escaping (or JSON) for `/search` (ACHADO-06).
  - `helmet()` security headers + rate limiting on `/login` and `/search` (ACHADO-09).
- **Phase 2 — Structural hardening:** centralized validation, an auth middleware applied by
  default, a query layer that forbids raw concatenation.
- **Phase 3 — Supply chain / infra:** add lockfile + dependency/secret scanning in CI.
- **Phase 4 — Tests & automation:** authz tests, SQLi/XSS regression tests, rate-limit tests.
- **Phase 5 — Observability:** structured logging with request ids; alerts on auth failures.

## 14. Reviewed code / patches

See the per-finding "Exemplo de correcao" blocks above. Net changes: parameterized queries,
an `requireAuth`/`requireAdmin` middleware, env-based secrets with fail-closed startup,
Argon2id hashing, contextual HTML escaping, and `helmet()` + rate limiting.

## 15. Required tests (by priority)

- **P0:** anonymous `/admin/users` → 401/403; anonymous delete → 401/403; SQLi regression on
  login + search; "no secret literals in source" CI check; salted-hash test.
- **P1:** XSS escaping test on `/search`; security-header presence test; rate-limit test.
- **P2:** input validation tests; centralized-auth coverage.

## 16. Production-readiness checklist

- [ ] No secret in the repository — **FAIL** (`db.js:8`, `app.js:11`)
- [ ] No token/secret returned to the client improperly — **FAIL** (`app.js:26`)
- [ ] All sensitive routes require authentication — **FAIL** (`app.js:47`, `app.js:55`)
- [ ] Authorization is per-resource, not just per-route — **FAIL**
- [ ] No known IDOR/BOLA — **FAIL** (ACHADO-01/02)
- [ ] No known SQL injection — **FAIL** (ACHADO-03/07)
- [ ] No known XSS — **FAIL** (ACHADO-06)
- [ ] Inputs validated server-side — **FAIL**
- [ ] Passwords hashed with a memory-hard algorithm + salt — **FAIL** (ACHADO-08)
- [ ] Security headers present — **FAIL** (ACHADO-09)
- [ ] Rate limiting on sensitive endpoints — **FAIL** (ACHADO-09)
- [ ] Errors logged with context, no stack leak — **PARTIAL** (no leak; not logged)

## 17. Final decision summary

**Can this go to production? No.**

Top blockers, in order: open admin and delete routes (ACHADO-01/02), SQL injection
(ACHADO-03/07), hardcoded + rotatable secrets (ACHADO-04/05), and unsalted MD5 hashing
(ACHADO-08). Fix everything in Phase 0 before any exposure, then Phase 1, then re-audit.
Residual risk after Phase 0/1 is acceptable for a demo but the dependency/CI gaps
(needs-context items) should be closed before a real launch.

*Next most important step: close the two open routes and parameterize the queries today.*
