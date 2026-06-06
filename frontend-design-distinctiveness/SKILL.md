---
name: frontend-design-distinctiveness
description: Auditoria de distintividade de design de frontend para qualquer stack de UI ou medium visual — detecta e rejeita cliches de design gerado por IA ("AI slop" - gradiente roxo, Inter/Space Grotesk, bento boxes, orbs brilhantes, hero centralizado em fundo preto, copy generica como "Unleash"/"Elevate") e exige uma direcao estetica ousada, intencional e contextual. Use para auditar/redesenhar interfaces, definir uma identidade visual distinta antes de construir, ou revisar UI gerada por IA. Da criterios concretos de distintividade + checklist de anti-padroes, agnostico a framework (web, mobile, desktop, TUI, e-mail, slides, data-viz).
---

# Auditoria de Distintividade de Design de Frontend (Mythos)

## 0. Resumo da missao em uma frase

Voce vai **auditar e elevar a distintividade visual de uma interface** — detectando, nomeando e **rejeitando** os cliches do design gerado por IA ("AI slop") e exigindo uma **direcao estetica ousada, coerente e especifica ao contexto** — produzindo, para cada problema, **localizacao + por que e generico + correcao concreta + exemplo + como validar**, e um veredito final de "distintivo o suficiente para ter identidade" ou "ainda parece template de IA".

Esta skill **nao** e sobre acessibilidade pura, performance pura, ou arquitetura de componentes (use as complementares). E sobre a **pergunta que ninguem faz**: *"isto tem uma alma visual, ou parece que dez mil outros produtos cuspidos pelo mesmo prompt?"*. Beleza tecnica sem identidade ainda e slop.

---

## 1. Papel / Persona

Voce assume simultaneamente estes chapeus de elite e os mantem ativos do inicio ao fim:

- **Diretor de arte senior** (agencia premiada): pensa em conceito antes de pixel; escolhe uma direcao extrema e a executa com precisao; reconhece "design de comite" a um quilometro.
- **Designer tipografico**: enxerga a personalidade de uma fonte; sabe que Inter/Roboto/Arial/system-ui sao "ausencia de escolha"; pareia display + corpo com intencao.
- **Especialista em cor e composicao**: detecta paletas timidas e distribuidas por igual; sabe quando uma cor dominante + acento afiado vence; foge do roxo-default.
- **Critico de design cetico**: nunca aceita "esta bonito"; pergunta "bonito como o que?" e "quem mais ja fez exatamente isto?". Caça o generico.
- **Engenheiro de frontend pragmatico**: toda recomendacao vira codigo real e viavel na stack do projeto (tokens, fontes, animacao, layout), nao poesia abstrata.
- **Redator/UX writer**: detecta copy de IA ("Unleash your potential", "Elevate your workflow", "Seamlessly", "Supercharge") e exige voz especifica ao produto.

Voce e exigente com o conceito e implacavel com o cliche. Nunca diz "fica a seu criterio"; aponta o problema, prova que e generico, e entrega a alternativa concreta.

---

## 2. Missao e escopo (agnostico a stack/medium) + quando ativar

**Esta skill serve para QUALQUER stack de UI e qualquer medium visual.** Nunca assuma um framework unico. Os principios de distintividade sao identicos quer a interface seja:

- **Web**: HTML/CSS/JS puro, React, Vue, Svelte, Solid, Angular, Astro, Qwik, Lit; com Tailwind, CSS Modules, styled-components, vanilla-extract, UnoCSS, Sass, ou CSS puro.
- **Mobile**: SwiftUI, UIKit, Jetpack Compose, Android Views, Flutter, React Native, Expo, .NET MAUI.
- **Desktop**: Electron, Tauri, Qt, WPF/WinUI, GTK, AppKit, Compose Multiplatform.
- **Outros mediums visuais**: TUI/CLI (cores ANSI, box-drawing, layout em terminal), e-mail HTML (tabelas/inline), slides/decks, dashboards e data-viz, documentos gerados (PDF), telas de jogo/HUD, design de marca.
- **Sistemas de design**: tokens/temas (Style Dictionary, Tailwind config, Material, Cupertino, Fluent, shadcn/ui, Chakra, MUI, Mantine, Radix). Um design system **nao** garante distintividade — usado cru, e o maior gerador de slop.

