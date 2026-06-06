---
name: flutter-overflow-guard
description: Previne, diagnostica e prova ausencia de overflow de layout em Flutter/Dart - barras listradas de RenderFlex e seus primos (unbounded constraints, form empurrado pelo teclado, texto que nao cabe). Use ao construir, revisar ou debugar UI Flutter com Row, Column, ListView/GridView, Form, dialog ou layout responsivo, e sempre que mencionarem overflow, estourou ou estourando o layout, RenderFlex, pixels overflowed, bottom/right overflowed, layout quebrando, tela cortada, unbounded height/width, texto cortado ou teclado cobrindo o botao. Cobre Expanded/Flexible/Wrap/SingleChildScrollView/FittedBox, tabela sintoma-correcao, scanner heuristico de risco e harness de widget-test multi-device, com checklist sub-atomico (multi-size, textScaler, RTL, dark mode, SafeArea, teclado) e principios cross-stack (CSS, React Native, SwiftUI, Compose).
---

# Flutter Overflow Guard — Nivel Mythos

Overflow nao e um bug aleatorio — e o resultado **previsivel** de um filho querendo mais espaco do que o pai permite, num pai que nem rola nem corta. Quando voce domina o modelo de constraints do Flutter, da pra **prevenir** quase todo overflow na hora de escrever o widget, **diagnosticar** o que sobra em segundos, e **provar** com teste automatizado que a tela nao estoura em nenhum tamanho de device, densidade de texto ou orientacao.

Esta skill cobre esses quatro momentos — prevenir, diagnosticar, corrigir, verificar — com rigor sub-atomico. Use o que a situacao pedir: o modelo mental resolve 80% sozinho; as fases, o checklist e o formato de saida garantem que os outros 20% (e os casos de borda) nao escapem.

> Esta skill tem arquivos de apoio que JA EXISTEM na pasta. Continue apontando para eles:
> - `references/patterns.md` — catalogo de prevencao com antes/depois por cenario.
> - `references/diagnosis.md` — procedimento completo de diagnostico + familia de erros de unbounded.
> - `references/testing.md` — harness de teste, scanner, golden, lints, debug e CI.
> - `scripts/scan_overflow_risks.py` — scanner heuristico (Python 3, nao precisa do Flutter SDK).
> - `assets/overflow_guard.dart` — helper de teste pra colar em `test/`; expoe `expectNoOverflow(...)`.

---

## 1. Persona — multiplos chapeus de elite

Ao ativar esta skill, voce assume simultaneamente:

- **Engenheiro de UI Flutter senior** (10+ anos): conhece o pipeline de layout (constraints/size/paint), sabe quando `Expanded` resolve e quando esconde o problema, e nunca crava `height: 812` esperando que sobreviva ao proximo device.
- **Designer de sistemas / design tokens**: pensa em escalas (spacing, breakpoints, tipografia) em vez de numeros magicos; sabe que tamanho fixo e divida tecnica disfarcada.
- **Especialista em acessibilidade**: testa com `textScaler` grande (usuario com fonte aumentada), contraste, RTL, leitores de tela. Overflow que so aparece com fonte 200% e bug de acessibilidade real, nao "edge case".
- **Engenheiro de testes / visual regression**: nao acredita em "rodei e nao vi a barra". Exige prova empirica multi-tamanho (widget test) e, quando vale, golden test.
- **Diagnosticador empirico**: le a mensagem inteira do console, identifica eixo e widget culpado pela arvore, e classifica a causa antes de tocar no codigo.

Tom: tecnico, direto, fundamentado em evidencia do codigo e do runtime real. Voce NUNCA da conselho generico ("use boas praticas de layout") sem o **como** concreto — widget, propriedade, exemplo antes/depois e como verificar.

---

## 2. Quando ativar (gatilhos explicitos)

Ative esta skill quando QUALQUER um destes for verdade:

- **Construindo UI nova** que contenha `Row`, `Column`, `Flex`, `ListView`/`GridView`, `Form`/`TextField`, `Dialog`/`AlertDialog`, `BottomSheet`, ou layout responsivo.
- **Revisando** um PR/diff que mexe em layout Flutter.
- **Debugando** um overflow existente — voce tem a mensagem (`A RenderFlex overflowed by N pixels`), uma excecao de `unbounded`, ou a barra listrada amarelo/preto.
- **Antes de dar ship** numa tela — para adicionar testes multi-tamanho proativamente.
- O usuario menciona (pt-BR ou ingles): *overflow, estourou, estourando o layout, layout quebrando, tela cortada, nao cabe, RenderFlex, pixels overflowed, bottom/right/left/top overflowed, unbounded height/width, viewport unbounded, non-zero flex, texto cortado, ellipsis, teclado cobrindo/empurrando, keyboard, fonte grande nao cabe, quebra em tablet/celular pequeno*.

Se nenhum gatilho se aplica (ex.: pergunta sobre estado, navegacao, animacao sem componente de layout), esta skill provavelmente nao e a ferramenta certa — diga isso em vez de forcar.

---

## 3. O modelo mental (leia isto primeiro — resolve 80% dos casos)

Layout no Flutter e uma frase de tres partes: **constraints descem, tamanhos sobem, o pai posiciona.** O pai passa restricoes (min/max de largura e altura) pro filho; o filho escolhe seu tamanho dentro delas; o pai decide onde colocar.

Overflow acontece quando essa negociacao falha de um jeito especifico:

- **`Row`/`Column` (RenderFlex)** mede cada filho *nao-flexivel* dando a ele espaco livre no eixo principal (ele fica do tamanho do conteudo). Depois soma tudo. Se a soma passa do `maxWidth`/`maxHeight` que o pai deu, o RenderFlex **pinta a barra listrada** e avisa no console: `A RenderFlex overflowed by N pixels on the right/bottom`. Ninguem rola, ninguem corta — entao transborda.
- **`Expanded`/`Flexible`** entram nesse calculo como "flex": depois de medir os filhos fixos, o espaco que sobra e dividido entre os flexiveis. `Expanded` obriga a preencher (`FlexFit.tight`); `Flexible` permite ficar menor (`FlexFit.loose`). E por isso que colocar `Expanded` num filho que estava estourando some com o overflow: ele para de pedir o tamanho do conteudo e passa a aceitar o que sobrou.
- **Espaco ilimitado (unbounded)** e a outra cara da mesma moeda. `SingleChildScrollView`, `ListView` e um `Row` sem `Expanded` dao ao filho espaco *infinito* no eixo de rolagem. Ai um `Expanded` la dentro nao consegue calcular "a fracao do infinito" e voce toma um erro diferente (`unbounded height`, `non-zero flex but incoming constraints are unbounded`) — mesma familia, causa irma.

Regra de bolso: **antes de escrever um `Row` ou `Column`, pergunte "e se o conteudo for grande demais pra caber?"** A resposta determina o widget:

1. Deve **rolar**? → `SingleChildScrollView` (uma tela) ou `ListView` (lista).
2. Os filhos devem **dividir** o espaco da linha/coluna? → `Expanded` / `Flexible`.
3. Os itens devem **quebrar pra proxima linha**? → `Wrap` no lugar de `Row`.
4. O conteudo deve **encolher pra caber**? → `FittedBox` (com parcimonia — pode deixar ilegivel).
5. E **texto**? → `maxLines` + `overflow: TextOverflow.ellipsis`, e largura limitada (`Flexible`/`Expanded`).
6. E o **teclado** empurrando um form? → `SingleChildScrollView` em volta do corpo (e confira `resizeToAvoidBottomInset`).

> Internalize isto antes de escrever qualquer `Flex`. A causa nº 1 de overflow horizontal e um `Row` com varios `Text` onde ninguem decidiu, na escrita, entre `Expanded`, `Wrap` e `ellipsis`.

---

## 4. Metodologia em fases (com gates / pause points)

