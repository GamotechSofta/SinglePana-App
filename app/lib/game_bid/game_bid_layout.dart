import 'package:flutter/material.dart';

import '../constants/remote_assets.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/casino_ui.dart';
import '../utils/market_timing.dart';
import 'betting_window_scope.dart';
import 'game_bid_ui.dart';

class GameBidLayout extends StatelessWidget {
  const GameBidLayout({
    super.key,
    required this.market,
    required this.title,
    required this.body,
    required this.bidsCount,
    required this.totalPoints,
    required this.session,
    required this.onSessionChanged,
    required this.selectedDateYmd,
    required this.onDateChanged,
    required this.onBack,
    required this.walletBalance,
    this.onSubmit,
    this.hideFooter = false,
    this.submitLabel = 'Submit Bets',
    this.sessionOptionsOverride,
    this.lockSession = false,
  });

  final Map<String, dynamic> market;
  final String title;
  final Widget body;
  final int bidsCount;
  final int totalPoints;
  final String session;
  final ValueChanged<String> onSessionChanged;
  final String selectedDateYmd;
  final ValueChanged<String> onDateChanged;
  final VoidCallback onBack;
  final double walletBalance;
  final VoidCallback? onSubmit;
  final bool hideFooter;
  final String submitLabel;
  final List<String>? sessionOptionsOverride;
  final bool lockSession;

  @override
  Widget build(BuildContext context) {
    final win = BettingWindowScope.of(context);
    final gameName = (market['gameName'] ?? market['marketName'] ?? '').toString();
    final headerTitle = gameName.isNotEmpty ? '$gameName - $title' : title;
    final minDate = getTodayIst();
    final isToday = selectedDateYmd == minDate;
    final isScheduled = selectedDateYmd.compareTo(minDate) > 0;
    final isRunning = market['status']?.toString() == 'running';

    final sessionOptions = sessionOptionsOverride != null && sessionOptionsOverride!.isNotEmpty
        ? sessionOptionsOverride!
        : (isToday && (isRunning || win.closeOnly) ? ['CLOSE'] : ['OPEN', 'CLOSE']);

    final goldBorder = BorderSide(color: AppColors.gold.withValues(alpha: 0.34), width: 1.5);

    return ColoredBox(
      color: Colors.transparent,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            CasinoUi.backdropBlur(
              borderRadius: BorderRadius.zero,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              fill: const Color(0xFF0A0908).withValues(alpha: 0.36),
              border: Border(bottom: goldBorder),
              child: Row(
                children: [
                  IconButton(
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back, size: 20),
                    color: CasinoUi.mutedGold(0.95),
                  ),
                  Expanded(
                    child: Text(
                      headerTitle,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: CasinoUi.lightGold,
                      ),
                    ),
                  ),
                  CasinoUi.backdropBlur(
                    borderRadius: BorderRadius.circular(20),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    fill: const Color(0xFF0A0908).withValues(alpha: 0.40),
                    border: Border.all(color: AppColors.gold.withValues(alpha: 0.34), width: 1.5),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.network(
                          RemoteAssets.walletIcon,
                          width: 20,
                          height: 20,
                          errorBuilder: (_, _, _) => Icon(Icons.wallet, size: 18, color: AppColors.gold.withValues(alpha: 0.85)),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '₹${walletBalance.toStringAsFixed(1)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: CasinoUi.lightGold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (!win.allowed && win.message != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.accentRose.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.accentRose.withValues(alpha: 0.45)),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: AppColors.accentRose.withValues(alpha: 0.95)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          win.message!,
                          style: TextStyle(color: CasinoUi.mutedGold(0.92), fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      alignment: Alignment.center,
                      constraints: const BoxConstraints(minHeight: AppSpacing.buttonMinHeight),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.buttonPaddingH,
                        vertical: AppSpacing.buttonPaddingV,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.gold.withValues(alpha: 0.34)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_today, size: 16, color: AppColors.gold.withValues(alpha: 0.9)),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              isScheduled ? '$selectedDateYmd · scheduled' : selectedDateYmd,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, color: CasinoUi.lightGold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        dropdownMenuTheme: DropdownMenuThemeData(
                          menuStyle: MenuStyle(
                            backgroundColor: WidgetStateProperty.all(CasinoUi.fieldFill),
                          ),
                        ),
                      ),
                      child: DropdownButtonFormField<String>(
                        key: ValueKey<String>('${session}_${sessionOptions.join()}'),
                        initialValue: sessionOptions.contains(session) ? session : sessionOptions.first,
                        dropdownColor: CasinoUi.fieldFill,
                        style: const TextStyle(color: CasinoUi.lightGold, fontWeight: FontWeight.w600, fontSize: 14),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: CasinoUi.fieldFill,
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
                            borderSide: BorderSide(color: AppColors.gold.withValues(alpha: 0.72), width: 2),
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.inputPaddingH,
                            vertical: AppSpacing.inputPaddingV,
                          ),
                        ),
                        items: sessionOptions
                            .map(
                              (e) => DropdownMenuItem(
                                value: e,
                                child: Text(e, textAlign: TextAlign.center, style: const TextStyle(color: CasinoUi.lightGold)),
                              ),
                            )
                            .toList(),
                        onChanged: (lockSession || (isToday && isRunning && sessionOptionsOverride == null))
                            ? null
                            : (v) {
                                if (v != null) onSessionChanged(v);
                              },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Theme(
                data: Theme.of(context).copyWith(
                  inputDecorationTheme: CasinoUi.inputDecorationOnDark(context),
                  textTheme: Theme.of(context).textTheme.apply(
                    bodyColor: Colors.white,
                    displayColor: Colors.white,
                  ),
                ),
                child: DefaultTextStyle(
                  style: GameBidUi.bodyFallback,
                  child: body,
                ),
              ),
            ),
            if (!hideFooter)
              SafeArea(
                top: false,
                child: CasinoUi.backdropBlur(
                  borderRadius: BorderRadius.zero,
                  fill: const Color(0xFF0A0908).withValues(alpha: 0.40),
                  border: Border(top: goldBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, -4),
                    ),
                  ],
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Bets', style: TextStyle(fontSize: 10, color: CasinoUi.mutedGold(0.65))),
                              Text(
                                '$bidsCount',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: CasinoUi.lightGold),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Points', style: TextStyle(fontSize: 10, color: CasinoUi.mutedGold(0.65))),
                              Text(
                                '$totalPoints',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: CasinoUi.lightGold),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            onPressed: (onSubmit == null || bidsCount == 0 || !win.allowed) ? null : onSubmit,
                            style: GameBidUi.primaryFilled(),
                            child: Text(submitLabel, textAlign: TextAlign.center),
                          ),
                        ),
                      ],
                    ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