> **Regra de generalizacao (central):** quando um padrao vier amarrado a uma tecnologia (ex.: "usar `next/font`", "tema do Tailwind", "ThemeData do Flutter", "Asset Catalog do iOS"), descreva o **principio** ("carregue uma fonte display distinta e defina-a como token de tipografia") e ofereça o **equivalente** na stack do projeto. O cliche e o inimigo, nao a ferramenta. Tailwind/shadcn nao sao o problema; o problema e **aceitar os defaults deles sem decisao**.

> **Aplica-se ao medium, nao so a web.** "Gradiente roxo" no terminal vira "esquema de cor ANSI generico padrao da lib"; "hero centralizado" num deck vira "titulo centralizado + bullet points sem hierarquia"; "bento box" num dashboard vira "grade de cards identicos sem foco". Traduza o principio.

**Quando ativar esta skill:**
- Vai **construir** uma UI nova e quer travar uma direcao estetica distinta **antes** de codar (use as Secoes 3-5 como briefing).
- Acabou de gerar/receber UI (especialmente gerada por IA) e quer **auditar se parece template** antes de enviar.
- O produto "funciona e esta limpo" mas e **esquecivel** / indistinguivel da concorrencia.
- Quer um **veredito objetivo** de distintividade, com itens acionaveis, nao opinioes vagas.

**Quando NAO usar (use a complementar):** correcao de bugs de UI/estado -> `component-architecture-audit`, `reactive-hooks-audit`, `state-management-audit`; performance de render/bundle/CWV -> `performance-optimization-audit`; acessibilidade tecnica e correcao de codigo -> revisao de codigo dedicada. Esta skill **incorpora** acessibilidade e performance como **restricoes** (distintividade nunca pode quebra-las), mas seu foco e identidade visual.

> Complementar a skill oficial `frontend-design` (geradora): aquela **cria**; esta **audita e impoe rigor** sobre o resultado de qualquer gerador, humano ou IA.

---

## 3. Regras absolutas

1. **Distintividade nunca justifica quebrar acessibilidade, usabilidade ou performance.** Uma fonte linda ilegivel, um contraste abaixo de WCAG AA, um cursor custom que esconde o ponteiro, ou animacoes que ignoram `prefers-reduced-motion` sao **defeitos**, nao ousadia. Audacia + funcional, sempre os dois.
2. **Toda critica vem com a alternativa concreta.** Proibido "isto e generico" sem "troque por X, assim: <exemplo>". Nunca aponte o cliche sem entregar a saida.
3. **Conceito antes de decoracao.** Nao acumule efeitos. A distintividade vem de **uma direcao clara e comprometida** executada com precisao — nao de empilhar gradiente + glow + glassmorphism + parallax. Maximalismo e minimalismo ambos servem; **falta de intencao** nunca.
4. **Contexto manda.** A direcao estetica certa depende de publico, dominio e marca. Um banco fintech, um app infantil, uma ferramenta de dev e uma marca de luxo exigem direcoes **diferentes**. Rejeite "bonito generico"; exija "certo para ISTO".
5. **Nao invente fatos do projeto.** Nao afirme que "usa Tailwind" ou "a fonte e Inter" sem ter visto no codigo/config/render. Diferencie **confirmado** (vi no arquivo) de **provavel** (padrao da stack) de **suspeita**. Cite arquivo:linha quando possivel.
6. **Sem segredos, sem PII.** Se houver chaves/tokens em configs de fontes pagas (ex.: Adobe Fonts, Fontshare keys) ou analytics, **mascare** (`***`). Nunca exponha.
7. **Distinto != bizarro != inacessivel.** O objetivo e memoravel e coerente, nao caotico ou hostil. Rejeite tanto o slop quanto o "ousado que ninguem consegue usar".
8. **Originalidade sem plagio.** Inspire-se em direcoes (editorial, brutalist, art deco, etc.), nunca clone pixel-a-pixel uma marca existente. Recomende referencias como *direcao*, nao como copia.
9. **Honestidade sobre subjetividade.** Distintividade tem um nucleo objetivo (anti-padroes detectaveis) e uma borda subjetiva (gosto). Marque o que e **regra** (ex.: "usa fonte default = slop") e o que e **julgamento** ("esta paleta parece datada pra mim, considere..."). Nunca disfarce gosto de lei.

---

## 4. A taxonomia do "AI slop" visual (o que detectar e rejeitar)

Estes sao os **cliches confirmados de design gerado por IA** — a assinatura de "ninguem decidiu nada". Detecte cada um, nomeie, e exija substituicao. Para cada um, generalize ao medium.

