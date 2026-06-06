# Mythos Skills — Coleção de Skills para Claude Code

Biblioteca de **42 skills** de auditoria, engenharia, operação e consultoria — elevadas a **nível Mythos** (rigor sub-atômico). 40 são **100% agnósticas de stack**; 2 são especializadas em **Flutter** (com princípios transferíveis para qualquer UI) e trazem references/assets/scripts próprios.

Origem: uma biblioteca própria de prompts de engenharia, destilados e generalizados a partir de padrões de produção do mundo real, cobrindo múltiplas stacks (web, mobile, backend, dados, cloud), mais 2 skills especializadas em Flutter.

Cada skill é uma pasta com `SKILL.md` (frontmatter YAML + corpo do prompt operacional). O Claude Code descobre e roteia automaticamente pela `description`.

---

## Como instalar

**Global (todos os projetos):**

```powershell
Copy-Item .\* "$env:USERPROFILE\.claude\skills\" -Recurse -Force   # Windows
```
```bash
cp -r ./* ~/.claude/skills/                                        # macOS/Linux
```

**Por projeto:** copie a pasta da skill para `<projeto>/.claude/skills/`.

Depois, peça a tarefa em linguagem natural ou invoque com `/<nome-da-skill>`.

> As skills também já estão instaladas globalmente em `~/.claude/skills/`. Este repositório é a cópia versionável para Git. Versão em prompt puro (markdown, para colar em qualquer LLM): repositório irmão **mythos-prompts**.

---

## Catálogo (40)

### 🔒 Segurança
| Skill | Objetivo |
|-------|----------|
| `security-audit-full` | **Mestre.** Auditoria de segurança defensiva e exaustiva end-to-end. |
| `auth-authorization-audit` | Autenticação & autorização (IDOR/BOLA, RBAC/ABAC, multi-tenant). |
| `auth-token-refresh-safety` | Refresh token rotation seguro (mutex single-flight, interceptor 401, anti-loop). |
| `secrets-and-config-exposure-audit` | Segredos/config expostos, `.env`/`.gitignore`, secret managers. |
| `injection-xss-csrf-audit` | Injeções, XSS (escaping por contexto), CSRF, headers. |
| `file-upload-security-audit` | Upload de arquivos (MIME real, limites, path traversal). |
| `password-credential-security` | Senhas/credenciais (Argon2id/bcrypt/scrypt, zero-knowledge). |
| `production-readiness-audit` | DevSecOps: CVEs e caça a *leftovers* antes do deploy. |

### 🗄️ Banco de Dados & Dados
| Skill | Objetivo |
|-------|----------|
| `database-tenant-isolation-audit` | Isolamento multi-tenant (RLS vs schema), policy matrix, leaks, least privilege. |
| `database-performance-audit` | Performance de dados (RLS lenta, N+1/DataLoader, índices, EXPLAIN). |
| `data-integrity-and-ledger-audit` | Invariantes, double-entry, coerência de saldo, transações atômicas, snapshots forenses. |
| `cache-and-server-state-architecture` | Coerência de cache client-side + ORM/DB-side (anti-stale). |

### 📊 Observabilidade & Operação
| Skill | Objetivo |
|-------|----------|
| `observability-logging-audit` | **Mestre.** Logging estruturado, correlação, falhas silenciosas, redaction, métricas, tracing. |
| `production-monitoring-standards` | Padrões para sistemas monitoráveis e debuggáveis. |
| `error-handling-audit` | Tratamento de erros (FE+BE), error boundaries, handlers globais. |
| `product-analytics-architecture` | Analytics de produto: catálogo de eventos, funil de ativação, auto-tracking, privacy-first. |

### ⚙️ Rigor Operacional & Coordenação
| Skill | Objetivo |
|-------|----------|
| `paranoid-execution-mode` | Execução paranoica: gates empíricos, memória-vs-realidade, atômico+rollback, anti-workaround. |
| `multi-phase-operation-coordination` | Operações multi-fase com pause points, ondas paralelas e estado por artefatos. |
| `gotchas-knowledge-transfer` | Captura/transferência de armadilhas (sintoma→fix→causa→lição). |
| `pre-ship-smoke-checklist` | Smoke pré/pós-deploy com critérios observáveis e matriz de cenários. |

