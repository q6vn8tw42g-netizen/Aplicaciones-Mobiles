import 'package:flutter/material.dart';

/// Tokens visuales compartidos por mapa, panel y tarjetas.
abstract final class EstacionaYaTokens {
  static const ink = Color(0xFF0F172A);
  static const muted = Color(0xFF475569);
  static const canvas = Color(0xFFF1F5F9);
  static const surface = Color(0xFFFFFFFF);
  static const primary = Color(0xFF2563EB);
  static const primarySoft = Color(0xFFDBEAFE);
  static const available = Color(0xFF166534);
  static const occupied = Color(0xFFB42318);
  static const reserved = Color(0xFF92400E);
  static const offline = Color(0xFF475569);
  static const outline = Color(0xFFE2E8F0);

  static const space4 = 4.0;
  static const space8 = 8.0;
  static const space12 = 12.0;
  static const space16 = 16.0;
  static const space20 = 20.0;
  static const space24 = 24.0;
  static const space32 = 32.0;

  static const radius12 = 12.0;
  static const radius16 = 16.0;
  static const radius20 = 20.0;
  static const radius24 = 24.0;
}

abstract final class EstacionaYaTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: EstacionaYaTokens.primary,
      brightness: Brightness.light,
      primary: EstacionaYaTokens.primary,
      surface: EstacionaYaTokens.surface,
      error: EstacionaYaTokens.occupied,
    );

    return ThemeData(
      useMaterial3: true,
      primaryColor: EstacionaYaTokens.primary,
      colorScheme: scheme,
      scaffoldBackgroundColor: EstacionaYaTokens.canvas,
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          color: EstacionaYaTokens.ink,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        titleMedium: TextStyle(
          color: EstacionaYaTokens.ink,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        bodyMedium: TextStyle(
          color: EstacionaYaTokens.ink,
          fontSize: 14,
        ),
        bodySmall: TextStyle(
          color: EstacionaYaTokens.muted,
          fontSize: 12,
        ),
      ),
      cardTheme: CardThemeData(
        color: EstacionaYaTokens.surface,
        elevation: 1,
        shadowColor: const Color(0x140F172A),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EstacionaYaTokens.radius20),
          side: const BorderSide(color: EstacionaYaTokens.outline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(EstacionaYaTokens.radius12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: EstacionaYaTokens.ink,
          minimumSize: const Size(48, 48),
          side: const BorderSide(color: EstacionaYaTokens.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(EstacionaYaTokens.radius12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
