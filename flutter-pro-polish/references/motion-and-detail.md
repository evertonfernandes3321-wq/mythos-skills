# Motion & Detail — movimento intencional e os detalhes que separam amador de profissional

Movimento e micro-detalhes são a última camada. Bem feitos, deixam o app "vivo" e caro. Mal feitos (ou ausentes), entregam o default ou o amadorismo. A regra de ouro do movimento profissional: **sutil, rápido, consistente**. Animação chamativa cansa e atrapalha.

## Índice
- [Tokens de duração e curva](#tokens-de-movimento)
- [Transição de página (o tell na navegação)](#transicao-de-pagina)
- [Micro-interações de toque](#micro-interacoes)
- [Entrada de conteúdo](#entrada-de-conteudo)
- [Os detalhes pequenos](#detalhes)

## Tokens de movimento

Como cor e espaço, **duração e curva são tokens** — não valores soltos por animação. Inconsistência de timing é um tell sutil mas real.

```dart
class Motion {
  static const fast = Duration(milliseconds: 150);   // toques, hovers, switches
  static const base = Duration(milliseconds: 250);   // transições padrão
  static const slow = Duration(milliseconds: 400);   // entradas grandes, sheets

  // curvas "emphasized" do Material 3 (aceleração assimétrica = orgânico)
  static const emphasized = Cubic(0.2, 0.0, 0.0, 1.0);
  static const emphasizedDecel = Cubic(0.05, 0.7, 0.1, 1.0);
  static const standard = Cubic(0.2, 0.0, 0.0, 1.0);
}
```

Princípio: a maioria das interações deve ser **rápida** (150–250ms). Só entradas grandes passam de 300ms. Curvas com desaceleração (rápido no início, suave no fim) parecem naturais; `Curves.linear` parece robótico; o `ease` default parece "de tutorial".

## Transição de página

A `PageTransitionsTheme` default usa o slide por plataforma (Cupertino no iOS, Zoom/fade no Android). Não é "errada", mas é reconhecível e às vezes destoa de um app com identidade própria. Uma transição custom unifica a sensação entre plataformas. Padrões profissionais comuns:

- **Fade-through** — a saída some enquanto a entrada aparece (bom para navegação entre seções não relacionadas).
- **Shared-axis** — leve deslize + fade no mesmo eixo (bom para fluxos sequenciais, tipo onboarding).

O `assets/motion.dart` traz um `FadeThroughPageTransitionsBuilder` pronto, sem dependência externa. Aplique no tema:

```dart
pageTransitionsTheme: const PageTransitionsTheme(
  builders: {
    TargetPlatform.android: FadeThroughPageTransitionsBuilder(),
    TargetPlatform.iOS: FadeThroughPageTransitionsBuilder(),
  },
),
```

> Se preferir não reinventar, o pacote `animations` (oficial, do time Material) traz `SharedAxisTransition`, `FadeThroughTransition` e `OpenContainer` (transição "container" de card→tela, que parece muito premium). Confira a versão atual no pub.dev.

## Micro-interações

Pequenos feedbacks que somam:

- **Toque que "afunda":** em vez de ripple em cards/itens, um leve `scale` (0.98) + queda de opacidade ao pressionar parece mais moderno. `assets/motion.dart` traz um `PressableScale` reutilizável (dependency-free, com `AnimatedScale`).
- **Estados de switch/checkbox/seleção:** anime a transição (`Motion.fast`), não troque instantaneamente.
- **Loading:** prefira **skeletons/shimmer** a um `CircularProgressIndicator` centralizado — skeleton parece muito mais profissional e reduz a percepção de espera. (Skeleton = blocos cinza no formato do conteúdo, com um brilho passando.)
- **Aparição de erro/sucesso:** anime entrada (fade+slide curto), não pisque na tela.

Regra: anime **mudança de estado**, não decore. Se a animação não comunica algo (mudou, carregou, apareceu), corte.

## Entrada de conteúdo

Listas e telas que aparecem com um fade+slide sutil leem como cuidado. Mas com parcimônia — animar **cada** item de uma lista longa, toda vez, irrita. Use em entradas de tela e em listas curtas/destaque.

`assets/motion.dart` traz `FadeSlideIn` (dependency-free, via `TweenAnimationBuilder`):

```dart
FadeSlideIn(
  delay: Duration(milliseconds: 60 * index), // stagger leve só nos primeiros itens
  child: MyCard(...),
);
```

> Para coreografias mais ricas, o pacote `flutter_animate` permite `widget.animate().fade().slideY()` de forma muito concisa. É excelente, mas é dependência — use se o projeto já tiver ou se valer a pena. Para o básico, o helper do asset basta.

## Detalhes

Os acabamentos que ninguém nota conscientemente, mas que somam para "profissional":

- **Status bar combinando.** Defina `systemOverlayStyle` no `AppBarTheme` (ou via `SystemChrome.setSystemUIOverlayStyle`) para os ícones da status bar contrastarem com o fundo. Status bar com ícone invisível é tell de descuido.
- **SafeArea de verdade.** Respeite notch e barras de gesto com `SafeArea`/`MediaQuery.viewPadding`. Conteúdo colado na borda ou cortado pelo notch grita amadorismo.
- **Splash screen e ícone do app.** O ícone default do Flutter e a splash branca são tells imediatos. Configure ícone (`flutter_launcher_icons`) e splash (`flutter_native_splash`) com a marca.
- **Estados vazios desenhados.** Tela vazia com só um texto "Nenhum item" parece inacabada. Um empty state com ilustração/ícone + título + ação parece produto.
- **Feedback de toque em tudo que é tocável.** Todo elemento clicável precisa de **algum** feedback (escala, overlay, ripple sutil). Nenhum feedback = parece travado.
- **Bordas e divisórias finas e discretas.** `outlineVariant` (1px) separa sem poluir. Divisória grossa/escura é tell de Material cru.
- **Consistência acima de tudo.** O mesmo raio, o mesmo espaçamento, a mesma família de sombra, as mesmas durações — repetidos por todo o app. Consistência é, sozinha, ~metade da percepção de "profissional".

Lembre: o objetivo não é mais efeitos, é **menos surpresas**. Um app onde tudo se comporta de forma previsível e harmônica lê como profissional; um cheio de animações distintas e timings diferentes lê como vibecoding.
