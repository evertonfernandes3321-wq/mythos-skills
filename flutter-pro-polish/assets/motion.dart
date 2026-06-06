// motion.dart
//
// Tokens de movimento + transição de página custom + helpers de micro-interação.
// Dependency-free (só flutter/material.dart). Mantenha junto com app_theme.dart.
//
// Movimento profissional = sutil, rápido, consistente. Anime MUDANÇA DE ESTADO,
// não decore. Veja references/motion-and-detail.md.

import 'package:flutter/material.dart';

// ===========================================================================
// TOKENS DE MOVIMENTO — duração e curva são tokens, não valores soltos
// ===========================================================================
class Motion {
  Motion._();

  static const Duration fast = Duration(milliseconds: 150); // toques, hovers, switches
  static const Duration base = Duration(milliseconds: 250); // transições padrão
  static const Duration slow = Duration(milliseconds: 400); // entradas grandes, sheets

  // Curvas "emphasized" do Material 3 (aceleração assimétrica = orgânico).
  static const Curve emphasized = Cubic(0.2, 0.0, 0.0, 1.0);
  static const Curve emphasizedDecel = Cubic(0.05, 0.7, 0.1, 1.0);
  static const Curve emphasizedAccel = Cubic(0.3, 0.0, 0.8, 0.15);
  static const Curve standard = Cubic(0.2, 0.0, 0.0, 1.0);
}

// ===========================================================================
// TRANSIÇÃO DE PÁGINA — fade-through (no lugar do slide padrão por plataforma)
// ===========================================================================
// Registre em ThemeData.pageTransitionsTheme (já feito em app_theme.dart):
//   pageTransitionsTheme: const PageTransitionsTheme(builders: {
//     TargetPlatform.android: FadeThroughPageTransitionsBuilder(),
//     TargetPlatform.iOS: FadeThroughPageTransitionsBuilder(), ...
//   })
class FadeThroughPageTransitionsBuilder extends PageTransitionsBuilder {
  const FadeThroughPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Entrada: fade-in na segunda metade + leve scale-up.
    final enter = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.30, 1.0, curve: Motion.emphasizedDecel),
    );
    // Saída (quando esta página é coberta): fade-out na primeira fração.
    final exit = CurvedAnimation(
      parent: secondaryAnimation,
      curve: const Interval(0.0, 0.30, curve: Motion.standard),
    );

    return FadeTransition(
      opacity: Tween<double>(begin: 1.0, end: 0.0).animate(exit),
      child: FadeTransition(
        opacity: enter,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1.0).animate(enter),
          child: child,
        ),
      ),
    );
  }
}

// Alternativa: shared-axis horizontal (bom p/ fluxos sequenciais tipo onboarding).
class SharedAxisXPageTransitionsBuilder extends PageTransitionsBuilder {
  const SharedAxisXPageTransitionsBuilder({this.distance = 30});
  final double distance;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final enter = CurvedAnimation(parent: animation, curve: Motion.emphasized);
    final exit = CurvedAnimation(parent: secondaryAnimation, curve: Motion.emphasized);
    return FadeTransition(
      opacity: Tween<double>(begin: 1.0, end: 0.0)
          .animate(CurvedAnimation(parent: secondaryAnimation, curve: const Interval(0, 0.3))),
      child: FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: const Interval(0.3, 1.0)),
        child: AnimatedBuilder(
          animation: Listenable.merge([enter, exit]),
          builder: (context, c) {
            final dx = (1 - enter.value) * distance - exit.value * distance;
            return Transform.translate(offset: Offset(dx, 0), child: c);
          },
          child: child,
        ),
      ),
    );
  }
}

// ===========================================================================
// ENTRADA DE CONTEÚDO — fade + slide sutil (use com parcimônia!)
// ===========================================================================
// Anime entradas de tela e listas curtas. NÃO anime cada item de uma lista
// longa toda vez — irrita. Para stagger leve, passe delay = const * index nos
// primeiros itens.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = Motion.base,
    this.offsetY = 0.08, // fração da altura do child (8% abaixo → sobe)
    this.curve = Motion.emphasizedDecel,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final double offsetY;
  final Curve curve;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      // anima já no primeiro frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _shown = true);
      });
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) setState(() => _shown = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: _shown ? Offset.zero : Offset(0, widget.offsetY),
      duration: widget.duration,
      curve: widget.curve,
      child: AnimatedOpacity(
        opacity: _shown ? 1.0 : 0.0,
        duration: widget.duration,
        curve: widget.curve,
        child: widget.child,
      ),
    );
  }
}

// ===========================================================================
// TOQUE QUE "AFUNDA" — alternativa moderna ao ripple em cards/itens
// ===========================================================================
// Envolva cards/itens clicáveis. O toque encolhe levemente (e opcionalmente
// reduz opacidade), parecendo mais premium que o splash padrão.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.97,
    this.duration = Motion.fast,
    this.dimOnPress = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final Duration duration;
  final bool dimOnPress;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _set(bool v) {
    if (mounted) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1.0,
        duration: widget.duration,
        curve: Motion.standard,
        child: AnimatedOpacity(
          opacity: widget.dimOnPress && _pressed ? 0.85 : 1.0,
          duration: widget.duration,
          child: widget.child,
        ),
      ),
    );
  }
}
