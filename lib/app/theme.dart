/// つづりの見た目（手帳・ノート風）
library;

import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

/// アクセントのこげ茶
const Color _brown = Color(0xFF6D4C41);

/// 見出しに使う明朝体
String? get _serif =>
    GoogleFonts.notoSerifJp(fontWeight: FontWeight.w600).fontFamily;

ThemeData buildLightTheme() => _build(
  brightness: Brightness.light,
  paper: const Color(0xFFFAF6EE),
  card: const Color(0xFFFFFDF8),
);

ThemeData buildDarkTheme() => _build(
  brightness: Brightness.dark,
  paper: const Color(0xFF1E1A16),
  card: const Color(0xFF29231E),
);

ThemeData _build({
  required Brightness brightness,
  required Color paper,
  required Color card,
}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: _brown,
    brightness: brightness,
  ).copyWith(surface: paper);

  final base = ThemeData(colorScheme: scheme, brightness: brightness);
  final serif = _serif;
  TextStyle? s(TextStyle? t) => t?.copyWith(fontFamily: serif);

  // 見出し・タイトルだけ明朝体に
  final text = base.textTheme.copyWith(
    displayLarge: s(base.textTheme.displayLarge),
    displayMedium: s(base.textTheme.displayMedium),
    displaySmall: s(base.textTheme.displaySmall),
    headlineLarge: s(base.textTheme.headlineLarge),
    headlineMedium: s(base.textTheme.headlineMedium),
    headlineSmall: s(base.textTheme.headlineSmall),
    titleLarge: s(base.textTheme.titleLarge),
    titleMedium: s(base.textTheme.titleMedium),
  );

  final line = scheme.outlineVariant.withValues(alpha: 0.6);

  return base.copyWith(
    scaffoldBackgroundColor: paper,
    textTheme: text,
    appBarTheme: AppBarTheme(
      backgroundColor: paper,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: text.titleLarge?.copyWith(color: scheme.onSurface),
    ),
    cardTheme: CardThemeData(
      color: card,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: line),
      ),
    ),
    dividerTheme: DividerThemeData(color: line),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: card,
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.primaryContainer,
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: card,
      indicatorColor: scheme.primaryContainer,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: card,
      surfaceTintColor: Colors.transparent,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: card,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: text.titleLarge?.copyWith(color: scheme.onSurface),
    ),
  );
}
