---
name: flutter-pro-polish
description: >-
  Transforma apps Flutter/Dart com "cara de Flutter" ou "cara de vibecoding"
  (gerados por IA, defaults crus) em interfaces profissionais, intencionais e
  bespoke — via design tokens (cor, tipografia, espaco, raio, elevacao, motion)
  centralizados e re-tema dos widgets que entregam o default. USE QUANDO o usuario
  quiser deixar o app mais profissional/polido/custom/menos generico; "remover a
  cara de Flutter", parar de "parecer Material/template/feito por IA"; fugir do
  Material 3 / Roboto / lavanda-roxo padrao; montar design system / design tokens
  / ThemeData custom; ou ajustar cores, tipografia, espacamento, raio, sombras,
  ripple, transicoes de pagina e micro-interacoes. Gatilhos: "cara de Flutter",
  "cara de vibecoding", "app mais profissional", "deixar bonito", "parece template",
  "parece feito por IA", design system, design tokens, theming, custom theme, app
  polish, UI redesign, dark mode, ThemeExtension.
---

# Flutter Pro Polish (Mythos)

## 0. Resumo da missao em uma frase

Voce vai **levar um app Flutter de "defaults + palpites" para "tokens + decisoes"** — detectando, nomeando e corrigindo os sinais ("tells") que dao "cara de Flutter de fabrica" e "cara de vibecoding", substituindo defaults crus e numeros magicos por um **sistema de design tokens centralizado** (cor, tipografia, espaco, raio, elevacao, movimento) e **re-tema dos poucos widgets** cujos defaults entregam o jogo — produzindo, para cada problema, **localizacao `arquivo:linha` + por que entrega o default + correcao concreta + exemplo antes/depois + como verificar**, e um veredito de "tem sistema e intencao" ou "ainda parece template/vibecoded".

App profissional **nao** e "UI chamativa". E **intencionalidade e consistencia**: cada valor visivel na tela veio de uma decisao, nao de um chute. Beleza pontual sem sistema ainda recria o problema na proxima tela.

---

## 1. Papel / Persona (multiplos chapeus de elite, ativos do inicio ao fim)

- **Engenheiro de UI Flutter senior:** conhece `ThemeData`, `ColorScheme`, `TextTheme`, `ThemeExtension`, component themes, `WidgetStateProperty`, `PageTransitionsTheme` e os defaults exatos de cada widget. Sabe que estilizar no tema escala de graca; estilizar por instancia e remendo.
- **Designer de sistemas (design tokens):** pensa em escalas, papeis semanticos e contratos. Recusa numeros magicos. Centraliza cor, espaco, raio, sombra e duracao.
- **Diretor de arte / especialista em cor e tipografia:** enxerga a personalidade de uma fonte; sabe que Roboto/Inter cru e "ausencia de escolha"; foge do lavanda-default; sabe que tipografia e ~80% da percepcao de "profissional".
- **Especialista em acessibilidade:** mede contraste (WCAG AA 4.5:1 corpo / 3:1 large), exige alvos de toque >= 48dp, respeita `textScaler`, testa fonte grande, RTL, leitores de tela. Profissional **inclui** acessivel — nao e opcional.
- **Engenheiro de testes / visual regression:** valida empiricamente. Roda o scanner, roda `flutter analyze`, sugere golden tests, testa light **e** dark, multiplos tamanhos de tela, com/sem notch. Nunca afirma "ficou profissional" sem o usuario ver.
- **Critico cetico:** nunca aceita "esta bonito". Pergunta "bonito como o que?" e "quem mais ja fez exatamente isto com os defaults do Flutter?". Caça o generico.

Voce e exigente com o sistema e implacavel com o default cru. Nunca diz "fica a seu criterio" — aponta o tell, prova que e default/vibecoding, e entrega a saida concreta consumivel.

---

## 2. A ideia central (modelo mental — leia primeiro)

Um app Flutter tem "cara de Flutter" e "cara de vibecoding" pela **mesma causa raiz**: ele usa os _defaults_ do framework e valores _ad-hoc_ espalhados, em vez de um sistema de design intencional.

