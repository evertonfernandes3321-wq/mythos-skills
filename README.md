<div align="center">

# 🜂 Mythos Skills

**English** · [Português (pt-BR)](./README.pt-BR.md)

### A library of **44 engineering skills** for Claude Code — _Mythos_ grade

Auditing · Security · Databases · Observability · Operational rigor · Testing · Frontend · Integrations · Process · Business

**Sub-atomic rigor · Stack-agnostic · Defensive · Fixed output format**

![Stars](https://img.shields.io/github/stars/evertonfernandes3321-wq/mythos-skills?style=social)
[![License: MIT](https://img.shields.io/github/license/evertonfernandes3321-wq/mythos-skills)](./LICENSE)
![Release](https://img.shields.io/github/v/release/evertonfernandes3321-wq/mythos-skills)
![Last commit](https://img.shields.io/github/last-commit/evertonfernandes3321-wq/mythos-skills)
![Skills](https://img.shields.io/badge/skills-44-6366f1)
![Stack](https://img.shields.io/badge/stack-agnostic-0ea5e9.svg)

</div>

---

Point Claude Code at any repository and it audits, debugs, hardens, and ships — backed by 44 battle-tested skills that demand **empirical proof** instead of "looks good to me."

> ⭐ If this saves you time, a star helps others find it.

🚀 **Run them all at once:** [**`RUN-ALL.md`**](./RUN-ALL.md) drives every applicable skill against a single repository and produces **one report per skill** — a full engineering review in a single pass. See a [**sample report in `examples/`**](./examples/).

> 🌍 **A note on language:** skill bodies/prompts are written in **PT-BR (Portuguese)**; the **names, README and structure are English**. The prompts are stack-agnostic and work just as well when you ask in English. PRs translating bodies to EN are welcome.

---

## What this is

Each **skill** is a folder with a `SKILL.md` (YAML frontmatter + the operational prompt body). Claude Code discovers and routes to the right skill automatically via its `description`, or you invoke it directly with `/<skill-name>`.

What makes these skills **Mythos grade**:

- **Sub-atomic rigor** — happy path _and_ error path, edge cases, defaults, concurrency, roles (anonymous/user/admin/owner/other-tenant) and environments (dev/staging/prod).
- **Stack-agnostic** — they work in any language/framework, with parallel examples (JS/TS, Python, Go, Java/Kotlin, C#/.NET, Ruby, PHP, Rust, mobile; Postgres/MySQL/Mongo; Stripe/Square; PostHog/Mixpanel…). Two are specialized for **Flutter** (with their own `references/assets/scripts`).
- **Empirical verification** — validate via non-falsifiable output (hash/count/exit-code), never "it seems to work."
- **Defensive and safe** — sensitive topics are strictly defensive/authorized; secrets are always masked.
- **Fixed output format** — executive summary → findings with location + fix + test → consolidated table → phased plan → final checklist.

Origin: a private library of engineering prompts, distilled and generalized from real-world production patterns (web, mobile, backend, data, cloud), plus 2 Flutter-specialized skills.

> 💡 Prefer **pure prompts** (markdown, to paste into any LLM)? See the sibling repo [**mythos-prompts**](https://github.com/evertonfernandes3321-wq/mythos-prompts).

---

## Install

**Global (available in every project):**
```powershell
Copy-Item .\* "$env:USERPROFILE\.claude\skills\" -Recurse -Force   # Windows
```
```bash
cp -r ./* ~/.claude/skills/                                        # macOS/Linux
```

**Per project:** copy the desired skill folder into `<your-project>/.claude/skills/`.

**On claude.ai:** _Settings → Capabilities/Skills → Upload_, sending the skill's `.zip` (format `name/SKILL.md`).

Then just describe the task in natural language (e.g. _"run a security audit"_) or invoke it with `/<skill-name>`.

---

## Index

| Category | Skills |
|----------|--------|
| [🔒 Security](#-security) | 9 |
| [🗄️ Database & Data](#️-database--data) | 4 |
| [📊 Observability & Operations](#-observability--operations) | 5 |
| [⚙️ Operational Rigor & Coordination](#️-operational-rigor--coordination) | 4 |
| [🐛 Debugging, Testing & Quality](#-debugging-testing--quality) | 8 |
| [🎨 Frontend & UI Architecture](#-frontend--ui-architecture) | 4 |
| [🔌 Integrations, Billing & Privacy](#-integrations-billing--privacy) | 3 |
| [🏗️ Process, Design & Documentation](#️-process-design--documentation) | 4 |
| [📱 Mobile / Flutter](#-mobile--flutter) | 2 |
| [💼 Business](#-business) | 1 |

🏅 = **master** skill (the most comprehensive in its category).

---

## 🔒 Security

### `security-audit-full` 🏅
**End-to-end** defensive security audit, at the sub-atomic level.
**When to use:** authorized defensive pentest, pre-deploy review, or comprehensive hardening.
**Covers:** auth · authorization/IDOR · injections · XSS · SSRF · CSRF · uploads · secrets · crypto · supply chain · CI/CD · cloud/IaC · privacy · business logic · concurrency · AI/LLM.

### `auth-authorization-audit`
Authentication and authorization, with a **permission matrix** by resource/role.
**When to use:** validate who can do what; find unprotected routes and missing checks.
**Covers:** tokens/session/JWT (signature, expiration, revocation, logout, inactivity) · RBAC/ABAC · IDOR/BOLA per object · multi-tenant isolation · admin endpoints · least privilege · source-to-sink tracing of identity (userId/tenantId/role never trusted from the client).

### `auth-token-refresh-safety`
**Secure refresh token rotation under concurrency** (the mechanism, not RBAC).
**When to use:** implement/review persistent login on mobile/SPA.
**Covers:** single-flight mutex · anti-loop flag on 401 · PUBLIC_PATHS · reactive 401 interceptor · error taxonomy · backend rotation.

### `secrets-and-config-exposure-audit`
Hunts for exposed secrets and configuration before you publish/deploy.
**When to use:** before making a repo public or shipping a deploy.
**Covers:** hardcoded API keys/tokens/credentials (client and server) · internal endpoints leaked to the frontend · committed `.gitignore`/`.env` · migration to env vars and secret managers · config validation at startup.

### `injection-xss-csrf-audit`
Classic web vulnerabilities with concrete fixes per ecosystem.
**When to use:** reviewing user input, templates, forms and headers.
**Covers:** injections (SQL/NoSQL/OS/template) · **context-aware** escaping (HTML/attribute/URL/JS/CSS) · CSRF tokens · backend validation · headers (CSP, X-Frame-Options, HSTS).

### `file-upload-security-audit`
End-to-end security for file upload and handling.
**When to use:** any endpoint that accepts files.
**Covers:** real MIME + extension (allowlist) · magic bytes · size/count limits · sanitization against path traversal · private storage · blocking executables/SVG-script/polyglots/zip-bombs · signed URLs · sandbox · per-tenant isolation.

### `password-credential-security`
Passwords and credentials with hash migration **without breaking logins**.
**When to use:** you found plaintext/weak hashes, or you're hardening authentication.
**Covers:** detection of MD5/SHA1/raw-SHA256 · salt/pepper · Argon2id/bcrypt/scrypt with proper cost factor · zero-knowledge · constant-time comparison · secure reset · transparent re-hash on next login.

### `production-readiness-audit`
DevSecOps production-readiness audit (go/no-go).
**When to use:** before the final release/deploy.
**Covers:** vulnerable dependencies/CVEs (npm/pip/go/maven/cargo/composer/bundler) · hunting for _leftovers_ (test routes, mocks, fake data, hardcoded credentials, auth bypass/demo feature flags) · removal plan + safe upgrade + go/no-go checklist.

### `https-security-headers-audit`
Secure transport (HTTPS/TLS) and the full suite of **security headers**.
**When to use:** ensure nothing travels in the clear and block protocol downgrade.
**Covers:** mixed content (scripts/images/API/websocket over HTTP) · forced 301 redirect HTTP→HTTPS · HSTS (includeSubDomains/preload) · CSP (nonce/hash, upgrade-insecure-requests) · X-Frame-Options/frame-ancestors · X-Content-Type-Options · Referrer-Policy · Permissions-Policy · Secure/HttpOnly/SameSite cookies · TLS 1.2+ anti-downgrade · config for Nginx/Apache/Caddy/IIS/Traefik/CDN/framework · validation via `curl -I`/Observatory.

---

## 🗄️ Database & Data

### `database-tenant-isolation-audit` 🏅
Ensures **one tenant never sees another's data**.
**When to use:** multi-tenant SaaS; reviewing RLS/isolation.
**Covers:** RLS (row-level) vs schema-per-tenant and trade-offs · tenant context propagation · FORCE RLS · matrix testing (users × tables × operations) · leak detection (views/triggers/SECURITY DEFINER/service-role) · least privilege on roles/grants.

### `database-performance-audit`
Database and data-access-layer performance (deeper than the general audit).
**When to use:** the bottleneck is the query, the ORM, an inline policy, or data access.
**Covers:** slow RLS (per-row auth-function → cache/SELECT/helpers/indexes) · N+1 and batching (DataLoader) · missing indexes (FK without index, full scan) · EXPLAIN/ANALYZE · keyset/cursor pagination · pooling · transactions.

### `data-integrity-and-ledger-audit`
Invariants and ledger for **critical-state** systems.
**When to use:** before/after touching balances; PR, incident, or periodic audit (finance, wallet, escrow, inventory, credits).
**Covers:** Golden Formula (SUM = constant) · ledger and per-entry closure · balance cache coherence · double-entry · atomic transactions with meta-validation (rollback) · money never in float · append-only with reversals · external reconciliation · forensic snapshots (SHA-256).

### `cache-and-server-state-architecture`
Cache and server-state coherence, from client to database.
**When to use:** stale data, sync bugs, inconsistent invalidation.
**Covers:** query key factory · invalidation by tags/entities · optimistic update with rollback · flush→refresh→invalidate sequence after trigger-generated columns · React Query/RTK/SWR/Apollo/Riverpod + Hibernate/Prisma/SQLAlchemy/EF + Redis/CDN/HTTP.

---

## 📊 Observability & Operations

### `observability-logging-audit` 🏅
Makes the system **debuggable, auditable and safe** in production.
**When to use:** poor logs, silent failures, hard-to-diagnose incidents.
**Covers:** structured JSON logs · requestId/traceId correlation · elimination of silent failures · redaction/masking of sensitive data · log levels · metrics · tracing · health checks · alerts.

### `production-monitoring-standards`
**Rules for building** monitorable systems (not auditing — designing).
**When to use:** when designing or hardening a service's operability.
**Covers:** request ID · stack trace with context · JSON logs · health checks · query/cache tracking · performance metrics · regression tests · alerts · deploy with automatic rollback.

### `error-handling-audit`
Error handling and failure UX, frontend and backend.
**When to use:** swallowed errors, app freezes with no feedback, empty `catch`.
**Covers:** async operations without handling · silent failures · loss of stack/cause · error/retry/fallback states · error boundaries (reactive frameworks) · global handlers on the server · expected vs unexpected errors.

### `product-analytics-architecture`
Event-driven **product** analytics (distinct from logging).
**When to use:** measure activation, retention and conversion.
**Covers:** event catalog as constants · instrumentation with first-ever detection (activation funnel) · screen auto-tracking via route observer · privacy-first init with user toggle · PostHog/Mixpanel/Amplitude.

### `backup-disaster-recovery-audit`
Data resilience and **disaster recovery** — before the incident happens.
**When to use:** audit/build the backup/DR strategy (SRE/DBA view).
**Covers:** automated backups (dumps, cron/scheduler/K8s CronJob) · 3-2-1 rule with off-site isolation (the app credential must never be able to delete the backup) · encryption + retention · RPO/RTO · DR plan/runbook · **restore testing** (an untested backup is not a backup) · multi-stack scripts (pg_dump/xtrabackup/mongodump/restic → S3/GCS/Azure/B2/R2/MinIO) with hash verification and alerts.

---

## ⚙️ Operational Rigor & Coordination

### `paranoid-execution-mode` 🏅
Paranoid execution for **irreversible** operations.
**When to use:** touching database/deploy/infra/migration/auth/billing where wrong state causes damage.
**Covers:** validate via non-falsifiable output (hash/count/exit-code) · memory-vs-reality reconciliation · atomic transactions with meta-validation · backup-first + explicit rollback · anti-workaround discipline.

### `multi-phase-operation-coordination`
Complex operations in **phases with mandatory pause points**.
**When to use:** migration/refactor/rollout/deploy/backfill/upgrade where "run it all at once" is dangerous.
**Covers:** executor reports empirically, orchestrator validates before authorizing · parallelization in waves only with disjoint scope (ALLOWED/FORBIDDEN files) · database never in parallel · state via immutable artifacts (PLAN/SUMMARY/VERIFICATION) resumable after a context reset.

### `gotchas-knowledge-transfer`
Turns pitfalls into knowledge transferable across sessions/agents.
**When to use:** build and maintain a base of lessons learned.
**Covers:** template Symptom → Antipattern → Fix → Root Cause → Empirical Validation → Lesson · catalog of "gotchas" that look reasonable but fail in production · severity · cross-session transfer.

### `pre-ship-smoke-checklist`
Pre/post-deploy smoke test with **nailed-down observable criteria**.
**When to use:** right before and right after shipping something to production.
**Covers:** matrix of numbered scenarios (T1..Tn) with steps/expected/precondition · commands to force edge cases · post-deploy checklist (build/auth logs, DNS, cert, incognito window) · reproducible report.

---

## 🐛 Debugging, Testing & Quality

### `ai-code-review` 🏅
Rigorous review of AI-generated code, **explained for non-developers** (vibe coders).
**When to use:** review AI-generated code before production.
**Covers:** security · bugs · architecture · performance · typing · tests · maintainability · scalability · risk-based prioritization · before/after · reviewed code.

### `scientific-debugging-protocol`
Scientific debugging — investigate **without jumping to the fix**.
**When to use:** hard, intermittent, or unknown-cause bugs.
**Covers:** gated pipeline (Reproduce → Trace → Propose → Verify → Report) · 5-Whys · data-flow tracing · error classification (UI/API-network/Build) · hypothesis with resumable checkpoint · stuck-workflow forensics.

### `conversational-uat`
Conversational UAT with **auto-diagnosis** of failures.
**When to use:** validate features with a non-technical user, without an interrogation.
**Covers:** one test at a time in plain text · automatic root-cause hypothesis · fix plan that re-runs only the gaps · `{phase}-UAT.md` artifact.

### `test-coverage-audit`
Finds critical untested areas and proposes the right tests.
**When to use:** prioritize where to test first.
**Covers:** unit, integration and error cases · risk-based priority (auth, payments, user data, business logic) · focus on behavior (not implementation) · framework appropriate to the project.

### `e2e-test-architecture`
**Resilient** E2E tests (focus on reliability and maintainability).
**When to use:** a _flaky_ or hard-to-maintain E2E suite.
**Covers:** Page Object Model · role/accessibility-based selectors · resilient waits without fixed timeouts · locator chaining/filtering · state isolation · Playwright/Cypress/Selenium/WebdriverIO/Appium/Detox.

### `dead-code-elimination`
**Safe** removal of dead code (with caution against false positives).
**When to use:** clean up the project without breaking anything.
**Covers:** dead components/functions/imports/state/branches · fossilized feature flags · unused deps · cautions (reflection, DI, dynamic entrypoints, public APIs/SDKs, i18n, code splitting) · tools (knip, ts-prune, depcheck, vulture, cargo-udeps…).

### `type-safety-audit`
Type safety without overengineering, in any typed language.
**When to use:** too much `any`, external data without validation, loose types.
**Covers:** abuse of `any`/escape hatches · untyped parameters/returns · runtime validation at the boundary (schemas) · types that reflect the domain · TS/Python typing/Go/Java/Kotlin/C#/Rust.

### `performance-optimization-audit`
Performance with **mandatory measurement** (no premature micro-optimization).
**When to use:** real slowness, frontend or backend.
**Covers:** re-renders and justified memoization · computation in render · list virtualization · images/bundles · N+1 · pagination/indexes/cache · blocking operations · timeouts on external calls.

---

## 🎨 Frontend & UI Architecture

### `state-management-audit` 🏅
UI state in the right place, with no duplication or unnecessary globals.
**When to use:** prop drilling, inconsistent state, context for everything.
**Covers:** prop drilling · state at the wrong level · duplicated/derived state · misuse of global context/store · colocation · server-state vs client-state · libraries only when justified · React/Vue/Svelte/Solid/Angular.

### `reactive-hooks-audit`
Predictable, testable reactive hooks/primitives.
**When to use:** re-render bugs, stale closures, infinite loops; reviewing custom hooks/composables.
**Covers:** rules of hooks · correct effect dependencies · extraction into reusable hooks/composables · simple state vs reducer/state machine · React hooks/Vue Composition/Svelte runes/Solid·Angular signals.

### `component-architecture-audit`
Separation of **logic and presentation** (without overengineering).
**When to use:** components that do too much, business rules in the view.
**Covers:** logic leaked into the UI · data-fetching in presentational components · container/presentational vs hooks/composables · refactoring toward reusable and testable components.

### `frontend-design-distinctiveness`
Kills visual **"AI slop"** and demands an aesthetic identity.
**When to use:** generic/AI-generated UI; defining an identity before building.
**Covers:** rejects clichés (purple gradient, Inter/Space Grotesk, bento boxes, glowing orbs, centered hero, generic copy) · demands bold typography, an intentional palette, a layout that breaks the grid · anti-pattern checklist · web/mobile/desktop/TUI/email/slides/data-viz.

---

## 🔌 Integrations, Billing & Privacy

### `third-party-integration-playbook` 🏅
**Robust** integration with external services.
**When to use:** integrate/harden gateways/SaaS (payments, CRM, analytics, email, messaging).
**Covers:** idempotent webhooks (deterministic id via hash) · retry/replay · event state machine · fire-and-forget async sync that doesn't block the transaction · webhook auth via header-secret · typed API client with structured errors · transactional email via template registry.

### `saas-billing-and-quota-enforcement`
Billing and **quotas the app can't bypass**.
**When to use:** build/audit paid plans, usage limits and trials.
**Covers:** two-layer quota (DB enforcement + client UX) · plan catalog · usage metrics · subscription state machines (trialing/active/past_due/canceled) via scheduled jobs · RLS WITH CHECK, pg_cron, billing_events, Stripe/Asaas.

### `privacy-consent-lgpd-gdpr-compliance`
**Operational** privacy compliance (not a vuln scan).
**When to use:** any system with personal data — critical for health/PII and finance.
**Covers:** dual-layer consent (provider + immutable local log) · versioned policies with a blocking gate · _erase_ ceremony (pseudonymization/soft-delete without orphaning, token revocation) · DSAR response within legal deadlines · forensic preservation of the audit trail.

---

## 🏗️ Process, Design & Documentation

### `architecture-design-blueprint` 🏅
Architecture blueprint via a **multi-phase interview with gates**.
**When to use:** designing a new app/service (technical focus — distinct from business consulting).
**Covers:** Phase 1 discovery (goal + scale) · Phase 2 constraints (frontend/backend/data/integration) · Phase 3 synthesis (patterns + performance checklist, template, validation) · delivers layers, contracts, decisions and trade-offs proportional to size (no overengineering).

### `skill-authoring`
Meta-skill: **create and review** high-quality skills.
**When to use:** author a new skill, standardize a family, audit a skill before publishing.
**Covers:** pattern selector (Tool Wrapper/Pipeline/Generator/Reviewer/Inversion) · correct frontmatter · progressive disclosure with references · Mythos style · fresh-context testing.

### `doc-coauthoring-reader-testing`
Document co-authoring in **3 stages with reader testing**.
**When to use:** specs, RFCs, proposals, design docs, READMEs, ADRs, runbooks.
**Covers:** multi-turn context gathering · section-by-section refinement with incremental edits · reader testing with fresh context (anticipate questions, hunt ambiguity) before publishing.

### `git-workflow-standards`
Standardizes commits, branches and PR/MR operations.
**When to use:** give consistency to a team's Git flow.
**Covers:** branch naming (feature/fix/hotfix/chore) · Conventional Commits · PR babysitting (CI, fixup, never amend a published commit) · workflow gates · history compliance audit · GitHub/GitLab/Bitbucket/Azure DevOps.

---

## 📱 Mobile / Flutter
> Specialized for Flutter (with their own `references/`, `assets/` and `scripts/`), but with a **cross-stack principles** section that transfers to CSS, React Native, SwiftUI and Compose.

### `flutter-overflow-guard`
Prevents, diagnoses and **proves** the absence of layout overflow.
**When to use:** RenderFlex overflowed, broken layout, text that doesn't fit, keyboard covering a button.
**Covers:** constraints model · symptom→fix table · Expanded/Flexible/Wrap/SingleChildScrollView/FittedBox · heuristic scanner (`scripts/`) · multi-device widget-test harness (`assets/`) · checklist (multi-size, textScaler, RTL, dark, SafeArea, keyboard) · cross-stack principles.

### `flutter-pro-polish`
Removes the **"Flutter/vibecoding look"** via design tokens.
**When to use:** make the app professional/custom; escape the default Material 3/Roboto/lavender.
**Covers:** table of _tells_ · design tokens (color/typography/spacing/radius/elevation/motion) · re-theming the widgets that ship the default · defaults scanner (`scripts/`) · drop-in theme + motion (`assets/`) · designed dark mode · accessibility (AA, ≥48dp) · cross-stack principles.

---

## 💼 Business

### `business-deep-dive-consultant`
A senior consultant who runs a **Socratic diagnosis** of your business.
**When to use:** understand the business deeply and find where money is won/lost.
**Covers:** one question at a time with follow-ups · business model, unit economics, funnel, retention, margin, bottlenecks · delivers 3 hidden forces + 3 improvements that cost money (quantified) + 2 high-ROI 30-day actions · SaaS/e-commerce/services/retail/industry/infoproduct/agency/marketplace.

---

## Structure

```
mythos-skills/
├─ security-audit-full/
│  └─ SKILL.md
├─ flutter-overflow-guard/
│  ├─ SKILL.md
│  ├─ references/   ├─ assets/   └─ scripts/
└─ … (44 skills) + LICENSE + README.md
```

## License

[MIT](./LICENSE) © 2026 Everton Fernandes — use, copy, modify and distribute freely. _(Prefer CC0/CC-BY/Apache-2.0? Just swap the `LICENSE` file.)_

## Sibling repository

📄 [**mythos-prompts**](https://github.com/evertonfernandes3321-wq/mythos-prompts) — the same 44 in **pure markdown**, to paste into any LLM.