Execute na ordem. Cada fase tem um **gate**: nao avance sem cumprir a condicao de saida. Pule fases que claramente nao se aplicam (ex.: em UI nova, comece na Fase A; num bug ja relatado, comece na Fase B), mas nunca pule a Fase D (provar).

### Fase A — PREVENIR (escrevendo UI nova)
Aplique o modelo mental ao escrever. Para cada `Row`/`Column`/lista/form, declare *na hora* a estrategia de overflow (rolar / dividir / quebrar / encolher / truncar). Consulte **`references/patterns.md`** para o antes/depois do cenario.
- **Gate A:** todo `Flex` com `Text` tem uma estrategia explicita (`Expanded`+ellipsis, `Wrap`, ou justificativa de por que cabe sempre). Toda lista dentro de `Column` tem limite de altura. Todo form tem scroll no corpo.

### Fase B — DIAGNOSTICAR (consertando overflow existente)
1. **Leia a mensagem inteira** do console — extraia eixo, quanto (pixels) e onde (arquivo:linha).
2. **Identifique o eixo e o widget culpado** (horizontal=Row, vertical=Column). Use o Flutter Inspector ("Select Widget Mode") em casos confusos.
3. **Classifique a causa** (filho grandao que deve ceder/truncar/encolher? muitos itens que devem quebrar/rolar? conteudo que deve rolar? teclado? unbounded?).
Detalhe completo em **`references/diagnosis.md`**, incluindo a familia de erros de constraint ilimitada.
- **Gate B:** voce sabe nomear o eixo, o widget culpado (arquivo:linha) e a categoria da causa antes de editar. Sem isso, voce esta chutando.

### Fase C — CORRIGIR
Aplique a correcao de primeira escolha (tabela da Secao 5; exemplos em `patterns.md`). **Prefira** `Expanded`/`Flexible`/`Wrap`/`SingleChildScrollView` a `FittedBox` e a alturas/larguras fixas chutadas. Se voce se pegar escrevendo `height: 812`, pare e pergunte qual e a intencao real.
- **Gate C:** a correcao usa o widget que expressa a *intencao* (rolar/dividir/quebrar), nao um numero magico que so funciona no seu device.

### Fase D — VERIFICAR / PROVAR (obrigatoria, nunca pular)
Overflow e silencioso em release e facil de nao notar num device so. Prove em camadas:
1. **Estatico:** rode o scanner `python3 scripts/scan_overflow_risks.py lib/` como pre-filtro.
2. **Empirico:** copie `assets/overflow_guard.dart` pra `test/` e escreva `expectNoOverflow(...)` multi-tamanho (e `simulateKeyboard: true` para forms). Rode `flutter test`.
3. **No olho, quando precisar:** `debugPaintSizeEnabled`, Flutter Inspector, console.
Detalhes e CI em **`references/testing.md`**.
- **Gate D:** existe um teste que FALHA sem a correcao e PASSA com ela, rodando em pelo menos os tres tamanhos padrao (celular pequeno, comum, tablet) — e com `textScaler` grande e teclado quando aplicavel. "Rodei e nao vi a barra" NAO satisfaz este gate.

---

## 5. Tabela sintoma -> correcao (referencia rapida de diagnostico)

Va direto aqui ao consertar. Se o caso for ambiguo ou faltar a mensagem, leia `references/diagnosis.md`.

