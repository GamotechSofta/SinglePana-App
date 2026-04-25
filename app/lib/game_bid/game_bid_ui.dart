import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/casino_ui.dart';

/// Shared “casino” styling for all game / bid flows (matches funds & shell).
abstract final class GameBidUi {
  static TextStyle get sectionLabel => TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.neonGreen.withValues(alpha: 0.72),
      );

  static TextStyle get emptyHint => TextStyle(
        fontSize: 12,
        color: Colors.white70,
      );

  static const TextStyle tableHeader = TextStyle(
    fontWeight: FontWeight.w700,
    fontSize: 12,
    color: Colors.white,
  );

  static TextStyle get panelTitle => const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      );

  /// Fallback for [Text] in bid bodies that omit [Text.style] (fields use theme + [betInputStyle]).
  static TextStyle get bodyFallback => const TextStyle(color: Colors.white);

  /// Use when a TextField sets an explicit [style] (size/weight) so typed text stays white.
  static TextStyle betInputStyle({double? fontSize, FontWeight? fontWeight}) {
    return TextStyle(
      color: Colors.white,
      fontSize: fontSize,
      fontWeight: fontWeight,
    );
  }

  /// Fallback / minimum square control size (used if width-based sizing is unavailable).
  static const double betChipSize = 32;

  /// Corner radius for digit tiles, quick-point chips, and list number badges (~8–12dp).
  static const double betChipRadius = 10;

  /// Neutral outline for all bet number chips (not green / gold trim).
  static Color numberChipBorderColor({bool selected = false}) =>
      CasinoUi.neutralShellBorderColor(alpha: selected ? 0.24 : 0.16);

  /// Charcoal chip fill — slightly above page chrome; stronger when [selected].
  static Color numberChipBackground({bool selected = false}) => selected
      ? Colors.white.withValues(alpha: 0.12)
      : AppColors.surfaceCard.withValues(alpha: 0.82);

  /// Digit grid cells, bulk pickers, and other tappable number tiles.
  static BoxDecoration numberChipTileDecoration({
    required bool selected,
    BorderRadiusGeometry? borderRadius,
  }) {
    return BoxDecoration(
      color: numberChipBackground(selected: selected),
      borderRadius: borderRadius ?? BorderRadius.circular(betChipRadius),
      border: Border.all(
        color: numberChipBorderColor(selected: selected),
        width: 1,
      ),
    );
  }

  /// Caps [betTileExtentForColumns] so digit and quick-point tiles stay compact on wide phones.
  static const double betTileMaxExtent = 40;

  /// Inner padding for digit outline buttons and inline points fields on the same row.
  static const EdgeInsets betChipContentPadding = EdgeInsets.symmetric(
    horizontal: AppSpacing.chipPaddingH,
    vertical: AppSpacing.chipPaddingV,
  );

  /// Single shared height for **single / double pana bulk** rows: digit chip, Pts [TextField]
  /// ([betPointsRectangleSlot]), Apply/Clear, and quick-point chips. Same as [primaryFilled]
  /// / [quickPointsClearOutlinedStyle] minimum height ([AppSpacing.buttonMinHeight]).
  static const double bulkPanaInlineRowHeight = AppSpacing.buttonMinHeight;

  /// Square digit chip width/height on bulk pana rows — identical to [bulkPanaInlineRowHeight].
  static const double bulkPanaDigitExtent = bulkPanaInlineRowHeight;

  /// Minimal content padding for bulk Pts fields inside [betPointsRectangleSlot] height
  /// [bulkPanaInlineRowHeight]. Pair with [isDense]: true and [textAlignVertical]: center.
  static const EdgeInsets bulkPanaPointsFieldPadding = EdgeInsets.symmetric(
    horizontal: AppSpacing.sm,
    vertical: 0,
  );

  /// Digit cell: default **square** [bulkPanaDigitExtent] × [bulkPanaInlineRowHeight] (standard button size).
  static Widget bulkPanaDigitChip({
    required String label,
    double chipWidth = bulkPanaDigitExtent,
  }) {
    return SizedBox(
      width: chipWidth,
      height: bulkPanaInlineRowHeight,
      child: DecoratedBox(
        decoration: numberChipTileDecoration(selected: false),
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: chipWidth >= bulkPanaDigitExtent ? 13 : 12,
            ),
          ),
        ),
      ),
    );
  }

  /// Responsive extent for digit tiles, framed number badges, quick-point chips, and
  /// adjacent points [TextField] height — keeps **number chip height == points row height**.
  static double betControlExtent(BuildContext context) => defaultBetTileExtent(context);

  /// Width and height for one grid cell with [columns] across the screen.
  /// Assumes parent [ListView] uses `padding: EdgeInsets.all(12)` → 24 horizontal inset.
  static double betTileExtentForColumns(
    double viewportWidth, {
    int columns = 5,
    double horizontalPadding = 24,
    double crossAxisSpacing = 8,
  }) {
    if (columns <= 0) return betChipSize;
    final inner = viewportWidth - horizontalPadding;
    if (inner <= 0) return betChipSize;
    final gaps = crossAxisSpacing * (columns - 1);
    final raw = (inner - gaps) / columns;
    final floored = math.max(betChipSize * 0.75, raw);
    return math.min(floored, betTileMaxExtent);
  }

  /// Same extent as a typical 5-column digit grid; use for quick points and paired points fields.
  /// Prefer the alias [betControlExtent] when pairing number chips with points rectangles.
  static double defaultBetTileExtent(BuildContext context) =>
      betTileExtentForColumns(MediaQuery.sizeOf(context).width);

  /// Prefer [glassPanel] for backdrop blur on the casino shell.
  static BoxDecoration panelDecoration({double radius = 16}) => BoxDecoration(
        gradient: AppColors.cardBackgroundGradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.14),
          width: 1,
        ),
      );

  /// Prefer [glassListRow] for backdrop blur.
  static BoxDecoration listRowDecoration({double radius = 8}) => BoxDecoration(
        gradient: AppColors.cardBackgroundGradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      );

  static Widget glassPanel({
    required Widget child,
    double radius = 16,
    EdgeInsetsGeometry? padding,
  }) {
    final r = BorderRadius.circular(radius);
    final core = CasinoUi.backdropBlur(
      borderRadius: r,
      padding: padding,
      fill: AppColors.surfaceCard.withValues(alpha: 0.5),
      border: Border.all(color: Colors.white.withValues(alpha: 0.14), width: 1),
      child: child,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        gradient: AppColors.cardBackgroundGradient,
      ),
      child: core,
    );
  }

  static Widget glassListRow({
    required Widget child,
    double radius = 8,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
    EdgeInsetsGeometry? margin,
  }) {
    final r = BorderRadius.circular(radius);
    final core = CasinoUi.backdropBlur(
      borderRadius: r,
      padding: padding,
      fill: AppColors.surfaceCard.withValues(alpha: 0.48),
      border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1),
      child: child,
    );
    if (margin != null) return Padding(padding: margin, child: core);
    return core;
  }

  static BoxDecoration digitBadgeDecoration({double radius = betChipRadius}) =>
      numberChipTileDecoration(
        selected: false,
        borderRadius: BorderRadius.circular(radius),
      );

  /// Square number label (list/special rows). Pair with [inlinePointsDecoration] inside
  /// `SizedBox(height: extent, child: TextField(...))` so heights match [extent].
  static Widget betNumberChip({
    required String label,
    required double extent,
    TextStyle? textStyle,
    BoxDecoration? decoration,
  }) {
    return SizedBox(
      width: extent,
      height: extent,
      child: DecoratedBox(
        decoration: decoration ?? digitBadgeDecoration(),
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: textStyle ??
                TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: extent >= 36 ? 14 : 12,
                ),
          ),
        ),
      ),
    );
  }

  /// Fixed-height slot for an inline points field next to a [betNumberChip] / digit tile.
  static Widget betPointsRectangleSlot({
    required double extent,
    required Widget child,
  }) {
    return SizedBox(height: extent, child: child);
  }

  /// Single-digit **special mode** pair: same outline/radius/fill strategy so digit and points
  /// cells match height (grid row should use [crossAxisAlignment: CrossAxisAlignment.stretch]).
  static BoxDecoration betNeonPairCellDecoration({required Color fillColor}) {
    return BoxDecoration(
      color: fillColor,
      borderRadius: BorderRadius.circular(betChipRadius),
      border: Border.all(color: numberChipBorderColor(), width: 1),
    );
  }

  static Widget betNeonPairDigit({
    required String digit,
    required double extent,
  }) {
    return SizedBox(
      width: extent,
      child: Container(
        decoration: betNeonPairCellDecoration(
          fillColor: numberChipBackground(selected: false),
        ),
        clipBehavior: Clip.antiAlias,
        alignment: Alignment.center,
        child: Text(
          digit,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  static Widget betNeonPairPointsField({
    required TextEditingController controller,
    ValueChanged<String>? onChanged,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    VoidCallback? onEditingComplete,
    ValueChanged<String>? onSubmitted,
  }) {
    return Container(
      decoration: betNeonPairCellDecoration(fillColor: CasinoUi.fieldFill),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType ?? TextInputType.number,
        textInputAction: textInputAction ?? TextInputAction.done,
        textAlign: TextAlign.center,
        textAlignVertical: TextAlignVertical.center,
        onChanged: onChanged,
        onEditingComplete: onEditingComplete,
        onSubmitted: onSubmitted,
        style: betInputStyle(fontSize: 14, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Points',
          hintStyle: const TextStyle(color: Colors.white54),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          contentPadding: betChipContentPadding,
        ),
      ),
    );
  }

  static InputDecoration inputDecoration({
    required String labelText,
    String? hintText,
    String? counterText,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      counterText: counterText,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.inputPaddingH,
        vertical: AppSpacing.inputPaddingV,
      ),
      filled: true,
      fillColor: CasinoUi.fieldFill,
      labelStyle: TextStyle(color: AppColors.neonGreen.withValues(alpha: 0.75)),
      hintStyle: const TextStyle(color: Colors.white54),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.neonGreen.withValues(alpha: 0.34)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.neonGreen.withValues(alpha: 0.34)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.neonGreen.withValues(alpha: 0.82), width: 2),
      ),
    );
  }

  /// Dense field used inside special-mode grids (same horizontal/vertical inset as [outlineDigit]).
  static InputDecoration inlinePointsDecoration() {
    return InputDecoration(
      isDense: true,
      hintText: 'Points',
      filled: true,
      fillColor: CasinoUi.fieldFill,
      hintStyle: const TextStyle(color: Colors.white54),
      contentPadding: betChipContentPadding,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.neonGreen.withValues(alpha: 0.34)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.neonGreen.withValues(alpha: 0.34)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.neonGreen.withValues(alpha: 0.82), width: 2),
      ),
    );
  }

  static ButtonStyle modeToggle(bool selected) => OutlinedButton.styleFrom(
        backgroundColor: selected
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.transparent,
        foregroundColor: selected ? Colors.white : Colors.white70,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.buttonPaddingH,
          vertical: AppSpacing.buttonPaddingV,
        ),
        minimumSize: const Size(0, AppSpacing.buttonMinHeight),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        side: BorderSide(
          color: Colors.white.withValues(alpha: selected ? 0.24 : 0.14),
          width: 1.5,
        ),
      );

  /// Digit grid key. Pass [extent] from [betControlExtent] / [defaultBetTileExtent] so the
  /// button matches quick points and adjacent points field height.
  static ButtonStyle outlineDigit(bool selected, {double? extent}) {
    final square = extent != null ? Size(extent, extent) : null;
    return OutlinedButton.styleFrom(
      backgroundColor: numberChipBackground(selected: selected),
      foregroundColor: Colors.white,
      padding: betChipContentPadding,
      minimumSize: square ?? Size(0, betChipSize),
      maximumSize: square,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      side: BorderSide(
        color: numberChipBorderColor(selected: selected),
        width: 1,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(betChipRadius),
      ),
    );
  }

  /// Label/icon on [primaryFilled] buttons (dark gold bar, light text).
  static const Color primaryFilledForeground = Color(0xFF02120A);

  /// Submit / Generate / Add to list (and footer submit) on dark bet chrome.
  static ButtonStyle primaryFilled({double? minHeight}) => FilledButton.styleFrom(
        backgroundColor: AppColors.neonGreenDeep,
        foregroundColor: primaryFilledForeground,
        disabledForegroundColor: const Color(0xFF9AA5A0),
        disabledBackgroundColor: AppColors.neonGreenDeep.withValues(alpha: 0.45),
        // [Size.fromHeight] uses infinite width as minimum — invalid inside [Row]s.
        minimumSize: Size(0, minHeight ?? AppSpacing.buttonMinHeight),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.buttonPaddingH,
          vertical: AppSpacing.buttonPaddingV,
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      );

  /// Quick-point chips: transparent fill, label reads as white with a light gold cast.
  static const Color quickPointsTextColor = Colors.white;

  static const TextStyle quickPointsLabelStyle = TextStyle(
    color: quickPointsTextColor,
    fontWeight: FontWeight.w600,
    fontSize: 13,
  );

  /// Clear beside “Quick points” rows.
  static ButtonStyle get quickPointsClearTextButtonStyle => TextButton.styleFrom(
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white38,
        minimumSize: const Size(0, AppSpacing.buttonMinHeight),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.buttonPaddingV,
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      );

  /// Vertical gap after the points [TextField] and before the “Quick points” row.
  static const double quickPointsAfterFieldGap = 4;

  /// Vertical gap between the “Quick points” row and the preset chip [Wrap].
  static const double quickPointsHeaderToChipsGap = 3;

  /// Outlined Clear on dark bet chrome (bulk rows, motor bars, etc.).
  static ButtonStyle quickPointsClearOutlinedStyle({double? minHeight}) => OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white38,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.buttonPaddingH,
          vertical: AppSpacing.buttonPaddingV,
        ),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
        minimumSize: Size(0, minHeight ?? AppSpacing.buttonMinHeight),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      );

  /// Quick-point presets: transparent fill + gold outline (Material 3 [FilterChip] fills are not reliably transparent).
  static Widget quickPointsChip({
    required bool selected,
    required String label,
    required ValueChanged<bool> onSelected,
    double? extent,
  }) {
    return _QuickPointsChipTile(
      selected: selected,
      label: label,
      onSelected: onSelected,
      extent: extent,
    );
  }

  static Widget quickPointsChoiceChip({
    required bool selected,
    required String label,
    required ValueChanged<bool> onSelected,
    double? extent,
  }) {
    return _QuickPointsChipTile(
      selected: selected,
      label: label,
      onSelected: onSelected,
      extent: extent,
    );
  }

  /// Dense grid inputs (e.g. Jodi bulk).
  static OutlineInputBorder cellBorder({double radius = 6}) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
      );
}

