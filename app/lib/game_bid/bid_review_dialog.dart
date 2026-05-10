import 'package:flutter/material.dart';

import '../models/bid_row_vm.dart';
import '../services/auth_service.dart';
import '../services/bet_history_storage.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/casino_ui.dart';
import '../utils/market_timing.dart';
import 'game_bid_ui.dart';

export '../models/bid_row_vm.dart' show BidRowVm;

Future<void> showBidReviewDialog({
  required BuildContext context,
  required BettingWindowResult bettingWindow,
  required String marketTitle,
  required List<BidRowVm> rows,
  required double walletBefore,
  required Future<void> Function() onConfirm,
  String labelKey = 'Bet',
  String? historyDateYmd,

  /// e.g. "Single Digit", "Jodi" — shown so users see which bet category is being placed.
  String? betCategoryTitle,

  /// Called when the user taps Cancel — clear staged bets on the parent screen.
  VoidCallback? onCancel,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _BidReviewDialog(
      bettingWindow: bettingWindow,
      marketTitle: marketTitle,
      rows: rows,
      walletBefore: walletBefore,
      onConfirm: onConfirm,
      labelKey: labelKey,
      historyDateYmd: historyDateYmd,
      betCategoryTitle: betCategoryTitle,
      onCancel: onCancel,
    ),
  );
}

class _BidReviewDialog extends StatefulWidget {
  const _BidReviewDialog({
    required this.bettingWindow,
    required this.marketTitle,
    required this.rows,
    required this.walletBefore,
    required this.onConfirm,
    required this.labelKey,
    required this.historyDateYmd,
    this.betCategoryTitle,
    this.onCancel,
  });

  final BettingWindowResult bettingWindow;
  final String marketTitle;
  final List<BidRowVm> rows;
  final double walletBefore;
  final Future<void> Function() onConfirm;
  final String labelKey;
  final String? historyDateYmd;
  final String? betCategoryTitle;
  final VoidCallback? onCancel;

  @override
  State<_BidReviewDialog> createState() => _BidReviewDialogState();
}

class _BidReviewDialogState extends State<_BidReviewDialog> {
  bool _submitting = false;
  String? _err;

  String _dateDisplayDdMmYyyy() {
    final ymd =
        (widget.historyDateYmd != null &&
            widget.historyDateYmd!.trim().isNotEmpty)
        ? widget.historyDateYmd!.trim()
        : getTodayIst();
    final parts = ymd.split('-');
    if (parts.length == 3) {
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final d = int.tryParse(parts[2]);
      if (y != null && m != null && d != null) {
        return '${d.toString().padLeft(2, '0')}/${m.toString().padLeft(2, '0')}/$y';
      }
    }
    return ymd;
  }

