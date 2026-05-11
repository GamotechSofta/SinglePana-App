import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/auth_service.dart';
import '../../services/bets_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/casino_ui.dart';
import '../bet_date_prefs.dart';
import '../bid_review_dialog.dart';
import '../betting_window_scope.dart';
import '../game_bid_layout.dart';
import '../game_bid_ui.dart';

class _PanaLine {
  _PanaLine({required this.number, required this.points, required this.session});

  final String number;
  final String points;
  final String session;
}

const Map<String, List<String>> _singlePanaBySum = {
  '0': ['127', '136', '145', '190', '235', '280', '370', '389', '460', '479', '569', '578'],
  '1': ['128', '137', '146', '236', '245', '290', '380', '470', '489', '560', '579', '678'],
  '2': ['129', '138', '147', '156', '237', '246', '345', '390', '480', '570', '589', '679'],
  '3': ['120', '139', '148', '157', '238', '247', '256', '346', '490', '580', '670', '689'],
  '4': ['130', '149', '158', '167', '239', '248', '257', '347', '356', '590', '680', '789'],
  '5': ['140', '159', '168', '230', '249', '258', '267', '348', '357', '456', '690', '780'],
  '6': ['123', '150', '169', '178', '240', '259', '268', '349', '358', '367', '457', '790'],
  '7': ['124', '160', '179', '250', '269', '278', '340', '359', '368', '458', '467', '890'],
  '8': ['125', '134', '170', '189', '260', '279', '350', '369', '378', '459', '468', '567'],
  '9': ['126', '135', '180', '234', '270', '289', '360', '379', '450', '469', '478', '568'],
};

class SinglePanaBulkBidScreen extends StatefulWidget {
  const SinglePanaBulkBidScreen({super.key, required this.market, required this.title});

  final Map<String, dynamic> market;
  final String title;

  @override
  State<SinglePanaBulkBidScreen> createState() => _SinglePanaBulkBidScreenState();
}

class _SinglePanaBulkBidScreenState extends State<SinglePanaBulkBidScreen> {
  static const _quickPoints = [10, 20, 30, 40, 50];
  String _session = 'OPEN';
  String _dateYmd = '';
  double _wallet = 0;
  String _warn = '';

  late final Map<String, String> _specialInputs;
  late final Map<String, TextEditingController> _groupBulkCtrls;
  late final Map<String, int?> _groupQuickSelection;

  @override
  void initState() {
    super.initState();
    _session = widget.market['status']?.toString() == 'running' ? 'CLOSE' : 'OPEN';
    _specialInputs = {
      for (final list in _singlePanaBySum.values)
        for (final pana in list) pana: '',
    };
    _groupBulkCtrls = {for (var i = 0; i < 10; i++) '$i': TextEditingController()};
    _groupQuickSelection = {for (var i = 0; i < 10; i++) '$i': null};
    _init();
  }

