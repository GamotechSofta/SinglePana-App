import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';

/// Shared light-on-dark “casino” styling for shell-backed pages.
abstract final class CasinoUi {
  static const Color lightGold = Color(0xFFEAFEF4);

  static Color mutedGold([double opacity = 1]) =>
      AppColors.goldMuted.withValues(alpha: opacity);

  static ShapeBorder cardShape({
    double borderOpacity = 0.38,
    double width = 1.5,
  }) {
    return RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(
        color: AppColors.gold.withValues(alpha: borderOpacity),
        width: width,
      ),
    );
  }

  static ShapeBorder cardShapeRadius(
    double radius, {
    double borderOpacity = 0.38,
  }) {
    return RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(
        color: AppColors.gold.withValues(alpha: borderOpacity),
        width: 1.5,
      ),
    );
  }

  /// Help Desk / Funds — neutral light border (not [AppColors.gold] / neon green).
  static Color neutralShellBorderColor({double alpha = 0.16}) =>
      Colors.white.withValues(alpha: alpha);

  /// Help Desk / support — neutral light border (not [AppColors.gold] / neon green).
  static ShapeBorder supportCardShape({
    double borderOpacity = 0.16,
    double width = 1,
  }) {
    return RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(
        color: Colors.white.withValues(alpha: borderOpacity),
        width: width,
      ),
    );
  }

  /// Dark fill for text fields on the casino backdrop.
  static const Color fieldFill = AppColors.surfaceCard;

  /// Blur strength for frosted glass over [HomeCasinoBackdrop] / shell pages.
  static const double glassBlurSigma = 12;

  /// Frosted glass: blurs content behind, optional tint + border.
  static Widget backdropBlur({
    required Widget child,
    BorderRadius borderRadius = BorderRadius.zero,
    EdgeInsetsGeometry? padding,
    Color? fill,
    BoxBorder? border,
    List<BoxShadow>? boxShadow,
  }) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: glassBlurSigma, sigmaY: glassBlurSigma),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fill ??
                AppColors.surfaceCard.withValues(alpha: 0.48),
            borderRadius: borderRadius,
            border: border,
            boxShadow: boxShadow,
          ),
          child: padding != null ? Padding(padding: padding, child: child) : child,
        ),
      ),
    );
  }

  static InputDecorationThemeData inputDecorationOnDark(BuildContext context) {
    final base = Theme.of(context).inputDecorationTheme;
    return base.copyWith(
      filled: true,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.inputPaddingH,
        vertical: AppSpacing.inputPaddingV,
      ),
      fillColor: fieldFill,
      labelStyle: TextStyle(color: mutedGold(0.88)),
      hintStyle: TextStyle(color: mutedGold(0.45)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.gold.withValues(alpha: 0.34)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.gold.withValues(alpha: 0.34)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: AppColors.gold.withValues(alpha: 0.75),
          width: 2,
        ),
      ),
    );
  }

  /// Text fields on support pages — neutral outline instead of green [AppColors.gold].
  static InputDecorationThemeData inputDecorationSupport(BuildContext context) {
    final base = Theme.of(context).inputDecorationTheme;
    const neutral = Color(0x33FFFFFF);
    const focused = Color(0x66FFFFFF);
    return base.copyWith(
      filled: true,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.inputPaddingH,
        vertical: AppSpacing.inputPaddingV,
      ),
      fillColor: fieldFill,
      labelStyle: TextStyle(color: mutedGold(0.88)),
      hintStyle: TextStyle(color: mutedGold(0.45)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: neutral),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: neutral),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: focused, width: 2),
      ),
    );
  }
}