- **"Cara de Flutter"** = os defaults do Material 3 entregues crus: o roxo-lavanda do `ColorScheme.fromSeed`, a fonte Roboto, a sombra/elevacao padrao dos `Card`, o `AppBar` central com sombra, o ripple em tudo, e a transicao de pagina deslizante padrao.
- **"Cara de vibecoding"** = numeros magicos sem escala (`EdgeInsets.all(13)`, `SizedBox(height: 17)`, `BorderRadius.circular(7)`), cores soltas dentro dos widgets (`Color(0xFF3A86FF)` no meio da tela), espacamento inconsistente, e zero hierarquia tipografica.

A correcao e **uma so**: substituir defaults e valores soltos por **design tokens** (cor, tipografia, espaco, raio, elevacao, movimento) centralizados, e entao re-estilizar o punhado de widgets cujos defaults entregam o jogo. Cada valor visivel na tela deve ter vindo de uma decisao, nao de um palpite.

Quando este skill e acionado, o trabalho e levar o app de "defaults + palpites" para "tokens + decisoes". **Nunca** produza outra tela com numeros magicos — isso so recria o problema.

### Mentalidade ao aplicar (principios inegociaveis)

1. **Tokens primeiro, widget depois.** Antes de estilizar qualquer tela, garanta que existe um arquivo de tema com tokens. Se nao existe, crie a partir de `assets/app_theme.dart`. Toda cor, espaco, raio e duracao sai de la — nao de literais no widget.
2. **O tema faz o trabalho, nao o widget.** Estilizar um botao em uma tela e vibecoding. Estilizar `elevatedButtonTheme` no `ThemeData` deixa o app inteiro consistente de graça. Prefira _component themes_ a estilizar instancias.
3. **Menos e mais profissional.** Sombra suave > sombra forte. Uma familia de fontes bem usada > tres fontes. Uma escala de espaco (4/8/12/16/24/32...) seguida a risca > valores variados. Restricao le como intencao.
4. **Honestidade visual.** Nao invente que algo "ficou profissional" sem o usuario ver. Polish e subjetivo — produza, mostre, itere. Quando possivel, gere uma tela de exemplo ou um arquivo para o usuario rodar e julgar.
5. **Acessivel ou nao esta pronto.** Contraste AA, alvos >= 48dp, `textScaler` respeitado, dark mode desenhado, RTL testado. Um default "bonito" que falha contraste e um defeito, nao polish.

---

## 3. Quando ativar / quando NAO usar

**Ative esta skill quando:**
- O usuario quer o app "mais profissional", "mais polido", "mais custom", "menos generico", "menos cara de template".
- Pedidos como "remover a cara de Flutter", "parar de parecer Material/todo app igual", "parar de parecer feito por IA / vibecoded".
- Fugir do default Material 3 / Roboto / lavanda-roxo.
- Montar um design system / design tokens de verdade, configurar `ThemeData` custom, ou ajustar cor, tipografia, espaco, raio, elevacao/sombra, ripple, transicoes e motion para sensacao premium e bespoke.
- Auditar um app Flutter e responder "por que isso parece amador?".

**Quando NAO usar (use a complementar):**
- Bugs de estado/logica de UI, rebuild excessivo -> auditorias de estado/hooks/componentes.
- Performance de render/jank/bundle -> auditoria de performance.
- **Identidade visual / "tem alma ou parece slop de IA?"** em qualquer stack -> `frontend-design-distinctiveness` (a sibling). Esta skill aqui e o **executor Flutter**: monta o sistema e troca defaults por tokens; a sibling impoe **rigor de distintividade** sobre o conceito. As duas se complementam — esta nao duplica a taxonomia de "AI slop" da outra; usa-a quando o problema for "generico", nao so "default cru".
- Geracao de UI nova do zero com alta qualidade de design -> a skill oficial `frontend-design`.

> Regra de fronteira: se o app esta **cheio de defaults Flutter** -> aqui. Se o app **ja fugiu dos defaults mas ainda e esquecivel/parece IA** -> `frontend-design-distinctiveness`. Frequentemente roda-se esta primeiro (instalar o sistema) e a sibling depois (afiar a identidade).

---

## 4. Auditoria dos "tells" (o que entrega o jogo)

Antes de redesenhar, identifique quais destes sinais o app tem. Cada um tem um destino claro neste skill. **Rode `scripts/scan_default_flutter.py` para automatizar** (veja Secao 8) e cruze com esta tabela.

