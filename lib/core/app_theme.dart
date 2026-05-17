// lib/core/app_theme.dart
// Единая тема всего приложения.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─── Палитра ────────────────────────────────────────────────
class AppColors {
  AppColors._();
  static const accent        = Color(0xFF00D4AA);
  static const accentDim     = Color(0xFF007A63);
  static const accentSurface = Color(0xFF003D32);
  static const bgDark        = Color(0xFF0D0F14);
  static const surfaceDark   = Color(0xFF161B24);
  static const cardDark      = Color(0xFF1C2333);
  static const borderDark    = Color(0xFF252D3D);
  static const dividerDark   = Color(0xFF1E2636);
  static const textPrimary   = Color(0xFFE8EDF5);
  static const textSecondary = Color(0xFF7A8BA0);
  static const textMuted     = Color(0xFF3D4F64);
  static const bgLight       = Color(0xFFF0F4F8);
  static const surfaceLight  = Color(0xFFFFFFFF);
  static const cardLight     = Color(0xFFFFFFFF);
  static const borderLight   = Color(0xFFDDE4EE);
  static const textPrimaryLight   = Color(0xFF0D1A2E);
  static const textSecondaryLight = Color(0xFF526480);
  static const layerPoint    = Color(0xFF00D4AA);
  static const layerPolygon  = Color(0xFF3D8EF5);
  static const layerPolyline = Color(0xFFF5A623);
  static const layerRaster   = Color(0xFFB06EF5);
  static const layerHeatmap  = Color(0xFFF55A5A);
  static const success       = Color(0xFF2DD4A4);
  static const warning       = Color(0xFFF5A623);
  static const error         = Color(0xFFF55A5A);
}

// ─── Темы ────────────────────────────────────────────────────
class AppTheme {
  AppTheme._();

  static ThemeData get dark => _build(Brightness.dark);
  static ThemeData get light => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final cs = isDark
        ? const ColorScheme.dark(
            primary: AppColors.accent,
            onPrimary: AppColors.bgDark,
            secondary: AppColors.accentDim,
            surface: AppColors.surfaceDark,
            onSurface: AppColors.textPrimary,
            outline: AppColors.borderDark,
            error: AppColors.error,
          )
        : const ColorScheme.light(
            primary: AppColors.accent,
            onPrimary: Colors.white,
            secondary: AppColors.accentDim,
            surface: AppColors.surfaceLight,
            onSurface: AppColors.textPrimaryLight,
            outline: AppColors.borderLight,
            error: AppColors.error,
          );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: cs,
      scaffoldBackgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      cardColor: isDark ? AppColors.cardDark : AppColors.cardLight,
      dividerColor: isDark ? AppColors.dividerDark : AppColors.borderLight,
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        foregroundColor: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.2,
          color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
        ),
        iconTheme: IconThemeData(
          color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight, size: 22,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.cardDark : AppColors.cardLight,
        hintStyle: TextStyle(
          color: isDark ? AppColors.textMuted : AppColors.textSecondaryLight, fontSize: 14,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: isDark ? AppColors.bgDark : Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accent,
          minimumSize: const Size(double.infinity, 52),
          side: const BorderSide(color: AppColors.accentDim, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.bgDark,
        elevation: 4,
        shape: CircleBorder(),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        modalBackgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        width: 300,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? AppColors.accent : AppColors.textMuted),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? AppColors.accentDim : AppColors.borderDark),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? AppColors.cardDark : AppColors.bgLight,
        selectedColor: AppColors.accentSurface,
        labelStyle: TextStyle(
          fontSize: 12,
          color: isDark ? AppColors.textSecondary : AppColors.textSecondaryLight,
        ),
        side: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? AppColors.cardDark : AppColors.cardLight,
        contentTextStyle: TextStyle(
          color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight, fontSize: 14,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
      ),
    );
  }
}
