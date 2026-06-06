// app_theme.dart
//
// Tema drop-in baseado em design tokens — o oposto do Flutter "de fábrica".
// Mantenha junto com `motion.dart` (mesma pasta), pois este arquivo o importa.
//
// COMO USAR
//   1. Copie este arquivo (e motion.dart) para lib/theme/.
//   2. Troque a paleta em `_LightPalette`/`_DarkPalette` pela cor da SUA marca.
//   3. Troque a fonte: por padrão usa fontFamily 'Inter' (empacote os .ttf no
//      pubspec — veja typography-color.md). Para google_fonts, descomente as
//      linhas marcadas e adicione o pacote.
//   4. No MaterialApp:
//        MaterialApp(
//          theme: AppTheme.light,
//          darkTheme: AppTheme.dark,
//          themeMode: ThemeMode.system,
//        )
//   5. Nos widgets, consuma via Theme.of(context) — nunca literais.
//
// Zero dependências externas (só flutter/material.dart). Testado contra a API
// do Flutter 3.4x (Material 3). Se o analyzer reclamar de um nome (ex.
// CardThemeData, withValues), ajuste para a sua versão — veja os comentários.

import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart'; // (opcional) descomente p/ google_fonts

import 'motion.dart';

// ===========================================================================
// FONTE
// ===========================================================================
// Empacote os .ttf no pubspec.yaml sob `family: Inter` (ver typography-color.md),
// ou troque por outra família. Para usar google_fonts em vez de fonte empacotada,
// deixe _fontFamily = null e descomente o uso de GoogleFonts em `_text()`.
const String? _fontFamily = 'Inter';

// ===========================================================================
// PALETA — troque pela cor da SUA marca (não use o lavanda padrão!)
// ===========================================================================
class _LightPalette {
  static const primary = Color(0xFF1F1F29); // ink — botões filled "premium minimal"
  static const onPrimary = Color(0xFFFFFFFF);
  static const secondary = Color(0xFF4C63E6); // accent (ações/links/destaques)
  static const onSecondary = Color(0xFFFFFFFF);
  static const tertiary = Color(0xFF2BA98E);
  static const onTertiary = Color(0xFFFFFFFF);

  static const surface = Color(0xFFFBFBFD); // off-white, não branco puro
  static const onSurface = Color(0xFF1A1A1F);
  static const onSurfaceVariant = Color(0xFF5C5C66);
  static const surfaceContainerLowest = Color(0xFFFFFFFF);
  static const surfaceContainerLow = Color(0xFFF5F5F8);
  static const surfaceContainer = Color(0xFFEFEFF3);
  static const surfaceContainerHigh = Color(0xFFE8E8EE);
  static const surfaceContainerHighest = Color(0xFFE1E1E8);

  static const outline = Color(0xFFC7C7D1);
  static const outlineVariant = Color(0xFFE3E3EA);
  static const error = Color(0xFFB3261E);
  static const onError = Color(0xFFFFFFFF);
  static const inverseSurface = Color(0xFF2E2E36);
  static const onInverseSurface = Color(0xFFF2F2F5);

  // cores semânticas que NÃO existem no ColorScheme do M3 (vão para AppTokens)
  static const success = Color(0xFF2E7D52);
  static const onSuccess = Color(0xFFFFFFFF);
  static const warning = Color(0xFFB7791F);
  static const onWarning = Color(0xFFFFFFFF);
  static const info = Color(0xFF2F6FED);
}

class _DarkPalette {
  static const primary = Color(0xFFE6E6EA); // ink claro p/ filled no escuro
  static const onPrimary = Color(0xFF1A1A1F);
  static const secondary = Color(0xFF93A4FF); // accent menos saturado p/ dark
  static const onSecondary = Color(0xFF0A1240);
  static const tertiary = Color(0xFF6FD6BC);
  static const onTertiary = Color(0xFF00251C);

  static const surface = Color(0xFF121215); // não #000000
  static const onSurface = Color(0xFFE6E6EA);
  static const onSurfaceVariant = Color(0xFFA6A6B0);
  static const surfaceContainerLowest = Color(0xFF0D0D10);
  static const surfaceContainerLow = Color(0xFF18181C); // mais claro = mais elevado
  static const surfaceContainer = Color(0xFF1D1D22);
  static const surfaceContainerHigh = Color(0xFF26262C);
  static const surfaceContainerHighest = Color(0xFF313138);

