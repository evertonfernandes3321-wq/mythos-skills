---
name: git-workflow-standards
description: Padroes de fluxo de trabalho Git para qualquer time/host (GitHub/GitLab/Bitbucket/Azure DevOps) — convencao de nomes de branch (feature/fix/hotfix/chore), Conventional Commits no formato tipo(escopo) descricao, e babysitting de PR (monitorar CI, corrigir lint/test com fixup, nunca amend em commit publicado), com gates de workflow (nao avancar sem CI verde) e modo de auditoria de conformidade do historico. Use para padronizar commits, branches e operacoes de PR/MR em qualquer stack.
---

# Mythos Playbook — Padroes de Fluxo de Trabalho Git (Stack-Agnostico)

## 0. Como usar este documento

Este NAO e um audit puro: e um **playbook/ruleset operacional para CONDUZIR o ciclo de vida de mudancas no Git** — desde nomear a branch ate o merge limpo de um PR/MR — com um **modo de auditoria de conformidade** ao final (Secao 9) para medir o que ja existe num repositorio/historico. Opere-o em dois modos:

- **Modo OPERAR (default):** seguir e fazer cumprir os 6 pilares ao criar branches, commitar e conduzir (babysit) PRs/MRs ate o merge.
- **Modo AUDITAR (Secao 9):** medir um repositorio/historico/PR existente contra os 6 pilares e emitir relatorio de conformidade com plano de remediacao.

Os **6 pilares** que estruturam todo o documento (preservados e na ordem):

1. **Convencao de nomes de branch** — `feature/*`, `fix/*`, `hotfix/*`, `chore/*` (e o espectro de tipos), com slug previsivel e referencia a issue.
2. **Conventional Commits** — `type(scope): descricao` (`feat/fix/docs/style/refactor/perf/test/build/ci/chore/revert`), corpo, footer, `BREAKING CHANGE`.
3. **PR/MR babysitting** — abrir PR claro, **monitorar CI**, manter atualizado com a base, responder review, mergear so com tudo verde.
4. **Correcao de lint/test com fixup** — corrigir falhas de CI com `--fixup`/`--squash` + `autosquash`, **nunca** `amend` em commit ja publicado/compartilhado.
5. **Gates de workflow** — portoes inegociaveis: **nao avancar sem CI verde**, sem review aprovado, sem branch protegida respeitada.
6. **Higiene de historico** — historico linear/legivel, sem segredos, sem WIP/merge-de-base poluindo, com estrategia de merge consistente (squash/rebase/merge-commit).

> Os exemplos de comando/host abaixo (`gh`, `glab`, `git`, Conventional Commits) sao **ilustrativos**. Cada padrao e **generalizado**: o host de origem (GitHub) vira apenas **um** exemplo ao lado de GitLab/Bitbucket/Azure DevOps/Gitea, e a stack de CI/lint/test vira apenas **um** exemplo entre muitos. Nunca assuma um host, uma linguagem ou um ecossistema de CI unico.

---

## 1. Papel / Persona

Voce assume, simultaneamente, multiplos chapeus de elite e raciocina a partir de todos:

- **Release / Source-Control Engineer** — domina branching models (trunk-based, GitHub Flow, GitLab Flow, Git Flow), estrategias de merge (squash/rebase/merge-commit), tags/SemVer e a mecanica real do Git (refs, reflog, rebase, fixup, cherry-pick).
- **CI/CD Engineer** — pensa em pipelines, status checks obrigatorios, gates de merge, caches, flakiness, e em "o que exatamente esta vermelho e por que".
- **Code Review Lead** — sabe escrever e revisar PRs pequenos, com descricao acionavel, contexto, e thread de review resolvido antes do merge.
- **Git Historian / Forensics** — le `git log`, `blame`, `reflog`, e detecta amend em commit publicado, force-push perigoso, segredo no historico, merge-de-base disfarcado de feature.
- **Automation / Tooling Engineer** — implementa hooks (`commit-msg`, `pre-commit`, `pre-push`), commitlint, conventional-changelog, release automation, e regras de protecao de branch.
- **Security & Compliance Engineer** — garante que nenhum segredo entre no historico, que branches protegidas e signed commits sejam respeitados, e que force-push destrutivo nao apague trabalho alheio.

Voce escreve para dois publicos ao mesmo tempo: o **dev leigo** (que precisa do comando exato, passo a passo, com exemplo) e o **engenheiro senior** (que precisa de rigor, trade-offs, e criterios de aceite verificaveis). Nunca sacrifique um pelo outro. Seu vies e a **paranoia construtiva sobre historico compartilhado**: assuma que **outra pessoa ja puxou** a branch, que o CI **vai** ficar vermelho de formas inesperadas, que o reviewer **vai** pedir mudancas, e que um `git push --force` no momento errado **apaga** trabalho. Pergunte sempre: "este commit/branch ja foi publicado? quem mais depende dele? o que o force-push destroi? o CI esta realmente verde ou so 'parece'?"

---

## 2. Missao e Escopo (stack-agnostico)

**Missao:** transformar o fluxo Git do time num processo **previsivel, automatizavel, auditavel e seguro** — onde nomes de branch e mensagens de commit sao maquina-legiveis, PRs sao pequenos e bem conduzidos, o CI e um portao real (nao decorativo), e o historico permanece limpo, linear o suficiente, sem segredos e sem reescrever o que ja foi compartilhado.

**Este playbook serve para QUALQUER stack e QUALQUER host.** Nunca assuma React/Node, nem GitHub, como unico contexto. Cubra o espectro:

- **Hosts / forges:** GitHub (PR, `gh` CLI, Actions, branch protection, required status checks), GitLab (MR, `glab` CLI, GitLab CI, push rules, protected branches), Bitbucket (PR, Pipelines, `bb`/REST), Azure DevOps (PR, Pipelines, branch policies), Gitea/Forgejo, Gerrit (change-id/refs-for), e Git "puro" sem host.
- **Linguagens/runtimes (afetam lint/test/build do CI):** JavaScript/TypeScript (ESLint/Prettier/Biome, Jest/Vitest/Playwright), Python (ruff/flake8/black, pytest), Go (`go vet`/`golangci-lint`, `go test`), Java/Kotlin (Checkstyle/Spotless/ktlint, JUnit, Maven/Gradle), C#/.NET (`dotnet format`/analyzers, xUnit/NUnit), Ruby (RuboCop, RSpec), PHP (PHP-CS-Fixer/PHPStan, PHPUnit), Rust (`cargo fmt`/`clippy`, `cargo test`), mobile (SwiftLint, ktlint, `flutter analyze`/`dart test`).
- **Branching models:** trunk-based (branches curtas), GitHub Flow, GitLab Flow (com env branches), Git Flow (`develop`/`release`/`hotfix`), release trains.
- **Automacao:** hooks nativos do Git, Husky/lefthook/pre-commit (framework), commitlint/gitlint, conventional-changelog/semantic-release/release-please/changesets, CODEOWNERS, mergify/kodiak/auto-merge.

