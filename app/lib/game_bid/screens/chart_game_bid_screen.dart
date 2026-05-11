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

class ChartGameBidScreen extends StatefulWidget {
  const ChartGameBidScreen({super.key, required this.market, required this.title});

  final Map<String, dynamic> market;
  final String title;

  @override
  State<ChartGameBidScreen> createState() => _ChartGameBidScreenState();
}

class _ChartGameBidScreenState extends State<ChartGameBidScreen> {
  static const _quickPoints = [10, 20, 30, 40, 50];
  static const _digitOrder = [1, 2, 3, 4, 5, 6, 7, 8, 9, 0];
  static const Map<String, Map<int, List<int>>> _chartData = {
    '20CHT': {
      1: [489, 560],
      2: [156, 237],
      3: [238, 490],
      4: [167, 590],
      5: [267, 348],
      6: [150, 249],
      7: [160, 278],
      8: [378, 459],
      9: [126, 450],
      0: [127, 389],
    },
    '30CHT': {
      1: [146, 380, 470],
      2: [138, 147, 570],
      3: [148, 247, 580],
      4: [149, 158, 257],
      5: [168, 249, 258],
      6: [169, 259, 358],
      7: [250, 269, 368],
      8: [279, 350, 369],
      9: [270, 360, 469],
      0: [136, 370, 479],
    },
    '40CHT': {
      1: [128, 236, 245, 290],
      2: [129, 390, 589, 679],
      3: [256, 346, 670, 689],
      4: [130, 239, 347, 356],
      5: [140, 230, 690, 780],
      6: [178, 367, 457, 790],
      7: [124, 340, 458, 467],
      8: [125, 134, 170, 189],
      9: [180, 289, 478, 568],
      0: [145, 235, 569, 578],
    },
    '50CHT': {
      1: [137, 146, 380, 470, 579],
      2: [137, 146, 380, 470, 579],
      3: [139, 148, 157, 247, 580],
      4: [149, 158, 248, 257, 680],
      5: [159, 168, 249, 258, 357],
      6: [169, 240, 259, 268, 358],
      7: [179, 250, 269, 359, 368],
      8: [260, 279, 350, 369, 468],
      9: [135, 270, 360, 379, 469],
      0: [136, 280, 37, 460, 479],
    },
    '60CHT': {
      1: [489, 560, 128, 236, 245, 290],
      2: [156, 237, 129, 390, 589, 679],
      3: [238, 490, 256, 346, 670, 689],
      4: [167, 590, 130, 239, 347, 356],
      5: [267, 348, 140, 230, 690, 780],
      6: [150, 249, 178, 367, 457, 790],
      7: [160, 278, 124, 340, 458, 467],
      8: [378, 459, 125, 134, 170, 189],
      9: [126, 450, 180, 289, 478, 568],
      0: [127, 389, 145, 235, 569, 578],
    },
    '70CHT': {
      1: [128, 236, 245, 290, 489, 560, 678],
      2: [129, 156, 237, 345, 390, 589, 679],
      3: [120, 238, 256, 346, 490, 670, 689],
      4: [130, 167, 239, 347, 356, 590, 789],
      5: [140, 230, 267, 348, 456, 690, 780],
      6: [123, 150, 178, 349, 367, 457, 790],
      7: [124, 160, 278, 340, 458, 467, 890],
      8: [125, 134, 170, 189, 378, 459, 567],
      9: [126, 180, 234, 289, 450, 478, 568],
      0: [127, 145, 190, 235, 389, 569, 578],
    },
  };

