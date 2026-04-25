import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_spacing.dart';

/// Named routes swap without slide animation (tabs feel instant).
class InstantPageTransitionsBuilder extends PageTransitionsBuilder {
  const InstantPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.neonGreen,
    brightness: Brightness.dark,
  ).copyWith(
    primary: AppColors.neonGreen,
    onPrimary: const Color(0xFF04140C),
    primaryContainer: const Color(0xFF14392A),
    onPrimaryContainer: const Color(0xFFD1FAE5),
    secondary: AppColors.neonGreenDeep,
    onSecondary: const Color(0xFF04140C),
    secondaryContainer: const Color(0xFF123528),
    onSecondaryContainer: const Color(0xFFD1FAE5),
    tertiary: const Color(0xFF34FF9A),
    onTertiary: const Color(0xFF04140C),
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    surfaceContainerLowest: AppColors.surfaceElevated,
    surfaceContainerLow: AppColors.surfaceCard,
    surfaceContainer: AppColors.surfaceCard,
    surfaceContainerHigh: const Color(0xFF252E3E),
    surfaceContainerHighest: AppColors.surfaceCard,
    error: AppColors.accentRose,
    onError: const Color(0xFF210A0A),
    outline: AppColors.outlineSoft,
    outlineVariant: AppColors.outlineMuted,
    onSurfaceVariant: AppColors.textSecondary,
  );
  final baseTextTheme = ThemeData(brightness: Brightness.dark).textTheme;
  TextStyle? scaleStyle(TextStyle? style) {
    if (style == null || style.fontSize == null) return style;
    return style.copyWith(fontSize: style.fontSize! * 0.92);
  }

  final compactTextTheme = baseTextTheme.copyWith(
    displayLarge: scaleStyle(baseTextTheme.displayLarge),
    displayMedium: scaleStyle(baseTextTheme.displayMedium),
    displaySmall: scaleStyle(baseTextTheme.displaySmall),
    headlineLarge: scaleStyle(baseTextTheme.headlineLarge),
    headlineMedium: scaleStyle(baseTextTheme.headlineMedium),
    headlineSmall: scaleStyle(baseTextTheme.headlineSmall),
    titleLarge: scaleStyle(baseTextTheme.titleLarge),
    titleMedium: scaleStyle(baseTextTheme.titleMedium),
    titleSmall: scaleStyle(baseTextTheme.titleSmall),
    bodyLarge: scaleStyle(baseTextTheme.bodyLarge),
    bodyMedium: scaleStyle(baseTextTheme.bodyMedium),
    bodySmall: scaleStyle(baseTextTheme.bodySmall),
    labelLarge: scaleStyle(baseTextTheme.labelLarge),
    labelMedium: scaleStyle(baseTextTheme.labelMedium),
    labelSmall: scaleStyle(baseTextTheme.labelSmall),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.surface,
    textTheme: compactTextTheme,
    primaryTextTheme: compactTextTheme,
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      backgroundColor: scheme.surfaceContainer,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.85)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainer,
      surfaceTintColor: Colors.transparent,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainer,
      surfaceTintColor: Colors.transparent,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xFF252E3E),
      contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.inputPaddingH,
        vertical: AppSpacing.inputPaddingV,
      ),
      fillColor: scheme.surfaceContainerHigh,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        elevation: 0,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.buttonPaddingH,
          vertical: AppSpacing.buttonPaddingV,
        ),
        minimumSize: const Size(0, AppSpacing.buttonMinHeight),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.primary,
        side: BorderSide(color: scheme.outline),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.buttonPaddingH,
          vertical: AppSpacing.buttonPaddingV,
        ),
        minimumSize: const Size(0, AppSpacing.buttonMinHeight),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.buttonPaddingH,
          vertical: AppSpacing.buttonPaddingV,
        ),
        minimumSize: const Size(0, AppSpacing.buttonMinHeight),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1),
    listTileTheme: ListTileThemeData(
      iconColor: scheme.primary,
      textColor: scheme.onSurface,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: InstantPageTransitionsBuilder(),
        TargetPlatform.iOS: InstantPageTransitionsBuilder(),
        TargetPlatform.macOS: InstantPageTransitionsBuilder(),
        TargetPlatform.linux: InstantPageTransitionsBuilder(),
        TargetPlatform.windows: InstantPageTransitionsBuilder(),
        TargetPlatform.fuchsia: InstantPageTransitionsBuilder(),
      },
    ),
  );
}
