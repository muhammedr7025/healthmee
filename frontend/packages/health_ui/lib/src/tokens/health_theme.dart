import 'package:flutter/material.dart';

import 'health_colors.dart';
import 'health_spacing.dart';
import 'health_typography.dart';

class HealthTheme {
  HealthTheme._();

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: HealthColors.accentPrimary,
      brightness: Brightness.light,
      surface: HealthColors.surface,
      primary: HealthColors.accentPrimary,
      secondary: HealthColors.accentSecondary,
      tertiary: HealthColors.accentTertiary,
      error: HealthColors.alertTrigger,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: HealthColors.bgBase,
      textTheme: TextTheme(
        displaySmall: HealthTypography.display(),
        bodyMedium: HealthTypography.body(),
        labelLarge: HealthTypography.label(),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: HealthColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(HealthSpacing.radiusMd)),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: HealthColors.bgBase,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: HealthColors.inkPrimary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: HealthColors.accentPrimary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(HealthSpacing.radiusSm)),
          padding: const EdgeInsets.symmetric(horizontal: HealthSpacing.lg, vertical: HealthSpacing.sm + 4),
          textStyle: HealthTypography.body(weight: FontWeight.w600, color: Colors.white),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: HealthColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HealthSpacing.radiusSm),
          borderSide: BorderSide(color: HealthColors.divider),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: HealthSpacing.md, vertical: HealthSpacing.sm + 4),
      ),
    );
  }
}
