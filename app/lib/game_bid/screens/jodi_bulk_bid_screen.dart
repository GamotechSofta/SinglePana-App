import 'package:flutter/material.dart';
import 'dart:async';

import '../../services/auth_service.dart';
import '../../services/bets_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/casino_ui.dart';
import '../bet_date_prefs.dart';
import '../bid_review_dialog.dart';
import '../betting_window_scope.dart';
import '../game_bid_layout.dart';
import '../game_bid_ui.dart';

class _JodiLine {
  _JodiLine({required this.number, required this.points});
  final String number;
  final String points;
}

class JodiBulkBidScreen extends StatefulWidget {
  const JodiBulkBidScreen({super.key, required this.market, required this.title});

  final Map<String, dynamic> market;
  final String title;

  @override
  State<JodiBulkBidScreen> createState() => _JodiBulkBidScreenState();
}

class _JodiBulkBidScreenState extends State<JodiBulkBidScreen> {
  static const _digits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
  static const _quickPoints = [10, 20, 30, 40, 50];

  String _session = 'OPEN';
  String _dateYmd = '';
  double _wallet = 0;
  String _warn = '';

  late final Map<String, String> _cells;
  late final Map<String, TextEditingController> _rowBulkCtrls;
  late final Map<String, TextEditingController> _colBulkCtrls;
  final Map<String, Timer> _rowTimers = {};
  final Map<String, Timer> _colTimers = {};
  int? _activeQuickPoint;

  @override
  void initState() {
    super.initState();
    _session = 'OPEN'; // Jodi Bulk: OPEN only
    _cells = {for (final r in _digits) for (final c in _digits) '$r$c': ''};
    _rowBulkCtrls = {for (final d in _digits) d: TextEditingController()};
    _colBulkCtrls = {for (final d in _digits) d: TextEditingController()};
    _init();
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

  @override
  void dispose() {
    for (final t in _rowTimers.values) {
      t.cancel();
    }
    for (final t in _colTimers.values) {
      t.cancel();
    }
    for (final c in _rowBulkCtrls.values) {
      c.dispose();
    }
    for (final c in _colBulkCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _toast(String m) {
    setState(() => _warn = m);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _warn = '');
    });
  }

  String _sanitize(String v) {
    final only = v.replaceAll(RegExp(r'\D'), '');
    return only.substring(0, only.length.clamp(0, 6));
  }

  String _sanitizeBulkField(String v) {
    final buf = StringBuffer();
    for (final r in v.runes) {
      final c = String.fromCharCode(r);
      if (RegExp(r'[\d,\s;]').hasMatch(c)) buf.write(c);
    }
    var s = buf.toString();
    if (s.length > 200) s = s.substring(0, 200);
    return s;
  }

  List<int> _parseBulkValues(String raw) {
    final out = <int>[];
    for (final m in RegExp(r'\d+').allMatches(raw)) {
      final n = int.tryParse(m.group(0)!) ?? 0;
      if (n > 0) out.add(n);
    }
    return out;
  }

  void _setSanitized(TextEditingController ctrl, String raw) {
    final s = _sanitizeBulkField(raw);
    if (ctrl.text == s) return;
    ctrl.value = TextEditingValue(
      text: s,
      selection: TextSelection.collapsed(offset: s.length),
    );
  }

