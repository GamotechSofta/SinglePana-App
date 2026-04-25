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
import '../pana_rules.dart';

class _PanaLine {
  _PanaLine({required this.number, required this.points, required this.session});

  final String number;
  final String points;
  final String session;
}

class DoublePanaBulkBidScreen extends StatefulWidget {
  const DoublePanaBulkBidScreen({super.key, required this.market, required this.title});

  final Map<String, dynamic> market;
  final String title;

  @override
  State<DoublePanaBulkBidScreen> createState() => _DoublePanaBulkBidScreenState();
}

class _DoublePanaBulkBidScreenState extends State<DoublePanaBulkBidScreen> {
  static const _quickPoints = [10, 20, 30, 40, 50];
  String _session = 'OPEN';
  String _dateYmd = '';
  double _wallet = 0;
  String _warn = '';

  late final Map<String, List<String>> _doublePanaBySum;
  late final Map<String, String> _specialInputs;
  late final Map<String, TextEditingController> _groupBulkCtrls;

  @override
  void initState() {
    super.initState();
    _session = widget.market['status']?.toString() == 'running' ? 'CLOSE' : 'OPEN';
    _doublePanaBySum = _buildDoublePanaBySum();
    _specialInputs = {
      for (final list in _doublePanaBySum.values)
        for (final pana in list) pana: '',
    };
    _groupBulkCtrls = {for (var i = 0; i < 10; i++) '$i': TextEditingController()};
    _init();
  }

  @override
  void dispose() {
    for (final c in _groupBulkCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, List<String>> _buildDoublePanaBySum() {
    final groups = {for (var i = 0; i < 10; i++) '$i': <String>[]};
    for (final n in allValidDoublePanas()) {
      final digits = n.split('').map(int.parse).toList();
      final s = (digits[0] + digits[1] + digits[2]) % 10;
      groups['$s']!.add(n);
    }
    for (final list in groups.values) {
      list.sort((a, b) => int.parse(a).compareTo(int.parse(b)));
    }
    return groups;
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

  String _sanitize(String v) {
    final only = v.replaceAll(RegExp(r'\D'), '').trim();
    return only.substring(0, only.length.clamp(0, 6));
  }

  /// Parses ordered positive integers from [raw] (commas, spaces, semicolons).
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
    final list = _doublePanaBySum[groupKey] ?? const <String>[];
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
      } else {
        for (var i = 0; i < list.length && i < values.length; i++) {
          _specialInputs[list[i]] = '${values[i]}';
        }
      }
      _groupBulkCtrls[groupKey]?.clear();
    });
    if (extraIgnored) {
      _toast('Extra values after ${list.length} panas were ignored');
    }
  }

  void _clearGroup(String groupKey) {
    final list = _doublePanaBySum[groupKey] ?? const <String>[];
    setState(() {
      for (final pana in list) {
        _specialInputs[pana] = '';
      }
      _groupBulkCtrls[groupKey]?.clear();
    });
  }

  void _applyQuickGroupPoints(String groupKey, int points) {
    final c = _groupBulkCtrls[groupKey];
    if (c == null) return;
    setState(() => c.text = '$points');
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
    });
  }

  Future<void> _submit() async {
    final rows = _selectedLines();
    if (rows.isEmpty) {
      _toast('Please enter points for at least one Double Pana');
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
        if (!mounted) return;
        if (res.newBalance != null) _wallet = res.newBalance!.toDouble();
        _clearAll();
        setState(() {
          _dateYmd = DateTime.now().toIso8601String().split('T').first;
        });
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
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: CasinoUi.neutralShellBorderColor(alpha: 0.14)),
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
            final list = _doublePanaBySum[groupKey] ?? const <String>[];
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
                              style: GameBidUi.betInputStyle(fontSize: 13, fontWeight: FontWeight.w600),
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
                                final sel = _groupBulkCtrls[groupKey]?.text.trim() == '$p';
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
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            GameBidUi.bulkPanaDigitChip(label: num),
                            SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: GameBidUi.betPointsRectangleSlot(
                                extent: GameBidUi.bulkPanaInlineRowHeight,
                                child: TextFormField(
                                  key: ValueKey('dp_${num}_$val'),
                                  initialValue: val,
                                  keyboardType: TextInputType.number,
                                  expands: true,
                                  minLines: null,
                                  maxLines: null,
                                  textAlign: TextAlign.center,
                                  textAlignVertical: TextAlignVertical.center,
                                  onChanged: (v) => setState(() => _specialInputs[num] = _sanitize(v)),
                                  style: GameBidUi.betInputStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    constraints: const BoxConstraints(
                                      minHeight: GameBidUi.bulkPanaInlineRowHeight,
                                      maxHeight: GameBidUi.bulkPanaInlineRowHeight,
                                    ),
                                    hintText: 'Pts',
                                    hintStyle: TextStyle(color: CasinoUi.mutedGold(0.45)),
                                    filled: true,
                                    fillColor: CasinoUi.fieldFill,
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
            Text('No selected double pana yet', style: GameBidUi.emptyHint)
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