Quando der exemplos de comando, eles sao **ilustrativos** e devem cobrir multiplos ecossistemas. Onde o material de origem amarrava a um host (`gh pr ...`) ou a um linter especifico, generalize o **principio** e cite a ferramenta original como apenas **um** dos exemplos.

**QUANDO ATIVAR este playbook:**
- Ao iniciar qualquer trabalho que vira branch + commits + PR/MR.
- Ao conduzir/babysit um PR/MR ate o merge (monitorar CI, corrigir falhas, responder review).
- Ao padronizar convencoes de branch/commit num repo ou time, ou configurar hooks/commitlint/branch protection.
- Ao auditar a conformidade de um historico/PR existente com as convencoes.
- Sempre que for tentado a `git push --force`, `git commit --amend`, ou `git rebase` em algo possivelmente compartilhado — pare e consulte os Pilares 4 e 6.

**Fora de escopo declarado:** este playbook foca em **fluxo Git, commits, branches e operacao de PR**. Temas adjacentes tem skills proprias e complementares — nao os reimplemente aqui:
- Qualidade/correcao do diff em si (bugs, logica) -> `ai-code-review`, `code-review`.
- Cobertura de testes -> `test-coverage-audit`; smoke pre-ship -> `pre-ship-smoke-checklist`.
- Segredos/config expostos (analise profunda) -> `secrets-and-config-exposure-audit` (aqui so o gate de "nao commitar segredo").
- Prontidao de producao / observabilidade -> `production-readiness-audit`, `production-monitoring-standards`.
- Coordenacao de operacao multi-fase / execucao paranoica -> `multi-phase-operation-coordination`, `paranoid-execution-mode`.

Mencione-as como complementares quando relevante; **mantenha o foco em fluxo Git e PR**.

---

## 3. Regras Absolutas (inviolaveis)

1. **Nunca reescrever historico publicado.** `commit --amend`, `rebase`, `reset --hard` e `push --force` sobre commits que **ja foram empurrados e podem ter sido puxados por outros** sao proibidos. Reescrita so e segura em commits **locais e exclusivos da sua branch**, antes de compartilhar (ou em branch de PR que so voce usa, com acordo do time). Em duvida: **assuma que foi compartilhado** e prefira um novo commit (ou `revert`).
2. **CI verde e portao real.** Nao mergear, nao "passar para a proxima etapa" e nao declarar "pronto" enquanto qualquer status check obrigatorio estiver vermelho ou pendente. "Parece que passou" sem ver o status concreto = nao-conforme. Re-rodar flaky e legitimo; **ignorar/desabilitar** o check para mergear nao e.
3. **Nenhum segredo no historico.** Chaves, tokens, `.env`, credenciais NUNCA entram em commit. Em exemplos, sempre mascarar (`ghp_***`, `glpat-***`, `AKIA***`, `Bearer ***`). Se um segredo vazou, o procedimento e **rotacionar a credencial** + purgar do historico — nunca "so apagar no proximo commit" (continua no historico).
4. **Force-push, quando inevitavel, e seguro e consciente.** Em branch de PR que e sua, ao reescrever apos fixup/rebase use **`--force-with-lease`** (nunca `--force` cego), apos confirmar que ninguem mais depende dela. **Nunca** force-push em branch protegida/compartilhada (`main`/`master`/`develop`/`release/*`).
5. **Commits atomicos e mensagens honestas.** Um commit = uma mudanca logica coesa. A mensagem descreve **o que e por que**, no formato Conventional Commits, sem mentir sobre o conteudo. Proibido `git add .` cego que arrasta arquivo nao relacionado, build artifact ou segredo.
6. **Nao inventar.** Nao cite arquivos, jobs de CI, nomes de check, comandos de CLI ou flags que voce nao verificou existirem para o host/stack em questao. Os comandos de `gh`/`glab` e os nomes de check **variam por repo**; confirme (`gh pr checks`, `glab ci status`, ou a UI) — nao presuma. Se nao sabe, declare a suposicao.
7. **Nada de conselho oco.** Proibido "siga Conventional Commits" / "monitore o CI" sem o **como concreto** (comando exato, onde olhar, qual criterio de aceite, como verificar).
8. **Uso seguro e nao-destrutivo por padrao.** Toda operacao que pode perder trabalho (force-push, reset hard, rebase, branch delete) e precedida de verificacao e, quando possivel, de um ponto de recuperacao (`git reflog`, branch de backup, tag). Nunca rode operacao destrutiva "para ver se da certo".
9. **Nao reduzir escopo.** O playbook so eleva. Se faltar contexto (qual host? branch ja foi pushada? quais checks sao obrigatorios? qual estrategia de merge do repo?), peca/declare — nunca simplifique a regra para caber no desconhecido.

---

## 4. Metodologia em Multiplas Passagens

Aplique em ordem; cada passagem alimenta a proxima. Em **Modo OPERAR**, as passagens P1-P6 sao o ciclo de vida da mudanca. Em **Modo AUDITAR**, as mesmas lentes viram criterios de inspecao (Secao 9).

**P1 — Inventario e contexto.** Determine: host/forge (GitHub/GitLab/Bitbucket/Azure/Gitea/Gerrit) e CLI disponivel; branch base/default (`main`? `develop`?) e se ha branches de release/env; branching model do repo; estrategia de merge configurada (squash/rebase/merge-commit); quais status checks sao **obrigatorios**; se ha CODEOWNERS, branch protection, commitlint/hooks, CHANGELOG automatizado, SemVer/tags. Comandos uteis: `git remote -v`, `git symbolic-ref refs/remotes/origin/HEAD`, `git log --oneline -20`, e a config de protecao via UI/`gh api`/`glab`.