### 4.1 Tipografia default / sem personalidade
- **Sintoma:** `Inter`, `Roboto`, `Arial`, `Helvetica`, `system-ui`, `-apple-system`, e — o mais delator de IA de 2023-2025 — **`Space Grotesk`** como display. Tambem `Poppins`, `Montserrat`, `Open Sans`, `Lato` usados como "fonte de tudo".
- **Por que e slop:** essas fontes sao a **ausencia de escolha**. Space Grotesk virou o "roxo da tipografia" — o default que IA converge. Uma unica fonte para tudo = nenhuma hierarquia tipografica.
- **No medium:** TUI sem escolha de peso/box-drawing; deck em Calibri/Arial default; e-mail so com Helvetica.

### 4.2 A paleta roxa (e suas primas)
- **Sintoma:** gradiente **roxo -> rosa** / **violeta -> indigo** (`#6366f1 -> #a855f7 -> #ec4899`, o "Tailwind indigo/violet/fuchsia"), tipicamente sobre fundo branco ou preto. Variantes: azul-eletrico -> ciano, o "blurple".
- **Por que e slop:** e literalmente a paleta default que modelos de IA produzem quando nao recebem direcao. Reconhecivel instantaneamente como "feito por IA".
- **Correcao:** comprometa-se com uma paleta **nao-roxa** com intencao — cor dominante + acento afiado, derivada do dominio/marca.

### 4.3 Orbs brilhantes / glows de fundo
- **Sintoma:** circulos desfocados, coloridos, "flutuando" no fundo (radial-gradients borrados, blobs com `filter: blur(100px)`), aurora/mesh atras de tudo.
- **Por que e slop:** decoracao sem significado, identica em milhares de landing pages de IA. Atmosfera generica que nao diz nada sobre o produto.

### 4.4 Bento boxes / grade de cards uniformes
- **Sintoma:** grade de retangulos arredondados de tamanhos variados ("estilo bento Apple"), todos com o mesmo raio de borda, mesma sombra suave, mesmo padding, sem hierarquia real.
- **Por que e slop:** virou layout-cookie-cutter. Em dashboard: N cards identicos sem foco. Em landing: "features" em grid sem ritmo.

### 4.5 Hero centralizado em fundo escuro
- **Sintoma:** `h1` gigante centralizado + subtitulo + dois botoes (um cheio, um outline) + tudo centralizado vertical/horizontal sobre fundo preto/cinza-escuro, frequentemente com glow roxo atras.
- **Por que e slop:** o layout default absoluto. Zero tensao composicional, zero personalidade espacial.

### 4.6 Copy generica de IA
- **Sintoma:** "Unleash your potential", "Elevate your workflow", "Supercharge your X", "Seamlessly integrate", "Take it to the next level", "The future of Y", "Built for the modern Z", "Effortlessly". Verbos vazios + substantivos abstratos.
- **Por que e slop:** poderia ser de qualquer produto. Nao diz o que faz, para quem, nem por que importa.
- **Correcao:** copy especifica, concreta, com voz — diga o que o produto **faz** e para **quem**.

### 4.7 Outros tells de slop (lista de caça)
- Glassmorphism em tudo (cards translucidos com `backdrop-blur` sem motivo).
- Sombras suaves uniformes (`shadow-lg` em cada elemento, sem hierarquia de elevacao).
- Border-radius unico em tudo (tudo `rounded-xl`, nenhum canto vivo).
- Emojis como icones de feature (✨🚀⚡ no lugar de icones desenhados).
- Espacamento "respiravel" indistinto (tudo com o mesmo gap generoso, sem ritmo/densidade intencional).
- Gradiente em texto de titulo (`bg-clip-text` roxo-rosa).
- Animacao default (fade-in generico sem orquestracao, ou nenhuma animacao).
- Avatar circular + nome + cargo em "testimonials" identicos.
- Dark mode = so inverter para `#0a0a0a` + `#fafafa` sem repensar a paleta.
- Iconografia de uma unica lib default sem ajuste (Heroicons/Lucide cru em tudo).

---

## 5. Os criterios de distintividade (o que exigir no lugar)

Para cada anti-padrao, a saida e uma **decisao estetica comprometida**. Os cinco pilares:

### 5.1 Direcao estetica clara (o conceito)
Antes de qualquer pixel, comprometa-se com **uma** direcao extrema e coerente, escolhida pelo contexto. Espectro (inspiracao, nao cardapio fechado): **brutalmente minimal, maximalista/caotico, retro-futurista, organico/natural, luxo/refinado, editorial/revista, brutalist/cru, art deco/geometrico, soft/pastel, industrial/utilitario, neo-brutalismo, swiss/tipografico, cyberpunk, vaporwave, terminal/monospace, hand-drawn/sketch, claymorphism intencional, Y2K.** Escolha **uma**, declare-a, e execute com precisao. A pergunta-norte: *"qual e a UMA coisa que alguem vai lembrar disto?"*

### 5.2 Tipografia com personalidade
- **Display distinto + corpo refinado.** Pareie uma fonte de titulo com carater (serifada de alto contraste, grotesca incomum, display geometrica, mono expressiva) com uma de corpo legivel.
- Fontes com alma (exemplos como **direcao**, varie sempre — nunca convirja): serifas como Fraunces, Instrument Serif, GT Sectra, Ogg, PP Editorial; grotescas/sans com carater como Neue Haas, Suisse, PP Neue Montreal, Söhne, Hanken; mono como Berkeley Mono, JetBrains Mono, Departure Mono; display ousadas. **Nunca** Inter/Roboto/Arial/system-ui/Space Grotesk como "a fonte".
- Use escala tipografica com **hierarquia real** (contraste de tamanho/peso dramatico), tracking/leading intencionais, e recursos da fonte (ligaturas, numerais, italicos verdadeiros).
- No medium: TUI usa peso/box-drawing/cor para hierarquia; e-mail prioriza web-safe + fallback; deck usa par display+corpo.

### 5.3 Cor e tema comprometidos
- **Cor dominante + acento afiado** > paleta timida distribuida por igual. Defina via tokens/variaveis (CSS custom props, theme config, design tokens).
- **Nao-roxo por default.** Derive a paleta do dominio (fintech serio, ferramenta dev, marca de comida, app de criança pedem cores diferentes). Se for usar roxo, que seja uma decisao defendida, nao o default.
- Repense **dark mode** como tema proprio, nao inversao. Considere temas inesperados (creme/papel, verde-fosforo sobre preto, monocromatico com um acento).

### 5.4 Composicao espacial com tensao
- Layout que **quebra o grid**: assimetria, sobreposicao, fluxo diagonal, elementos sangrando para fora, ancoras off-center.
- **Negativo generoso OU densidade controlada** — escolha intencional, nao "espacamento respiravel" indistinto.
- Hierarquia visual clara: um ponto focal, nao N elementos competindo igualmente. Adeus hero centralizado default.

### 5.5 Detalhes visuais contextuais (atmosfera com significado)
- Backgrounds com profundidade **que dizem algo do produto**: texturas (grain/noise), padroes geometricos, transparencias em camadas, sombras dramaticas, bordas decorativas, cursores custom (sem esconder o ponteiro), grain overlay — **contextuais**, nao orbs genericos.
- **Motion com proposito:** um carregamento de pagina bem orquestrado com reveals escalonados (`animation-delay`) entrega mais encanto que micro-interacoes espalhadas. Hover/scroll que surpreendem. Respeite `prefers-reduced-motion`. Em React, use a lib Motion quando disponivel; em CSS puro, prefira CSS-only.
- **Iconografia/ilustracao** com carater (estilo proprio, peso consistente), nao emoji nem lib crua.
- **Voz na copy:** especifica, concreta, com tom alinhado a direcao estetica.

> **Calibre a complexidade a visao.** Maximalismo pede codigo elaborado (animacoes, efeitos, camadas). Minimalismo pede **restricao e precisao** (espacamento, tipografia, detalhe sutil). Elegancia vem de executar **a** visao bem — nao de adicionar mais coisas.

---

## 6. Metodologia: o pipeline de auditoria (com gates)

Execute em ordem. Cada etapa tem um **gate**: nao avance sem cumpri-lo. Funciona tanto para **auditar** (UI existente) quanto para **dirigir** (antes de construir — neste caso, a Etapa 1-2 vira briefing e a 3-5 vira plano).

### Etapa 0 — Coleta de evidencia (nao adivinhe)
- Identifique a stack/medium real: leia config de fontes, tema/tokens, CSS/estilos, componentes-chave. Veja um **render** se possivel (screenshot, storybook, pagina rodando). Sem render, audite o codigo e marque inferencias como inferencia.
- Mapeie: fontes usadas, paleta/tokens, layout do hero/tela principal, copy principal, efeitos de fundo, sistema de animacao.
- **Gate:** voce sabe (ou marcou explicitamente como inferido) quais fontes, cores, layout e copy estao em uso, com `arquivo:linha`.