  static const outline = Color(0xFF45454E);
  static const outlineVariant = Color(0xFF2C2C32);
  static const error = Color(0xFFF2B8B5);
  static const onError = Color(0xFF601410);
  static const inverseSurface = Color(0xFFE6E6EA);
  static const onInverseSurface = Color(0xFF1A1A1F);

  static const success = Color(0xFF6FD69E);
  static const onSuccess = Color(0xFF00301B);
  static const warning = Color(0xFFE7B85C);
  static const onWarning = Color(0xFF2E2100);
  static const info = Color(0xFF9DBBFF);
}

// ===========================================================================
// ESCALAS (não mudam com o tema — objetos const reutilizáveis)
// ===========================================================================
@immutable
class Gaps {
  const Gaps();
  final double xs = 4;
  final double sm = 8;
  final double md = 12;
  final double lg = 16;
  final double xl = 24;
  final double xxl = 32;
  final double huge = 48;
}

@immutable
class Radii {
  const Radii();
  final BorderRadius sm = const BorderRadius.all(Radius.circular(8));
  final BorderRadius md = const BorderRadius.all(Radius.circular(12));
  final BorderRadius lg = const BorderRadius.all(Radius.circular(20));
  final BorderRadius full = const BorderRadius.all(Radius.circular(999));
}

// ===========================================================================
// THEME EXTENSION — tokens type-safe e theme-aware (com copyWith + lerp!)
// ===========================================================================
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    this.gap = const Gaps(),
    this.radii = const Radii(),
    required this.shadowSoft,
    required this.shadowLifted,
    required this.success,
    required this.onSuccess,
    required this.warning,
    required this.onWarning,
    required this.info,
  });

  final Gaps gap;
  final Radii radii;
  final List<BoxShadow> shadowSoft; // cards
  final List<BoxShadow> shadowLifted; // menus, dialogs
  final Color success;
  final Color onSuccess;
  final Color warning;
  final Color onWarning;
  final Color info;

  @override
  AppTokens copyWith({
    Gaps? gap,
    Radii? radii,
    List<BoxShadow>? shadowSoft,
    List<BoxShadow>? shadowLifted,
    Color? success,
    Color? onSuccess,
    Color? warning,
    Color? onWarning,
    Color? info,
  }) {
    return AppTokens(
      gap: gap ?? this.gap,
      radii: radii ?? this.radii,
      shadowSoft: shadowSoft ?? this.shadowSoft,
      shadowLifted: shadowLifted ?? this.shadowLifted,
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      info: info ?? this.info,
    );
  }

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      gap: gap, // escalas não interpolam
      radii: radii,
      shadowSoft: BoxShadow.lerpList(shadowSoft, other.shadowSoft, t) ?? shadowSoft,
      shadowLifted:
          BoxShadow.lerpList(shadowLifted, other.shadowLifted, t) ?? shadowLifted,
      success: Color.lerp(success, other.success, t) ?? success,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t) ?? onSuccess,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      onWarning: Color.lerp(onWarning, other.onWarning, t) ?? onWarning,
      info: Color.lerp(info, other.info, t) ?? info,
    );
  }
}

// ===========================================================================
// SOMBRAS DESENHADAS (suaves, multicamada, tingidas — não a elevação Material)
// ===========================================================================
const _shadowTint = Color(0xFF1A1A2E);

const List<BoxShadow> _shadowSoftLight = [
  BoxShadow(color: Color(0x0A1A1A2E), blurRadius: 2, offset: Offset(0, 1)),
  BoxShadow(color: Color(0x0F1A1A2E), blurRadius: 12, offset: Offset(0, 4)),
];
const List<BoxShadow> _shadowLiftedLight = [
  BoxShadow(color: Color(0x141A1A2E), blurRadius: 4, offset: Offset(0, 2)),
  BoxShadow(color: Color(0x1F1A1A2E), blurRadius: 24, offset: Offset(0, 12)),
];
// no escuro a profundidade vem da superfície, não da sombra → sombras quase nulas
const List<BoxShadow> _shadowSoftDark = [
  BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 2)),
];
const List<BoxShadow> _shadowLiftedDark = [
  BoxShadow(color: Color(0x4D000000), blurRadius: 24, offset: Offset(0, 12)),
];