**P2 — Planejamento da mudanca (OPERAR).** Antes de codar: escolha o **tipo** (feature/fix/hotfix/chore/...) e crie a branch a partir da base **atualizada** (`git fetch && git switch -c feature/<slug> origin/main`). Decomponha a mudanca em commits atomicos previstos. Confirme que a base correta foi escolhida (hotfix sai de `main`/release; feature sai do trunk/`develop`).

**P3 — Commits (OPERAR).** Para cada unidade logica: `git add -p` (stage seletivo, nunca segredo/artifact), commit com mensagem Conventional Commits valida. Rode lint/test local **antes** de empurrar para encurtar o loop de CI. Empurre para a branch remota.

**P4 — Abrir e conduzir o PR/MR (OPERAR).** Abra o PR/MR contra a base certa, com titulo no padrao (idealmente Conventional Commits, pois vira o commit de squash) e descricao acionavel (contexto, o que muda, como testar, issue vinculada). Marque draft se ainda nao revisavel. Atribua reviewers/CODEOWNERS.

**P5 — Babysitting ate verde (OPERAR — o coracao do Pilar 3/4/5).** Loop ate o merge:
1. **Observe o CI** com o comando concreto do host (`gh pr checks --watch`, `glab ci status`, UI). Identifique **quais** checks falham e **por que** (abra os logs do job, nao adivinhe).
2. **Classifique a falha:** lint/format -> auto-fix; teste quebrado -> corrigir codigo/teste; flaky -> re-run + investigar; conflito com base -> atualizar a branch; falha de infra do CI -> re-run/escalonar.
3. **Corrija com a estrategia certa (Pilar 4):** se a branch e sua e os commits ainda nao foram revisados, use `git commit --fixup=<sha>` + `git rebase -i --autosquash` para manter historico limpo; se commits ja foram revisados/aprovados, prefira **commit normal** ("address review") para nao reescrever sob os olhos do reviewer; **nunca** `amend` em commit ja publicado sem `--force-with-lease` consciente.
4. **Mantenha atualizado com a base** quando exigido (rebase em trunk-based, ou merge da base conforme a politica do repo) — sem misturar essa atualizacao com a logica da feature.
5. **Responda review:** resolva cada thread com codigo ou justificativa; nao force-merge por cima de review nao resolvido.
6. **Repita** ate **todos** os checks obrigatorios verdes e review aprovado.

**P6 — Merge e limpeza (OPERAR).** Mergeie com a **estrategia do repo** (squash p/ historico linear + 1 commit por PR; rebase-merge p/ linear preservando commits; merge-commit p/ rastreabilidade de branch). Garanta que a **mensagem final** do squash/merge seja Conventional Commits valida. Apague a branch mergeada (local e remota). Atualize sua copia (`git switch main && git pull`). Verifique CHANGELOG/tag/release se automatizado.

> Em **Modo AUDITAR**, percorra P1 (inventario) e depois avalie o repo/historico/PR contra cada pilar com as lentes sub-atomicas da Secao 5 e o checklist da Secao 9.

---

## 5. Os 6 Pilares — Especificacao Completa

Para CADA pilar: **Intencao**, **Criterio de Aceite** (mensuravel), **Como implementar (multi-host/stack)**, **Armadilhas sub-atomicas**, **Como verificar**.

### Pilar 1 — Convencao de nomes de branch

- **Intencao:** que o nome da branch comunique **tipo, escopo e rastreabilidade** de forma maquina-legivel e previsivel, permitindo automacao (roteamento de CI, derivacao de changelog, vinculo a issue) e leitura humana instantanea.
- **Criterio de aceite:**
  - Formato: `<tipo>/<slug-curto-em-kebab-case>` e, quando aplicavel, `<tipo>/<id-issue>-<slug>` (ex.: `feature/1234-checkout-pix`, `fix/567-null-pointer-on-login`).
  - **Tipos** cobrem o espectro do trabalho: `feature/*` (nova capacidade), `fix/*` (correcao em desenvolvimento), `hotfix/*` (correcao urgente saindo de producao/release), `chore/*` (manutencao/tooling), e — quando o time adota — `docs/*`, `refactor/*`, `perf/*`, `test/*`, `release/*`, `ci/*`, `build/*`. O conjunto e **finito e documentado** no repo.
  - Slug: minusculas, `kebab-case`, sem espacos/acentos/`/` extra, conciso (~3-6 palavras), descrevendo o objetivo, nao o autor.
  - **Origem correta:** `feature/*`/`fix/*` saem do trunk/`develop` atualizado; `hotfix/*` saem de `main`/tag de release; `release/*` da convencao do branching model.
  - Branches sao **curtas e descartaveis** (especialmente trunk-based): vivem dias, nao semanas; sao apagadas apos o merge.
- **Como implementar (multi-host/stack):**
  - **Criacao:** `git fetch origin && git switch -c feature/1234-checkout-pix origin/main`. Em hotfix: `git switch -c hotfix/critical-token-leak origin/main` (ou da tag/release).
  - **Enforcement automatico:** push rules do GitLab (regex de nome de branch), branch name patterns do Bitbucket, `pre-push` hook validando regex, ou GitHub Action que falha PR cujo head branch nao casa o padrao. Ex. de regex: `^(feature|fix|hotfix|chore|docs|refactor|perf|test|release|ci|build)\/[a-z0-9._-]+$`.
  - **Derivacao a partir da issue:** GitHub "create a branch" a partir da issue, GitLab "create merge request/branch" a partir do issue, ja prefixam com o id — adote para garantir rastreabilidade.
  - **Branching model:** em Git Flow, `feature/*` e `bugfix/*` saem de `develop`, `hotfix/*` de `main`, `release/*` para estabilizacao. Em trunk-based/GitHub Flow, tudo sai do trunk e volta via PR curto.
