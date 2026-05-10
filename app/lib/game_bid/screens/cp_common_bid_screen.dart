import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/bets_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/casino_ui.dart';
import '../bet_date_prefs.dart';
import '../betting_window_scope.dart';
import '../bid_review_dialog.dart';
import '../game_bid_layout.dart';
import '../game_bid_ui.dart';
import '../pana_rules.dart';

class CpCommonBidScreen extends StatefulWidget {
  const CpCommonBidScreen({super.key, required this.market, required this.title});

  final Map<String, dynamic> market;
  final String title;

  @override
  State<CpCommonBidScreen> createState() => _CpCommonBidScreenState();
}

class _CpCommonBidScreenState extends State<CpCommonBidScreen> {
  static const _quickPoints = [10, 20, 30, 40, 50];
  static final List<String> _singlePanas = validSinglePanas.toList()..sort();
  static final List<String> _doublePanas = allValidDoublePanas().toList()..sort();

  String _session = 'OPEN';
  String _dateYmd = '';
  double _wallet = 0;
  String _warn = '';
  bool _includeSp = false;
  bool _includeDp = false;
  bool _includeTriple = false;
  final List<String> _selectedDigits = [];
  final _ptsCtrl = TextEditingController();
  List<({String id, String pana, String points})> _rows = [];
  Timer? _generateDebounce;

  @override
  void initState() {
    super.initState();
    _session = widget.market['status']?.toString() == 'running' ? 'CLOSE' : 'OPEN';
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
    _generateDebounce?.cancel();
    _ptsCtrl.dispose();
    super.dispose();
  }