// ===========================================================================
// TIPOGRAFIA — hierarquia real (pesos, letter-spacing, line-height)
// ===========================================================================
TextTheme _text(Brightness brightness, Color onSurface) {
  final base = (brightness == Brightness.dark
          ? ThemeData.dark()
          : ThemeData.light())
      .textTheme;

  // Para google_fonts, troque a linha acima por:
  //   final base = GoogleFonts.interTextTheme(
  //       (brightness == Brightness.dark ? ThemeData.dark() : ThemeData.light()).textTheme);

  return base
      .copyWith(
        displayLarge: base.displayLarge
            ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -1.0, height: 1.08),
        displayMedium: base.displayMedium
            ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.8, height: 1.1),
        displaySmall: base.displaySmall
            ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5, height: 1.12),
        headlineLarge: base.headlineLarge
            ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5),
        headlineMedium: base.headlineMedium
            ?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.3),
        headlineSmall:
            base.headlineSmall?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.2),
        titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.2),
        titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        bodyLarge: base.bodyLarge?.copyWith(height: 1.5),
        bodyMedium: base.bodyMedium?.copyWith(height: 1.5),
        bodySmall: base.bodySmall?.copyWith(height: 1.45),
        labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.2),
        labelMedium: base.labelMedium?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.2),
      )
      .apply(bodyColor: onSurface, displayColor: onSurface);
}