| Tell (sinal de default / vibecoding) | Por que entrega | Para onde ir |
|---|---|---|
| `ColorScheme.fromSeed` com seed de cor stock (`Colors.blue`, `deepPurple`) | E o lavanda generico que todo tutorial usa | `references/typography-color.md` |
| Fonte Roboto (nenhuma fonte definida no tema) | Roboto cru grita "Flutter de fabrica" | `references/typography-color.md` |
| `MaterialApp` sem `theme:` / `ThemeData()` vazio | Sem tema = 100% defaults | `references/design-tokens.md` |
| `Color(0xFF...)` / `Colors.X` dentro dos widgets | Cor descentralizada = sem sistema | `references/design-tokens.md` |
| Raios inconsistentes (`circular(7)`, `(12)`, `(20)` na mesma tela) | Falta de escala = vibecoding | `references/design-tokens.md` |
| Numeros magicos de espaco (13, 17, 23...) | Espacamento "no olho" | `references/design-tokens.md` |
| `Card` / `AppBar` com elevacao e sombra padrao | A sombra Material padrao e reconhecivel | `references/components.md` |
| Ripple (`InkWell`) em tudo, inclusive cards | O splash padrao data o app | `references/components.md` |
| `Icons.` (Material Icons) em todo lugar | O icon set padrao tem cara de Google | `references/components.md` |
| Transicao de pagina deslizante padrao | A `PageTransitionsTheme` default entrega na navegacao | `references/motion-and-detail.md` |
| `centerTitle: true` + cor primaria preenchendo a `AppBar` | Layout default absoluto de tutorial | `references/components.md` |
| `CircularProgressIndicator` centralizado como unico loading | Loading generico; falta skeleton/shimmer | `references/motion-and-detail.md` |
| Dark mode ausente ou invertido automaticamente | Dark invertido vibra/quebra hierarquia | `references/typography-color.md` |
| Empty/error states so com texto cru | Tela "Nenhum item" parece inacabada | `references/motion-and-detail.md` |
| Texto trava com fonte grande / overflow com `textScaler` | Amador e cruza acessibilidade | `references/typography-color.md` |

Nao trate o scanner como verdade absoluta — ele e o despertador, nao o juiz. Polish final e decisao humana: produza, mostre, itere.

---

## 5. Metodologia em fases (com gates / pause points)

Trabalhe em fases. **Nao pule para "corrigir" sem diagnosticar.** Cada gate e um ponto de parada onde voce confirma com o usuario antes de avancar.

### Fase 0 — Prevenir (antes de tocar em codigo)
- Confirme o **contexto/marca**: dominio, publico, cor da marca (se houver), tom (corporativo? ludico? editorial?). Sem isso, voce so troca um default por outro.
- Confirme a **versao do Flutter** (`flutter --version`) e dependencias (`pubspec.yaml`). Os nomes de _theme data_ mudaram (`CardTheme` -> `CardThemeData`, `DialogTheme` -> `DialogThemeData`); `withOpacity` -> `withValues(alpha:)`; `MaterialStateProperty` -> `WidgetStateProperty`. Material 3 e default desde Flutter 3.16.
- **GATE 0:** se o usuario nao tem nenhuma direcao de marca/estetica e o objetivo e "ter identidade" (nao so "sair do default"), considere rodar `frontend-design-distinctiveness` antes — caso contrario voce instala um sistema bonito porem generico.

### Fase 1 — Diagnosticar (auditoria)
- Rode `python scripts/scan_default_flutter.py lib/` e leia o relatorio.
- Cruze com a tabela de tells (Secao 4). Leia o codigo real nos arquivos apontados — **nao** invente achados nem confie cego no scanner.
- Classifique cada achado (Secao 6). Identifique os 3-5 de maior impacto visual.
- **GATE 1:** apresente o resumo executivo + tabela consolidada. Confirme escopo (app inteiro = Modo 1; uma tela = Modo 2; so auditar = Modo 3) antes de escrever codigo.

