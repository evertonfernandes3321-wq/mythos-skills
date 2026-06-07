# 🜂 MYTHOS — Auditoria Total do Repositório (Run-All)

Prompt executor para rodar **todas** as skills/prompts Mythos contra um repositório e gerar
**um arquivo de relatório por skill** + uma síntese executiva.

## Como usar (no outro PC)
1. Clone este repo (e/ou `mythos-skills`).
2. Instale as skills: copie `mythos-skills/*` para `~/.claude/skills/` (ou `<projeto>/.claude/skills/`).
3. Abra o Claude Code **dentro do repositório que quer analisar**, ligue **ultracode** e cole o bloco abaixo.

---

```markdown
Você é o **Claude Code em modo ultracode**. As skills da biblioteca **Mythos** estão instaladas.
Sua missão: auditar ESTE repositório de forma **exaustiva**, aplicando **TODAS** as skills/prompts
Mythos, e gerar **um arquivo de relatório por skill** + uma **síntese executiva** consolidada.

## Alvo e fontes
- **Repositório-alvo:** o diretório de trabalho atual (o projeto onde o Claude foi aberto).
  Exclua da análise: `node_modules`, `.git`, `dist`, `build`, `vendor`, `.venv`, e as próprias
  pastas `mythos-*`/`mythos-reports` se existirem aqui.
- **Catálogo de skills:** descubra dinamicamente, nesta ordem:
  1. Skills instaladas em `~/.claude/skills/*/SKILL.md` (preferir INVOCAR a skill: `/<nome>`).
  2. Se não instaladas, leia os prompts em `<caminho-do-clone>/mythos-prompts/*.md`
     (ignore `README.md` e `RUN-ALL.md`) e aplique o corpo de cada um.
  - Liste todos os nomes encontrados e confirme a contagem (esperado: ~44). Não invente skills.

## Saída
- Crie a pasta `./mythos-reports/`.
- **Um arquivo por skill:** `mythos-reports/<NN>-<nome-da-skill>.md` (NN = índice 01..N por categoria).
- **Síntese:** `mythos-reports/00-EXECUTIVE-SUMMARY.md` e `mythos-reports/INDEX.md`.
- Não modifique o código do repositório-alvo (somente leitura + escrita em `mythos-reports/`).

## Orquestração (ultracode)
Use a ferramenta **Workflow** para paralelizar: **um subagente por skill**, em pipeline de 3 fases.

**Fase 1 — Inventário (1 subagente):** mapeie a stack do repo-alvo (linguagens, frameworks, banco,
infra, build; web/mobile/backend/CLI/lib; é Flutter?; tem auth/pagamentos/multi-tenant/uploads/PII?).
Salve em `mythos-reports/_inventory.md`. Esse inventário alimenta a decisão de aplicabilidade.

**Fase 2 — Aplicar cada skill (N subagentes em paralelo):** cada subagente:
1. **Decide aplicabilidade** com base no inventário:
   - **Aplicável** → aplica a metodologia da skill ao repo e produz o relatório completo.
   - **Específica de stack ausente** (ex.: `flutter-*` num repo sem Dart) → arquivo curto
     `## Não aplicável — <motivo>` + princípios cross-stack que ainda valem.
   - **Interativa/consultiva** (`business-deep-dive-consultant`, `conversational-uat`) → não conduza
     diálogo; extraia do código o possível (modelo de negócio inferido, fluxos testáveis, lacunas) +
     liste as perguntas que o dono precisa responder.
   - **Builder/processo/meta** (`architecture-design-blueprint`, `skill-authoring`,
     `doc-coauthoring-reader-testing`, `production-monitoring-standards`, `paranoid-execution-mode`,
     `multi-phase-operation-coordination`, `gotchas-knowledge-transfer`, `git-workflow-standards`,
     `pre-ship-smoke-checklist`, `backup-disaster-recovery-audit`) → rode em **modo auditoria de
     conformidade**: o quanto o repo já segue o padrão, o que falta e como adotar.
2. **Aplica no nível Mythos** (rigor sub-atômico): caminho feliz e de erro, edge cases, papéis,
   ambientes. Nenhuma suposição sem evidência.
3. **Escreve o relatório** em `mythos-reports/<NN>-<nome>.md`, no formato fixo da skill:
   - `# <Skill> — Relatório` + cabeçalho (data, stack detectada, escopo, status de aplicabilidade)
   - **Resumo executivo** + nota de maturidade (inexistente→excelente)
   - **Achados** em bloco fixo: Severidade (crítica/alta/média/baixa) · Prioridade (P0–P3) ·
     Confiança (confirmada/provável/suspeita/precisa-de-contexto) · **`arquivo:linha`** · Evidência ·
     Impacto · **Correção** + exemplo · **Como validar** (teste/comando)
   - **Tabela consolidada** · **Plano de remediação em fases** · **Checklist final**
4. Retorna um resumo: `{ skill, aplicavel, maturidade, nCriticos, nAltos, top3 }`.

**Fase 3 — Síntese (1 subagente):** lê todos os resumos/relatórios e escreve:
- `00-EXECUTIVE-SUMMARY.md`: veredito ("Pode ir para produção? Sim/Não/Com restrições"), **scorecard**
  (tabela skill × maturidade × P0 × P1), **achados P0/P1 transversais deduplicados** (mesma causa raiz
  em várias skills → consolide) e um **roadmap único priorizado** (Fase 0 contenção → 1 crítico →
  2 hardening → 3 testes/observabilidade).
- `INDEX.md`: lista linkando cada relatório, com 1 linha de status e contagem de achados.

## Regras de qualidade (obrigatórias)
- **Baseado em evidência:** todo achado aponta `arquivo:linha` real. Diferencie confirmado de provável;
  marque "precisa de contexto" quando faltar info — nunca invente arquivos, funções ou achados.
- **Defensivo:** somente análise defensiva/autorizada; nenhum payload ofensivo operacionalizável.
- **Sem vazar segredos:** se achar credenciais, **mascare** (`sk_live_***`) e trate como achado crítico
  (recomende rotação); nunca cole o segredo em claro no relatório.
- **Acionável:** cada achado tem correção concreta + como validar. Nada de "use boas práticas" genérico.
- **Sem ruído:** não duplique o mesmo achado entre skills sem consolidar na síntese.
- **Escala ultracode:** seja exaustivo; custo de token não é restrição. Cubra TODAS as skills.

## Comece agora
1. Faça a Fase 1 (inventário) e mostre a stack detectada + a lista de skills descobertas (com a contagem).
2. Dispare a Fase 2 (todas as skills em paralelo via Workflow) e a Fase 3 (síntese).
3. Ao final, imprima o caminho de `mythos-reports/`, o scorecard resumido e os 5 principais P0/P1.
```

---

> Substitua `<caminho-do-clone>` só se as skills **não** estiverem instaladas globalmente. Com elas
> instaladas (passo 2), o Claude invoca cada `/skill` direto. O catálogo é descoberto dinamicamente,
> então qualquer skill nova entra automaticamente.
