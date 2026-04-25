import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/bets_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/casino_ui.dart';
import '../bet_date_prefs.dart';
import '../bid_review_dialog.dart';
import '../betting_window_scope.dart';
import '../game_bid_layout.dart';
import '../game_bid_ui.dart';
import '../pana_rules.dart';

class _Row {
  _Row({required this.id, required this.pana, required this.points});
  final String id;
  final String pana;
  String points;
}

class DpMotorBidScreen extends StatefulWidget {
  const DpMotorBidScreen({super.key, required this.market, required this.title});

  final Map<String, dynamic> market;
  final String title;

  @override
  State<DpMotorBidScreen> createState() => _DpMotorBidScreenState();
}

class _DpMotorBidScreenState extends State<DpMotorBidScreen> {
  static const _quickPoints = [10, 20, 30, 40, 50];
  String _session = 'OPEN';
  String _dateYmd = '';
  double _wallet = 0;
  String _warn = '';
  final Set<int> _selectedDigits = {};
  final _digitsCtrl = TextEditingController();
  final _ptsCtrl = TextEditingController();
  final List<_Row> _rows = [];
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
    _digitsCtrl.dispose();
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
    setState(() {
      if (_selectedDigits.contains(d)) {
        _selectedDigits.remove(d);
      } else {
        _selectedDigits.add(d);
      }
      _digitsCtrl.text = (_selectedDigits.toList()..sort()).join();
    });
    _scheduleGenerate();
  }

  List<String> _generateDoubleCombos(String digitStr) {
    final digits = digitStr.replaceAll(RegExp(r'\D'), '').split('').toSet().toList()..sort();
    if (digits.length < 2) return [];
    final out = <String>{};
    for (var i = 0; i < digits.length; i++) {
      for (var j = 0; j < digits.length; j++) {
        if (i == j) continue;
        final a = digits[i];
        final b = digits[j];
        out.add('$a$a$b');
        out.add('$a$b$a');
        out.add('$b$a$a');
      }
    }
    return out.where(isValidDoublePana).toList()..sort((a, b) => int.parse(a).compareTo(int.parse(b)));
  }

  void _clearLocal() {
    setState(() {
      _selectedDigits.clear();
      _digitsCtrl.clear();
      _ptsCtrl.clear();
      _rows.clear();
    });
  }

  void _generate({bool silent = false}) {
    final digits = _digitsCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 2) {
      if (!silent) _toast('Enter at least 2 digits to generate double pana combinations.');
      if (silent && _rows.isNotEmpty) setState(() => _rows.clear());
      return;
    }
    final pts = int.tryParse(_ptsCtrl.text.trim()) ?? 0;
    if (pts < 1) {
      if (!silent) _toast('Please enter points.');
      if (silent && _rows.isNotEmpty) setState(() => _rows.clear());
      return;
    }
    final combos = _generateDoubleCombos(digits);
    if (combos.isEmpty) {
      if (!silent) _toast('No valid double pana from these digits.');
      if (silent && _rows.isNotEmpty) setState(() => _rows.clear());
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    setState(() {
      _rows
        ..clear()
        ..addAll([for (var i = 0; i < combos.length; i++) _Row(id: '${combos[i]}-$now-$i', pana: combos[i], points: '$pts')]);
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
    if (active.isEmpty) return _toast('Add at least one combination with points.');
    final win = BettingWindowScope.of(context);
    final name = (widget.market['gameName'] ?? widget.market['marketName'] ?? widget.title).toString();
    await showBidReviewDialog(
      context: context,
      bettingWindow: win,
      marketTitle: name,
      walletBefore: _wallet,
      labelKey: 'Dp Motor',
      betCategoryTitle: widget.title,
      historyDateYmd: _dateYmd,
      onCancel: () {
        if (!mounted) return;
        setState(() => _rows.clear());
      },
      rows: active.map((r) => BidRowVm(id: r.id.hashCode, number: r.pana, points: r.points, sessionLabel: _session)).toList(),
      onConfirm: () async {
        final mid = widget.market['id'] ?? widget.market['_id'];
        final sched = scheduledDateIfFuture(_dateYmd);
        final lines = active
            .map((r) => PlaceBetLine(betType: 'dp-motor', betNumber: r.pana, amount: int.tryParse(r.points) ?? 0, betOn: _session.toUpperCase() == 'CLOSE' ? 'close' : 'open'))
            .toList();
        final res = await BetsService.instance.placeBet(marketId: mid, lines: lines, scheduledDate: sched);
        if (!res.success) throw Exception(res.message ?? 'Failed');
        await applyNewBalance(res.newBalance);
        await clearBetSelectedDate();
        if (!mounted) return;
        setState(() {
          _rows.clear();
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
      onBack: () => Navigator.of(context).pop(),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (_warn.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_warn, style: TextStyle(color: Colors.red.shade700)),
            ),
          Text('Select Digits', style: GameBidUi.sectionLabel),
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
              final sel = _selectedDigits.contains(i);
              return OutlinedButton(
                onPressed: () => _toggleDigit(i),
                style: GameBidUi.outlineDigit(sel, extent: tile),
                child: Text('$i', style: const TextStyle(fontWeight: FontWeight.w700)),
              );
            },
          ),
          const SizedBox(height: 8),
          TextField(
            readOnly: true,
            controller: _digitsCtrl,
            decoration: GameBidUi.inputDecoration(labelText: 'Enter digits', hintText: 'Tap digits above'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ptsCtrl,
            keyboardType: TextInputType.number,
            onChanged: (_) {
              setState(() {});
              _scheduleGenerate();
            },
            decoration: GameBidUi.inputDecoration(labelText: 'Points per pana'),
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
                      onPressed: () => setState(() => _rows.removeWhere((e) => e.id == r.id)),
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