  @override
  void dispose() {
    for (final c in _groupBulkCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _init() async {
    final u = await AuthService.instance.getStoredUser();
    final b = u?['balance'] ?? u?['walletBalance'] ?? 0;
    final d = await loadBetSelectedDateOrToday();
    if (!mounted) return;
    setState(() {
      _wallet = (b is num) ? b.toDouble() : double.tryParse(b.toString()) ?? 0;
      _dateYmd = d;
    });
  }

  void _toast(String m) {
    setState(() => _warn = m);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _warn = '');
    });
  }

  String _sanitize(String v) => v.replaceAll(RegExp(r'\D'), '').trim().substring(0, v.replaceAll(RegExp(r'\D'), '').trim().length.clamp(0, 6));

  /// Parses ordered positive integers from [raw] (any mix of separators).
  List<int> _parseAllPtsValues(String raw) {
    final out = <int>[];
    for (final m in RegExp(r'\d+').allMatches(raw)) {
      final n = int.tryParse(m.group(0)!) ?? 0;
      if (n > 0) out.add(n);
    }
    return out;
  }

  void _applyGroup(String groupKey) {
    final raw = _groupBulkCtrls[groupKey]?.text ?? '';
    final values = _parseAllPtsValues(raw);
    if (values.isEmpty) {
      _toast('Please enter points');
      return;
    }
    final list = _singlePanaBySum[groupKey] ?? const <String>[];
    final extraIgnored = values.length > list.length && values.length > 1;
    setState(() {
      for (final pana in list) {
        _specialInputs[pana] = '';
      }
      if (values.length == 1) {
        final n = values.first;
        for (final pana in list) {
          _specialInputs[pana] = '$n';
        }
        _groupQuickSelection[groupKey] = _quickPoints.contains(n) ? n : null;
      } else {
        for (var i = 0; i < list.length && i < values.length; i++) {
          _specialInputs[list[i]] = '${values[i]}';
        }
        _groupQuickSelection[groupKey] = null;
      }
      _groupBulkCtrls[groupKey]?.clear();
    });
    if (extraIgnored) {
      _toast('Extra values after ${list.length} panas were ignored');
    }
  }

  void _clearGroup(String groupKey) {
    final list = _singlePanaBySum[groupKey] ?? const <String>[];
    setState(() {
      for (final pana in list) {
        _specialInputs[pana] = '';
      }
      _groupBulkCtrls[groupKey]?.clear();
      _groupQuickSelection[groupKey] = null;
    });
  }

  void _applyQuickGroupPoints(String groupKey, int points) {
    final c = _groupBulkCtrls[groupKey];
    if (c == null) return;
    setState(() {
      _groupQuickSelection[groupKey] = points;
      c.text = '$points';
    });
    _applyGroup(groupKey);
  }

  List<_PanaLine> _selectedLines() {
    final out = <_PanaLine>[];
    for (final entry in _specialInputs.entries) {
      final pts = int.tryParse(entry.value) ?? 0;
      if (pts > 0) {
        out.add(_PanaLine(number: entry.key, points: '$pts', session: _session));
      }
    }
    return out;
  }

  void _clearAll() {
    setState(() {
      for (final k in _specialInputs.keys) {
        _specialInputs[k] = '';
      }
      for (final c in _groupBulkCtrls.values) {
        c.clear();
      }
      for (final k in _groupQuickSelection.keys) {
        _groupQuickSelection[k] = null;
      }
    });
  }

  Future<void> _submit() async {
    final rows = _selectedLines();
    if (rows.isEmpty) {
      _toast('Please enter points for at least one Single Pana');
      return;
    }
    final win = BettingWindowScope.of(context);
    final name = (widget.market['gameName'] ?? widget.market['marketName'] ?? widget.title).toString();
    await showBidReviewDialog(
      context: context,
      bettingWindow: win,
      marketTitle: name,
      walletBefore: _wallet,
      labelKey: 'Pana',
      betCategoryTitle: widget.title,
      historyDateYmd: _dateYmd,
      onCancel: _clearAll,
      rows: [
        for (final r in rows)
          BidRowVm(
            id: Object.hash(r.number, r.points, r.session, DateTime.now().microsecondsSinceEpoch),
            number: r.number,
            points: r.points,
            sessionLabel: r.session,
          ),
      ],
      onConfirm: () async {
        final mid = widget.market['id'] ?? widget.market['_id'];
        final sched = scheduledDateIfFuture(_dateYmd);
        final lines = [
          for (final r in rows)
            PlaceBetLine(
              betType: 'panna',
              betNumber: r.number,
              amount: int.tryParse(r.points) ?? 0,
              betOn: r.session.toUpperCase() == 'CLOSE' ? 'close' : 'open',
            ),
        ];
        final res = await BetsService.instance.placeBet(marketId: mid, lines: lines, scheduledDate: sched);
        if (!res.success) throw Exception(res.message ?? 'Failed');
        await applyNewBalance(res.newBalance);
        await clearBetSelectedDate();
        if (!mounted) return res;
        setState(() {
          if (res.newBalance != null) _wallet = res.newBalance!.toDouble();
          _clearAll();
          _dateYmd = DateTime.now().toIso8601String().split('T').first;
        });
        return res;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedLines();
    final total = selected.fold<int>(0, (s, e) => s + (int.tryParse(e.points) ?? 0));
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: AppColors.gold.withValues(alpha: 0.45)),
    );

    BoxDecoration cardBorderOnly({required double radius}) {
      return BoxDecoration(
        color: AppColors.surfaceCard.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: CasinoUi.neutralShellBorderColor(alpha: 0.28)),
      );
    }

    return GameBidLayout(
      market: widget.market,
      title: widget.title,
      walletBalance: _wallet,
      session: _session,
      onSessionChanged: (v) => setState(() => _session = v),
      selectedDateYmd: _dateYmd,
      onDateChanged: (v) async {
        setState(() => _dateYmd = v);
        await saveBetSelectedDate(v);
      },
      bidsCount: selected.length,
      totalPoints: total,
      onSubmit: _submit,
      onBack: () => Navigator.of(context).pop(),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (_warn.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_warn, style: TextStyle(color: Colors.red.shade700)),
            ),
          Text(
            'Pick a sum (0–9), enter points, then Apply or a quick chip. Your panas appear in each card.',
            style: GameBidUi.emptyHint.copyWith(height: 1.35),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              onPressed: _clearAll,
              style: GameBidUi.quickPointsClearOutlinedStyle(),
              child: const Text('Clear'),
            ),
          ),
          const SizedBox(height: 6),
          ...List<Widget>.generate(10, (idx) {
            final groupKey = '$idx';
            final list = _singlePanaBySum[groupKey] ?? const <String>[];
            if (list.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: cardBorderOnly(radius: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        GameBidUi.bulkPanaDigitChip(label: groupKey),
                        SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: GameBidUi.betPointsRectangleSlot(
                            extent: GameBidUi.bulkPanaInlineRowHeight,
                            child: TextFormField(
                              controller: _groupBulkCtrls[groupKey],
                              keyboardType: const TextInputType.numberWithOptions(decimal: false, signed: false),
                              expands: true,
                              minLines: null,
                              maxLines: null,
                              textAlign: TextAlign.center,
                              textAlignVertical: TextAlignVertical.center,
                              onChanged: (_) => setState(() {}),
                              style: GameBidUi.betInputStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'[0-9,\s;]')),
                                LengthLimitingTextInputFormatter(240),
                              ],
                              decoration: InputDecoration(
                                isDense: true,
                                constraints: const BoxConstraints(
                                  minHeight: GameBidUi.bulkPanaInlineRowHeight,
                                  maxHeight: GameBidUi.bulkPanaInlineRowHeight,
                                ),
                                hintText: 'All pts (e.g. 10 or 10 20 30)',
                                hintStyle: TextStyle(color: CasinoUi.mutedGold(0.45)),
                                filled: true,
                                fillColor: CasinoUi.fieldFill,
                                border: border,
                                enabledBorder: border,
                                contentPadding: GameBidUi.bulkPanaPointsFieldPadding,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: AppSpacing.sm),
                        OutlinedButton(
                          onPressed: (_groupBulkCtrls[groupKey]?.text.trim().isEmpty ?? true) ? null : () => _applyGroup(groupKey),
                          style: GameBidUi.quickPointsClearOutlinedStyle(
                            minHeight: GameBidUi.bulkPanaInlineRowHeight,
                          ),
                          child: const Text('Apply'),
                        ),
                        SizedBox(width: AppSpacing.xs),
                        OutlinedButton(
                          onPressed: () => _clearGroup(groupKey),
                          style: GameBidUi.quickPointsClearOutlinedStyle(
                            minHeight: GameBidUi.bulkPanaInlineRowHeight,
                          ),
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          'Quick points',
                          style: GameBidUi.sectionLabel,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: _quickPoints.map((p) {
                                final sel = _groupQuickSelection[groupKey] == p;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: GameBidUi.quickPointsChip(
                                    selected: sel,
                                    label: '$p',
                                    extent: GameBidUi.bulkPanaDigitExtent,
                                    onSelected: (_) => _applyQuickGroupPoints(groupKey, p),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: AppSpacing.sm,
                        crossAxisSpacing: AppSpacing.sm,
                        mainAxisExtent: GameBidUi.bulkPanaInlineRowHeight,
                      ),
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final num = list[i];
                        final val = _specialInputs[num] ?? '';
                        final hasPoints = (int.tryParse(val) ?? 0) > 0;
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            GameBidUi.bulkPanaDigitChip(label: num),
                            SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: GameBidUi.betPointsRectangleSlot(
                                extent: GameBidUi.bulkPanaInlineRowHeight,
                                child: TextFormField(
                                  key: ValueKey('p_${num}_$val'),
                                  initialValue: val,
                                  keyboardType: TextInputType.number,
                                  expands: true,
                                  minLines: null,
                                  maxLines: null,
                                  textAlign: TextAlign.center,
                                  textAlignVertical: TextAlignVertical.center,
                                  onChanged: (v) => setState(() => _specialInputs[num] = _sanitize(v)),
                                  onTap: () {
                                    if (_groupQuickSelection[groupKey] != null) {
                                      setState(() => _groupQuickSelection[groupKey] = null);
                                    }
                                  },
                                  style: GameBidUi.betInputStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    constraints: const BoxConstraints(
                                      minHeight: GameBidUi.bulkPanaInlineRowHeight,
                                      maxHeight: GameBidUi.bulkPanaInlineRowHeight,
                                    ),
                                    hintText: 'Pts',
                                    hintStyle: TextStyle(color: CasinoUi.mutedGold(0.45)),
                                    filled: true,
                                    fillColor: hasPoints
                                        ? AppColors.neonGreenDeep.withValues(alpha: 0.22)
                                        : CasinoUi.fieldFill,
                                    contentPadding: GameBidUi.bulkPanaPointsFieldPadding,
                                    border: border,
                                    enabledBorder: border,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          Text('Selected history', style: GameBidUi.panelTitle.copyWith(fontSize: 14)),
          const SizedBox(height: 6),
          if (selected.isEmpty)
            Text('No selected pana yet', style: GameBidUi.emptyHint)
          else
            ...selected.take(30).map(
              (e) => ListTile(
                dense: true,
                title: Text(
                  '${e.number} · ${e.session}',
                  style: const TextStyle(color: CasinoUi.lightGold, fontWeight: FontWeight.w600),
                ),
                trailing: Text('₹${e.points}', style: TextStyle(color: CasinoUi.mutedGold(0.9))),
              ),
            ),
        ],
      ),
    );
  }
}