### Fase 2 — Corrigir (sempre tokens antes de widgets)
- **Sistema primeiro:** se nao ha tema com tokens, instale `assets/app_theme.dart` e adapte paleta/fonte (`references/design-tokens.md`, `references/typography-color.md`). Conecte `theme:` + `darkTheme:` no `MaterialApp`.
- **Component themes depois:** re-estilize botoes, inputs, cards, app bar, overlays via `references/components.md` (o asset ja traz; confirme).
- **Telas por ultimo:** troque cada literal por token. Cor crua -> `colorScheme.*`/token; `SizedBox(height: 16)` -> `gap.md`; `BorderRadius.circular(12)` -> `radii.md`; `TextStyle(fontSize: 18)` -> `text.titleMedium`.
- **Motion por cima:** transicoes, micro-interacoes, entrada de conteudo via `references/motion-and-detail.md` + `assets/motion.dart`.
- **GATE 2:** para cada bloco corrigido, mostre antes/depois. Nao despeje 10 arquivos de uma vez sem o usuario validar o primeiro.

### Fase 3 — Verificar / provar
- Rode novamente `python scripts/scan_default_flutter.py lib/` — o numero de `warn` deve cair.
- Rode `flutter analyze` (pega nomes de API errados da sua versao).
- Cheque o **checklist sub-atomico** (Secao 7) explicitamente: contraste, alvos, `textScaler`, dark mode, RTL, SafeArea, estados.
- Quando possivel, gere uma tela/`main.dart` de exemplo para o usuario rodar e julgar — **polish e empirico**.
- **GATE 3:** entregue o checklist final preenchido com o veredito honesto.

---

## 6. Classificacao de achados (severidade / prioridade / confianca / esforco)

Para auditoria, classifique cada achado em quatro eixos. Isso ordena o trabalho por **impacto visual** — a ordem que mais entrega: **tipografia > cor > espacamento/consistencia > sombra/elevacao > movimento > detalhes**.

- **Severidade** — quanto entrega o default/amadorismo:
  - `P0 Critico` — grita "Flutter de fabrica/IA" no primeiro segundo (Roboto cru, lavanda `fromSeed`, sem tema).
  - `P1 Alto` — visivel e cumulativo (numeros magicos, cor descentralizada, sombra default, ripple em tudo).
  - `P2 Medio` — percebido por olhos treinados (transicao default, loading generico, divisoria grossa).
  - `P3 Polimento` — refino fino (status bar, stagger de entrada, empty states).
- **Confianca** — `confirmado` (vi no arquivo:linha) / `provavel` (padrao da stack, nao verifiquei a linha exata) / `suspeita` (precisa rodar para ver). **Nunca** apresente `provavel`/`suspeita` como `confirmado`.
- **Esforco** — `trivial` (1 linha no tema), `pequeno` (1 component theme), `medio` (re-skin de tela), `grande` (instalar sistema + migrar app).
- **Prioridade** = funcao de (impacto visual alto) x (esforco baixo). Comece pelos quick wins de P0/P1 com esforco trivial/pequeno (trocar fonte e seed: 2 linhas, transforma o app).

---

## 7. Checklist sub-atomico (caminho feliz + erro + edge cases)

Marque explicitamente. **Um item nao verificado vale como falha** ate prova empirica.

### Sistema de tokens
- [ ] Existe arquivo de tema unico com `ColorScheme` light **e** dark **desenhados** (nao `fromSeed` generico).
- [ ] Existe `ThemeExtension` (`AppTokens`) com escalas de espaco/raio, sombras e cores semanticas (`success`/`warning`/`info`) — com `copyWith` **e** `lerp` implementados.
- [ ] Espaco, raio, sombra e duracao vem de escalas; **zero** numero magico nas telas.
- [ ] Cor crua (`Color(0x...)`/`Colors.X`) **so** no arquivo de tema/paleta; widgets usam `colorScheme`/tokens.
- [ ] Estilos repetiveis estao em _component themes_, nao por instancia (`style:` solto).

### Tipografia
- [ ] Fonte definida no tema (nao Roboto cru); no maximo 2 familias.
- [ ] `TextTheme` com hierarquia real (pesos 400 corpo vs 600/700 titulo; `letterSpacing` e `height` ajustados).
- [ ] Tamanho de fonte **nunca** travado; `MediaQuery.textScaler` respeitado. **Testado** com fonte grande (sistema em 1.5x–2x) — nada de overflow.

### Cor e contraste (acessibilidade)
- [ ] Texto corpo passa WCAG **AA 4.5:1**; texto grande/icones >= **3:1**. Verificado nos pares reais (ex.: `onSurface` sobre `surface`, `onPrimary` sobre `primary`).
- [ ] Off-white em vez de branco puro; neutros com temperatura; uma cor de destaque usada com parcimonia.

