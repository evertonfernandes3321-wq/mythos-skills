# Design Tokens — o sistema por baixo do app profissional

Tokens são as decisões de design nomeadas e centralizadas. Em vez de `16` espalhado pelo código, você tem `tokens.gap.md`. Em vez de `Color(0xFF22C7F0)` em três telas, você tem `colorScheme.primary`. Centralizar é o que separa "app com sistema" de "app vibecoded".

## Índice
- [As escalas](#as-escalas)
- [ThemeExtension: tokens type-safe e theme-aware](#themeextension)
- [Montando o ThemeData a partir dos tokens](#montando-o-themedata)
- [Consumindo tokens nos widgets](#consumindo-tokens)
- [Centralizando cor](#centralizando-cor)
- [Checklist de tokens](#checklist)

## As escalas

Profissionais não usam valores arbitrários. Usam **escalas** — conjuntos pequenos e regulares. A inconsistência (raios 7, 12, 20 na mesma tela) é o tell #1 de vibecoding.

**Espaço** — base 4, geralmente: `4, 8, 12, 16, 24, 32, 48, 64`. Nomeie: `xs=4, sm=8, md=12, lg=16, xl=24, xxl=32`. Toda margem/padding/`SizedBox` sai daí.

**Raio** — escolha 2-3 valores e seja fiel: ex. `sm=8, md=12, lg=20, full=999`. Um app inteiro com o mesmo raio de canto lê como intencional. Misturar 5 raios diferentes lê como acidente.

**Tipografia** — uma escala modular (veja `typography-color.md`). Não invente tamanhos por tela.

**Elevação/sombra** — 2-3 níveis de sombra _desenhada_ (não a elevação Material crua). Ex.: `none`, `soft` (cards), `lifted` (menus/dialogs). Veja `components.md`.

**Duração/curva** — tokens de movimento (veja `motion-and-detail.md`): `fast=150ms`, `base=250ms`, `slow=400ms`, com curvas `emphasized`.

## ThemeExtension

`ColorScheme` e `TextTheme` cobrem cor e texto. Para o resto (espaço, raio, sombras, durações, cores semânticas extras), o jeito profissional e theme-aware é um `ThemeExtension`. Ele:
- é acessível em qualquer lugar via `Theme.of(context).extension<AppTokens>()!`;
- muda junto com light/dark (você registra um por brilho);
- anima suavemente em troca de tema (graças ao `lerp`).

Estrutura mínima (o `assets/app_theme.dart` traz uma completa):

```dart
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.gap,
    required this.radii,
    required this.shadowSoft,
    required this.success,
    required this.warning,
    required this.durFast,
    required this.durBase,
  });

  final _Gap gap;          // escala de espaço
  final _Radii radii;      // escala de raio
  final List<BoxShadow> shadowSoft;
  final Color success;     // cor semântica fora do ColorScheme
  final Color warning;
  final Duration durFast;
  final Duration durBase;

  @override
  AppTokens copyWith({Color? success, Color? warning, /* ... */}) => AppTokens(
        gap: gap, radii: radii, shadowSoft: shadowSoft,
        success: success ?? this.success,
        warning: warning ?? this.warning,
        durFast: durFast, durBase: durBase,
      );

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      gap: gap, radii: radii, // escalas não interpolam
      shadowSoft: BoxShadow.lerpList(shadowSoft, other.shadowSoft, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      durFast: durFast, durBase: durBase,
    );
  }
}
```

**Por que não usar só constantes globais (`const kGapMd = 16;`)?** Constantes funcionam para espaço/raio (não mudam com o tema) e são até mais simples — pode usar. Mas cores semânticas e sombras **mudam** entre light/dark; essas precisam estar no `ThemeExtension` para reagir ao tema. O asset combina: escalas como objetos const reutilizáveis + cores/sombras no extension. Não esqueça `copyWith` e `lerp` — sem eles, animação e troca de tema quebram.

## Montando o ThemeData

A regra de ouro: **o tema estiliza, o widget consome**. Tudo que é repetível vai para `ThemeData` como _component theme_, não para a instância do widget.

```dart
ThemeData buildTheme(ColorScheme scheme, TextTheme text, AppTokens tokens) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    textTheme: text,
    scaffoldBackgroundColor: scheme.surface,
    splashFactory: InkSparkle.splashFactory, // ou NoSplash p/ domar (ver components)
    extensions: [tokens],

    // component themes — o coração da consistência:
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: tokens.radii.md),
      clipBehavior: Clip.antiAlias,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(/* ver components.md */),
    filledButtonTheme: FilledButtonThemeData(/* ... */),
    outlinedButtonTheme: OutlinedButtonThemeData(/* ... */),
    textButtonTheme: TextButtonThemeData(/* ... */),
    inputDecorationTheme: InputDecorationTheme(/* ver components.md */),
    chipTheme: ChipThemeData(/* ... */),
    dialogTheme: DialogThemeData(/* ... */),
    snackBarTheme: SnackBarThemeData(/* ... */),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1),
    pageTransitionsTheme: const PageTransitionsTheme(/* ver motion */),
  );
}
```

> Nota de versão: os nomes dos _theme data_ mudaram com o tempo (ex. `CardTheme` → `CardThemeData`, `DialogTheme` → `DialogThemeData`) nas versões recentes do Flutter. Se o `flutter analyze` reclamar, confira o nome correto para a sua versão. Material 3 é default desde o Flutter 3.16, então `useMaterial3: true` é redundante em projetos novos, mas explicitá-lo não custa.

## Consumindo tokens

Nos widgets, **nunca** literais. Sempre via tema:

```dart
final scheme = Theme.of(context).colorScheme;
final text = Theme.of(context).textTheme;
final t = Theme.of(context).extension<AppTokens>()!;

return Padding(
  padding: EdgeInsets.all(t.gap.lg),               // não EdgeInsets.all(16)
  child: Container(
    decoration: BoxDecoration(
      color: scheme.surfaceContainer,              // não Color(0xFF...)
      borderRadius: t.radii.md,                     // não BorderRadius.circular(12)
      boxShadow: t.shadowSoft,                       // sombra desenhada
    ),
    child: Text('Olá', style: text.titleMedium),     // não TextStyle(fontSize: 18)
  ),
);
```

Dica de ergonomia: crie extensions de contexto para reduzir boilerplate (opcional, mas profissionais costumam ter):

```dart
extension ThemeX on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
}
// uso: context.colors.primary, context.tokens.gap.md
```

## Centralizando cor

Regra simples e poderosa: **cor crua (`Color(0x...)` / `Colors.X`) só pode existir no arquivo de tema/paleta.** Em qualquer outro lugar é `colorScheme.*` ou um token semântico. O scanner deste skill aplica exatamente essa regra (arquivos com nome `theme`/`colors`/`tokens`/`palette` são a casa permitida das cores; fora deles, cor crua vira `warning`).

Por quê: cor descentralizada impossibilita rebrand, dark mode e consistência. Quando tudo vem do `ColorScheme`, trocar a marca é editar um arquivo, e o dark mode "simplesmente funciona".

Mapeie cores para papéis semânticos do M3, não para nomes literais:
- fundo da tela → `surface`
- card/superfície elevada → `surfaceContainer` / `surfaceContainerLow/High`
- ação primária → `primary` / `onPrimary`
- destaque secundário → `secondary` / `tertiary`
- erro → `error` / `onError`
- bordas/divisórias → `outline` / `outlineVariant`
- sucesso/aviso (não existem no M3) → tokens semânticos no `AppTokens`

## Checklist

- [ ] Existe um arquivo de tema único com `ColorScheme` (light+dark) desenhado, não `fromSeed` genérico.
- [ ] Há um `ThemeExtension` (`AppTokens`) com escalas de espaço/raio, sombras e cores semânticas — com `copyWith` e `lerp`.
- [ ] Espaço, raio, sombra e duração vêm de escalas; nenhum número mágico nas telas.
- [ ] Cor crua só no arquivo de tema; widgets usam `colorScheme`/tokens.
- [ ] Estilos repetíveis estão em _component themes_, não por instância.
- [ ] Dark mode desenhado de propósito, não invertido automaticamente.