  void _toast(String m) {
    setState(() => _warn = m);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _warn = '');
    });
  }

  void _toggleDigit(int d) {
    final s = '$d';
    setState(() {
      if (_selectedDigits.contains(s)) {
        _selectedDigits.remove(s);
      } else {
        if (_selectedDigits.length >= 2) {
          _toast('Select at most 2 digits for CP.');
          return;
        }
        _selectedDigits.add(s);
        _selectedDigits.sort((a, b) => int.parse(a).compareTo(int.parse(b)));
      }
    });
    _scheduleGenerate();
  }

  void _clearLocal() {
    setState(() {
      _selectedDigits.clear();
      _ptsCtrl.clear();
      _includeSp = false;
      _includeDp = false;
      _includeTriple = false;
      _rows = [];
    });
  }

  void _generate({bool silent = false}) {
    final pts = num.tryParse(_ptsCtrl.text.trim()) ?? 0;
    final useSingles = _includeSp || _includeTriple;
    final useDoubles = _includeDp || _includeTriple;
    if (_selectedDigits.isEmpty || _selectedDigits.length > 2) {
      if (silent) {
        if (_rows.isNotEmpty) setState(() => _rows = []);
      } else {
        _toast('Select 1 or 2 digits.');
      }
      return;
    }
    if (pts <= 0) {
      if (silent) {
        if (_rows.isNotEmpty) setState(() => _rows = []);
      } else {
        _toast('Points must be greater than 0.');
      }
      return;
    }
    if (!useSingles && !useDoubles && !_includeTriple) {
      if (silent) {
        if (_rows.isNotEmpty) setState(() => _rows = []);
      } else {
        _toast('Select at least one filter: SP / DP / SPDPT.');
      }
      return;
    }

    final required = _selectedDigits.toSet();
    final merged = <String, int>{};

    if (useSingles) {
      for (final pana in _singlePanas) {
        if (required.every(pana.contains)) merged[pana] = pts.toInt();
      }
    }
    if (useDoubles) {
      for (final pana in _doublePanas) {
        if (required.every(pana.contains)) merged[pana] = pts.toInt();
      }
    }
    if (_includeTriple) {
      // One triple per selected digit (ddd), not “all digits in one triple” (impossible for two distinct digits).
      for (final d in required) {
        final di = int.tryParse(d);
        if (di == null) continue;
        final pana = '$di$di$di';
        if (!isValidTriplePana(pana)) continue;
        merged[pana] = pts.toInt();
      }
    }

    final panas = merged.keys.toList()..sort((a, b) => int.parse(a).compareTo(int.parse(b)));
    if (panas.isEmpty) {
      if (!silent) _toast('No CP combinations found for selected filters.');
      if (_rows.isNotEmpty) setState(() => _rows = []);
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    setState(() {
      _rows = [for (var i = 0; i < panas.length; i++) (id: '${panas[i]}-$now-$i', pana: panas[i], points: '${merged[panas[i]] ?? 0}')];
    });
  }

  void _scheduleGenerate() {
    _generateDebounce?.cancel();
    _generateDebounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      _generate(silent: true);
    });
  }

  Future<void> _submit() async {
    final active = _rows.where((r) => (int.tryParse(r.points) ?? 0) > 0).toList();
    if (active.isEmpty) {
      _toast('Generate and keep at least one row with points.');
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
      onCancel: () {
        if (!mounted) return;
        setState(() {});
      },
      rows: active.map((r) => BidRowVm(id: r.id, number: r.pana, points: r.points, sessionLabel: _session)).toList(),
      onConfirm: () async {
        final mid = widget.market['id'] ?? widget.market['_id'];
        final sched = scheduledDateIfFuture(_dateYmd);
        final lines = active
            .map(
              (r) => PlaceBetLine(
                betType: 'cp-common',
                betNumber: r.pana,
                amount: int.tryParse(r.points) ?? 0,
                betOn: _session.toUpperCase() == 'CLOSE' ? 'close' : 'open',
              ),
            )
            .toList();
        final res = await BetsService.instance.placeBet(marketId: mid, lines: lines, scheduledDate: sched);
        if (!res.success) throw Exception(res.message ?? 'Failed');
        await applyNewBalance(res.newBalance);
        await clearBetSelectedDate();
        if (!mounted) return;
        setState(() {
          _clearLocal();
          if (res.newBalance != null) _wallet = res.newBalance!.toDouble();
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tile = GameBidUi.defaultBetTileExtent(context);
    final active = _rows.where((r) => (int.tryParse(r.points) ?? 0) > 0).toList();
    final total = active.fold<int>(0, (s, r) => s + (int.tryParse(r.points) ?? 0));
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
      bidsCount: active.length,
      totalPoints: total,
      onSubmit: _submit,
      submitLabel: 'Submit',
      onBack: () => Navigator.of(context).pop(),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (_warn.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_warn, style: TextStyle(color: Colors.red.shade700)),
            ),
          Row(
            children: [
              Text('Select Digits', style: GameBidUi.sectionLabel),
              const Spacer(),
              Row(
                children: [
                  Checkbox(
                    value: _includeSp,
                    onChanged: (v) {
                      setState(() => _includeSp = v ?? false);
                      _scheduleGenerate();
                    },
                    visualDensity: VisualDensity.compact,
                    side: const BorderSide(color: AppColors.gold),
                  ),
                  const Text('SP', style: TextStyle(color: CasinoUi.lightGold)),
                  const SizedBox(width: 4),
                  Checkbox(
                    value: _includeDp,
                    onChanged: (v) {
                      setState(() => _includeDp = v ?? false);
                      _scheduleGenerate();
                    },
                    visualDensity: VisualDensity.compact,
                    side: const BorderSide(color: AppColors.gold),
                  ),
                  const Text('DP', style: TextStyle(color: CasinoUi.lightGold)),
                  const SizedBox(width: 4),
                  Checkbox(
                    value: _includeTriple,
                    onChanged: (v) {
                      setState(() => _includeTriple = v ?? false);
                      _scheduleGenerate();
                    },
                    visualDensity: VisualDensity.compact,
                    side: const BorderSide(color: AppColors.gold),
                  ),
                  const Text('SPDPT', style: TextStyle(color: CasinoUi.lightGold)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              mainAxisExtent: tile,
            ),
            itemCount: 10,
            itemBuilder: (context, i) {
              final sel = _selectedDigits.contains('$i');
              return OutlinedButton(
                onPressed: () => _toggleDigit(i),
                style: GameBidUi.outlineDigit(sel, extent: tile),
                child: Text('$i', style: const TextStyle(fontWeight: FontWeight.w700)),
              );
            },
          ),
          if (_includeTriple) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Triple panas (SPDPT)', style: GameBidUi.sectionLabel),
            ),
            const SizedBox(height: 6),
            if (_selectedDigits.isEmpty)
              Text(
                'Select digit(s) — each chosen digit adds its triple (e.g. 7 → 777).',
                style: GameBidUi.emptyHint.copyWith(height: 1.3),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final d in _selectedDigits)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceCard.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.gold.withValues(alpha: 0.38)),
                      ),
                      child: Text(
                        '$d$d$d',
                        style: const TextStyle(
                          color: CasinoUi.lightGold,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                ],
              ),
          ],
          const SizedBox(height: 10),
          TextField(
            controller: _ptsCtrl,
            keyboardType: TextInputType.number,
            onChanged: (_) {
              setState(() {});
              _scheduleGenerate();
            },
            decoration: GameBidUi.inputDecoration(labelText: 'Points per line'),
          ),
          const SizedBox(height: GameBidUi.quickPointsAfterFieldGap),
          Row(
            children: [
              Text('Quick points', style: GameBidUi.sectionLabel),
              const Spacer(),
              TextButton(
                style: GameBidUi.quickPointsClearTextButtonStyle,
                onPressed: _clearLocal,
                child: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: GameBidUi.quickPointsHeaderToChipsGap),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _quickPoints.map((p) {
              final sel = _ptsCtrl.text.trim() == '$p';
              return GameBidUi.quickPointsChip(
                selected: sel,
                label: '$p',
                extent: tile,
                onSelected: (_) {
                  setState(() => _ptsCtrl.text = '$p');
                  _scheduleGenerate();
                },
              );
            }).toList(),
          ),
          const Divider(height: 24),
          Text('Your bets', style: GameBidUi.panelTitle.copyWith(fontSize: 15)),
          if (_rows.isEmpty)
            Text('No bets yet', style: GameBidUi.emptyHint)
          else
            ..._rows.map(
              (r) => ListTile(
                dense: true,
                title: Text(
                  '${r.pana} · $_session',
                  style: const TextStyle(color: CasinoUi.lightGold, fontWeight: FontWeight.w600),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('₹${r.points}', style: TextStyle(color: CasinoUi.mutedGold(0.9))),
                    IconButton(
                      onPressed: () => setState(() => _rows = _rows.where((e) => e.id != r.id).toList()),
                      icon: Icon(Icons.close, color: AppColors.gold.withValues(alpha: 0.85)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