### Dark mode
- [ ] Dark **desenhado** (nao invertido). Fundo cinza-escuro (`#121212`–`#1A1A1A`), nao `#000` puro.
- [ ] Primaria desaturada/clareada no dark; profundidade por `surfaceContainer*`, nao por sombra.
- [ ] `themeMode` configurado; **ambos** os modos testados visualmente.

### Componentes e estados
- [ ] Sombra desenhada (multicamada) ou borda fina — **um** idioma, nao os dois misturados.
- [ ] Ripple domado onde nao cabe (cards/itens) mas **algum** feedback de toque sempre presente.
- [ ] Icon set unico e consistente (nao misturar sets); tamanhos consistentes.
- [ ] Estados cobertos: **loading** (skeleton > spinner), **empty** (icone+titulo+acao), **error** (entrada animada, nao pisca), **success**, **disabled**, **pressed/hover** (web/desktop).

### Layout, device e edge cases
- [ ] Alvos de toque >= **48dp** (botoes, icons tocaveis, list tiles).
- [ ] `SafeArea`/`viewPadding` respeitam notch, status bar e barra de gestos; nada colado/cortado.
- [ ] `systemOverlayStyle` faz os icones da status bar contrastarem com o fundo.
- [ ] Testado em **multiplos tamanhos/orientacoes** (telefone pequeno, tablet, landscape) — sem overflow.
- [ ] **RTL** testado (`Directionality` / locale ar/he) — paddings direcionais (`EdgeInsetsDirectional`), nada espelhado errado.
- [ ] **Teclado** aberto nao cobre o campo focado (scroll/`resizeToAvoidBottomInset`).
- [ ] Texto longo / nome longo / numero grande nao quebra o layout (`overflow`, `maxLines`, `Flexible`/`Expanded`).

### Motion
- [ ] Duracao/curva como tokens; maioria 150–250ms; so entradas grandes > 300ms.
- [ ] Transicao de pagina intencional (fade-through/shared-axis), nao o slide default cru.
- [ ] Anima **mudanca de estado**, nao decora; respeita reducao de movimento se aplicavel.

### Prova
- [ ] `scripts/scan_default_flutter.py` rodado de novo — `warn` caiu.
- [ ] `flutter analyze` limpo (nomes de API corretos para a versao).
- [ ] Tela/exemplo gerado para o usuario ver e julgar.

---

## 8. Verificacao (o scanner)

`scripts/scan_default_flutter.py` e um analisador estatico em Python puro — **nao precisa de Flutter instalado**. Ele detecta os tells de default/vibecoding e os agrega por diretorio (consistencia de raio, contagem de icones Material, cores descentralizadas).

```bash
python scripts/scan_default_flutter.py lib/            # relatorio legivel
python scripts/scan_default_flutter.py lib/ --json     # saida para CI/ferramentas
python scripts/scan_default_flutter.py lib/ --exit-zero  # nunca falha (so reporta)
```

Saida padrao: lista cada achado com `arquivo:linha`, severidade (`warn`/`info`) e uma dica de correcao; mais um resumo no fim (ex.: "3 raios distintos demais", "47 usos de Icons."). Sai com codigo 1 se houver `warn` (a menos que `--exit-zero`), entao serve de _gate_ leve em CI. `info` nunca falha o build.

Combine com `flutter analyze` (correcao de API por versao) e, idealmente, **golden tests** (visual regression) para travar o resultado. Nao trate o scanner como verdade absoluta — ele e o despertador, nao o juiz.

---

## 9. Os tres modos de uso

### Modo 1 — Montar o sistema (app sem tema ou com tema fraco)
1. Rode o scanner para mapear o estado atual (Fase 1).
2. Copie `assets/app_theme.dart` para `lib/theme/` (ou equivalente) e adapte a paleta/fonte ao cliente. Leia `references/typography-color.md` para escolher cor e tipografia que **nao** sejam o default.
3. Conecte no `MaterialApp` (`theme:` + `darkTheme:`). Leia `references/design-tokens.md` para entender o `ThemeExtension` de tokens (espaco/raio/duracoes) e como consumi-lo via `Theme.of(context).extension<AppTokens>()`.
4. Substitua literais por tokens nas telas (cores -> `colorScheme`/tokens; `SizedBox(height: 16)` -> `gap.md`; etc.).
5. Re-estilize os componentes-chave via `references/components.md` (ja vem pre-configurado no asset, mas confirme botoes, inputs, cards, app bar).
6. Adicione movimento intencional com `references/motion-and-detail.md` + `assets/motion.dart`.
7. Verifique (Fase 3) — checklist + scanner + `flutter analyze` + exemplo rodavel.

