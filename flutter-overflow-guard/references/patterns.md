# Padrões de prevenção de overflow

Catálogo de "o problema → o padrão certo → por quê", com exemplos antes/depois. Todo código (widgets, propriedades, mensagens) em inglês porque é o que o framework usa; explicação em português.

## Índice
1. [Row que estoura na horizontal](#1-row-que-estoura-na-horizontal)
2. [Column que estoura na vertical](#2-column-que-estoura-na-vertical)
3. [Texto longo](#3-texto-longo)
4. [Form empurrado pelo teclado](#4-form-empurrado-pelo-teclado)
5. [Lista/grid dentro de Column](#5-listagrid-dentro-de-column)
6. [Imagens](#6-imagens)
7. [Encolher pra caber (FittedBox)](#7-encolher-pra-caber-fittedbox)
8. [Layout responsivo](#8-layout-responsivo)
9. [Diálogos e bottom sheets](#9-diálogos-e-bottom-sheets)
10. [Chips, tags e botões que quebram linha](#10-chips-tags-e-botões-que-quebram-linha)

---

## 1. Row que estoura na horizontal

A causa nº 1. `Row` dá largura livre aos filhos fixos; se a soma passa da tela, estoura à direita.

**Antes (estoura quando o texto é grande):**
```dart
Row(
  children: [
    const Icon(Icons.person),
    Text(user.veryLongDisplayName), // empurra além da borda
    const Icon(Icons.chevron_right),
  ],
)
```

**Depois — opção A: o texto cede o espaço e trunca**
```dart
Row(
  children: [
    const Icon(Icons.person),
    const SizedBox(width: 8),
    Expanded(
      child: Text(
        user.veryLongDisplayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
    const Icon(Icons.chevron_right),
  ],
)
```
`Expanded` limita a largura do `Text` ao espaço que sobra depois dos dois ícones; `ellipsis` corta com "…". Os ícones têm tamanho intrínseco e ficam fixos.

**Depois — opção B: itens fluem pra próxima linha**
```dart
Wrap(
  spacing: 8,
  runSpacing: 8,
  children: [for (final tag in tags) Chip(label: Text(tag))],
)
```
Use `Wrap` quando faz sentido descer de linha (tags, filtros, botões). `Row` nunca quebra linha — ou cabe, ou estoura.

**Dois filhos elásticos disputando espaço:** use `Flexible` com `flex` ou `Expanded` em ambos.
```dart
Row(
  children: [
    Expanded(flex: 2, child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis)),
    Expanded(flex: 1, child: Text(price, textAlign: TextAlign.end, maxLines: 1, overflow: TextOverflow.ellipsis)),
  ],
)
```

`Expanded` = `Flexible(fit: FlexFit.tight)`. Use `Flexible` (loose) quando o filho pode ser *menor* que sua fração; `Expanded` quando deve preencher.

---

## 2. Column que estoura na vertical

`Column` numa tela mais baixa que o conteúdo (ou dentro de algo com altura limitada) estoura embaixo.

**Antes:**
```dart
Scaffold(
  body: Column(
    children: [ /* muitos cards, formulário longo */ ],
  ),
)
```

**Depois — deve rolar:**
```dart
Scaffold(
  body: SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [ /* mesmo conteúdo */ ],
    ),
  ),
)
```

**Depois — um filho deve esticar e o resto é fixo (ex.: header + lista + footer):**
```dart
Column(
  children: [
    const HeaderBar(),                       // fixo
    Expanded(child: ListView(children: [...])), // ocupa o que sobra e rola sozinho
    const FooterBar(),                        // fixo
  ],
)
```
Aqui `Expanded` dá altura limitada à `ListView` (senão ela tomaria erro de `unbounded height`). Não envolva essa `Column` num `SingleChildScrollView` — daria conflito de duas rolagens.

`mainAxisSize: MainAxisSize.min` faz a `Column` ficar só do tamanho dos filhos — útil quando ela mesma está num contexto sem altura definida (dentro de outra `Column`, num `Dialog`).

---

## 3. Texto longo

Texto sem tratamento ou estoura (largura limitada) ou empurra o layout (largura livre).

```dart
Text(
  longString,
  maxLines: 2,
  overflow: TextOverflow.ellipsis, // .fade, .clip também existem
  softWrap: true,
)
```

Regras:
- Em `Row`, **sempre** combine com `Expanded`/`Flexible` — ellipsis sozinho não basta se a largura é livre.
- `maxLines` sem `overflow` ainda pode estourar a altura; defina os dois juntos.
- Para uma única linha que deve encolher a fonte em vez de truncar, veja `FittedBox` (seção 7) ou `AutoSizeText` (pacote externo).

---

## 4. Form empurrado pelo teclado

O overflow mais comum em apps reais. O teclado aumenta `MediaQuery.viewInsets.bottom`; com `resizeToAvoidBottomInset: true` (padrão), o corpo do `Scaffold` encolhe e o conteúdo fixo estoura embaixo — só ao focar um campo.

**Antes:**
```dart
Scaffold(
  body: Column(
    children: [
      TextField(...),
      TextField(...),
      const Spacer(),
      ElevatedButton(onPressed: ..., child: const Text('Salvar')),
    ],
  ),
)
```

**Depois:**
```dart
Scaffold(
  // resizeToAvoidBottomInset: true é o padrão — mantenha
  body: SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(...),
          const SizedBox(height: 12),
          TextField(...),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: ..., child: const Text('Salvar')),
        ],
      ),
    ),
  ),
)
```
Com a rolagem, o conteúdo que não cabe sob o teclado fica acessível rolando. Cuidado: `Spacer`/`Expanded` não funcionam dentro de `SingleChildScrollView` (altura ilimitada) — troque por `SizedBox`. Para colar o botão acima do teclado, considere `Scaffold.bottomNavigationBar` ou `Padding(padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom))`.

---

## 5. Lista/grid dentro de Column

`ListView`/`GridView` são ilimitados no eixo de rolagem. Dentro de uma `Column` (altura livre) → erro `unbounded height`. Dentro de um `Row` → `unbounded width`.

**Depois — caso normal (a lista ocupa o resto e rola):**
```dart
Column(
  children: [
    const SearchBar(),
    Expanded(child: ListView.builder(itemCount: n, itemBuilder: ...)),
  ],
)
```

**Depois — lista curta que NÃO deve rolar sozinha (faz parte da rolagem externa):**
```dart
SingleChildScrollView(
  child: Column(
    children: [
      const Header(),
      ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length, // poucos itens!
        itemBuilder: ...,
      ),
    ],
  ),
)
```
`shrinkWrap: true` faz a lista medir todos os filhos e ter altura própria — **mata a virtualização**, então só para listas curtas e conhecidas. Para listas de tamanho real misturadas com outro conteúdo, prefira `CustomScrollView` com `SliverList`/`SliverToBoxAdapter`.

---

## 6. Imagens

Imagem sem restrição assume seu tamanho intrínseco (pixels do arquivo) e estoura o container.

```dart
// Tamanho fixo, recorta o excesso
SizedBox(
  width: 120,
  height: 120,
  child: Image.network(url, fit: BoxFit.cover),
)

// Proporção fixa, largura vinda do pai
AspectRatio(
  aspectRatio: 16 / 9,
  child: Image.network(url, fit: BoxFit.cover),
)

// Ocupa o espaço restante numa coluna
Expanded(child: Image.network(url, fit: BoxFit.contain))
```
`BoxFit.cover` preenche e recorta; `contain` cabe inteira com possível sobra; `fitWidth`/`fitHeight` ajustam um eixo. Sempre dê uma restrição de tamanho à imagem.

---

## 7. Encolher pra caber (FittedBox)

`FittedBox` escala o filho pra caber nas restrições do pai. Resolve "esse número grande às vezes não cabe", mas pode deixar conteúdo minúsculo — use com critério.

```dart
SizedBox(
  width: 80,
  child: FittedBox(
    fit: BoxFit.scaleDown, // só diminui; nunca aumenta além do natural
    alignment: Alignment.centerLeft,
    child: Text('R\$ ${valorEnorme}'),
  ),
)
```
Para texto, `BoxFit.scaleDown` é o mais seguro. Prefira `Expanded` + ellipsis quando truncar é aceitável; `FittedBox` quando o valor inteiro precisa aparecer (preços, placares).

---

## 8. Layout responsivo

Quando o layout muda conforme o espaço disponível, deixe a UI se adaptar em vez de chutar tamanhos.

```dart
LayoutBuilder(
  builder: (context, constraints) {
    if (constraints.maxWidth < 600) {
      return const _PhoneLayout(); // empilha em Column
    }
    return const _WideLayout();    // lado a lado em Row com Expanded
  },
)
```
`LayoutBuilder` te dá as restrições reais do pai (melhor que `MediaQuery` quando o widget não ocupa a tela toda). Para dimensões da tela/insets:
- `MediaQuery.sizeOf(context)` — tamanho da tela (mais eficiente que `MediaQuery.of(context).size`, evita rebuilds desnecessários).
- `MediaQuery.viewInsetsOf(context).bottom` — altura do teclado.
- `MediaQuery.paddingOf(context)` — notch/barras.

`FractionallySizedBox(widthFactor: 0.8, child: ...)` dimensiona como fração do pai sem número fixo.

---

## 9. Diálogos e bottom sheets

`AlertDialog`/`Dialog` têm altura limitada pela tela; conteúdo alto estoura. Bottom sheets idem com o teclado.

```dart
AlertDialog(
  title: const Text('Termos'),
  content: SizedBox(
    width: double.maxFinite,
    child: SingleChildScrollView(child: Text(longTerms)),
  ),
)

// Bottom sheet que respeita o teclado
showModalBottomSheet(
  context: context,
  isScrollControlled: true, // permite passar de metade da tela
  builder: (context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: const _SheetForm(),
  ),
);
```

---

## 10. Chips, tags e botões que quebram linha

Conjunto de itens de largura variável que precisa fluir em múltiplas linhas → `Wrap`, nunca `Row`.

```dart
Wrap(
  spacing: 8,      // espaço horizontal entre itens
  runSpacing: 8,   // espaço vertical entre linhas
  children: [for (final f in filtros) FilterChip(label: Text(f), selected: ..., onSelected: ...)],
)
```
Se precisar de rolagem horizontal em vez de quebra (uma fileira de categorias), use `SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(...))` — aí o `Row` ganha largura ilimitada e não estoura, mas não use `Expanded` lá dentro.