// ===========================================================================
// MONTAGEM DO THEMEDATA
// ===========================================================================
class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(
        scheme: const ColorScheme(
          brightness: Brightness.light,
          primary: _LightPalette.primary,
          onPrimary: _LightPalette.onPrimary,
          secondary: _LightPalette.secondary,
          onSecondary: _LightPalette.onSecondary,
          tertiary: _LightPalette.tertiary,
          onTertiary: _LightPalette.onTertiary,
          error: _LightPalette.error,
          onError: _LightPalette.onError,
          surface: _LightPalette.surface,
          onSurface: _LightPalette.onSurface,
          onSurfaceVariant: _LightPalette.onSurfaceVariant,
          surfaceContainerLowest: _LightPalette.surfaceContainerLowest,
          surfaceContainerLow: _LightPalette.surfaceContainerLow,
          surfaceContainer: _LightPalette.surfaceContainer,
          surfaceContainerHigh: _LightPalette.surfaceContainerHigh,
          surfaceContainerHighest: _LightPalette.surfaceContainerHighest,
          outline: _LightPalette.outline,
          outlineVariant: _LightPalette.outlineVariant,
          inverseSurface: _LightPalette.inverseSurface,
          onInverseSurface: _LightPalette.onInverseSurface,
        ),
        tokens: const AppTokens(
          shadowSoft: _shadowSoftLight,
          shadowLifted: _shadowLiftedLight,
          success: _LightPalette.success,
          onSuccess: _LightPalette.onSuccess,
          warning: _LightPalette.warning,
          onWarning: _LightPalette.onWarning,
          info: _LightPalette.info,
        ),
      );

  static ThemeData get dark => _build(
        scheme: const ColorScheme(
          brightness: Brightness.dark,
          primary: _DarkPalette.primary,
          onPrimary: _DarkPalette.onPrimary,
          secondary: _DarkPalette.secondary,
          onSecondary: _DarkPalette.onSecondary,
          tertiary: _DarkPalette.tertiary,
          onTertiary: _DarkPalette.onTertiary,
          error: _DarkPalette.error,
          onError: _DarkPalette.onError,
          surface: _DarkPalette.surface,
          onSurface: _DarkPalette.onSurface,
          onSurfaceVariant: _DarkPalette.onSurfaceVariant,
          surfaceContainerLowest: _DarkPalette.surfaceContainerLowest,
          surfaceContainerLow: _DarkPalette.surfaceContainerLow,
          surfaceContainer: _DarkPalette.surfaceContainer,
          surfaceContainerHigh: _DarkPalette.surfaceContainerHigh,
          surfaceContainerHighest: _DarkPalette.surfaceContainerHighest,
          outline: _DarkPalette.outline,
          outlineVariant: _DarkPalette.outlineVariant,
          inverseSurface: _DarkPalette.inverseSurface,
          onInverseSurface: _DarkPalette.onInverseSurface,
        ),
        tokens: const AppTokens(
          shadowSoft: _shadowSoftDark,
          shadowLifted: _shadowLiftedDark,
          success: _DarkPalette.success,
          onSuccess: _DarkPalette.onSuccess,
          warning: _DarkPalette.warning,
          onWarning: _DarkPalette.onWarning,
          info: _DarkPalette.info,
        ),
      );

  static ThemeData _build({
    required ColorScheme scheme,
    required AppTokens tokens,
  }) {
    final text = _text(scheme.brightness, scheme.onSurface);
    const radii = Radii();

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: text,
      fontFamily: _fontFamily,
      scaffoldBackgroundColor: scheme.surface,
      extensions: [tokens],

      // Ripple domado: troque por NoSplash.splashFactory para remover de vez,
      // mas garanta outro feedback de toque (ver components.md / PressableScale).
      splashFactory: InkSparkle.splashFactory,
      highlightColor: Colors.transparent,

      // Transição de página custom (no lugar do slide padrão por plataforma).
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeThroughPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeThroughPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeThroughPageTransitionsBuilder(),
          TargetPlatform.windows: FadeThroughPageTransitionsBuilder(),
          TargetPlatform.linux: FadeThroughPageTransitionsBuilder(),
        },
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle:
            text.titleLarge?.copyWith(fontWeight: FontWeight.w600, color: scheme.onSurface),
      ),

      // Em versões antigas do Flutter o tipo é `CardTheme` (sem "Data").
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: radii.md,
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 52)),
          padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: radii.md)),
          textStyle: WidgetStatePropertyAll(text.labelLarge),
          elevation: const WidgetStatePropertyAll(0),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 52)),
          backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainerLowest),
          foregroundColor: WidgetStatePropertyAll(scheme.onSurface),
          padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(
            borderRadius: radii.md,
            side: BorderSide(color: scheme.outlineVariant),
          )),
          textStyle: WidgetStatePropertyAll(text.labelLarge),
          elevation: const WidgetStatePropertyAll(0),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 52)),
          padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
          side: WidgetStatePropertyAll(BorderSide(color: scheme.outline)),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: radii.md)),
          textStyle: WidgetStatePropertyAll(text.labelLarge),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: radii.sm)),
          textStyle: WidgetStatePropertyAll(text.labelLarge),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        border: OutlineInputBorder(
            borderRadius: radii.md, borderSide: BorderSide(color: scheme.outlineVariant)),
        enabledBorder: OutlineInputBorder(
            borderRadius: radii.md, borderSide: BorderSide(color: scheme.outlineVariant)),
        focusedBorder: OutlineInputBorder(
            borderRadius: radii.md, borderSide: BorderSide(color: scheme.primary, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: radii.md, borderSide: BorderSide(color: scheme.error)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: radii.md, borderSide: BorderSide(color: scheme.error, width: 1.5)),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainer,
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle: text.labelMedium,
        shape: RoundedRectangleBorder(borderRadius: radii.full),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),

      // Em versões antigas o tipo é `DialogTheme` (sem "Data").
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: radii.lg),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(color: scheme.onInverseSurface),
        shape: RoundedRectangleBorder(borderRadius: radii.md),
        insetPadding: const EdgeInsets.all(16),
      ),

      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),

      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: radii.md),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}

// ===========================================================================
// EXTENSION DE CONTEXTO (ergonomia — opcional, mas reduz boilerplate)
// ===========================================================================
extension ThemeX on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
}

// Uso nos widgets:
//   Container(
//     padding: EdgeInsets.all(context.tokens.gap.lg),
//     decoration: BoxDecoration(
//       color: context.colors.surfaceContainer,
//       borderRadius: context.tokens.radii.md,
//       boxShadow: context.tokens.shadowSoft,
//     ),
//     child: Text('Olá', style: context.text.titleMedium),
//   );
