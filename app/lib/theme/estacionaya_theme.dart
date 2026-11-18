import 'package:flutter/material.dart';

/// Tokens visuales compartidos por mapa, panel y tarjetas.
abstract final class EstacionaYaTokens {
  static const night = Color(0xFF142B49);
  static const ink = Color(0xFF111827);
  static const muted = Color(0xFF475569);
  static const canvas = Color(0xFFF6F8FC);
  static const surface = Color(0xFFFFFFFF);
  static const primary = Color(0xFF2563EB);
  static const primarySoft = Color(0xFFEFF6FF);
  static const available = Color(0xFF166534);
  static const occupied = Color(0xFFB42318);
  static const reserved = Color(0xFF92400E);
  static const offline = Color(0xFF475569);
  static const outline = Color(0xFFE2E8F0);
  static const availableSoft = Color(0xFFEDF8F0);
  static const occupiedSoft = Color(0xFFFEF0EE);
  static const softShadow = [
    BoxShadow(color: Color(0x0C142B49), blurRadius: 24, offset: Offset(0, 6)),
  ];

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
      onPrimary: Colors.white,
      secondary: EstacionaYaTokens.night,
      surface: EstacionaYaTokens.surface,
      onSurface: EstacionaYaTokens.ink,
      error: EstacionaYaTokens.occupied,
    );

    return ThemeData(
      useMaterial3: true,
      primaryColor: EstacionaYaTokens.primary,
      colorScheme: scheme,
      scaffoldBackgroundColor: EstacionaYaTokens.canvas,
      visualDensity: VisualDensity.standard,
      dividerTheme: const DividerThemeData(
        color: EstacionaYaTokens.outline,
        thickness: 1,
        space: 1,
      ),
      iconTheme: const IconThemeData(color: EstacionaYaTokens.muted, size: 22),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: EstacionaYaTokens.primary,
        linearTrackColor: EstacionaYaTokens.primarySoft,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: EstacionaYaTokens.canvas,
        foregroundColor: EstacionaYaTokens.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: EstacionaYaTokens.canvas,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: EstacionaYaTokens.outline)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: EstacionaYaTokens.outline)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                const BorderSide(color: EstacionaYaTokens.primary, width: 2)),
        errorMaxLines: 3,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: EstacionaYaTokens.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: EstacionaYaTokens.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 44)),
          textStyle: const WidgetStatePropertyAll(
              TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        ),
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(
            color: EstacionaYaTokens.ink,
            fontSize: 20,
            letterSpacing: -.55,
            fontWeight: FontWeight.w700,
            height: 1.25),
        headlineSmall: TextStyle(
          color: EstacionaYaTokens.ink,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          height: 1.2,
        ),
        titleMedium: TextStyle(
          color: EstacionaYaTokens.ink,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: -.2,
          height: 1.3,
        ),
        bodyMedium: TextStyle(
          color: EstacionaYaTokens.ink,
          fontSize: 14,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          color: EstacionaYaTokens.muted,
          fontSize: 12,
          height: 1.45,
        ),
        labelSmall: TextStyle(
            color: EstacionaYaTokens.muted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: EstacionaYaTokens.surface,
        indicatorColor: EstacionaYaTokens.primarySoft,
        indicatorShape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected)
                ? EstacionaYaTokens.primary
                : EstacionaYaTokens.muted)),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? EstacionaYaTokens.primary
                : EstacionaYaTokens.muted,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            fontSize: 12)),
      ),
      chipTheme: ChipThemeData(
        selectedColor: EstacionaYaTokens.primarySoft,
        backgroundColor: EstacionaYaTokens.surface,
        side: const BorderSide(color: EstacionaYaTokens.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      cardTheme: CardThemeData(
        color: EstacionaYaTokens.surface,
        elevation: 0,
        shadowColor: const Color(0x140F172A),
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EstacionaYaTokens.radius20),
          side: const BorderSide(color: EstacionaYaTokens.outline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          elevation: 0,
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