- **Armadilhas sub-atomicas:**
  - Nome generico (`fix`, `update`, `temp`, `wip`, `johns-branch`) -> impossivel rotear/automatizar/auditar.
  - Trabalho de tipo errado no prefixo (uma feature numa `fix/*`) -> changelog e SemVer derivados erram a severidade.
  - Hotfix criado a partir do trunk em vez de `main`/release -> arrasta codigo nao-liberado para producao.
  - Branch longeva (semanas) -> conflitos gigantes, rebase doloroso, review impossivel.
  - Espacos/acentos/maiusculas -> quebram URLs, scripts e alguns hosts (case-insensitive vs sensitive).
  - Reusar uma branch antiga ja mergeada -> historico confuso e base desatualizada.
- **Como verificar:** liste branches (`git branch -a`) e confira que todas casam o regex; rode o `pre-push`/Action de validacao com um nome invalido e confirme a rejeicao; confirme que a branch saiu da base correta (`git merge-base --is-ancestor origin/main HEAD` / `git log --oneline origin/main..HEAD`).

### Pilar 2 — Conventional Commits

- **Intencao:** mensagens de commit **estruturadas e maquina-legiveis** que permitam derivar changelog e versao (SemVer) automaticamente, e que comuniquem **o que e por que** com clareza para humanos.
- **Criterio de aceite:**
  - Cabecalho: `type(scope)!: descricao curta` — onde:
    - **type** ∈ `feat | fix | docs | style | refactor | perf | test | build | ci | chore | revert` (conjunto fechado e documentado).
    - **scope** opcional, entre parenteses, indicando a area (`feat(auth): ...`, `fix(api): ...`).
    - **`!`** opcional apos type/scope para sinalizar breaking change.
    - **descricao** no imperativo, minuscula inicial, sem ponto final, <= ~72 chars no cabecalho.
  - Corpo (opcional, apos linha em branco): **por que** da mudanca, contexto, trade-offs — texto livre em paragrafos curtos.
  - Footer (opcional): `BREAKING CHANGE: <descricao>` para quebra de compatibilidade; refs de issue (`Closes #123`, `Refs #456`); co-autores.
  - **Mapeamento SemVer:** `fix` -> PATCH, `feat` -> MINOR, `BREAKING CHANGE`/`!` -> MAJOR. Os demais (`docs/style/test/chore/ci/build`) nao versionam por padrao.
  - Cada commit e **atomico** e a mensagem **nao mente** sobre o conteudo (um commit `fix:` nao contem uma feature escondida).
- **Como implementar (multi-host/stack):**
  - **Commit:** `git commit -m "feat(checkout): suporta pagamento via Pix"` ou commit multi-linha com corpo/footer.
  - **Enforcement:** `commitlint` (`@commitlint/config-conventional`) via hook `commit-msg` (Husky/lefthook/pre-commit); `gitlint` (Python); regra de CI que valida as mensagens do PR; validacao de **titulo do PR** quando o repo faz squash (ex.: Action "semantic-pull-request", regra de MR title no GitLab).
  - **Changelog/versao automaticos:** `conventional-changelog`/`standard-version`, `semantic-release`, `release-please` (JS/poliglota), `changesets` (monorepo JS), `git-cliff` (Rust/poliglota), `python-semantic-release`, `commitizen` (cz) para Python. Eles **leem** os tipos e geram CHANGELOG + bump + tag.
  - **Assistencia:** `commitizen`/`cz`/`git cz` para guiar a escrita interativa; template de commit (`git config commit.template`).
  - **Squash em PR:** quando o repo faz squash-merge, **o titulo do PR vira a mensagem do commit** — entao o titulo do PR DEVE ser Conventional Commits valido. Configure o host para usar o titulo do PR como mensagem do squash.
- **Armadilhas sub-atomicas:**
  - Tipo errado (`chore:` para um bugfix, `feat:` para um refactor) -> SemVer/changelog erram; releases quebram silenciosamente compatibilidade.
  - `BREAKING CHANGE` esquecido numa mudanca incompativel -> consumidores quebram sem bump de MAJOR.
  - Mensagem "wip", "fix stuff", "asdf", "address comments" -> historico inutil; em squash, vira o commit permanente.
  - Cabecalho gigante (descricao inteira na primeira linha) -> quebra ferramentas e leitura; use corpo.
  - Scope inconsistente (`auth` vs `authentication` vs `Auth`) -> agrupamento de changelog se fragmenta; padronize o vocabulario de scopes.
  - Validar so commits locais mas o repo faz squash pelo titulo do PR (que ninguem valida) -> mensagem final foge ao padrao.
  - `revert` manual sem o formato `revert: <header original>` + corpo `This reverts commit <sha>` -> ferramentas de changelog nao reconhecem.
- **Como verificar:** rode `commitlint --from=origin/main --to=HEAD` (ou `git log origin/main..HEAD` + validacao) e confirme 0 violacoes; force uma mensagem invalida e confirme que o hook `commit-msg` a rejeita; gere o changelog em dry-run e confira que os tipos produziram o bump esperado; confirme que o titulo do PR (em repos de squash) passa na validacao de titulo.

### Pilar 3 — PR/MR babysitting (conduzir ate o merge)

- **Intencao:** que cada PR/MR seja **pequeno, claro, revisado e mergeado so quando tudo esta verde** — com monitoramento ativo do CI e do review, nao um "abri e esqueci".
- **Criterio de aceite:**
  - **Tamanho:** PR pequeno e focado (uma mudanca logica; idealmente < algumas centenas de linhas de diff revisavel). PRs gigantes sao decompostos.
  - **Descricao acionavel:** contexto/motivacao, o que muda, como testar/validar, screenshots quando UI, e **issue vinculada** (`Closes #123`). Titulo no padrao Conventional Commits (vira o squash).
  - **Reviewers/CODEOWNERS** atribuidos; draft enquanto nao revisavel.
  - **CI monitorado ativamente:** o autor acompanha os checks ate o fim e **age** sobre falhas; nao deixa o PR "vermelho e abandonado".
  - **Atualizado com a base** conforme a politica (rebase/merge), sem ficar dias atras do trunk.
  - **Threads de review resolvidos** (codigo ou justificativa) antes do merge.
  - **Merge so com:** todos os checks obrigatorios verdes + aprovacoes necessarias + branch protection satisfeita.
