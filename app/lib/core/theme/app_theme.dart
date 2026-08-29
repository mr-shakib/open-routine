import 'package:flutter/material.dart';

/// Light and dark themes built from one seed colour.
///
/// Both are defined explicitly so nothing inherits a half-set palette, and
/// contrast is checked against the Material 3 defaults rather than hand-picked.
abstract final class AppTheme {
  static const seed = Color(0xFF00696E);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        space: 1,
        thickness: 1,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }
}

/// Semantic colours for the class-type accents.
///
/// Type is never signalled by colour alone -- every card also carries a text
/// label -- so this stays safe for colour-blind users.
extension ClassAccents on ColorScheme {
  Color get labAccent => brightness == Brightness.light
      ? const Color(0xFF7B4E00)
      : const Color(0xFFFFB871);

  Color get optionalAccent => brightness == Brightness.light
      ? const Color(0xFF6B4E9E)
      : const Color(0xFFCFBCFF);
}