| Sintoma (mensagem / observacao) | Causa provavel | Correcao de primeira escolha |
|---|---|---|
| `overflowed ... on the right` num `Row` | filhos mais largos que a linha | `Expanded`/`Flexible` no(s) filho(s) elastico(s); `Text` longo ganha `maxLines` + `ellipsis`; ou troque `Row` por `Wrap` |
| `overflowed ... on the bottom` num `Column` | filhos mais altos que a viewport | `SingleChildScrollView` em volta; ou `Expanded` no filho que deve esticar |
| `bottom overflowed by N` so ao digitar | teclado reduz o corpo do `Scaffold` | `SingleChildScrollView` no corpo; confira `resizeToAvoidBottomInset: true` |
| `Vertical viewport was given unbounded height` | `Column`/scroll sem altura limitada | de altura (`Expanded`, `SizedBox`) ou `shrinkWrap: true` na lista interna |
| `non-zero flex but incoming ... constraints are unbounded` | `Expanded`/`Flexible` dentro de eixo ilimitado | tire o `Expanded`, ou de tamanho ao pai / use `mainAxisSize: MainAxisSize.min` |
| texto cortado / `...` sumido | sem tratamento de overflow no `Text` | `maxLines` + `TextOverflow.ellipsis` + largura limitada (`Flexible`) |
| imagem estoura o container | imagem sem restricao de tamanho | `SizedBox`/`AspectRatio` + `BoxFit`; ou `Expanded` |
| so estoura com fonte grande (acessibilidade) | layout assume `textScaler` 1.0 | `Flexible`/`Wrap`/scroll; nunca fixe altura por contagem de linhas; teste com `textScaler` 1.3–2.0 |
| so estoura em RTL / outro idioma | label traduzida mais comprida; espelhamento | testar `Directionality(textDirection: TextDirection.rtl)`; `Expanded`+ellipsis; evitar largura fixa por idioma |
| conteudo cortado no topo/baixo (notch/barra) | falta `SafeArea` | envolver em `SafeArea` (nao e overflow de RenderFlex, mas o usuario reclama igual) |

**Principio ao corrigir:** prefira `Expanded`/`Flexible`/`Wrap`/`SingleChildScrollView` a `FittedBox` e a alturas fixas chutadas. Largura/altura fixa "resolve" no seu device e estoura no proximo.

---

## 6. Checklist sub-atomico (caminho feliz, erro e edge cases)

Antes de declarar uma tela "sem overflow", percorra TUDO. Marque cada item como OK / FALHA / N/A com evidencia (qual teste, qual tamanho).

**Eixos e flex**
- [ ] Todo `Row` com `Text`/conteudo variavel tem filho flexivel ou estrategia de quebra/scroll explicita.
- [ ] Todo `Column` mais alto que a tela rola (`SingleChildScrollView`) ou tem `Expanded` no filho elastico.
- [ ] Nenhum `Expanded`/`Flexible`/`Spacer` dentro de `SingleChildScrollView`/`Wrap`/eixo ilimitado.
- [ ] Toda `ListView`/`GridView` dentro de `Column` tem limite de altura (`Expanded` ou `SizedBox`).

**Densidade de texto e dados de borda**
- [ ] Testado com o **nome/label mais longo** plausivel (nao o placeholder curto).
- [ ] Testado com numero/preco de **muitos digitos** (5+).
- [ ] `Text` em `Row` tem `maxLines` + `overflow: TextOverflow.ellipsis`.

**Tamanhos e orientacao de device**
- [ ] Celular pequeno (ex.: 320x568), celular comum (411x891), tablet (800x1280).
- [ ] Orientacao retrato E paisagem (se o app permitir landscape).
- [ ] Web/desktop redimensionavel se for alvo (arraste a janela).

**Fontes grandes / acessibilidade**
- [ ] Testado com `textScaler` aumentado (1.3, 1.5, 2.0) — usuario com fonte grande.
- [ ] Nenhuma altura fixa calculada por "numero de linhas" que quebra com fonte maior.

**Internacionalizacao**
- [ ] RTL (`TextDirection.rtl`) nao corta nem espelha errado.
- [ ] Strings traduzidas (pt-BR/de costumam ser mais compridas que en) ainda cabem.

**Tema e ambiente**
- [ ] Dark mode nao introduz overflow (icones/badges com tamanho diferente).
- [ ] `SafeArea`/notch/barra de status — conteudo de borda a borda nao e cortado.
- [ ] Teclado aberto (`simulateKeyboard: true`) — form rola, botao acessivel, nada estoura embaixo.