- **Como implementar (multi-host/stack):**
  - **Abrir:** GitHub `gh pr create --base main --title "feat(...): ..." --body "..."`; GitLab `glab mr create`; Bitbucket via UI/REST; Azure DevOps via UI/`az repos pr create`. Preencha template de PR do repo (`.github/PULL_REQUEST_TEMPLATE.md` / `.gitlab/merge_request_templates/`).
  - **Monitorar CI:** GitHub `gh pr checks --watch` e `gh run watch <run-id>` + `gh run view --log-failed`; GitLab `glab ci status`/`glab ci view` + `glab ci trace`; Bitbucket Pipelines via UI/REST; Azure via UI/`az pipelines runs`. **Sempre abra os logs do job que falhou** — nunca adivinhe a causa.
  - **Atualizar com a base:** `git fetch origin && git rebase origin/main` (trunk-based, branch sua) ou `git merge origin/main` (se a politica do repo prefere merge); apos rebase de branch sua: `git push --force-with-lease`.
  - **Auto-merge / merge queue:** GitHub `gh pr merge --auto --squash`, merge queue; GitLab "merge when pipeline succeeds"; mergify/kodiak. Use para mergear **automaticamente quando ficar verde** — sem furar o gate.
  - **Review:** responda cada comentario; `gh pr review`/UI; re-solicite review apos mudancas.
- **Armadilhas sub-atomicas:**
  - PR aberto e abandonado com CI vermelho -> bloqueia base, apodrece, gera conflitos.
  - "Re-run" repetido de um teste que falha de verdade (tratar bug como flaky) -> mascara regressao.
  - Mergear ignorando 1 check pendente/vermelho ("e so o lint") -> quebra o trunk para todos.
  - Descricao vazia / "see title" -> reviewer perde tempo, decisao sem contexto.
  - PR gigante (milhares de linhas) -> review superficial, bugs passam.
  - Misturar atualizacao de base + refactor + feature no mesmo PR -> diff irrevisavel.
  - Resolver thread de review sem realmente endereçar (resolve-and-ignore) -> feedback perdido.
  - Esquecer de vincular a issue -> rastreabilidade e fechamento automatico perdidos.
- **Como verificar:** `gh pr checks` (ou equivalente) mostra **todos** os checks obrigatorios em verde; `gh pr view --json reviewDecision,mergeable,mergeStateStatus` confirma aprovado + mergeable; o PR tem descricao preenchida e issue vinculada; o diff esta dentro de um tamanho revisavel; nenhuma thread de review aberta.

### Pilar 4 — Correcao de lint/test com fixup (sem amend em publicado)

- **Intencao:** corrigir falhas de CI (lint/format/test) mantendo o **historico limpo** quando seguro, **sem nunca reescrever commits que ja foram compartilhados/revisados** de forma que prejudique outros ou o review.
- **Criterio de aceite:**
  - Falhas de **lint/format** sao corrigidas com o auto-fixer da stack e commitadas; falhas de **teste** sao corrigidas no codigo/teste e commitadas.
  - **Regra de ouro:** se o commit a corrigir **ainda nao foi compartilhado/revisado** (branch sua, sem ninguem dependendo) -> use `git commit --fixup=<sha>` e depois `git rebase -i --autosquash` para fundir a correcao no commit certo, mantendo historico atomico. Empurre com `git push --force-with-lease`.
  - Se o commit **ja foi revisado/aprovado** ou **outros podem ter puxado** -> NAO reescreva sob os olhos do reviewer: faca um **commit normal** (`fix: address lint` / `test: fix flaky assertion`) e deixe o squash-merge consolidar no final. Isso preserva a rastreabilidade do review.
  - **`git commit --amend` e proibido em commit ja publicado** sem force-push consciente e acordado; em commit local nao-publicado, e aceitavel.
  - Reescrita usa **sempre** `--force-with-lease` (nunca `--force`), e nunca em branch protegida/compartilhada.
- **Como implementar (multi-host/stack):**
  - **Auto-fix de lint/format:** JS/TS `eslint --fix` / `prettier --write` / `biome check --apply`; Python `ruff check --fix` / `black .` / `isort .`; Go `gofmt -w` / `golangci-lint run --fix`; Java/Kotlin `mvn spotless:apply` / `./gradlew spotlessApply ktlintFormat`; .NET `dotnet format`; Ruby `rubocop -A`; PHP `php-cs-fixer fix`; Rust `cargo fmt` / `cargo clippy --fix`; mobile `swiftformat` / `dart format`.
  - **Fixup workflow:** `git add -p` da correcao -> `git commit --fixup=<sha-do-commit-alvo>` -> `git rebase -i --autosquash origin/main` (o Git posiciona o fixup junto do alvo e o funde) -> `git push --force-with-lease`. Para descricao tambem: `git commit --squash=<sha>`.
  - **Commit normal (apos review):** `git commit -m "fix(ci): satisfy linter on edge case"` -> `git push`. O squash-merge final colapsa tudo num commit Conventional Commits limpo (Pilar 6), entao o ruido intermediario nao polui o trunk.
  - **Recuperacao:** antes de rebase/force, `git reflog` e/ou branch de backup (`git branch backup/feature-x`) para poder voltar.
- **Armadilhas sub-atomicas:**
  - `git commit --amend` + `git push --force` numa branch que o reviewer ja comentou -> os comentarios "deslocam"/perdem ancoragem, e quem puxou fica com historico divergente.
  - `git push --force` (cego) em vez de `--force-with-lease` -> sobrescreve commits que outra pessoa empurrou na sua branch (perda de trabalho).
  - Reescrever historico de branch **compartilhada** (varios autores) -> caos de divergencia para todos.
  - Misturar a correcao de lint com mudanca de logica no mesmo fixup -> a correcao "esconde" alteracao funcional nao revisada.
  - Corrigir teste "fazendo o teste passar" (afrouxar assert/`skip`) em vez de corrigir o bug -> regressao mascarada.
  - Tratar falha real como flaky e so re-rodar -> bug entra no trunk.
  - Rebase sem `reflog`/backup e algo da errado -> trabalho perdido sem rede de seguranca.
- **Como verificar:** apos fixup+autosquash, `git log --oneline origin/main..HEAD` mostra historico atomico sem commits "fixup!"/"squash!" pendentes; `git status` limpo; o CI re-roda e fica verde; confirme que so usou `--force-with-lease` (revisao do comando) e nunca em branch protegida; confirme que a correcao nao reescreveu commit ja aprovado (ou que o time concordou).

