import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Tipografi tunggal: Inter untuk UI, JetBrains Mono untuk kode/angka.
/// Font dibundel di repo (bukan google_fonts) supaya offline & konsisten.
abstract final class AppTypography {
  static const String ui = 'Inter';
  static const String mono = 'JetBrainsMono';

  static TextTheme textTheme(Brightness b) {
    final Color dasar = b == Brightness.dark ? AppColors.textDark : AppColors.textLight;
    final Color redup =
        b == Brightness.dark ? AppColors.textMutedDark : AppColors.textMutedLight;

    TextStyle s(
      double size,
      FontWeight weight, {
      double? height,
      double? spacing,
      Color? color,
    }) =>
        TextStyle(
          fontFamily: ui,
          fontSize: size,
          fontWeight: weight,
          height: height,
          letterSpacing: spacing,
          color: color ?? dasar,
        );

    return TextTheme(
      displaySmall: s(32, FontWeight.w800, height: 1.15, spacing: -0.6),
      headlineMedium: s(26, FontWeight.w800, height: 1.2, spacing: -0.4),
      headlineSmall: s(22, FontWeight.w700, height: 1.25, spacing: -0.3),
      titleLarge: s(19, FontWeight.w700, height: 1.3, spacing: -0.2),
      titleMedium: s(16, FontWeight.w600, height: 1.35),
      titleSmall: s(14, FontWeight.w600, height: 1.35, color: redup),
      bodyLarge: s(16, FontWeight.w400, height: 1.5),
      bodyMedium: s(15, FontWeight.w400, height: 1.5),
      bodySmall: s(13, FontWeight.w400, height: 1.45, color: redup),
      labelLarge: s(14, FontWeight.w600, height: 1.2),
      labelMedium: s(12.5, FontWeight.w600, height: 1.2, color: redup),
      labelSmall: s(11.5, FontWeight.w500, height: 1.2, color: redup),
    );
  }

  static TextStyle mono({
    double size = 13,
    FontWeight weight = FontWeight.w400,
    Color? color,
  }) =>
      TextStyle(
        fontFamily: mono,
        fontSize: size,
        fontWeight: weight,
        height: 1.5,
        color: color,
      );
}