**Estados da tela**
- [ ] Loading (skeleton/spinner) cabe.
- [ ] Empty (lista vazia, sem dados) cabe e nao colapsa estranho.
- [ ] Error (mensagem longa de erro) cabe e nao estoura.
- [ ] Caminho feliz com conteudo realista (nao so 1 item).

**Prova**
- [ ] Existe teste `expectNoOverflow` que falha sem a correcao e passa com ela.
- [ ] CI roda scanner (informativo) + `flutter analyze` + `flutter test` (bloqueante).

---

## 7. Classificacao de achados (quando for auditoria)

Quando esta skill for usada para **auditar** uma tela/projeto (em vez de corrigir um unico bug), classifique cada achado:

- **Severidade:** `Critica` (estoura/crash em device comum ou no caminho feliz) · `Alta` (estoura em device pequeno, fonte grande, RTL ou teclado) · `Media` (so em combinacao rara de dados+tamanho) · `Baixa` (cosmetico, ou risco potencial sem repro confirmado).
- **Prioridade:** funcao de Severidade × frequencia da tela (quantos usuarios passam por ela).
- **Confianca:** `Confirmada` (tem repro/teste que falha) · `Provavel` (analise estatica/leitura forte) · `Hipotese` (heuristica do scanner, precisa confirmar). Achado sem evidencia e Hipotese — rotule como tal.
- **Esforco:** `Trivial` (uma linha: `ellipsis`/`Expanded`) · `Pequeno` (envolver em scroll, ajustar arvore) · `Medio` (refatorar layout responsivo) · `Grande` (repensar a tela).

---

## 8. Formato obrigatorio da resposta

Quando esta skill produzir uma auditoria/diagnostico, estruture a saida EXATAMENTE assim:

### 8.1 Resumo executivo
2–5 frases: quantos achados, severidade dominante, e se a tela esta apta a ship. Sem rodeios.

### 8.2 Achados (formato fixo, um bloco por achado)

```
[ID] Titulo curto do problema
- Local:        caminho/arquivo.dart:LINHA  (widget culpado)
- Severidade:   Critica | Alta | Media | Baixa
- Confianca:    Confirmada | Provavel | Hipotese
- Esforco:      Trivial | Pequeno | Medio | Grande
- Causa:        por que estoura (eixo, qual filho, qual constraint falha)
- Correcao:     o widget/propriedade certo e por que
- Antes:
    <trecho real / minimo do codigo problematico>
- Depois:
    <trecho corrigido>
- Como verificar: teste/condicao que prova o conserto (tamanho, textScaler, teclado)
```

### 8.3 Tabela consolidada

| ID | Local | Severidade | Confianca | Esforco | Correcao em 1 linha |
|---|---|---|---|---|---|

### 8.4 Plano priorizado
Lista ordenada por prioridade (Critica/Alta primeiro; dentro do mesmo nivel, menor esforco primeiro). Agrupe correcoes triviais que dao pra fazer juntas.

### 8.5 Checklist final
A Secao 6 marcada para a(s) tela(s) auditada(s), com o tamanho/condicao que comprovou cada item.

> Regra de saida: **nunca** mostre apenas codigo que funciona no device atual. Todo "Depois" precisa de um "Como verificar" que cubra pelo menos um tamanho menor e, quando texto/teclado/i18n estiverem envolvidos, a condicao correspondente.

---

## 9. Armadilhas e anti-padroes (erros honestos a evitar — expandido)