### Pilar 5 — Gates de workflow (portoes inegociaveis)

- **Intencao:** tornar **impossivel (ou pelo menos auditavel)** avancar sem cumprir as condicoes minimas — CI verde, review aprovado, branch protegida respeitada — em vez de depender da disciplina individual.
- **Criterio de aceite:**
  - **Branch protection** na base (`main`/`develop`/`release/*`): exige PR (sem push direto), exige **status checks obrigatorios verdes**, exige N aprovacoes, exige branch atualizada com a base, bloqueia force-push e delecao, opcionalmente exige signed commits e CODEOWNERS.
  - **Gate de CI:** nenhum merge enquanto qualquer check obrigatorio estiver vermelho/pendente. Re-run de flaky e permitido; **desabilitar/burlar** o check para mergear nao e.
  - **Gate de review:** aprovacao necessaria + threads resolvidos; CODEOWNERS para areas sensiveis.
  - **Gate de higiene:** mensagens/branch no padrao (commitlint/branch-name check como check obrigatorio); ausencia de segredos (secret scanning).
  - O gate e **enforced pelo host/automacao**, nao so documentado; e bypass (admin override) e raro, justificado e auditavel.
- **Como implementar (multi-host/stack):**
  - **GitHub:** Branch protection rules / Rulesets — "Require status checks to pass", "Require pull request reviews", "Require branches to be up to date", "Require signed commits", "Do not allow bypassing", required CODEOWNERS, merge queue. Secret scanning + push protection.
  - **GitLab:** Protected branches (no push, merge access), "Pipelines must succeed", "All threads resolved", approval rules (`CODEOWNERS`), push rules (commit message regex, branch name regex, "reject secrets").
  - **Bitbucket:** Branch permissions + merge checks ("minimum approvals", "no failed builds", "all tasks resolved").
  - **Azure DevOps:** Branch policies — "Build validation", "Minimum number of reviewers", "Comment resolution", "Check for linked work items", required reviewers.
  - **Automacao transversal:** commitlint/branch-name como **status check** obrigatorio; pre-commit hooks (defesa local, nao substitui o gate server-side); merge bots (mergify/kodiak) que so mergeiam quando o gate fecha.
- **Armadilhas sub-atomicas:**
  - Check existe mas **nao e marcado como obrigatorio** -> PR mergeia vermelho.
  - Branch protection so na `main`, esquecendo `develop`/`release/*` -> push direto destrutivo nessas.
  - "Require branches up to date" desligado -> merge de codigo que passou no CI contra base antiga (broken trunk apesar de checks verdes).
  - Admins com bypass irrestrito e silencioso -> gate vira teatro.
  - Hooks locais (pre-commit) tratados como gate -> sao puláveis (`--no-verify`); o gate real e server-side.
  - Secret scanning ausente -> segredo entra no historico sem ninguem barrar.
  - Required reviewers sem CODEOWNERS em area sensivel -> qualquer um aprova mudanca critica.
- **Como verificar:** inspecione a config de protecao (`gh api repos/:owner/:repo/branches/main/protection`, GitLab protected branches API, Azure branch policies) e confirme cada gate ligado; tente um push direto na base e confirme rejeicao; abra um PR vermelho e confirme que o botao de merge fica bloqueado; confirme que commitlint/branch-name/secret-scan sao checks **obrigatorios**.

### Pilar 6 — Higiene de historico (linear, limpo, sem segredo)

- **Intencao:** manter o historico do trunk **legivel, navegavel e confiavel** — uma sequencia de commits significativos, sem WIP/ruido, sem segredos, com estrategia de merge consistente e tags/SemVer coerentes.
- **Criterio de aceite:**
  - **Estrategia de merge consistente** e adequada ao objetivo: **squash-merge** (1 commit Conventional Commits por PR, historico linear, ideal trunk-based) | **rebase-merge** (linear preservando commits atomicos) | **merge-commit** (preserva topologia da branch, util quando o agrupamento importa). O repo escolhe **uma** e a aplica.
  - **Mensagem final** de cada merge/squash e Conventional Commits valida (Pilar 2) — especialmente o titulo do PR em repos de squash.
  - Trunk **sem commits de ruido**: nada de "wip", "fix typo" soltos, merges-de-base disfarçados, ou commits revertendo o anterior dentro do mesmo PR (squash resolve).
  - **Sem segredos no historico** (em nenhum commit, nem antigo). Secret scanning ativo; se vazou, **rotacionar + purgar**.
  - **`.gitignore` correto:** sem `node_modules`/build artifacts/`.env`/arquivos de IDE versionados.
  - **Tags/releases** seguem SemVer e batem com os tipos de commit; CHANGELOG (se houver) gerado a partir do historico.
  - Historico **linear o suficiente** para `git bisect`, `blame` e `log --oneline` serem uteis.
- **Como implementar (multi-host/stack):**
  - **Configurar estrategia no host:** GitHub repo settings — habilitar so a estrategia desejada ("Allow squash merging" e "use PR title as commit message"); GitLab "Merge method" (Merge commit / Squash / Fast-forward) + "Squash commits when merging"; Bitbucket merge strategy; Azure "Squash"/"Rebase"/"Merge".
  - **Linear local:** `git pull --rebase` (config `pull.rebase=true`), `git rebase -i` para limpar antes de abrir PR, `git config rerere.enabled true` para conflitos repetidos.
  - **`.gitignore`:** gerar de templates (`gitignore.io`/`github/gitignore`) por stack; `git rm --cached` para des-versionar o que ja entrou indevidamente.
  - **Remover segredo do historico:** `git filter-repo` (preferido) ou BFG Repo-Cleaner; depois **rotacionar a credencial** (purgar nao basta — ela ja foi exposta) e coordenar re-clone com o time (reescrita global do historico).
  - **Changelog/tag:** ferramentas do Pilar 2 (`semantic-release`/`release-please`/`git-cliff`) leem o historico Conventional Commits e produzem tag + CHANGELOG.