class _QuickPointsChipTile extends StatelessWidget {
  const _QuickPointsChipTile({
    required this.selected,
    required this.label,
    required this.onSelected,
    this.extent,
  });

  final bool selected;
  final String label;
  final ValueChanged<bool> onSelected;
  final double? extent;

  @override
  Widget build(BuildContext context) {
    final side = BorderSide(
      color: GameBidUi.numberChipBorderColor(selected: selected),
      width: 1,
    );
    final s = extent ?? GameBidUi.betChipSize;
    return Theme(
      data: Theme.of(context).copyWith(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
      ),
      child: SizedBox(
        width: s,
        height: s,
        child: OutlinedButton(
          onPressed: () => onSelected(!selected),
          style: ButtonStyle(
            backgroundColor: WidgetStatePropertyAll<Color>(
              GameBidUi.numberChipBackground(selected: selected),
            ),
            foregroundColor: const WidgetStatePropertyAll<Color>(GameBidUi.quickPointsTextColor),
            shadowColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
            surfaceTintColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
            overlayColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
            elevation: const WidgetStatePropertyAll<double>(0),
            padding: const WidgetStatePropertyAll(EdgeInsets.zero),
            minimumSize: WidgetStatePropertyAll(Size(s, s)),
            maximumSize: WidgetStatePropertyAll(Size(s, s)),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(GameBidUi.betChipRadius),
                side: side,
              ),
            ),
          ),
          child: Center(
            child: Text(label, style: GameBidUi.quickPointsLabelStyle, textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}