  String _session = 'OPEN';
  String _dateYmd = '';
  double _wallet = 0;
  String _warn = '';
  String _selectedChart = '';
  String _selectedDigit = '';
  final _ptsCtrl = TextEditingController();
  List<({String id, String chart, String pana, String label, String points})> _rows = [];
  Timer? _addDebounce;

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
    _addDebounce?.cancel();
    _ptsCtrl.dispose();
    super.dispose();
  }

  void _toast(String m) {
    setState(() => _warn = m);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _warn = '');
    });
  }

  List<String> _numbersFor(String chartKey, String digitKey) {
    final chart = _chartData[chartKey];
    if (chart == null) return [];
    final d = int.tryParse(digitKey);
    if (d == null || d < 0 || d > 9) return [];
    final list = chart[d];
    if (list == null) return [];
    return list.map((n) => n.toString().padLeft(3, '0')).toList();
  }

  void _scheduleAutoAdd() {
    _addDebounce?.cancel();
    _addDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _tryAutoAdd();
    });
  }

  void _tryAutoAdd() {
    final pts = int.tryParse(_ptsCtrl.text.trim()) ?? 0;
    if (_selectedChart.isEmpty || _selectedDigit.isEmpty || pts <= 0) return;
    final numbers = _numbersFor(_selectedChart, _selectedDigit);
    if (numbers.isEmpty) {
      _toast('No numbers found for selected chart and digit.');
      return;
    }
    setState(() {
      final next = [..._rows];
      for (final pana in numbers) {
        final idx = next.indexWhere((r) => r.chart == _selectedChart && r.pana == pana);
        if (idx >= 0) {
          final old = next[idx];
          final oldPts = int.tryParse(old.points) ?? 0;
          next[idx] = (
            id: old.id,
            chart: old.chart,
            pana: old.pana,
            label: old.label,
            points: '${oldPts + pts}'
          );
        } else {
          next.add((
            id: '$_selectedChart-$pana',
            chart: _selectedChart,
            pana: pana,
            label: '$_selectedChart - $pana',
            points: '$pts',
          ));
        }
      }
      _rows = next;
      _selectedChart = '';
      _selectedDigit = '';
      _ptsCtrl.clear();
    });
  }

  void _clearLocal() {
    setState(() {
      _selectedChart = '';
      _selectedDigit = '';
      _ptsCtrl.clear();
      _rows = [];
    });
  }

  Future<void> _submit() async {
    final active = _rows.where((r) => (int.tryParse(r.points) ?? 0) > 0).toList();
    if (active.isEmpty) {
      _toast('Add at least one chart row with points.');
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
      rows: active
          .map((r) => BidRowVm(id: r.id, number: r.label, points: r.points, sessionLabel: _session))
          .toList(),
      onConfirm: () async {
        final mid = widget.market['id'] ?? widget.market['_id'];
        final sched = scheduledDateIfFuture(_dateYmd);
        final lines = active
            .map(
              (r) => PlaceBetLine(
                betType: 'panna',
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
        if (!mounted) return res;
        setState(() {
          _clearLocal();
          if (res.newBalance != null) _wallet = res.newBalance!.toDouble();
        });
        return res;
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
          Text('Quick points', style: GameBidUi.sectionLabel),
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
                  _scheduleAutoAdd();
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _ptsCtrl,
            keyboardType: TextInputType.number,
            onChanged: (_) {
              setState(() {});
              _scheduleAutoAdd();
            },
            decoration: GameBidUi.inputDecoration(labelText: 'Points'),
          ),
          const SizedBox(height: 12),
          Text('Select Chart', style: GameBidUi.sectionLabel),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _chartData.keys.map((chart) {
              final sel = _selectedChart == chart;
              return OutlinedButton(
                onPressed: () {
                  setState(() => _selectedChart = chart);
                  _scheduleAutoAdd();
                },
                style: GameBidUi.outlineDigit(sel, extent: tile),
                child: Text(chart, style: const TextStyle(fontWeight: FontWeight.w700)),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Text('Select Digit', style: GameBidUi.sectionLabel),
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
            itemCount: _digitOrder.length,
            itemBuilder: (context, i) {
              final d = _digitOrder[i];
              final ds = '$d';
              final sel = _selectedDigit == ds;
              return OutlinedButton(
                onPressed: () {
                  setState(() => _selectedDigit = ds);
                  _scheduleAutoAdd();
                },
                style: GameBidUi.outlineDigit(sel, extent: tile),
                child: Text('$d', style: const TextStyle(fontWeight: FontWeight.w700)),
              );
            },
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: _clearLocal,
                style: GameBidUi.quickPointsClearOutlinedStyle(),
                child: const Text('Clear'),
              ),
            ],
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
                  '${r.label} · $_session',
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