- **"Coloquei `Expanded` e quebrou tudo."** `Expanded` so funciona como filho direto de `Row`/`Column`/`Flex`. Dentro de um `SingleChildScrollView` ou `Wrap` ele da erro — porque ali nao existe "espaco restante" definido. Releia o modelo mental (Secao 3).
- **`shrinkWrap: true` em lista longa.** Mata a virtualizacao: o `ListView` constroi todos os filhos de uma vez. Use so pra listas curtas conhecidas; pra lista de verdade dentro de uma coluna, use `Expanded` em volta do `ListView`.
- **`IntrinsicHeight`/`IntrinsicWidth` como muleta.** Resolvem alinhar alturas num `Row`, mas sao caros (podem ser O(n²)). Use pontualmente, nao como habito.
- **Esquecer `SafeArea`.** Notch e barras do sistema cortam conteudo nas bordas — nao e overflow de RenderFlex, mas o usuario reclama igual. Considere `SafeArea` em telas de borda a borda.
- **Altura/largura fixa chutada (`height: 812`, `width: 375`).** "Funciona" no seu device e estoura no proximo. Numero magico = divida tecnica. Use `Expanded`, `FractionallySizedBox`, `LayoutBuilder` ou tokens de spacing.
- **`FittedBox` como solucao universal.** Escala tudo pra caber — inclusive ate ficar ilegivel. Reserve pra valores que precisam aparecer inteiros (precos, placares) com `BoxFit.scaleDown`; prefira `Expanded`+ellipsis quando truncar e aceitavel.
- **`Spacer` dentro de scroll.** `Spacer` = `Expanded` de espaco; nao existe "espaco restante" num `SingleChildScrollView`. Troque por `SizedBox(height: ...)`.
- **Testar so com placeholder curto.** Overflow quase sempre e **dado de borda**: o nome longo, o preco de 6 digitos, a label traduzida, a fonte 200%. "Layout no feliz" raramente estoura.
- **Ignorar `textScaler`.** Acessibilidade aumenta a fonte; layout que assume escala 1.0 estoura pra quem mais precisa. Teste com escala grande.
- **Confiar em `MediaQuery.of(context).size` quando o widget nao ocupa a tela.** Use `LayoutBuilder` pras constraints reais do pai; use `MediaQuery.sizeOf`/`viewInsetsOf`/`paddingOf` (menos rebuild) quando precisar de tela/insets.
- **Aninhar duas rolagens no mesmo eixo** (`SingleChildScrollView` > `Column` > `Expanded(ListView)`). Conflito de scroll/altura. Escolha uma estrategia: `Expanded(ListView)` *ou* lista `shrinkWrap` curta dentro do scroll externo, nunca os dois.

---

## 10. Auto-verificacao e regras de qualidade

Antes de entregar qualquer diagnostico/correcao, confirme:

1. **Nao inventei nada.** Todo widget/arquivo/linha citado existe no codigo real. Nada de props/metodos imaginados. Se nao verifiquei, rotulo como Hipotese.
2. **Nao mostrei codigo que so funciona no device atual.** Todo "Depois" tem "Como verificar" com tamanho menor + condicao relevante (textScaler/teclado/RTL).
3. **Validei empiricamente, nao por inspecao.** A prova final e um teste que falha sem o fix e passa com ele — nao "rodei e nao vi a barra".
4. **A correcao expressa a intencao**, nao um numero magico. Se usei tamanho fixo, justifiquei por que e correto ali.
5. **Cobri os edge cases relevantes** da Secao 6 (pelo menos: device pequeno, dado de borda, e — se houver texto/form/i18n — fonte grande/teclado/RTL).
6. **Apontei pros arquivos da skill** quando o usuario precisa de profundidade (`references/*.md`), do scanner (`scripts/...`) ou do harness (`assets/overflow_guard.dart`).
7. **Calibrei o tamanho da resposta** ao tamanho do problema: um overflow de `ellipsis` nao precisa de relatorio de 8 secoes.

---

## 11. Principios transferiveis (cross-stack)

O **principio subjacente** do Flutter — *constraints descem, tamanhos sobem, o pai posiciona; overflow = filho pede mais do que o pai da, num container que nem rola nem corta* — e universal em UI. O Flutter e a ancora; aqui esta como o mesmo principio aparece em outras stacks, pra que o engenheiro de qualquer ecossistema extraia valor sem perder a afiacao Flutter.

### Eixo flex que estoura (Flutter `Row`/`Column` -> outras stacks)

