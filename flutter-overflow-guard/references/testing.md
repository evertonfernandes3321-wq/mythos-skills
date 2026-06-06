# Verificando overflow (provar que não estoura)

Overflow é silencioso: a barra listrada só aparece em debug, num device do tamanho errado, e some em release. Por isso "rodei e não vi" não é prova. Este guia mostra como provar com automação, em camadas — do mais barato (estático) ao mais forte (teste de widget multi-tamanho).

## Camada 1 — Scanner heurístico (`scripts/scan_overflow_risks.py`)

Pré-filtro estático. Roda em qualquer máquina com Python 3 (não precisa do Flutter SDK), então serve até em CI leve ou pre-commit.

```bash
python3 scripts/scan_overflow_risks.py lib/
python3 scripts/scan_overflow_risks.py lib/widgets/user_tile.dart
python3 scripts/scan_overflow_risks.py lib/ --json   # saída pra ferramenta/CI
```

O que cada regra procura e por quê:

| Regra | Marca | Raciocínio |
|---|---|---|
| `row-text-no-flex` | `Row` com `Text`/`TextField` mas sem `Expanded`/`Flexible`/`Wrap`/`Spacer` nos filhos diretos | é a causa nº 1 de overflow horizontal |
| `list-in-column` | `ListView`/`GridView` cujo ancestral próximo é `Column` sem `Expanded` em volta | gera `unbounded height` |
| `form-no-scroll` | `Scaffold`/`Column` com `TextField` e sem `SingleChildScrollView`/`ListView` em volta | overflow ao abrir o teclado |
| `text-no-overflow` | `Text` com string longa e sem `overflow:`/`maxLines:` | pode estourar/empurrar |
| `fixed-screen-size` | uso de `height:`/`width:` com número grande (> 400) cravado | quebra entre devices |
| `mediaquery-size` | `MediaQuery.of(context).size` | sugere `MediaQuery.sizeOf(context)` (menos rebuild) |

**É heurística, não verdade absoluta.** A análise é por chave/colchete (não AST completo), então há falsos positivos (ex.: um `Row` que cabe de propósito) e falsos negativos. Trate a saída como uma lista de "olha aqui", priorize pra revisão humana, e confirme com a Camada 3. Cada achado vem com arquivo:linha e a regra, pra você decidir rápido.

## Camada 2 — `flutter analyze` e lints

```bash
flutter analyze
```
Não pega overflow de runtime (é estático e o overflow depende de tamanho real em tempo de execução), mas pega problemas estruturais relacionados e mantém a base limpa. Vale ativar lints úteis no `analysis_options.yaml`:

```yaml
include: package:flutter_lints/flutter.yaml
linter:
  rules:
    sized_box_for_whitespace: true
    use_decorated_box: true
```
Para regras *de verdade* sobre overflow (ex.: proibir `Expanded` fora de `Flex`), dá pra escrever lints customizadas com o pacote `custom_lint` — vale a pena só em base grande; para a maioria, Camada 3 cobre.

## Camada 3 — Teste de widget multi-tamanho (a prova forte)

Esta é a que realmente garante. Quando um `RenderFlex` estoura em debug, ele reporta um `FlutterError`; em `flutter_test`, isso é capturado e fica disponível via `tester.takeException()`. O harness pumpa a tela em vários tamanhos de device e falha se algum disparar overflow.

### Instalação
Copie `assets/overflow_guard.dart` para `test/` do projeto (ex.: `test/support/overflow_guard.dart`). Ele só depende de `flutter_test` e `flutter/material.dart` — nada externo.

### Uso
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'support/overflow_guard.dart';
import 'package:my_app/screens/user_tile.dart';

void main() {
  testWidgets('UserTile não estoura em nenhum tamanho', (tester) async {
    await expectNoOverflow(
      tester,
      UserTile(user: User(name: 'Um nome absurdamente longo que costuma estourar')),
    );
  });

  testWidgets('LoginForm não estoura com o teclado aberto', (tester) async {
    await expectNoOverflow(tester, const LoginForm(), simulateKeyboard: true);
  });

  testWidgets('Dashboard cabe até no celular pequeno', (tester) async {
    await expectNoOverflow(
      tester,
      const Dashboard(),
      sizes: const [Size(320, 568)], // foca no menor device
    );
  });
}
```

### Como funciona (resumo)
Para cada tamanho da lista, o helper: ajusta `tester.view.physicalSize` e `devicePixelRatio`; envolve seu widget num `MaterialApp` mínimo (e injeta `viewInsets` de teclado se `simulateKeyboard: true`); dá `pumpWidget` + `pumpAndSettle`; chama `tester.takeException()` e assere que é `null`. Se houve overflow, a exceção não é nula e o teste falha com o tamanho exato no `reason`. No fim, reseta o tamanho da view via `addTearDown`. Os tamanhos padrão (320×568, 411×891, 800×1280) cobrem celular pequeno, celular comum e tablet — onde os overflows reais aparecem.

### Dica de cobertura
Teste com os **dados que estouram**: o nome mais longo, o preço de cinco dígitos, a lista vazia e a lista cheia, a label traduzida (pt-BR costuma ser mais comprido que en). Overflow quase sempre é dado de borda, não layout "no feliz".

## Camada 4 — Golden tests (opcional)

Golden tests capturam um PNG de referência e comparam pixel a pixel; pegam regressão visual incluindo overflow, mas são mais frágeis (mudou a fonte, quebrou o golden). Use para telas-chave estáveis:
```dart
await expectLater(find.byType(MyScreen), matchesGoldenFile('goldens/my_screen.png'));
```
Gere/atualize com `flutter test --update-goldens`. Para a maioria dos casos, a Camada 3 é suficiente e menos chata de manter.

## No olho (durante o desenvolvimento)

- **Barra listrada:** rode em debug e procure a faixa amarela/preta; o console traz `A RenderFlex overflowed by N pixels`.
- **`debugPaintSizeEnabled`:** em `import 'package:flutter/rendering.dart'`, set `debugPaintSizeEnabled = true` no `main()` pra desenhar as caixas de layout e enxergar quem está pedindo espaço demais.
- **Flutter Inspector (DevTools):** "Select Widget Mode" → clique na barra → veja a subárvore e as constraints de cada nó. A melhor ferramenta pra casos confusos.
- **Device Preview / redimensionar:** rode em web/desktop e arraste a janela, ou use o pacote `device_preview`, pra ver vários tamanhos rápido.

## CI

Ordem barata → cara, falhando cedo:
```bash
python3 scripts/scan_overflow_risks.py lib/ || true   # informativo (heurístico)
flutter analyze                                        # bloqueia em erro estático
flutter test                                           # roda os testes de overflow (Camada 3)
```
Mantenha o scanner como informativo (`|| true`) pra não travar o pipeline com falso positivo, e deixe os testes de widget como a barreira que de fato bloqueia merge.