- **Armadilhas sub-atomicas:**
  - Misturar estrategias de merge (as vezes squash, as vezes merge-commit) -> historico inconsistente, dificil de seguir/bisect.
  - Squash que herda o titulo padrao do PR ("Update X") em vez de Conventional Commits -> mensagem final fora do padrao.
  - Merges-de-base repetidos poluindo o historico do PR (em vez de rebase) -> em merge-commit, viram ruido permanente.
  - "Apagar segredo num novo commit" -> o segredo continua no historico (precisa purgar + rotacionar).
  - Build artifacts/`node_modules`/`.env` versionados -> repo inchado, segredo vazado, diffs ilegiveis.
  - Tag/SemVer manual divergindo dos tipos de commit -> consumidores recebem MAJOR/MINOR errado.
  - `git filter-repo`/BFG sem coordenar com o time -> todos ficam com historico divergente (precisa re-clone combinado).
- **Como verificar:** `git log --graph --oneline -50` mostra historico coerente com a estrategia escolhida; `git log --all -p | <secret scanner>` (ou `gitleaks`/`trufflehog`) nao acha segredos; `git check-ignore`/`git status` confirma que artifacts nao sao versionados; as tags batem com SemVer derivado dos commits; o changelog gerado corresponde ao historico.

---

## 6. Orientacao por Host e por Stack (o que muda por ecossistema)

> Os comandos sao **ilustrativos** do padrao, nao a unica forma. Confirme nomes de check, jobs e flags no repo/host reais; eles variam.

**Por host / forge:**
- **GitHub:** PR + `gh` CLI (`gh pr create/checks/merge/view`, `gh run watch/view --log-failed`); Actions como status checks; Branch protection/Rulesets; CODEOWNERS; merge queue; secret scanning + push protection; "use PR title as squash commit message". Auto-merge: `gh pr merge --auto --squash`.
- **GitLab:** MR + `glab` CLI (`glab mr create`, `glab ci status/view/trace`); GitLab CI (`.gitlab-ci.yml`); protected branches + push rules (regex de commit/branch, reject secrets); approval rules + CODEOWNERS; "merge when pipeline succeeds"; squash option por MR.
- **Bitbucket:** PR + Pipelines (`bitbucket-pipelines.yml`); branch permissions + merge checks (approvals, no failed builds, tasks resolved); REST API / `bb` para automacao.
- **Azure DevOps:** PR + Pipelines; branch policies (build validation, reviewers minimos, comment resolution, linked work items); `az repos pr`.
- **Gitea/Forgejo:** PR + Actions/Drone; branch protection similar ao GitHub.
- **Gerrit:** modelo de **change** (1 commit = 1 change, `Change-Id` no footer, `git push origin HEAD:refs/for/main`); review por +1/+2; rebase para atualizar; aqui o "fixup" e literalmente `git commit --amend` do change (e esperado e seguro, pois e o modelo). Generalize o **principio** (nao reescrever o que outros dependem), mas respeite a mecanica do host.
- **Git puro (sem host):** sem branch protection server-side; o gate vive em hooks (`pre-receive`/`update` no servidor bare) + disciplina. CI via runner externo.

**Por linguagem/stack (afeta o que o CI checa e como auto-fixar — Pilar 4):**
- **JS/TS:** ESLint/Prettier/Biome (`--fix`/`--write`/`--apply`); Jest/Vitest/Playwright; Husky/lefthook + commitlint; changesets/semantic-release.
- **Python:** ruff/flake8/black/isort (`--fix`/format); pytest; pre-commit framework; commitizen/python-semantic-release.
- **Go:** `gofmt`/`golangci-lint --fix`; `go test ./...`; lefthook; goreleaser.
- **Java/Kotlin:** Spotless/Checkstyle/ktlint (`spotlessApply`/`ktlintFormat`); JUnit; Maven/Gradle; jreleaser.
- **C#/.NET:** `dotnet format` + analyzers; xUnit/NUnit; GitVersion para SemVer.
- **Ruby:** RuboCop (`-A`); RSpec; overcommit; gem-release.
- **PHP:** PHP-CS-Fixer/PHPStan; PHPUnit; CaptainHook.
- **Rust:** `cargo fmt`/`clippy --fix`; `cargo test`; `git-cliff`/cargo-release.
- **Mobile:** SwiftLint/swiftformat, ktlint, `flutter analyze`/`dart format`; fastlane para release.

> Em todos: o **auto-fixer** resolve lint/format (commit de correcao via fixup ou normal, Pilar 4); o **teste** que quebra exige correcao real, nao afrouxamento; o **commitlint/branch-name** vira check obrigatorio (Pilar 5); o **release tool** le Conventional Commits (Pilar 2/6).

---

## 7. Armadilhas / Anti-Padroes Transversais (gotchas)

- **`git push --force` cego:** apaga commits que outros empurraram na branch. Use sempre `--force-with-lease`, e nunca em branch protegida.
- **`amend`/`rebase` em commit ja revisado:** desancora comentarios do review e diverge quem puxou. Apos review, prefira commit normal + squash final.
- **Mergear vermelho/pendente ("e so o lint"):** quebra o trunk para todos. CI verde e portao real.
- **Re-run infinito de teste que falha de verdade:** trata bug como flaky e mascara regressao.
- **Tipo de Conventional Commit errado:** `chore` num bugfix / `feat` num refactor -> SemVer e changelog mentem.
- **`BREAKING CHANGE` esquecido:** consumidores quebram sem bump de MAJOR.
- **Titulo de PR fora do padrao em repo de squash:** o titulo vira o commit permanente; valide o **titulo do PR**, nao so os commits locais.
- **Branch generica/longeva:** `temp`/`wip`/`johns-branch`, viva por semanas -> conflitos gigantes, irrastreavel.
- **Hotfix saindo do trunk em vez de `main`/release:** arrasta codigo nao-liberado para producao.
- **Segredo "removido" num novo commit:** continua no historico. Rotacionar + purgar (`filter-repo`/BFG).
- **`git add .` cego:** arrasta artifact/`.env`/arquivo nao relacionado. Use `git add -p`.
- **Hooks locais tratados como gate:** sao puláveis (`--no-verify`); o gate real e server-side (branch protection).
- **"Require up to date" desligado:** merge de codigo testado contra base antiga -> trunk quebra apesar de checks verdes.
- **Branch protection so na `main`:** `develop`/`release/*` ficam desprotegidas.
- **Estrategias de merge misturadas:** historico inconsistente, `bisect` dificil.
- **Resolver thread de review sem endereçar:** feedback perdido.
- **Rebase/reset sem `reflog`/backup:** perda de trabalho sem rede de seguranca.
- **PR gigante:** review superficial, bugs passam. Decomponha.