  void _scheduleRowApply(String r) {
    _rowTimers[r]?.cancel();
    final values = _parseBulkValues(_rowBulkCtrls[r]?.text ?? '');
    if (values.isEmpty) return;
    _rowTimers[r] = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      _applyRow(r);
    });
  }

  void _scheduleColApply(String c) {
    _colTimers[c]?.cancel();
    final values = _parseBulkValues(_colBulkCtrls[c]?.text ?? '');
    if (values.isEmpty) return;
    _colTimers[c] = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      _applyCol(c);
    });
  }

  void _applyRow(String r) {
    _rowTimers[r]?.cancel();
    final values = _parseBulkValues(_rowBulkCtrls[r]?.text ?? '');
    if (values.isEmpty) return;
    setState(() {
      if (values.length == 1) {
        for (final c in _digits) {
          final key = '$r$c';
          _cells[key] = '${values.first}';
        }
      } else {
        for (var i = 0; i < _digits.length && i < values.length; i++) {
          final key = '$r${_digits[i]}';
          _cells[key] = '${values[i]}';
        }
        if (values.length > _digits.length) {
          _toast('Extra row values after 10 cells were ignored');
        }
      }
      _rowBulkCtrls[r]?.clear();
    });
  }

  void _applyCol(String c) {
    _colTimers[c]?.cancel();
    final values = _parseBulkValues(_colBulkCtrls[c]?.text ?? '');
    if (values.isEmpty) return;
    setState(() {
      if (values.length == 1) {
        for (final r in _digits) {
          final key = '$r$c';
          _cells[key] = '${values.first}';
        }
      } else {
        for (var i = 0; i < _digits.length && i < values.length; i++) {
          final key = '${_digits[i]}$c';
          _cells[key] = '${values[i]}';
        }
        if (values.length > _digits.length) {
          _toast('Extra column values after 10 cells were ignored');
        }
      }
      _colBulkCtrls[c]?.clear();
    });
  }

  void _applyQuickToRow(String r) {
    final p = _activeQuickPoint;
    if (p == null) return;
    setState(() {
      for (final c in _digits) {
        _cells['$r$c'] = '$p';
      }
    });
  }

  void _applyQuickToCol(String c) {
    final p = _activeQuickPoint;
    if (p == null) return;
    setState(() {
      for (final r in _digits) {
        _cells['$r$c'] = '$p';
      }
    });
  }

  void _applyQuickToCell(String key) {
    final p = _activeQuickPoint;
    if (p == null) return;
    setState(() => _cells[key] = '$p');
  }

  void _clearAll() {
    setState(() {
      for (final k in _cells.keys) {
        _cells[k] = '';
      }
      for (final c in _rowBulkCtrls.values) {
        c.clear();
      }
      for (final c in _colBulkCtrls.values) {
        c.clear();
      }
      _activeQuickPoint = null;
    });
  }

  List<_JodiLine> _rows() {
    final out = <_JodiLine>[];
    for (final r in _digits) {
      for (final c in _digits) {
        final k = '$r$c';
        final p = int.tryParse(_cells[k] ?? '') ?? 0;
        if (p > 0) out.add(_JodiLine(number: k, points: '$p'));
      }
    }
    return out;
  }

  Future<void> _submit() async {
    final rows = _rows();
    if (rows.isEmpty) {
      _toast('Please enter points for at least one Jodi');
      return;
    }
    final win = BettingWindowScope.of(context);
    final name = (widget.market['gameName'] ?? widget.market['marketName'] ?? widget.title).toString();
    await showBidReviewDialog(
      context: context,
      bettingWindow: win,
      marketTitle: name,
      walletBefore: _wallet,
      labelKey: 'Jodi',
      betCategoryTitle: widget.title,
      historyDateYmd: _dateYmd,
      onCancel: _clearAll,
      rows: rows
          .map((r) => BidRowVm(id: Object.hash(r.number, r.points), number: r.number, points: r.points, sessionLabel: 'OPEN'))
          .toList(),
      onConfirm: () async {
        final mid = widget.market['id'] ?? widget.market['_id'];
        final sched = scheduledDateIfFuture(_dateYmd);
        final lines = rows
            .map(
              (r) => PlaceBetLine(
                betType: 'jodi',
                betNumber: r.number,
                amount: int.tryParse(r.points) ?? 0,
                betOn: 'open',
              ),
            )
            .toList();
        final res = await BetsService.instance.placeBet(marketId: mid, lines: lines, scheduledDate: sched);
        if (!res.success) throw Exception(res.message ?? 'Failed');
        await applyNewBalance(res.newBalance);
        await clearBetSelectedDate();
        if (!mounted) return res;
        setState(() {
          if (res.newBalance != null) _wallet = res.newBalance!.toDouble();
          _clearAll();
        });
        return res;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows();
    final total = rows.fold<int>(0, (s, r) => s + (int.tryParse(r.points) ?? 0));
    final tile = GameBidUi.defaultBetTileExtent(context);
    final cellBorder = GameBidUi.cellBorder();

    return GameBidLayout(
      market: widget.market,
      title: widget.title,
      walletBalance: _wallet,
      session: _session,
      onSessionChanged: (_) {},
      sessionOptionsOverride: const ['OPEN'],
      lockSession: true,
      selectedDateYmd: _dateYmd,
      onDateChanged: (v) async {
        setState(() => _dateYmd = v);
        await saveBetSelectedDate(v);
      },
      bidsCount: rows.length,
      totalPoints: total,
      onSubmit: _submit,
      onBack: () => Navigator.of(context).pop(),
      body: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          if (_warn.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(_warn, style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
            ),
          Row(
            children: [
              Text('Quick points', style: GameBidUi.sectionLabel.copyWith(fontSize: 11)),
              const Spacer(),
              TextButton(
                style: GameBidUi.quickPointsClearTextButtonStyle,
                onPressed: _clearAll,
                child: const Text('Clear', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
          if (_activeQuickPoint != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 2),
              child: Text(
                'Quick point ₹$_activeQuickPoint selected. Tap any row digit, column digit, or jodi (00-99) to apply.',
                style: TextStyle(color: CasinoUi.mutedGold(0.78), fontSize: 10),
              ),
            ),
          const SizedBox(height: GameBidUi.quickPointsHeaderToChipsGap),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _quickPoints
                .map(
                  (p) => GameBidUi.quickPointsChip(
                    selected: _activeQuickPoint == p,
                    label: '$p',
                    extent: tile,
                    onSelected: (_) => setState(() => _activeQuickPoint = p),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              children: [
                Row(
                  children: [
                    const SizedBox(width: 72),
                    for (final c in _digits)
                      SizedBox(
                        width: 38,
                        child: InkWell(
                          onTap: () => _applyQuickToCol(c),
                          borderRadius: BorderRadius.circular(6),
                          child: Center(
                            child: Text(
                              c,
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: CasinoUi.lightGold),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                Row(
                  children: [
                    SizedBox(
                      width: 36,
                      child: Text('Col', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: CasinoUi.mutedGold(0.85))),
                    ),
                    const SizedBox(width: 36),
                    for (final c in _digits)
                      SizedBox(
                        width: 38,
                        child: Padding(
                          padding: const EdgeInsets.all(1),
                          child: TextFormField(
                            controller: _colBulkCtrls[c],
                            onChanged: (v) => setState(() {
                              _setSanitized(_colBulkCtrls[c]!, v);
                              _scheduleColApply(c);
                            }),
                            onFieldSubmitted: (_) => _applyCol(c),
                            onTapOutside: (_) => _applyCol(c),
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.text,
                            style: GameBidUi.betInputStyle(fontSize: 10, fontWeight: FontWeight.w600),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: 'P',
                              hintStyle: TextStyle(fontSize: 9, color: CasinoUi.mutedGold(0.5)),
                              fillColor: CasinoUi.fieldFill,
                              filled: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 4),
                              border: cellBorder,
                              enabledBorder: cellBorder,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                for (final r in _digits)
                  Row(
                    children: [
                      SizedBox(
                        width: 18,
                        child: InkWell(
                          onTap: () => _applyQuickToRow(r),
                          borderRadius: BorderRadius.circular(6),
                          child: Center(
                            child: Text(
                              r,
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: CasinoUi.lightGold),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 54,
                        child: Padding(
                          padding: const EdgeInsets.all(1),
                          child: TextFormField(
                            controller: _rowBulkCtrls[r],
                            onChanged: (v) => setState(() {
                              _setSanitized(_rowBulkCtrls[r]!, v);
                              _scheduleRowApply(r);
                            }),
                            onFieldSubmitted: (_) => _applyRow(r),
                            onTapOutside: (_) => _applyRow(r),
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.text,
                            style: GameBidUi.betInputStyle(fontSize: 10, fontWeight: FontWeight.w600),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: 'Pts',
                              hintStyle: TextStyle(fontSize: 9, color: CasinoUi.mutedGold(0.5)),
                              fillColor: CasinoUi.fieldFill,
                              filled: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 4),
                              border: cellBorder,
                              enabledBorder: cellBorder,
                            ),
                          ),
                        ),
                      ),
                      for (final c in _digits)
                        SizedBox(
                          width: 38,
                          child: Padding(
                            padding: const EdgeInsets.all(1),
                            child: Builder(
                              builder: (context) {
                                final key = '$r$c';
                                final val = _cells[key] ?? '';
                                final hasPoints = (int.tryParse(val) ?? 0) > 0;
                                return Column(
                                  children: [
                                    Text(
                                      key,
                                      style: TextStyle(
                                        fontSize: 8,
                                        color: hasPoints ? CasinoUi.lightGold : CasinoUi.mutedGold(0.75),
                                        fontWeight: hasPoints ? FontWeight.w800 : FontWeight.w600,
                                        height: 1,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    TextFormField(
                                      key: ValueKey('joc_${r}_${c}_$val'),
                                      initialValue: val,
                                      onChanged: (v) => setState(() => _cells[key] = _sanitize(v)),
                                      onTap: () => _applyQuickToCell(key),
                                      textAlign: TextAlign.center,
                                      keyboardType: TextInputType.number,
                                      style: GameBidUi.betInputStyle(fontSize: 10, fontWeight: FontWeight.w600),
                                      decoration: InputDecoration(
                                        isDense: true,
                                        hintText: 'Pts',
                                        hintStyle: TextStyle(fontSize: 8, color: CasinoUi.mutedGold(0.5)),
                                        filled: true,
                                        fillColor: hasPoints
                                            ? AppColors.neonGreenDeep.withValues(alpha: 0.22)
                                            : CasinoUi.fieldFill,
                                        contentPadding: const EdgeInsets.symmetric(vertical: 4),
                                        border: cellBorder,
                                        enabledBorder: cellBorder,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