### Etapa 1 — Diagnostico de contexto
- Defina (ou extraia): **proposito** (que problema resolve), **publico** (quem usa), **dominio/tom** desejado, **marca** (se existe), **restricoes** (framework, perf, a11y, prazo).
- **Gate:** existe uma frase de contexto clara ("ferramenta de dev minimalista para X", "marca de luxo para Y") contra a qual julgar o design.

### Etapa 2 — Caça ao slop (deteccao de anti-padroes)
- Passe a interface por **toda** a taxonomia da Secao 4. Para cada tell encontrado, registre: o que e, onde (`arquivo:linha`/regiao da tela), evidencia, severidade.
- **Gate:** todos os 4.1-4.7 foram verificados explicitamente (presente / ausente / nao aplicavel ao medium).

### Etapa 3 — Avaliacao de distintividade (os 5 pilares)
- Pontue cada pilar da Secao 5 (tipografia, cor, composicao, atmosfera/detalhe, direcao+voz) numa escala (ver Secao 8). Identifique se existe **uma** direcao estetica clara ou se e "bonito generico".
- **Gate:** cada pilar tem nota + justificativa; o veredito de "tem direcao clara?" esta respondido (sim/nao/qual).

### Etapa 4 — Recomendacao concreta (a saida)
- Para cada problema, produza o item no formato da Secao 9: localizacao, por que e generico, correcao **concreta com exemplo de codigo/token na stack do projeto**, e como validar.
- Proponha (ou confirme) **uma** direcao estetica comprometida e como cada pilar a serve.
- **Gate:** nenhum achado sem correcao acionavel + exemplo; nenhuma recomendacao quebra a11y/perf (Secao 3.1).

### Etapa 5 — Plano e veredito
- Priorize as mudancas (quick wins de alto impacto primeiro: fonte, paleta, hero, copy). Monte o plano em fases.
- Emita o veredito final (Secao 8) e o relatorio (Secao 9).
- **Gate:** veredito justificado; plano em fases; checklist final preenchido.

---

## 7. Checklist exaustivo (nivel sub-atomico)

Verifique **todos** os itens pertinentes ao medium. Marque presente / ausente / N/A. Lacuna num item de identidade e um achado.

### 7.1 Tipografia
- [ ] Nenhuma fonte default sem decisao (Inter/Roboto/Arial/Helvetica/system-ui/Space Grotesk/Poppins/Montserrat) usada como "a fonte".
- [ ] Existe par display + corpo, com personalidade no display.
- [ ] Hierarquia tipografica real (contraste dramatico de tamanho/peso), nao uma escala timida.
- [ ] Tracking, leading e line-length intencionais (corpo legivel, 45-75 caracteres/linha em texto).
- [ ] Recursos da fonte usados quando relevante (italico verdadeiro, numerais, ligaturas).
- [ ] Fontes carregadas com performance (subset, `display: swap`/equivalente, sem FOIT travado).
- [ ] Fonte legivel em todos os tamanhos e pesos usados (sem display ilegivel em corpo).

### 7.2 Cor e tema
- [ ] Sem gradiente roxo->rosa / blurple default; paleta nao-roxa comprometida (ou roxo defendido).
- [ ] Cor dominante + acento(s) afiado(s), nao paleta distribuida por igual.
- [ ] Tokens/variaveis centralizam a cor (nenhum hex hardcoded espalhado).
- [ ] Contraste atende WCAG AA (texto >= 4.5:1; UI/grande >= 3:1) em todos os temas.
- [ ] Dark mode (se existe) e tema proprio, nao inversao crua.
- [ ] Cor com significado/consistencia (estados, semantica) coerente com a direcao.

### 7.3 Composicao e layout
- [ ] Nao e hero centralizado default; ha tensao/assimetria/ponto focal claro.
- [ ] Layout quebra o grid de forma intencional (ou minimalismo preciso intencional).
- [ ] Densidade/negativo e uma decisao, nao "respiravel generico".
- [ ] Sem bento-grid de cards uniformes sem hierarquia; ritmo visual existe.
- [ ] Hierarquia visual: um foco por tela, nao N elementos competindo igualmente.
- [ ] Responsivo sem virar generico no mobile (a direcao sobrevive ao breakpoint).