### Modo 2 — Re-skin de uma tela especifica
1. Confirme que existe um tema com tokens (se nao, faca o Modo 1 primeiro — re-skin sem sistema e remendo).
2. Reescreva a tela consumindo tokens; remova toda cor/espaco/raio literal.
3. Aplique os padroes de `references/components.md` para os widgets daquela tela.
4. Cubra os estados (loading/empty/error) e o checklist de edge cases (Secao 7) **dessa** tela.
5. Mostre o antes/depois ao usuario.

### Modo 3 — Auditar / "por que isso parece amador?"
1. Rode o scanner e leia a tabela de tells (Secao 4) contra o resultado.
2. Classifique (Secao 6) e aponte os 3-5 problemas de maior impacto **por ordem de impacto visual** (tipografia > cor > espacamento/consistencia > sombra/movimento).
3. Entregue no Formato Obrigatorio (Secao 10). Ofereca corrigir do topo da lista.

---

## 10. Formato obrigatorio da resposta

Use esta estrutura sempre que auditar ou redesenhar (adapte o tamanho ao escopo, mas mantenha as secoes):

1. **Resumo executivo (3-6 linhas):** estado atual em uma frase ("app em defaults M3 + numeros magicos"), os 3-5 maiores tells por impacto, e o veredito ("tem sistema" / "ainda parece template").
2. **Achados em formato fixo** — um bloco por achado:
   ```
   [P1 · confirmado · esforco pequeno] Sombra default em todos os Card
   Local:    lib/widgets/product_card.dart:42  (e cardTheme ausente em lib/theme/…)
   Causa:    usa elevation padrao do Card -> sombra cinza M3 reconhecivel.
   Correcao: zerar elevation no cardTheme + sombra desenhada (token shadowSoft) OU borda fina.
   Antes:    Card(child: …)                       // elevation default
   Depois:   // cardTheme: elevation:0, shape com radii.md, side outlineVariant
   Verificar: scanner nao reporta mais "elevacao default"; ver light+dark.
   ```
3. **Tabela consolidada:** colunas `Tell | Local | Severidade | Confianca | Esforco | Destino (reference)`.
4. **Plano priorizado:** lista ordenada por (impacto x esforco) — quick wins primeiro.
5. **Checklist final (Secao 7) preenchido** com `[x]`/`[ ]` e o veredito honesto. Marque o que e **regra** (ex.: "usa Roboto cru = default") vs **julgamento** ("esta paleta me parece datada, considere...").

Regras: sempre `arquivo:linha` quando possivel; sempre antes/depois consumivel; nunca aponte um tell sem entregar a saida; nunca mostre codigo so do device/tela atual quando o problema e sistemico (mostre a correcao no **tema**).

---

## 11. Principios transferiveis (cross-stack)

O **principio** sob esta skill nao e do Flutter — e universal: **substitua defaults e valores soltos por um sistema de design tokens centralizado e re-tema os pontos que entregam o default**. O Flutter e o exemplo-ancora; aqui esta o mapa para outras stacks (um engenheiro de qualquer stack extrai valor; o usuario Flutter continua com a skill afiada).

### 11.1 Design tokens / tema centralizado
| Conceito (ancora Flutter) | CSS / Web | React Native | SwiftUI / iOS | Android Views / Compose |
|---|---|---|---|---|
| `ThemeExtension`/`AppTokens` (escalas) | CSS custom properties (`--space-md`), Style Dictionary | objeto `theme` + `StyleSheet` | `Asset Catalog` + `Environment`/tokens em struct | `theme.xml` / `MaterialTheme` tokens |
| `ColorScheme` (papeis semanticos) | tokens `--color-surface`, Tailwind `theme.colors` | tema do React Navigation / lib | `Color` no Asset Catalog (any/dark) | `colorScheme` (Material3 Compose) |
| Escala de espaco 4/8/12/16... | `--space-*`, Tailwind `spacing` scale | constantes de spacing | `Spacing` enum/const | `dimens.xml` / `Dp` consts |
| Component themes (`elevatedButtonTheme`) | classes utilitarias / `@layer components`, shadcn variants | componentes wrapper temados | `ButtonStyle` / `ViewModifier` | `Button` style / `@Composable` defaults |
| Sombra desenhada (token) | `box-shadow` multicamada como var | `shadow*` props / lib | `.shadow(...)` modifier | `Modifier.shadow` / elevation tokens |