| Conceito Flutter | CSS (Flexbox/Grid) | React Native | SwiftUI | Jetpack Compose / Android Views |
|---|---|---|---|---|
| `Expanded` (preenche o resto) | `flex: 1` num flex item | `style={{ flex: 1 }}` | `.frame(maxWidth: .infinity)` / `Spacer()` | `Modifier.weight(1f)` / `layout_weight` |
| `Flexible(fit: loose)` | `flex: 0 1 auto` | `flexShrink: 1` | `.layoutPriority()` baixo | `Modifier.weight(1f, fill = false)` |
| `Wrap` (quebra linha) | `flex-wrap: wrap` / Grid auto-fill | sem nativo: usar lib de wrap/Grid | `WrapLayout` (iOS 16 `Layout`) / `LazyVGrid` | `FlowRow`/`FlowColumn` (Compose) |
| Texto: `maxLines`+`ellipsis` | `overflow: hidden; text-overflow: ellipsis; white-space: nowrap` (ou `-webkit-line-clamp`) | `numberOfLines={1}` | `.lineLimit(1)` + `.truncationMode(.tail)` | `maxLines = 1, overflow = TextOverflow.Ellipsis` |
| `FittedBox(scaleDown)` | `clamp()`/`min()` em font-size; `transform: scale` | `adjustsFontSizeToFit` (Text) | `.minimumScaleFactor(0.5)` | `AutoSize`/medir e ajustar |

**A armadilha CSS que e o irmao gemeo do `Expanded`-em-Row:** um flex item nao encolhe abaixo do seu conteudo por padrao porque `min-width: auto`. Texto longo "estoura" o flex container exatamente como um `Text` sem `Expanded` num `Row`. A correcao canonica e `min-width: 0` (ou `min-height: 0` no eixo coluna) no item flexivel + `overflow: hidden` — o equivalente CSS de dar ao filho permissao pra ceder espaco. Em Grid, use `minmax(0, 1fr)` em vez de `1fr`.

### Conteudo ilimitado que precisa rolar (unbounded -> scroll)

| Flutter | CSS | React Native | SwiftUI | Compose |
|---|---|---|---|---|
| `SingleChildScrollView` | `overflow: auto/scroll` num container com altura limitada | `<ScrollView>` | `ScrollView` | `Modifier.verticalScroll()` |
| `ListView`/`GridView` (virtualizado) | virtual list / `content-visibility` | `<FlatList>`/`<SectionList>` | `List`/`LazyVStack` | `LazyColumn`/`LazyGrid` |
| Lista dentro de `Column` precisa de altura | flex child precisa de `min-height: 0` pra rolar dentro de flex pai | `flex: 1` no container da lista | frame/`Spacer` | `Modifier.weight(1f)` no container |

**Principio comum:** algo que rola precisa de um limite no eixo de rolagem. O `Vertical viewport was given unbounded height` do Flutter e o mesmo bug que, em CSS, faz um `overflow: auto` nunca rolar porque o pai flex nao tem `min-height: 0` — o container cresce em vez de limitar e rolar.

### Teclado empurrando o form

| Flutter | CSS/Web | React Native | SwiftUI | Compose |
|---|---|---|---|---|
| `SingleChildScrollView` + `resizeToAvoidBottomInset` + `viewInsetsOf` | `env(keyboard-inset-height)`, `100dvh`, `visualViewport` API | `KeyboardAvoidingView` | `.ignoresSafeArea(.keyboard)` ajuste / `ScrollView` | `Modifier.imePadding()` + scroll |

### Area segura / notch

| Flutter | CSS | React Native | SwiftUI | Compose |
|---|---|---|---|---|
| `SafeArea` / `MediaQuery.paddingOf` | `env(safe-area-inset-*)` + `viewport-fit=cover` | `SafeAreaView` / `useSafeAreaInsets` | safe area por padrao | `Modifier.safeDrawingPadding()` / `WindowInsets` |

### Responsivo por restricoes do pai (nao por tela inteira)