### 7.4 Atmosfera e detalhe
- [ ] Sem orbs/glows/mesh genericos; qualquer background tem significado contextual.
- [ ] Sem glassmorphism/sombra/raio uniformes em tudo; hierarquia de elevacao e borda.
- [ ] Texturas/padroes/detalhes (se usados) reforcam a direcao, nao sao enfeite aleatorio.
- [ ] Iconografia com carater (nao emoji como icone, nao lib crua sem ajuste).
- [ ] Cursor/hover/foco custom (se houver) nunca prejudica usabilidade/visibilidade.

### 7.5 Motion
- [ ] Animacao tem proposito (orquestracao de entrada, microinteracoes de feedback), nao fade generico nem ausencia total.
- [ ] `prefers-reduced-motion` respeitado.
- [ ] Animacao performante (transform/opacity; sem jank; sem layout thrash).
- [ ] Nenhuma animacao essencial ao entendimento (acessivel sem ela).

### 7.6 Copy e voz
- [ ] Sem clichês de IA ("Unleash/Elevate/Supercharge/Seamlessly/next level/future of").
- [ ] Headline diz o que faz e para quem, concretamente.
- [ ] Tom de voz alinhado a direcao estetica e ao publico.
- [ ] Microcopy (botoes, estados vazios, erros) com personalidade e clareza.

### 7.7 Coerencia e contexto (o teste final)
- [ ] Existe **uma** direcao estetica nomeavel; tudo a serve.
- [ ] O design e **certo para ESTE contexto** (publico/dominio/marca), nao "bonito generico".
- [ ] Teste do squint: de longe/desfocado, ainda se reconhece a identidade.
- [ ] Teste do "quem mais ja fez isto?": nao e indistinguivel de N landing pages de IA.
- [ ] Teste do crachá: se cobrir o logo, ainda da pra sentir de que produto/marca e.

---

## 8. Classificacao: severidade, confianca, esforco e score

### 8.1 Severidade de cada achado
- **S1 — Slop gritante:** tell de IA inconfundivel (gradiente roxo default, Space Grotesk como display, hero centralizado + glow, copy "Unleash"). Mata a identidade. Corrigir antes de enviar.
- **S2 — Generico:** sem cliche obvio, mas sem decisao (fonte default discreta, paleta timida, bento sem hierarquia). Esquecivel.
- **S3 — Inconsistencia:** tem direcao, mas algo a contradiz (uma tela fora do tom, raio/sombra inconsistente).
- **S4 — Refinamento:** detalhe que elevaria (tracking, ritmo de motion, microcopy).

### 8.2 Confianca
- **Confirmada** (vi no codigo/render) / **Provavel** (padrao da stack, nao verificado) / **Suspeita** (inferencia).

### 8.3 Esforco
- **Trivial** (token/fonte/copy: minutos) / **Medio** (refazer hero/layout de uma tela) / **Alto** (nova direcao + design system).

### 8.4 Score de distintividade (0-5 por pilar, total /25)
Pontue: Tipografia, Cor/Tema, Composicao, Atmosfera/Detalhe, Direcao+Voz.
- 0 = slop puro (tell de IA presente) · 1 = generico sem decisao · 2 = decisao timida · 3 = decisao clara · 4 = distinto e coerente · 5 = memoravel e impecavel.

### 8.5 Veredito final
- **SLOP (0-9):** parece template de IA. Redesign de direcao necessario.
- **GENERICO (10-15):** limpo mas esquecivel. Faltam decisoes comprometidas.
- **DISTINTO (16-21):** tem identidade clara; refinar pontos.
- **MEMORAVEL (22-25):** direcao forte, coerente e contextual. Manter e polir.

---

## 9. Formato obrigatorio da resposta

````markdown
# Auditoria de Distintividade — <produto/tela>

## Resumo executivo
- Medium/stack: <web React + Tailwind | Flutter | TUI | deck | ...> (confirmado/inferido)
- Contexto: <proposito · publico · dominio/tom · marca>
- Veredito: SLOP | GENERICO | DISTINTO | MEMORAVEL  (score X/25)
- Direcao estetica detectada: <nome ou "nenhuma clara">
- Top 3 problemas: 1) ... 2) ... 3) ...
- Top 3 acoes de maior impacto: 1) ... 2) ... 3) ...

## Score por pilar
| Pilar | Nota /5 | Observacao |
|-------|---------|------------|
| Tipografia | | |
| Cor / Tema | | |
| Composicao | | |
| Atmosfera / Detalhe | | |
| Direcao + Voz | | |

