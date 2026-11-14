import 'package:flutter/material.dart';
import 'package:zonixweb/core/theme/app_dimens.dart';
import 'package:zonixweb/core/theme/zonix_colors.dart';

/// The app-wide Material 3 theme, built on the Zonix brand palette.
class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final base = ColorScheme.fromSeed(seedColor: ZonixColors.navy);
    final colorScheme = base.copyWith(
      primary: ZonixColors.navy,
      onPrimary: Colors.white,
      primaryContainer: ZonixColors.navyContainer,
      onPrimaryContainer: ZonixColors.navy,
      secondary: ZonixColors.cyan,
      onSecondary: ZonixColors.navy,
      secondaryContainer: ZonixColors.cyanContainer,
      onSecondaryContainer: ZonixColors.onCyanContainer,
      tertiary: ZonixColors.emerald,
      onTertiary: Colors.white,
      tertiaryContainer: ZonixColors.emeraldContainer,
      onTertiaryContainer: ZonixColors.onEmeraldContainer,
    );
    final softOutline = colorScheme.outlineVariant.withValues(alpha: 0.6);
    final fieldRadius = BorderRadius.circular(AppDimens.radiusLarge);
    final buttonShape = RoundedRectangleBorder(borderRadius: fieldRadius);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          side: BorderSide(color: softOutline),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        contentPadding: AppDimens.paddingH16V14,
        border: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: BorderSide(color: colorScheme.error, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: BorderSide(color: colorScheme.error, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          // A finite minimum width, not Size.fromHeight (which is
          // Size(double.infinity, height)): an infinite minimum width
          // crashes any button placed in an unbounded context, like a
          // dialog's action Row. Full-width auth buttons get their width
          // from their Column's CrossAxisAlignment.stretch instead.
          minimumSize: const Size(64, 48),
          shape: buttonShape,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: buttonShape,
          side: BorderSide(color: colorScheme.outlineVariant),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: buttonShape,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.spacing8),
        ),
        side: BorderSide.none,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: AppDimens.fontLabel,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spacing8,
          vertical: AppDimens.spacing2,
        ),
      ),
      dividerTheme: DividerThemeData(color: softOutline),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusSheetTop),
        ),
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ZonixColors.navy,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
        shape: buttonShape,
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(
          color: ZonixColors.navy.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(AppDimens.radiusSmall),
        ),
        textStyle: const TextStyle(
          color: Colors.white,
          fontSize: AppDimens.fontLabel,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: colorScheme.primary,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        indicatorColor: colorScheme.primary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: softOutline,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: fieldRadius,
          side: BorderSide(color: softOutline),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: colorScheme.surfaceContainerHighest,
      ),
      scrollbarTheme: ScrollbarThemeData(
        radius: const Radius.circular(AppDimens.spacing8),
        thumbColor: WidgetStatePropertyAll(
          colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}
