import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_motion.dart';
import 'app_shadows.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

export 'app_colors.dart';
export 'app_motion.dart';
export 'app_shadows.dart';
export 'app_spacing.dart';
export 'app_typography.dart';

/// Tema Material 3 aplikasi.
///
/// Dua sumber warna:
/// 1) dynamic_color (Material You) - kalau HP Android 12+ dan user tidak matikan.
/// 2) brand seed sendiri (indigo #5B5BD6) - fallback & tampilan brand.
abstract final class AppTheme {
  static ThemeData light(ColorScheme? dynamic) =>
      _bangun(dynamic, Brightness.light);

  static ThemeData dark(ColorScheme? dynamic) =>
      _bangun(dynamic, Brightness.dark);

  static ThemeData _bangun(ColorScheme? dynamic, Brightness b) {
    final bool gelap = b == Brightness.dark;
    final Color seed = dynamic?.primary ?? AppColors.brand;

    ColorScheme cs = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: b,
    ).copyWith(
      surface: gelap ? AppColors.surfaceDark : AppColors.surfaceLight,
      surfaceContainerLowest: gelap ? AppColors.inkDark : Colors.white,
      surfaceContainerLow: gelap ? const Color(0xFF16161E) : const Color(0xFFF6F6FA),
      surfaceContainer: gelap ? const Color(0xFF1B1B24) : const Color(0xFFF1F1F6),
      surfaceContainerHigh: gelap ? const Color(0xFF21212C) : const Color(0xFFEDEDF3),
      outlineVariant: gelap ? AppColors.lineDark : AppColors.lineLight,
      primary: gelap ? const Color(0xFFB9B9FF) : AppColors.brand,
      onPrimary: gelap ? const Color(0xFF1B1B6B) : Colors.white,
      secondary: gelap ? const Color(0xFF6FE3D0) : AppColors.mint,
      onSecondary: gelap ? const Color(0xFF00382F) : Colors.white,
      tertiary: gelap ? const Color(0xFFFFB59B) : AppColors.coral,
      onTertiary: gelap ? const Color(0xFF5A1B00) : Colors.white,
      error: AppColors.danger,
    );

    final TextTheme teks = AppTypography.textTheme(b);
    final bool planar = b == Brightness.light;

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      brightness: b,
      fontFamily: AppTypography.ui,
      textTheme: teks,
      scaffoldBackgroundColor: cs.surface,
      splashFactory: InkSparkle.splashFactory,

      visualDensity: VisualDensity.standard,

      appBarTheme: AppBarTheme(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: cs.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: teks.titleLarge,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: gelap ? Brightness.light : Brightness.dark,
          statusBarBrightness: gelap ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: cs.surface,
          systemNavigationBarIconBrightness:
              gelap ? Brightness.light : Brightness.dark,
        ),
      ),

      cardTheme: CardThemeData(
        color: planar ? Colors.white : const Color(0xFF1A1A23),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.br20),
      ),

      dividerTheme: DividerThemeData(
        color: cs.outlineVariant,
        thickness: 1,
        space: 1,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: cs.surfaceContainer,
        side: BorderSide(color: cs.outlineVariant),
        labelStyle: teks.labelMedium,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.br12),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainer,
        hintStyle: teks.bodyMedium?.copyWith(
          color: cs.onSurfaceVariant.withValues(alpha: 0.7),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 14),
        border: const OutlineInputBorder(
          borderRadius: AppRadius.br16,
          borderSide: BorderSide.none,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AppRadius.br16,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.br16,
          borderSide: BorderSide(color: cs.primary, width: 1.6),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.br14),
          textStyle: teks.labelLarge,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          side: BorderSide(color: cs.outlineVariant),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.br14),
          textStyle: teks.labelLarge,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 44),
          textStyle: teks.labelLarge,
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(44, 44),
          highlightColor: cs.primary.withValues(alpha: 0.10),
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: planar ? Colors.white : const Color(0xFF17171F),
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: cs.outline,
        dragHandleSize: const Size(36, 4),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheet),
        clipBehavior: Clip.antiAlias,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: planar ? Colors.white : const Color(0xFF1A1A23),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.dialog),
        titleTextStyle: teks.titleMedium,
        contentTextStyle: teks.bodyMedium,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: gelap ? const Color(0xFF2A2A36) : AppColors.inkLight,
        contentTextStyle: teks.bodySmall?.copyWith(color: Colors.white),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.br12),
        insetPadding: const EdgeInsets.all(AppSpacing.lg),
      ),

      listTileTheme: ListTileThemeData(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.br12),
        titleTextStyle: teks.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
        subtitleTextStyle: teks.bodySmall,
        iconColor: cs.onSurfaceVariant,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cs.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        indicatorColor: cs.primary.withValues(alpha: 0.16),
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStatePropertyAll(teks.labelSmall),
      ),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),

      extensions: <ThemeExtension<dynamic>>[AppTokens(gelap: gelap)],
    );
  }
}

/// Token ekstra yang tidak muat di ColorScheme (gelembung chat, shimmer, dll).
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({required this.gelap});

  final bool gelap;

  @override
  AppTokens copyWith({bool? gelap}) => AppTokens(gelap: gelap ?? this.gelap);

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) =>
      t < 0.5 ? this : (other as AppTokens? ?? this);
}

extension AppTokensX on BuildContext {
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
  ColorScheme get cs => Theme.of(this).colorScheme;
  TextTheme get teks => Theme.of(this).textTheme;
  bool get gelap => Theme.of(this).brightness == Brightness.dark;
}
