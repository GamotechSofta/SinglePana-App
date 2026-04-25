/// Shared layout for [AppHeader] and [AppBottomNav].
abstract final class AppNavMetrics {
  static const double innerHeight = 64;
  static const double horizontalPadding = 12;

  /// Top bar content row (shorter than [innerHeight] used by bottom nav).
  static const double headerInnerHeight = 48;

  /// Top bar — minimal vertical padding.
  static const double headerVerticalPadding = 4;

  /// Bottom bar vertical padding (unchanged when only the header is tweaked).
  static const double bottomVerticalPadding = 10;

  /// Below status bar only — for [PreferredSizeWidget] callers.
  static const double headerBodyHeight =
      headerInnerHeight + headerVerticalPadding * 2;
}
