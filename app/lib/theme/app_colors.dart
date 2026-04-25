import 'package:flutter/material.dart';

/// Global neon-dark design tokens.
abstract final class AppColors {
  static const Color navy = Color(0xFF1D2533);
  static const Color navyDark = Color(0xFF151B26);
  static const Color navyMid = Color(0xFF262F42);
  static const Color gold = Color(0xFF00E676);
  static const Color goldDark = Color(0xFF00C853);
  /// Primary filled actions on dark casino / bid chrome (submit, generate, add to list).
  static const Color goldDeep = Color(0xFF00C853);
  static const Color goldMuted = Color(0xFFD1FAE5);

  /// Page / scaffold background.
  static const Color surface = Color(0xFF151B26);
  static const Color surfaceElevated = Color(0xFF1D2533);
  static const Color surfaceCard = Color(0xFF1A2230);

  static const Color outlineSoft = Color(0xFF355648);
  static const Color outlineMuted = Color(0xFF2A483C);

  static const Color textPrimary = Color(0xFFE5E7EB);
  static const Color textSecondary = Color(0xFF9CA3AF);

  static const Color accentEmerald = Color(0xFF00E676);
  static const Color accentRose = Color(0xFFF87171);
  static const Color statusSoftError = Color(0xFFF87171);
  /// Primary accent (softer than pure #00FF88 — less glow).
  static const Color neonGreen = Color(0xFF00E676);
  static const Color neonGreenDeep = Color(0xFF00C853);
  static const Color cardSurfaceTop = Color(0xFF263143);
  static const Color cardSurfaceBottom = Color(0xFF1C2434);

  /// App background / full-screen base.
  static const LinearGradient primaryBackgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF181F2C), Color(0xFF222B3A), Color(0xFF1A2130)],
    stops: [0.0, 0.5, 1.0],
  );

  /// Neutral trim gradient for subtle modern borders.
  static const LinearGradient neonGlowGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0x2AFFFFFF), Color(0x1FFFFFFF), Color(0x2AFFFFFF)],
    stops: [0.0, 0.5, 1.0],
  );

  /// CTA button (register / primary action).
  static const LinearGradient ctaButtonGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF18C978), Color(0xFF00A85A)],
    stops: [0.0, 1.0],
  );

  /// Subtle depth for market cards and dark containers.
  static const LinearGradient cardBackgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [cardSurfaceTop, cardSurfaceBottom],
    stops: [0.0, 1.0],
  );

  /// Login / signup mobile backdrop.
  static const LinearGradient authBackgroundGradient = primaryBackgroundGradient;

  static const LinearGradient drawerHeaderGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navyDark, navy, Color(0xFF3D5A78)],
  );

  /// Shiny gold gradient for premium accents and borders.
  static const LinearGradient shinyGoldGradient = LinearGradient(
    colors: [
      Color(0xFFFFD700),
      Color(0xFFFFC300),
      Color(0xFFFFE066),
      Color(0xFFFFC300),
      Color(0xFFFFA500),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
