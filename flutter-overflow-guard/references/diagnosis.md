# Diagnóstico de overflow

Procedimento pra ir da mensagem de erro (ou da barra listrada) até a correção certa, sem chutar. Use quando a tabela rápida do SKILL.md não for suficiente.

## Passo 1 — Leia a mensagem inteira

O Flutter te dá quase tudo de graça no console. Uma mensagem típica:

```
A RenderFlex overflowed by 37 pixels on the right.
The relevant error-causing widget was:
  Row  Row:file:///.../lib/widgets/user_tile.dart:24:16
The overflowing RenderFlex has an orientation of Axis.horizontal.
```

Extraia três coisas:
- **Eixo:** `on the right`/`on the left` = horizontal (um `Row`). `at the bottom`/`on the top` = vertical (uma `Column`). A linha `orientation of Axis.horizontal/vertical` confirma.
- **Quanto:** "by 37 pixels" — overflow pequeno costuma ser padding/spacing; overflow grande costuma ser um filho inteiro que não cabe.
- **Onde:** o arquivo e a linha do widget culpado (`user_tile.dart:24`). Vá direto pra lá.

## Passo 2 — Identifique o eixo e o widget culpado

- Overflow **horizontal** → o problema está num `Row` (ou `Wrap`/`Flex` horizontal). Os filhos somados passam da largura.
- Overflow **vertical** → o problema está numa `Column` (ou `Flex` vertical, `ListBody`).

Se a linha apontada for um `Row`/`Column`, ótimo. Se apontar um widget que *contém* um `Row`/`Column`, suba/desça um nível. Use o **Flutter Inspector** (DevTools) — o botão "Select Widget Mode" deixa você clicar na barra listrada e ver a subárvore e as constraints de cada nó.

## Passo 3 — Classifique a causa

Para cada filho do `Row`/`Column` culpado, pergunte "esse aqui tem tamanho fixo ou pode ceder?":

- Há um `Text`, `Image` ou `Container` de tamanho fixo que é o "grandão"? → ele precisa **ceder** (`Expanded`/`Flexible`) ou **truncar** (`maxLines`+`ellipsis`) ou **encolher** (`FittedBox`).
- São muitos itens pequenos que somados estouram? → talvez devam **quebrar linha** (`Wrap`) ou **rolar** (`SingleChildScrollView` no eixo certo).
- O conteúdo total simplesmente não cabe e deveria rolar? → **`SingleChildScrollView`** (uma tela) ou **`ListView`** (lista).
- Só estoura quando o teclado abre? → é o caso do teclado: **`SingleChildScrollView`** no corpo + checar `resizeToAvoidBottomInset`.

## Passo 4 — Aplique e confirme

Aplique a correção (veja `patterns.md` para o exemplo do cenário) e **rode um teste** que prove o conserto, não só "rodei e não vi a barra" — porque a barra some no device que você testou e volta no menor. Use o harness de `assets/overflow_guard.dart` (detalhes em `testing.md`):

```dart
testWidgets('UserTile não estoura', (tester) async {
  await expectNoOverflow(tester, UserTile(user: longNameUser));
});
```

---

## A família dos erros de constraint ilimitada (os primos do overflow)

Estes **não** são "overflow de RenderFlex", mas vivem coladas e as pessoas confundem. Em vez da barra listrada, você toma uma exceção vermelha. A causa raiz é a mesma — uma negociação de constraints que não fecha — mas o lado oposto: aqui falta limite, no overflow sobra conteúdo.

### `Vertical viewport was given unbounded height`
Você colocou algo que rola (`ListView`, `GridView`, `SingleChildScrollView`) num pai que dá altura ilimitada (uma `Column`, outro scroll). O viewport não sabe que altura ter.

**Correção:** dê um limite.
- `Expanded(child: ListView(...))` se a lista deve ocupar o resto da coluna.
- `SizedBox(height: 200, child: ListView(...))` se tem altura definida.
- `shrinkWrap: true` + `physics: NeverScrollableScrollPhysics()` se é lista curta dentro de outra rolagem (mata virtualização — só pra poucos itens).

### `RenderFlex children have non-zero flex but incoming height/width constraints are unbounded`
Você pôs `Expanded`/`Flexible` (flex ≠ 0) num `Row`/`Column` que está num eixo ilimitado. Não dá pra calcular "a fração do infinito".

Acontece classicamente com:
- `Column` com `Expanded` dentro de `SingleChildScrollView` (altura ilimitada).
- `Row` com `Expanded` dentro de `Row` horizontalmente ilimitado, ou dentro de `scrollDirection: Axis.horizontal`.

**Correção:**
- Tire o `Expanded`/`Flexible` e deixe o filho ter tamanho intrínseco.
- Ou dê tamanho ao pai (`SizedBox`, `ConstrainedBox`).
- Ou, na `Column`/`Row`, use `mainAxisSize: MainAxisSize.min` se ela deve só envolver os filhos.

### `Horizontal viewport was given unbounded width`
Mesma ideia do vertical, no eixo X — geralmente um `ListView(scrollDirection: Axis.horizontal)` dentro de um `Row` sem largura definida.

**Correção:** `Expanded`/`SizedBox(width: ...)` em volta, ou limitar o pai.

### `BoxConstraints forces an infinite width/height`
Algo pediu tamanho infinito (ex.: `double.infinity` num eixo sem limite, ou `Spacer` dentro de scroll). Procure `double.infinity`/`Spacer`/`Expanded` em contexto ilimitado e troque por tamanho concreto ou remova.

---

## Checklist mental rápido

Quando bater um overflow, percorra nesta ordem:
1. **Eixo?** horizontal=Row, vertical=Column.
2. **Deveria rolar?** Se sim, `SingleChildScrollView`/`ListView` — e pronto na maioria das vezes.
3. **Algum filho deveria ceder/truncar?** `Expanded`/`Flexible` (+ `maxLines`+`ellipsis` se for texto).
4. **Itens deveriam quebrar linha?** `Wrap`.
5. **É o teclado?** Scroll no corpo + `resizeToAvoidBottomInset`.
6. **É lista dentro de coluna?** `Expanded` em volta (ou `shrinkWrap` se curta).
7. **Tomei exceção vermelha de "unbounded"?** É a família acima — falta limite, dê um.
8. **Confirme com teste** em vários tamanhos, não só no seu device.
