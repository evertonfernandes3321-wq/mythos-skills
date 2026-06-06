# Components — re-estilizando os widgets que entregam o default

Mesmo com cor e fonte resolvidas, alguns widgets têm defaults tão reconhecíveis que sozinhos dão "cara de Flutter": a sombra do `Card`, o `AppBar` central com elevação, o ripple em tudo, os ícones do Material. Re-estilize-os **no tema** (component themes), não por instância.

## Índice
- [Sombra desenhada (não elevação Material)](#sombra)
- [Botões](#botoes)
- [Inputs](#inputs)
- [Cards e superfícies](#cards)
- [AppBar](#appbar)
- [Dialogs, bottom sheets, snackbars](#overlays)
- [Domando o ripple/splash](#ripple)
- [Trocando o icon set](#icones)

## Sombra

A sombra/elevação padrão do Material (cinza, difusa, "M3") é um tell. Sombras profissionais são **suaves, multicamada e com cor tingida**. Defina-as como token (no `AppTokens`) e aplique via `BoxShadow`, não via `elevation:`.

```dart
// sombra suave para cards (token)
final shadowSoft = <BoxShadow>[
  BoxShadow(
    color: const Color(0xFF1A1A2E).withValues(alpha: 0.04),
    blurRadius: 2, offset: const Offset(0, 1),
  ),
  BoxShadow(
    color: const Color(0xFF1A1A2E).withValues(alpha: 0.06),
    blurRadius: 12, offset: const Offset(0, 4),
  ),
];
```

Duas camadas (uma curta e nítida + uma longa e difusa) imitam luz real e parecem muito mais caras que a sombra padrão de uma camada. No dark mode, profundidade vem de superfície mais clara — reduza/remova sombra e suba o `surfaceContainer`.

> `withValues(alpha:)` é a API atual; `withOpacity` foi depreciada nas versões recentes. Se o analyzer reclamar, ajuste para a sua versão.

## Botões

Defaults a corrigir: cantos, altura, peso do label, e o realce. Estilize via `*ButtonThemeData`:

```dart
filledButtonTheme: FilledButtonThemeData(
  style: ButtonStyle(
    minimumSize: WidgetStatePropertyAll(Size(0, 52)),     // altura confortável
    padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
    shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: tokens.radii.md)),
    textStyle: WidgetStatePropertyAll(
        text.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
    elevation: const WidgetStatePropertyAll(0),            // sem sombra padrão
  ),
),
```

Princípios: **hierarquia clara** entre os tipos de botão — `FilledButton` para a ação primária (1 por tela, idealmente), `OutlinedButton`/`TextButton` para secundárias. Altura ≥ 48dp (toque). Label em peso 600. Sem sombra (ações flat leem moderno). Estados de hover/pressed sutis via `WidgetStateProperty` se for web/desktop.

`WidgetStatePropertyAll`/`WidgetStateProperty` são os nomes atuais (antes `MaterialStateProperty`). Ajuste se necessário.

## Inputs

O `TextField` default (preenchido, sublinhado grosso, label flutuante Material) é muito reconhecível. Profissionais costumam usar borda fina e cantos consistentes:

```dart
inputDecorationTheme: InputDecorationTheme(
  filled: true,
  fillColor: scheme.surfaceContainerLowest,
  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  border: OutlineInputBorder(
    borderRadius: tokens.radii.md,
    borderSide: BorderSide(color: scheme.outlineVariant),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: tokens.radii.md,
    borderSide: BorderSide(color: scheme.outlineVariant),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: tokens.radii.md,
    borderSide: BorderSide(color: scheme.primary, width: 1.5),
  ),
  hintStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
),
```

Consistência de raio com botões e cards é o que amarra o visual.

## Cards

O `Card` do M3 vem com elevação e sombra padrão. Zere a elevação e use cor de superfície + (opcional) sua sombra desenhada ou uma borda fina:

```dart
cardTheme: CardThemeData(
  elevation: 0,
  color: scheme.surfaceContainerLow,
  shape: RoundedRectangleBorder(
    borderRadius: tokens.radii.md,
    side: BorderSide(color: scheme.outlineVariant), // borda fina em vez de sombra
  ),
  clipBehavior: Clip.antiAlias,
  margin: EdgeInsets.zero, // controle o espaçamento por fora, com tokens
),
```

Escolha **um** idioma e mantenha: ou cards com borda fina (flat, moderno), ou cards com sombra suave (elevado, premium) — não misture os dois no mesmo app. `CardTheme` virou `CardThemeData` nas versões recentes.

## AppBar

Tells do default: `centerTitle: true` (no Android), elevação com sombra, e a cor primária preenchendo a barra. Versão profissional, integrada à superfície:

```dart
appBarTheme: AppBarTheme(
  backgroundColor: scheme.surface,
  foregroundColor: scheme.onSurface,
  elevation: 0,
  scrolledUnderElevation: 0.5,        // leve separação só ao rolar
  centerTitle: false,                  // título à esquerda lê mais moderno/premium
  titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w600),
  systemOverlayStyle: SystemUiOverlayStyle.dark, // status bar combinando (ver motion)
),
```

Para um visual atual, considere título grande/colapsável (`SliverAppBar.large`) em telas principais.

## Overlays

- **Dialogs:** `DialogThemeData` com o mesmo raio do resto, fundo `surfaceContainerHigh`, e a sombra "lifted". Botões do dialog seguindo a hierarquia de botões.
- **Bottom sheets:** `BottomSheetThemeData` com cantos superiores arredondados (`radii.lg`), `showDragHandle: true` para um toque nativo, e `surfaceContainerLow`.
- **SnackBars:** `SnackBarThemeData` com `behavior: SnackBarBehavior.floating`, raio consistente, e cores do tema. O snackbar default (retangular, colado embaixo) é um tell clássico.

```dart
snackBarTheme: SnackBarThemeData(
  behavior: SnackBarBehavior.floating,
  shape: RoundedRectangleBorder(borderRadius: tokens.radii.md),
  backgroundColor: scheme.inverseSurface,
  contentTextStyle: text.bodyMedium?.copyWith(color: scheme.onInverseSurface),
),
```

## Ripple

O splash do Material (`InkWell`) em **tudo** — inclusive em cards e itens de lista — data o app. Estratégia profissional:

- **Botões:** mantêm um feedback de toque, mas sutil. Pode trocar o `splashFactory` global por `InkSparkle.splashFactory` (suave) ou reduzir o overlay.
- **Cards/itens clicáveis:** muitas vezes melhor um feedback de **escala/opacidade** rápido (toque que "afunda" levemente) do que ripple. Veja o helper em `motion-and-detail.md` / `assets/motion.dart`.
- **Desligar o ripple onde não cabe:** `splashFactory: NoSplash.splashFactory` no `ThemeData`, ou `splashColor: Colors.transparent` + `highlightColor` no widget. Não exagere — toque sem **nenhum** feedback parece quebrado; troque por outro feedback, não por nada.

## Ícones

`Icons.` (Material Icons) é um icon set reconhecível "do Google". Para fugir do default, troque por um set com identidade própria:

- **`lucide_icons_flutter`** — limpo, fino, cara de SaaS moderno. Ótimo para apps com bastante espaço em branco. (Lucide é fork do Feather; sem variantes preenchidas fortes.)
- **`phosphor_flutter`** — flexível, com pesos (Thin/Light/Regular/Bold/Fill) — bom quando você precisa de estados selecionados/cheios.
- **Remix, Tabler, Hugeicons** — outras opções neutras e amplas.

Escolha **um** set e use só ele (misturar icon sets é tell de vibecoding). Confira a versão atual no pub.dev — o ecossistema de ícones do Flutter mudou após o desacoplamento de Material/Cupertino. Mantenha tamanho de ícone consistente (ex.: 20 para inline, 24 para ações) — outro lugar onde a escala importa.