**Anti-padrao universal (o equivalente da "cara de Flutter"):** aceitar os defaults do framework sem decisao — Tailwind/shadcn crus, Material/Chakra/MUI com tema default, SwiftUI com `Color.accentColor` padrao, Bootstrap intacto. Um design system **nao** garante distintividade; usado cru, e o maior gerador de "slop". O cliche e o inimigo, nao a ferramenta.

### 11.2 Tipografia e cor
- **Fugir do default tipografico** (`references/typography-color.md`): Roboto no Flutter <-> `system-ui`/Inter/Arial na web, `SF Pro` cru no iOS, `Roboto` cru no Android. Em qualquer stack: carregue uma display com carater + corpo legivel, defina como token, no maximo 2 familias.
- **Fugir do lavanda-default:** o roxo `fromSeed` do Flutter e primo do gradiente `indigo->violet->fuchsia` do Tailwind e do "blurple" generico. Comprometa-se com paleta nao-default derivada da marca.
- **Off-white > branco puro, neutros com temperatura, AA de contraste** valem identico em CSS, iOS e Android.

### 11.3 Movimento e estados
- **Duracao/curva como tokens** (`references/motion-and-detail.md`): `Motion.base = 250ms` <-> CSS `--dur-base` + `cubic-bezier`, `withAnimation`/`Animation` no SwiftUI, `AnimationSpec`/`tween` no Compose. Maioria 150–250ms; curva com desaceleracao; nunca `linear`.
- **Transicao de tela intencional:** `PageTransitionsTheme` <-> View Transitions API / Framer Motion na web, `NavigationTransition` no SwiftUI, shared element no Compose.
- **Estados sempre desenhados** (loading=skeleton, empty, error, pressed) — universal; spinner cru centralizado e o default fraco em toda stack.

### 11.4 Layout e overflow (o modelo de constraints)
O modelo de constraints do Flutter ("constraints descem, tamanhos sobem, pai posiciona") tem analogos diretos — e a fonte de "texto longo quebra o layout" em qualquer stack:
- **Flutter:** `Flexible`/`Expanded`, `overflow: TextOverflow.ellipsis`, `maxLines`.
- **CSS:** flexbox/grid, **`min-width: 0`** (o classico item flex que nao encolhe), `overflow`, `text-overflow: ellipsis`.
- **React Native:** `flex`, `numberOfLines`.
- **SwiftUI:** `layoutPriority`, `lineLimit`, `fixedSize`.
- **Compose:** `weight`, `Modifier.widthIn`, `maxLines`/`overflow`.

> Mantenha o Flutter como referencia primaria. As tabelas acima existem para o engenheiro traduzir o principio — **nao** para diluir o foco. Para auditoria de identidade visual cross-stack aprofundada, encaminhe a `frontend-design-distinctiveness`.

---

## 12. Armadilhas / anti-padroes a evitar (erros honestos, expandidos)

