// overflow_guard.dart
//
// Helper de teste pra provar que uma tela não dá overflow em nenhum tamanho
// de device. Copie este arquivo para `test/` (ex.: test/support/overflow_guard.dart)
// e use `expectNoOverflow(...)` dentro de `testWidgets`.
//
// Depende só de flutter_test e flutter/material.dart — nada externo.
//
// Como funciona: quando um RenderFlex (Row/Column) estoura em modo debug, ele
// reporta um FlutterError. Em flutter_test esse erro é capturado e fica
// disponível via `tester.takeException()`. Pumpamos a tela em vários tamanhos e
// asserimos que nenhuma exceção foi disparada.
//
// Requer Flutter 3.10+ (usa a API `tester.view`). Para versões antigas, troque
// `tester.view.physicalSize`/`devicePixelRatio` por
// `tester.binding.window.physicalSizeTestValue`/`devicePixelRatioTestValue` e
// os resets por `clearPhysicalSizeTestValue()`/`clearDevicePixelRatioTestValue()`.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tamanhos que pegam os overflows que realmente mordem: um celular pequeno
/// (o clássico "não cabe"), um celular comum e um tablet em retrato.
const List<Size> kOverflowTestSizes = <Size>[
  Size(320, 568), // iPhone SE — o menor que ainda importa
  Size(411, 891), // Pixel-ish — Android comum
  Size(800, 1280), // tablet retrato
];

/// Pumpa [widget] em cada tamanho de [sizes] e FALHA o teste se algum disparar
/// overflow (a barra listrada amarela/preta do RenderFlex).
///
/// - [sizes]: tamanhos lógicos de tela a testar. Padrão: [kOverflowTestSizes].
/// - [simulateKeyboard]: se true, injeta `viewInsets.bottom` simulando o
///   teclado aberto — use pra telas de formulário. (Só tem efeito com o wrapper
///   padrão; se você passar um [wrapper] customizado, injete os insets nele.)
/// - [wrapper]: envelope customizado em volta do widget (ex.: providers,
///   MaterialApp.router, tema). Se nulo, usa um MaterialApp mínimo.
///
/// Exemplo:
/// ```dart
/// testWidgets('UserTile não estoura', (tester) async {
///   await expectNoOverflow(tester, UserTile(user: longNameUser));
/// });
///
/// testWidgets('LoginForm não estoura com teclado', (tester) async {
///   await expectNoOverflow(tester, const LoginForm(), simulateKeyboard: true);
/// });
/// ```
Future<void> expectNoOverflow(
  WidgetTester tester,
  Widget widget, {
  List<Size> sizes = kOverflowTestSizes,
  bool simulateKeyboard = false,
  Widget Function(Widget child)? wrapper,
}) async {
  // Garante que o tamanho da view volta ao normal depois do teste, mesmo que
  // ele falhe — senão "vaza" pro próximo teste do arquivo.
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  for (final Size size in sizes) {
    // devicePixelRatio 1.0 faz tamanho lógico == tamanho físico, então
    // Size(320, 568) vira 320x568 pontos lógicos (o que o layout enxerga).
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;

    final Widget tree = wrapper != null
        ? wrapper(widget)
        : MaterialApp(
            debugShowCheckedModeBanner: false,
            home: widget,
            // O builder roda ABAIXO da MediaQuery do MaterialApp, então o
            // copyWith dos insets chega no Scaffold (que lê viewInsets.bottom
            // pra reagir ao teclado).
            builder: simulateKeyboard
                ? (BuildContext context, Widget? child) => MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        viewInsets: const EdgeInsets.only(bottom: 300),
                      ),
                      child: child!,
                    )
                : null,
          );

    await tester.pumpWidget(tree);
    // Um segundo pump curto deixa animações implícitas e FutureBuilders com
    // Future já resolvido assentarem, SEM o risco de travar de `pumpAndSettle`
    // em telas com animação infinita (ex.: CircularProgressIndicator).
    await tester.pump(const Duration(milliseconds: 350));

    final Object? exception = tester.takeException();
    expect(
      exception,
      isNull,
      reason: 'Overflow detectado em '
          '${size.width.toInt()}x${size.height.toInt()}'
          '${simulateKeyboard ? ' (teclado aberto)' : ''}:\n$exception',
    );
  }
}

/// Versão pra um único tamanho, quando você só quer focar no menor device.
///
/// ```dart
/// await expectNoOverflowAt(tester, const Dashboard(), const Size(320, 568));
/// ```
Future<void> expectNoOverflowAt(
  WidgetTester tester,
  Widget widget,
  Size size, {
  bool simulateKeyboard = false,
  Widget Function(Widget child)? wrapper,
}) {
  return expectNoOverflow(
    tester,
    widget,
    sizes: <Size>[size],
    simulateKeyboard: simulateKeyboard,
    wrapper: wrapper,
  );
}