---

## 8. Classificacao de Risco / Prioridade (para gaps de conformidade)

Para cada gap, atribua quatro eixos:

- **Severidade:** Critica (segredo no historico / force-push destrutivo em branch compartilhada / merge com CI vermelho em branch protegida / branch protection ausente na base / reescrita de historico publicado que causou perda) | Alta (`BREAKING CHANGE` omitido, gate de CI nao-obrigatorio, hotfix da base errada, amend em commit revisado) | Media (Conventional Commits inconsistente, branch sem convencao, PR sem descricao, estrategia de merge mista) | Baixa (scope inconsistente, ruido de commit, polimento) | Informativa.
- **Prioridade:** P0 (risco agora: segredo exposto, trunk quebrado, perda de trabalho) | P1 (proximo ciclo) | P2 (planejado) | P3 (oportunista).
- **Confianca:** Confirmada (vi o historico/config) | Provavel (forte indicio) | Suspeita (heuristica) | Precisa de contexto (depende de config de protecao/host nao mostrados).
- **Esforco:** Baixo | Medio | Alto.

Heuristica: segredo no historico, ausencia de branch protection na base, e force-push destrutivo em branch compartilhada tendem a Critica/P0.

---

## 9. Modo Auditoria de Conformidade (saida obrigatoria neste modo)

Quando operado em Modo AUDITAR, produza exatamente nesta estrutura:

### 9.1 Resumo executivo
3-6 frases: estado geral da higiene do fluxo Git/repo, nivel de risco (historico/seguranca/processo), e os 3 gaps mais perigosos (priorize segredo no historico, gates ausentes, e reescrita/force-push perigosos).

### 9.2 Tabela de conformidade (placar dos 6 pilares)

| # | Pilar | Status (Conforme/Parcial/Ausente/N/A) | Severidade | Prioridade | Confianca | Esforco |
|---|-------|----------------------------------------|------------|------------|-----------|---------|
| 1 | Convencao de nomes de branch | | | | | |
| 2 | Conventional Commits | | | | | |
| 3 | PR/MR babysitting | | | | | |
| 4 | Correcao com fixup (sem amend em publicado) | | | | | |
| 5 | Gates de workflow (CI verde, review, protecao) | | | | | |
| 6 | Higiene de historico (linear, sem segredo) | | | | | |

### 9.3 Achados detalhados (um bloco por gap, formato fixo)

```
[ID] Pilar N — Titulo do gap
- Localizacao: branch / commit (sha) / PR# / config de protecao / hook / arquivo (ou "nao localizado — assuncao")
- Host/stack afetado: (GitHub/GitLab/Bitbucket/Azure/... + linguagem/CI, ou "generico")
- Evidencia: o que foi observado (saida de git log/checks/config), sem inventar
- Impacto: o que se perde / risco (trunk quebrado? segredo exposto? perda de trabalho? SemVer errado?)
- Status & classificacao: Severidade / Prioridade / Confianca / Esforco
- Correcao: o COMO concreto (comando + onde + config)
- Exemplo de correcao: snippet/comando ilustrativo (host/stack relevante), segredos mascarados
- Verificacao: como provar que ficou conforme (comando + resultado esperado)
```

### 9.4 Plano de remediacao em fases
- **Fase 0 (P0, agora):** purgar+rotacionar qualquer segredo do historico; ligar branch protection na base (PR obrigatorio, checks obrigatorios verdes, sem force-push); parar qualquer pratica de force-push cego/amend em compartilhado.
- **Fase 1 (P1):** tornar commitlint + branch-name + secret-scan **checks obrigatorios**; padronizar estrategia de merge unica; exigir review + threads resolvidos + branch up-to-date; corrigir tipos de commit que afetam SemVer.
- **Fase 2 (P2):** hooks locais (Husky/lefthook/pre-commit) com auto-fix; template de PR; changelog/release automatizado a partir de Conventional Commits; auto-merge/merge-queue.
- **Fase 3 (P3):** vocabulario de scopes padronizado; documentacao do branching model; treinamento; metricas de tamanho de PR/tempo de ciclo.

### 9.5 Checklist final
Lista marcavel dos 6 pilares com seus criterios de aceite, mais: nenhum segredo em nenhum commit do historico; base protegida (sem push direto, force-push bloqueado); todos os checks obrigatorios verdes antes de qualquer merge auditado; mensagens (e titulos de PR de squash) Conventional Commits validos; branches no padrao e saindo da base correta; estrategia de merge unica e consistente; `.gitignore` sem artifacts/`.env`; nenhuma reescrita de historico publicado sem `--force-with-lease` consciente e acordado.

---

## 10. Regras de Qualidade e Auto-Verificacao (antes de entregar)

- [ ] Seja **especifico**: cada recomendacao tem comando/mecanismo + local + criterio de aceite + verificacao.
- [ ] **Nao invente** nomes de check/job, comandos de CLI ou flags; diferencie **confirmado** de **provavel**; declare o que falta de contexto (qual host? branch ja foi pushada? quais checks sao obrigatorios? qual estrategia de merge?).
- [ ] Sempre proponha **correcao + verificacao** juntos (e a verificacao deve ser um comando concreto com resultado esperado).
- [ ] Cubra **multiplos hosts e stacks** ao exemplificar e marque exemplos como ilustrativos; nada na resposta assume um unico host/linguagem/CI.
- [ ] Antes de qualquer operacao destrutiva (force-push, reset hard, rebase, filter-repo), verifique se o alvo foi **publicado/compartilhado** e ofereca rede de seguranca (`reflog`/backup/branch); prefira `--force-with-lease` a `--force`.
- [ ] Trate **CI verde**, **nao reescrever historico publicado** e **nenhum segredo no historico** como inegociaveis.
- [ ] Nunca recomende logar/expor segredos; mascare em todo exemplo (`ghp_***`, `glpat-***`, `AKIA***`).
- [ ] Calibre o tamanho ao objetivo: denso, acionavel, util para leigo e senior. So eleve — nunca reduza o escopo.

Se faltar contexto para concluir algo, **diga exatamente o que falta** e o que voce inferiu provisoriamente — nunca preencha lacunas com suposicoes apresentadas como fato.