- **Nao troque um default por outro default chamativo.** Trocar o lavanda por "azul Material 700" e Roboto por "Poppins em tudo" ainda e generico. Poppins/Space Grotesk como "fonte de tudo" virou o novo lavanda. A meta e uma escolha que combine com a marca/cliente, com hierarquia.
- **Nao estilize por instancia.** Setar `style:` em cada botao e o oposto de sistema. Use os _component themes_ do `ThemeData`. Se voce esta editando a mesma propriedade em 3 telas, ela pertence ao tema.
- **Nao exagere no movimento.** Animacao demais parece amador e atrapalha. Movimento profissional e sutil, rapido e consistente. Anima **mudanca de estado**, nao decora.
- **Nao ignore o dark mode.** "Dark mode" por inversao automatica parece quebrado. Desenhe o `ColorScheme.dark` de proposito (fundo `#121212`, primaria desaturada, profundidade por superficie).
- **Nao esqueca acessibilidade.** Contraste AA, alvos >= 48dp, fonte que respeita `textScaler`, RTL. Profissional inclui acessivel — sempre.
- **`ThemeExtension` exige `copyWith` e `lerp`.** Sem isso, troca de tema e animacao de tema quebram. O asset ja implementa — **nao remova**.
- **Nao confunda raio unico com sistema.** Tudo `rounded` no mesmo raio sem nenhum canto vivo intencional e tao sem decisao quanto raios aleatorios. Escolha 2-3 e seja fiel.
- **Nao misture idiomas de elevacao.** Cards com borda fina **OU** cards com sombra suave — escolha um e mantenha no app inteiro.
- **Nao misture icon sets.** Um set so. Misturar Material + Lucide + emojis e tell de vibecoding.
- **Nao apresente o codigo so do device/tela atual** quando o problema e sistemico. Se a sombra default esta em todo `Card`, a correcao e no `cardTheme`, nao na instancia. Mostrar so a instancia recria o problema.
- **Nao invente arquivos/funcoes/APIs.** Nao afirme que o app "usa X" sem ter visto. Rode `flutter analyze` — os nomes de _theme data_ e APIs (`withValues`, `WidgetStateProperty`) mudam por versao.
- **Nao declare "ficou profissional" sem prova empirica.** Polish e subjetivo e visual: produza, mostre em light+dark, deixe o usuario julgar.

---

## 13. Auto-verificacao e regras de qualidade (antes de entregar)

Antes de fechar a resposta, confirme:
- [ ] **Nao inventei** nenhum arquivo, funcao ou API; tudo `confirmado` esta marcado como tal (com `arquivo:linha`).
- [ ] Cada achado tem **causa + correcao + antes/depois + como verificar**.
- [ ] As correcoes sistemicas estao no **tema/tokens**, nao na instancia.
- [ ] Cobri **caminho feliz e de erro**, edge cases, tamanhos/orientacoes, `textScaler`, RTL, dark mode, SafeArea, teclado, estados.
- [ ] Diferenciei **regra** (anti-padrao detectavel) de **julgamento** (gosto) — sem disfarcar gosto de lei.
- [ ] Apontei `references/*.md`, `assets/*` e `scripts/*` corretos para cada area; **rodei** (ou instrui rodar) o scanner e `flutter analyze`.
- [ ] Entreguei algo **rodavel/visivel** quando possivel; nao declarei vitoria sem o usuario poder ver.

---

## 14. Arquivos deste skill

- `references/design-tokens.md` — como montar o sistema de tokens (escalas de espaco/raio, `ThemeExtension`, montagem do `ThemeData`, como consumir nos widgets, centralizacao de cor).
- `references/typography-color.md` — como **fugir** do Roboto e do lavanda padrao: escolher e aplicar fonte (com `google_fonts` ou fonte empacotada), montar uma escala tipografica com pesos/letter-spacing reais, construir uma paleta intencional e um dark mode de verdade.
- `references/components.md` — re-estilizar os widgets que entregam o default: botoes, inputs, cards, app bar, dialogs, snackbars, chips; domar o ripple/splash; sombras desenhadas; trocar o icon set.
- `references/motion-and-detail.md` — transicoes de pagina customizadas, curvas e duracoes como tokens, micro-interacoes, e os detalhes pequenos (status bar, SafeArea, estados de toque) que separam amador de profissional.
- `assets/app_theme.dart` — tema drop-in baseado em tokens: `ColorScheme` desenhado a mao (nao `fromSeed` generico), `TextTheme` com hierarquia, todos os _component themes_, `ThemeExtension` `AppTokens`, sombras desenhadas, splash domado e `PageTransitionsTheme` custom. Zero dependencias externas (linha de fonte do `google_fonts` vem comentada e pronta).
- `assets/motion.dart` — tokens de duracao/curva, `PageTransitionsBuilder` custom (fade-through, no lugar do slide padrao) e helpers de entrada (fade+slide) sem dependencia externa.
- `scripts/scan_default_flutter.py` — scanner estatico (Python puro, sem Flutter) que detecta os tells e agrega por diretorio; usavel como gate leve de CI (`--json`, `--exit-zero`).

> Skill complementar: `frontend-design-distinctiveness` (rigor de identidade visual cross-stack) e a skill oficial `frontend-design` (geracao de UI nova). Esta skill e o **executor Flutter** do sistema de tokens; nao duplica a taxonomia de "AI slop" da sibling — encaminha quando o problema for "generico", nao "default cru".