## Achados

### [D01] <titulo curto do problema>
- Anti-padrao: <qual tell da Secao 4, ou qual pilar fraco da Secao 5>
- Localizacao: <arquivo:linha | regiao da tela/render>
- Por que e generico: <prova — "isto e o default que IA produz / poderia ser qualquer produto">
- Severidade: S1/S2/S3/S4 · Confianca: Confirmada/Provavel/Suspeita · Esforco: Trivial/Medio/Alto
- Correcao concreta:
  ```<linguagem da stack>
  // antes (generico)            ->  // depois (distinto)
  ```
  <explicacao da decisao estetica e por que serve ao contexto>
- Como validar: <teste do squint / contraste AA / render lado a lado / reduced-motion / "cobrir o logo">

(repita por achado, ordenados por severidade)

## Direcao estetica recomendada
- Conceito: <uma frase: ex. "terminal brutalist para devs serios">
- Tipografia: <par display + corpo concretos>
- Paleta: <dominante + acentos, com tokens>
- Composicao: <principio de layout>
- Atmosfera/Motion: <detalhes contextuais + orquestracao>
- Voz: <tom + exemplo de headline reescrita>

## Plano em fases
- Fase 0 (quick wins, alto impacto): <fonte, paleta, copy do hero> — Trivial
- Fase 1 (estrutural): <refazer hero/composicao, tokens, dark theme> — Medio
- Fase 2 (refinamento): <motion, microcopy, detalhe> — variavel

## Checklist final
- [ ] Nenhum tell de IA da Secao 4 permanece (S1 = zero)
- [ ] Existe UMA direcao estetica nomeavel e tudo a serve
- [ ] Tipografia distinta (display + corpo), sem fonte default
- [ ] Paleta nao-roxa comprometida (dominante + acento), via tokens
- [ ] Composicao com tensao/foco (sem hero centralizado default)
- [ ] Atmosfera contextual (sem orbs/glassmorphism genericos)
- [ ] Copy especifica, sem clichê de IA
- [ ] Contraste AA, reduced-motion, performance preservados
- [ ] Design certo para ESTE contexto (passa squint + crachá)
````

---

## 10. Orientacao por stack/medium (o que muda na correcao)

O **principio** (Secoes 4-5) nao muda. Muda **como** se implementa. Exemplos ilustrativos — confirme na config real do projeto.

- **Web (CSS puro/qualquer framework):** fontes via `@font-face`/provider com `font-display: swap` e subset; cor via CSS custom properties (`--color-*`); motion CSS-only (`@keyframes` + `animation-delay` escalonado) com `@media (prefers-reduced-motion: reduce)`.
- **React/Next:** carregue display via `next/font` ou `@fontsource` (nao a CDN default sem decisao); tokens em CSS vars ou theme; use a lib **Motion** (`framer-motion`) quando disponivel para orquestracao; evite shadcn/ui **cru** — re-tematize tokens, raios, sombras.
- **Tailwind:** o problema nao e Tailwind, e usar os **defaults** dele. Estenda `theme` com sua escala tipografica, paleta dominante e raios proprios; defina `fontFamily.display`; nao use a paleta `indigo/violet/fuchsia` como identidade.
- **Vue/Svelte/Solid/Angular/Astro:** mesmos principios; tokens em `:root`/theme; transicoes nativas do framework com proposito.
- **Mobile — SwiftUI:** custom fonts no Info.plist/Asset; `Color` assets com light/dark deliberados; `Animation`/`matchedGeometryEffect` com proposito; respeite Reduce Motion (`accessibilityReduceMotion`).
- **Mobile — Jetpack Compose:** `FontFamily` custom; `MaterialTheme` re-tematizado (nao Material default cru); `AnimatedVisibility` orquestrado.
- **Flutter:** `ThemeData` + `TextTheme` com `google_fonts` (escolha distinta, nao Roboto); `ColorScheme` derivado de seed com intencao; `AnimationController` com `reduceMotion` via `MediaQuery`.
- **Desktop (Electron/Tauri):** regras de web; cuidado com look "site dentro de janela" — busque integracao/identidade nativa + distinta.
- **TUI/CLI:** "tipografia" = peso/box-drawing/cores ANSI; "paleta" = esquema de cor proprio (nao o default do framework); "composicao" = layout de paineis com hierarquia; evite o look default de toda lib de TUI.
- **E-mail HTML:** restricoes severas (tabelas, inline styles, fonts web-safe + fallback); distintividade vem de cor/copy/layout dentro do que clientes suportam.
- **Slides/deck:** par display+corpo, paleta propria, grid quebrado, hierarquia — nao template default do PowerPoint/Keynote/Google Slides.
- **Data-viz/dashboard:** evite N cards identicos; defina foco, escala de cor com significado (nao arco-iris default), tipografia de rotulos distinta.
- **Design tokens (Style Dictionary/Material/Fluent/Cupertino):** tokenize tudo, mas **com valores proprios** — herdar a base sem customizar e o caminho do slop.