  Widget _statCell(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              height: 1.2,
              color: CasinoUi.mutedGold(0.65),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: CasinoUi.lightGold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final win = widget.bettingWindow;
    final total = widget.rows.fold<double>(
      0,
      (s, r) => s + (double.tryParse(r.points) ?? 0),
    );
    final after = widget.walletBefore - total;
    final insufficient = after < 0;
    final hasOpenWhenCloseOnly = win.closeOnly &&
        widget.rows.any((r) => r.sessionLabel.toUpperCase() == 'OPEN');
    final cannot = insufficient || !win.allowed || hasOpenWhenCloseOnly;
    final borderColor = Colors.white.withValues(alpha: 0.14);
    final headerTitle = widget.marketTitle.isEmpty
        ? 'Confirm Bets'
        : widget.marketTitle;
    final dateLine = _dateDisplayDdMmYyyy();
    final totalAmountStr = total == total.roundToDouble()
        ? total.toInt().toString()
        : total.toStringAsFixed(1);

    return Dialog(
      backgroundColor: CasinoUi.fieldFill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: borderColor, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            const reservedOutsideBody = 152.0;
            final bodyMaxH = constraints.maxHeight.isFinite
                ? (constraints.maxHeight - reservedOutsideBody).clamp(
                    0.0,
                    constraints.maxHeight,
                  )
                : double.infinity;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated.withValues(alpha: 0.65),
                    border: Border(
                      bottom: BorderSide(color: borderColor, width: 1),
                    ),
                  ),
                  child: Text(
                    '$headerTitle - $dateLine',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: CasinoUi.lightGold,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: bodyMaxH),
                  child: ListView(
                    shrinkWrap: true,
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                    children: [
                        if (!win.allowed && win.message != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              win.message!,
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        if (hasOpenWhenCloseOnly)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              'Opening time has passed — open-session bets are not allowed. '
                              'Switch to CLOSE on the betting screen so lines are submitted as close.',
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        if (insufficient)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              'Insufficient balance',
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        if (widget.betCategoryTitle != null &&
                            widget.betCategoryTitle!.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              'Bet type: ${widget.betCategoryTitle!.trim()}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: CasinoUi.lightGold,
                              ),
                            ),
                          ),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.labelKey,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: CasinoUi.lightGold,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'Points',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: CasinoUi.lightGold,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'Session',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: CasinoUi.lightGold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ...widget.rows.map(
                          (r) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: AppColors.surfaceCard.withValues(
                                  alpha: 0.55,
                                ),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: borderColor),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 8,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        r.number,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                          color: CasinoUi.lightGold,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        r.points,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                          color: CasinoUi.lightGold,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        r.sessionLabel.toUpperCase(),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                          color: CasinoUi.lightGold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: borderColor),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Table(
                            border: TableBorder(
                              horizontalInside: BorderSide(color: borderColor),
                              verticalInside: BorderSide(color: borderColor),
                            ),
                            children: [
                              TableRow(
                                children: [
                                  _statCell(
                                    'Total Bets',
                                    '${widget.rows.length}',
                                  ),
                                  _statCell('Total Bet Amount', totalAmountStr),
                                ],
                              ),
                              TableRow(
                                children: [
                                  _statCell(
                                    'Wallet Balance Before Deduction',
                                    widget.walletBefore.toStringAsFixed(1),
                                  ),
                                  _statCell(
                                    'Wallet Balance After Deduction',
                                    after.toStringAsFixed(1),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          '*Note: Bet once placed cannot be cancelled*',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (_err != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            _err!,
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                    ],
                  ),
                ),
                Divider(height: 1, thickness: 1, color: borderColor),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _submitting
                              ? null
                              : () {
                                  widget.onCancel?.call();
                                  Navigator.pop(context);
                                },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: CasinoUi.lightGold,
                            side: BorderSide(color: borderColor),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.buttonPaddingH,
                              vertical: AppSpacing.buttonPaddingV,
                            ),
                            minimumSize: const Size(0, AppSpacing.buttonMinHeight),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: cannot || _submitting
                              ? null
                              : () async {
                                  setState(() {
                                    _submitting = true;
                                    _err = null;
                                  });
                                  try {
                                    await widget.onConfirm();
                                    if (!context.mounted) return;
                                    final u = await AuthService.instance
                                        .getStoredUser();
                                    final uid =
                                        u?['_id']?.toString() ??
                                        u?['id']?.toString();
                                    final ymd =
                                        (widget.historyDateYmd != null &&
                                            widget.historyDateYmd!
                                                .trim()
                                                .isNotEmpty)
                                        ? widget.historyDateYmd!.trim()
                                        : getTodayIst();
                                    final parts = ymd.split('-');
                                    String dateText = ymd;
                                    if (parts.length == 3) {
                                      final y = int.tryParse(parts[0]);
                                      final m = int.tryParse(parts[1]);
                                      final d = int.tryParse(parts[2]);
                                      if (y != null && m != null && d != null) {
                                        dateText =
                                            '${d.toString().padLeft(2, '0')}/${m.toString().padLeft(2, '0')}/$y';
                                      }
                                    }
                                    final totalAfter = widget.rows.fold<double>(
                                      0,
                                      (s, r) =>
                                          s + (double.tryParse(r.points) ?? 0),
                                    );
                                    await BetHistoryStorage.instance
                                        .appendEntry(
                                          userId: uid,
                                          marketTitle: widget.marketTitle,
                                          dateText: dateText,
                                          labelKey: widget.labelKey,
                                          rows: widget.rows,
                                          totalBets: widget.rows.length,
                                          totalAmount: totalAfter,
                                        );
                                    if (!context.mounted) return;
                                    Navigator.pop(context);
                                  } catch (e) {
                                    setState(() {
                                      _submitting = false;
                                      _err = e.toString().replaceFirst(
                                        'Exception: ',
                                        '',
                                      );
                                    });
                                  }
                                },
                          style: GameBidUi.primaryFilled(),
                          child: _submitting
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: GameBidUi.primaryFilledForeground,
                                  ),
                                )
                              : const Text(
                                  'Submit Bet',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

Future<void> applyNewBalance(num? newBalance) async {
  if (newBalance != null) {
    await AuthService.instance.updateStoredBalance(newBalance);
  }
}