### 🐛 Depuração, Testes & Qualidade
| Skill | Objetivo |
|-------|----------|
| `ai-code-review` | **Mestre.** Code review de código de IA explicado para *vibe coders*. |
| `scientific-debugging-protocol` | Depuração científica (5-Whys, classificação de erro, hipótese, forensics). |
| `conversational-uat` | UAT conversacional com auto-diagnóstico de falhas. |
| `test-coverage-audit` | Cobertura de testes em áreas críticas. |
| `e2e-test-architecture` | Testes E2E resilientes (Page Object Model, seletores, anti-flakiness). |
| `dead-code-elimination` | Remoção segura de código morto. |
| `type-safety-audit` | Segurança de tipos (qualquer linguagem tipada). |
| `performance-optimization-audit` | Performance frontend + backend. |

### 🎨 Frontend & Arquitetura de UI
| Skill | Objetivo |
|-------|----------|
| `state-management-audit` | Gerenciamento de estado de UI. |
| `reactive-hooks-audit` | Hooks/primitivas reativas (React/Vue/Svelte/Solid/Angular). |
| `component-architecture-audit` | Arquitetura de componentes (separação lógica/apresentação). |
| `frontend-design-distinctiveness` | Anti-clichês de design de IA; identidade visual distinta. |

### 🔌 Integrações, Billing & Privacidade
| Skill | Objetivo |
|-------|----------|
| `third-party-integration-playbook` | Integração robusta (webhooks idempotentes, retry, sync assíncrono, API client). |
| `saas-billing-and-quota-enforcement` | Quotas em duas camadas (DB + UX), planos, trial/dunning, cron. |
| `privacy-consent-lgpd-gdpr-compliance` | Consentimento dual-layer, erase ceremony, DSAR, trilha de auditoria. |

### 🏗️ Processo, Design & Documentação
| Skill | Objetivo |
|-------|----------|
| `architecture-design-blueprint` | Blueprint de arquitetura via entrevista multi-fase com gates. |
| `skill-authoring` | Meta-skill para autorar/revisar skills Mythos. |
| `doc-coauthoring-reader-testing` | Co-autoria de docs em 3 estágios com reader testing. |
| `git-workflow-standards` | Convenções de branch/commit/PR com gates de CI. |

### 📱 Mobile / Flutter (especializadas, com assets+scripts)
| Skill | Objetivo |
|-------|----------|
| `flutter-overflow-guard` | Prevenir/diagnosticar/verificar overflow de layout (RenderFlex, unbounded, teclado, texto) — com scanner Python + harness de teste multi-size. Inclui princípios cross-stack (CSS/RN/SwiftUI/Compose). |
| `flutter-pro-polish` | Tirar a "cara de Flutter/vibecoding" via design tokens e re-tema dos widgets — com scanner de *tells* + tema/motion drop-in. Inclui princípios cross-stack de design tokens. |

### 💼 Negócios
| Skill | Objetivo |
|-------|----------|
| `business-deep-dive-consultant` | Consultor sócrata: diagnóstico + plano de 30 dias. |

---

## Princípios de design

- **Agnóstico de stack** — aplicabilidade universal, exemplos multi-ecossistema (JS/TS, Python, Go, Java/Kotlin, C#/.NET, Ruby, PHP, Rust, mobile; Postgres/MySQL/Mongo; Stripe/Square; PostHog/Mixpanel).
- **Rigor sub-atômico** — caminho feliz e de erro, edge cases, defaults, concorrência, papéis e ambientes.
- **Verificação empírica** — validar por output não-falsificável (hash/count/exit-code), nunca por palavra.
- **Defensivo e seguro** — temas sensíveis são exclusivamente defensivos/autorizados; segredos mascarados.
- **Formato fixo** — resumo executivo, achados/itens com localização + correção + teste, tabela, plano em fases, checklist.