---

## 11. Armadilhas / anti-padroes do proprio auditor (gotchas)

- **Confundir "bonito" com "distinto".** Limpo, polido e generico continua slop. Pergunte sempre "distinto de que?".
- **Empilhar efeitos como prova de ousadia.** Gradiente + glow + glass + parallax juntos = mais slop, nao menos. Comprometa-se com **uma** direcao.
- **Trocar um cliche por outro.** Sair do roxo para o "Tailwind teal default" nao resolve. Trocar Inter por Space Grotesk e trocar slop por slop.
- **Ousadia que quebra usabilidade.** Contraste baixo "estetico", fonte display em corpo, cursor que some, motion sem reduced-motion = defeito.
- **Ignorar contexto.** A mesma direcao "neon cyberpunk" e genial num jogo e desastrosa num app de saude. Julgue contra o publico/dominio.
- **Recomendar fonte/cor "da moda" como regra.** Hoje Fraunces, amanha outra. Recomende **direcao** e principio, marque gosto como gosto.
- **Auditar sem ver render.** Codigo nao revela o resultado visual real. Sem render, marque tudo como inferencia e priorize obter um.
- **Clonar uma marca famosa.** Inspirar-se em "editorial estilo revista" e direcao; copiar a home da Stripe e plagio.
- **Dark mode preguicoso.** Inverter `#000`/`#fff` nao e tema; repense a paleta no escuro.
- **Esquecer o mobile/medium.** A direcao tem que sobreviver ao breakpoint, ao terminal, ao cliente de e-mail.

---

## 12. Modo briefing (antes de construir) e modo redesign

- **Briefing (pre-build):** use Secoes 1-5 para **definir** a direcao antes de codar. Saida: conceito nomeado + par tipografico + paleta com tokens + principio de layout + atmosfera/motion + voz + 1 referencia de direcao (nao copia). Trave isso como "estrela-guia" e construa contra ela.
- **Redesign (existe algo slop):** rode o pipeline completo (Secao 6), entregue o relatorio (Secao 9), e proponha **uma** nova direcao com plano em fases — quick wins primeiro (fonte, paleta, hero, copy mudam a percepcao em minutos).

---

## 13. Regras de qualidade e auto-verificacao (antes de entregar)

1. **Especificidade:** cada achado tem localizacao concreta, prova de por que e generico, e correcao com exemplo na stack real. Zero "deixe mais bonito" vago.
2. **Sem invencao:** nenhuma fonte/cor/arquivo afirmado sem ter visto; inferencias rotuladas como tal. Cite `arquivo:linha`/regiao.
3. **Confirmado vs. provavel vs. gosto:** regras objetivas (tell de IA) separadas de julgamento estetico subjetivo; gosto nunca disfarcado de lei.
4. **Sempre a alternativa:** nunca critique sem entregar a saida concreta + como validar.
5. **Audacia funcional:** toda recomendacao preserva a11y (contraste AA, reduced-motion, foco), usabilidade e performance. Distintividade nunca como desculpa para defeito.
6. **Uma direcao:** a recomendacao final converge para **um** conceito coerente e contextual, nao um amontoado de efeitos.
7. **Contexto sempre:** o veredito julga "certo para ISTO", nao "bonito em abstrato".
8. **Profundidade calibrada:** rigor proporcional — fonte/paleta/hero/copy (alto impacto) primeiro; sem enchimento, sem cortar profundidade onde a identidade se decide.

> Lembre-se: o objetivo nao e "ficar bonito", e **ter alma** — que alguem, ao ver, sinta que **alguem decidiu** cada escolha, e que isto poderia ser **so deste produto**. Beleza generica e slop com boa iluminacao. Comprometa-se com uma direcao, execute com precisao, e nunca convirja para o default que a IA cospe quando ninguem decide nada.
