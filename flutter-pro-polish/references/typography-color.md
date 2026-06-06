# Typography & Color — fugindo do Roboto e do lavanda padrão

Estes são os dois tells mais fortes de "cara de Flutter". Roboto cru e o `ColorScheme` lavanda do `fromSeed(seedColor: Colors.deepPurple)` (ou o seed default) gritam "projeto de tutorial". Trocá-los é o passo de maior retorno visual — comece por aqui.

## Índice
- [Tipografia: o maior retorno](#tipografia)
- [Escolhendo a fonte](#escolhendo-a-fonte)
- [Aplicando a fonte (google_fonts ou empacotada)](#aplicando-a-fonte)
- [A escala tipográfica](#a-escala-tipografica)
- [Cor: fugindo do lavanda](#cor)
- [Construindo uma paleta intencional](#construindo-uma-paleta)
- [Dark mode de verdade](#dark-mode)

## Tipografia

Tipografia é ~80% da percepção de "profissional". Um app com fonte e hierarquia bem resolvidas já parece premium mesmo com paleta neutra. Três decisões importam:

1. **A família** (fugir do Roboto).
2. **A hierarquia** (pesos e tamanhos com contraste claro entre título, corpo, legenda).
3. **O acabamento** (`height`/line-height e `letterSpacing` ajustados — defaults costumam ser apertados demais em títulos e largos demais em corpo).

## Escolhendo a fonte

Princípio: combine com a marca, não com a moda. Mas como ponto de partida confiável e não-genérico:

- **SaaS/produto limpo e moderno:** `Inter`, `Geist`, `Manrope`, `Plus Jakarta Sans`. Inter é o "seguro" — neutro e legível em qualquer tamanho.
- **Mais caráter/editorial:** par de fontes — display serifada (`Fraunces`, `Newsreader`, `Lora`) para títulos + sans neutra para corpo.
- **Técnico/dados:** sans neutra + uma mono (`JetBrains Mono`, `Geist Mono`) para números/código.
- **Evite o clichê:** `Poppins` em tudo virou o novo "default genérico" — geométrica demais para corpo. Use com parcimônia, se usar.

Regra: no máximo **duas** famílias (uma display + uma de corpo). Mais que isso parece amador. Muitas vezes uma família só, bem usada nos pesos, já basta.

## Aplicando a fonte

**Opção A — `google_fonts` (mais rápido para começar).** Adicione `google_fonts` ao `pubspec.yaml` e gere o `TextTheme` a partir da família escolhida:

```dart
import 'package:google_fonts/google_fonts.dart';

TextTheme buildTextTheme(ColorScheme scheme) {
  final base = ThemeData(brightness: scheme.brightness).textTheme;
  return GoogleFonts.interTextTheme(base).apply(
    bodyColor: scheme.onSurface,
    displayColor: scheme.onSurface,
  );
}
// Par de fontes: GoogleFonts.fraunces() nos displays, GoogleFonts.interTextTheme() no resto.
```

> Atenção em produção: por padrão `google_fonts` baixa a fonte em runtime na primeira execução (precisa de rede e pode dar "flash" de fonte). Para apps sérios, **empacote os arquivos** `.ttf` e desligue o fetch (`GoogleFonts.config.allowRuntimeFetching = false;`), ou use a Opção B. Confira a doc atual do pacote no pub.dev — a API de fontes do Flutter mudou recentemente (Material e Cupertino foram desacoplados).

**Opção B — fonte empacotada (recomendado para release).** Coloque os `.ttf` em `assets/fonts/`, declare no `pubspec.yaml` e use `fontFamily`:

```yaml
flutter:
  fonts:
    - family: Inter
      fonts:
        - asset: assets/fonts/Inter-Regular.ttf
        - asset: assets/fonts/Inter-Medium.ttf
          weight: 500
        - asset: assets/fonts/Inter-SemiBold.ttf
          weight: 600
        - asset: assets/fonts/Inter-Bold.ttf
          weight: 700
```

```dart
ThemeData(fontFamily: 'Inter', /* ... */);
```

O `assets/app_theme.dart` deste skill usa a Opção B por default (zero dependência) e traz a linha do `google_fonts` comentada e pronta — descomente se preferir a Opção A.

## A escala tipográfica

Não invente `fontSize` por tela. Defina um `TextTheme` e use seus papéis (`displayLarge`, `headlineMedium`, `titleLarge`, `bodyLarge`, `bodyMedium`, `labelLarge`...). Princípios de acabamento que separam profissional de cru:

- **Títulos:** `letterSpacing` levemente negativo (`-0.5` a `-1.5` em displays grandes) deixa moderno e "apertado". `height` ~1.1–1.25.
- **Corpo:** `height` ~1.4–1.6 para legibilidade. `letterSpacing` ~0.
- **Labels/botões:** peso 600, `letterSpacing` ~0.1–0.5.
- **Contraste de peso:** título 600/700 vs. corpo 400 cria hierarquia. Tudo no mesmo peso parece chapado.

Exemplo de overrides sobre a base:

```dart
text.copyWith(
  displayLarge: text.displayLarge?.copyWith(
      fontWeight: FontWeight.w700, letterSpacing: -1.0, height: 1.1),
  titleLarge: text.titleLarge?.copyWith(
      fontWeight: FontWeight.w600, letterSpacing: -0.3),
  bodyMedium: text.bodyMedium?.copyWith(height: 1.5),
  labelLarge: text.labelLarge?.copyWith(
      fontWeight: FontWeight.w600, letterSpacing: 0.2),
);
```

Acessibilidade: nunca trave o tamanho de fonte. Respeite o `MediaQuery.textScaler` do sistema. Teste com fonte grande — layout que quebra com texto grande é amador (e cruza com o tema overflow).

## Cor

O lavanda do M3 vem de `ColorScheme.fromSeed` com seed roxo/azul stock. `fromSeed` em si é uma ferramenta legítima — o problema é usar a seed default ou uma `Colors.X` stock e parar aí. Duas saídas profissionais:

1. **`fromSeed` com seed da marca + ajustes.** Use a cor real da marca como seed e então sobrescreva os papéis que ficaram estranhos. Bom equilíbrio entre esforço e harmonia automática.
2. **`ColorScheme` desenhado à mão.** Especifique os papéis principais explicitamente. Mais controle, visual mais único. É o que o asset faz.

```dart
// Saída 1: seed da marca, com correções
final scheme = ColorScheme.fromSeed(
  seedColor: const Color(0xFF22C7F0),     // cor da marca, não Colors.deepPurple
  brightness: Brightness.light,
).copyWith(
  surface: const Color(0xFFFBFBFD),        // fundo levemente off-white, não branco puro
  // ajuste primary/secondary se o gerado destoar da marca
);

// Saída 2: desenhado à mão (controle total)
const scheme = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFF1A1A2E),
  onPrimary: Color(0xFFFFFFFF),
  secondary: Color(0xFF22C7F0),
  onSecondary: Color(0xFF031527),
  surface: Color(0xFFFBFBFD),
  onSurface: Color(0xFF1A1A1A),
  error: Color(0xFFB3261E),
  onError: Color(0xFFFFFFFF),
  // ...os demais papéis
);
```

## Construindo uma paleta

Princípios de paleta que leem como profissional:

- **Off-white, não branco puro.** Fundo `#FBFBFD` em vez de `#FFFFFF` reduz a "cara de protótipo" e cansa menos o olho. Superfícies elevadas um tom acima.
- **Neutros com temperatura.** Cinzas com leve viés (quente ou frio) parecem desenhados; cinza neutro puro parece padrão.
- **Uma cor de destaque, usada com parcimônia.** Profissionais usam a cor primária em poucos pontos de ação; o resto é neutro. Tela colorida demais parece amadora.
- **Contraste suficiente.** Texto sobre fundo deve passar WCAG AA (4.5:1 para corpo). Lavanda claro sobre branco costuma falhar — outro motivo para sair dele.
- **Cores semânticas separadas.** `success`/`warning`/`info` não existem no `ColorScheme` do M3 — coloque no `AppTokens` (veja `design-tokens.md`), não use `Colors.green` solto.

## Dark mode

Dark mode profissional é **desenhado**, não invertido. Erros comuns que entregam amadorismo:

- **Preto puro (`#000`) como fundo.** Use cinza-escuro (`#121212`–`#1A1A1A`); preto puro vibra contra texto branco e some a hierarquia de superfícies.
- **Mesma cor primária saturada do light.** Cores saturadas "queimam" no escuro. Desaturar/clarear levemente a primária no dark.
- **Sombras invisíveis.** No escuro, profundidade vem de **superfície mais clara**, não de sombra. Use a escala `surfaceContainer*` do M3 para hierarquia (mais elevado = mais claro).

```dart
const darkScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFF7FDBFF),      // versão mais clara/menos saturada da primária
  onPrimary: Color(0xFF00131A),
  surface: Color(0xFF121214),       // não #000000
  onSurface: Color(0xFFE6E6E6),
  // surfaceContainerLow/High mais claros para hierarquia por elevação
  // ...
);
```

Registre os dois `AppTokens` (light e dark) e passe `theme:` + `darkTheme:` no `MaterialApp`, deixando `themeMode: ThemeMode.system` (ou controlado pelo usuário). Teste as duas — um dark mode quebrado é pior que não ter.