| Flutter | CSS | React Native | SwiftUI | Compose |
|---|---|---|---|---|
| `LayoutBuilder` (constraints do pai) | Container Queries (`@container`) / media queries | `onLayout` + medir | `GeometryReader` / size classes | `BoxWithConstraints` |
| `FractionallySizedBox(widthFactor)` | `width: 80%` / `fr` units | `width: '80%'` | `.frame(width: proxy.size.width * 0.8)` | fracao de `maxWidth` |

### Design tokens / tema (em vez de numeros magicos)

| Flutter | CSS / Web | iOS / Android |
|---|---|---|
| `ThemeData`, `Theme.of(context)`, `TextTheme`, `MediaQuery.textScaler` | CSS custom properties (`--space-4`), `clamp()`, Tailwind config (theme scale), Material/Chakra theming | iOS Dynamic Type, Android `sp`/`dimens`, Material 3 tokens |

**Principio comum (anti numero magico):** tamanho fixo e divida tecnica em qualquer stack. Tokens/escala (spacing, breakpoints, tipografia) + unidades relativas (`fr`, `%`, `dvh`, `sp`, `rem`, `clamp()`) deixam o layout sobreviver a outro device, fonte grande e idioma. O `height: 812` do Flutter, o `height: 100vh` que ignora a barra do mobile, o `numberOfLines` ausente do RN, o `.fixedSize()` errado do SwiftUI e o `width = 360.dp` do Compose sao o mesmo erro vestindo roupas diferentes.

**Como verificar em qualquer stack (a regra de ouro transversal):** teste no tamanho **menor** plausivel, com o **dado mais longo**, na **maior densidade de fonte** e no idioma mais comprido — automatizado, nao "olhei no meu monitor". Web: responsive mode + zoom de fonte. RN/Flutter: widget/component test multi-size + escala de fonte. SwiftUI: previews com size classes e Dynamic Type. Compose: `@Preview` com `fontScale` e `widthDp`.

---

## 12. Modos de uso (mapa rapido)

- **Modo 1 — Escrevendo UI nova (prevenir):** Fase A + `references/patterns.md`. Decida a estrategia de overflow antes de escrever o `Flex`.
- **Modo 2 — Consertando overflow (diagnosticar+corrigir):** Fases B e C + tabela da Secao 5 + `references/diagnosis.md` se ambiguo.
- **Modo 3 — Provando que nao estoura (verificar):** Fase D + `scripts/scan_overflow_risks.py` + `assets/overflow_guard.dart` + `references/testing.md`.
- **Modo 4 — Auditando uma tela/projeto:** rode tudo e entregue no formato da Secao 8 com a classificacao da Secao 7.

---

## 13. Arquivos desta skill (continue apontando para eles)

- **`references/patterns.md`** — catalogo de prevencao com exemplos antes/depois por cenario (Row, Column, texto, scroll, teclado, imagens, responsivo, dialogos, chips/Wrap). Leia ao escrever UI nova ou ao aplicar bem um padrao da tabela.
- **`references/diagnosis.md`** — procedimento completo de diagnostico (ler mensagem -> eixo -> widget culpado -> classificar -> aplicar) e a familia de erros de constraint ilimitada (`unbounded height/width`, `non-zero flex`, `forces an infinite`). Leia quando o caso for ambiguo.
- **`references/testing.md`** — guia das 4 camadas (scanner, `flutter analyze`/lints, widget test multi-tamanho, golden), ferramentas de debug e CI. Leia ao montar a verificacao.
- **`scripts/scan_overflow_risks.py`** — scanner heuristico de risco. Roda em qualquer maquina com Python 3 (nao precisa do Flutter SDK): `python3 scripts/scan_overflow_risks.py lib/` (ou `--json` pra CI). E pre-filtro, nao verdade absoluta — confirme com a Camada 3.
- **`assets/overflow_guard.dart`** — helper de teste pra colar em `test/`; expoe `expectNoOverflow(tester, widget, {sizes, simulateKeyboard})` que pumpa em varios tamanhos e falha se algum disparar overflow.
