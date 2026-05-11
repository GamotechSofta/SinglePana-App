import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/bets_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/casino_ui.dart';
import '../bet_date_prefs.dart';
import '../bid_review_dialog.dart';
import '../betting_window_scope.dart';
import '../../theme/app_spacing.dart';
import '../game_bid_layout.dart';
import '../game_bid_ui.dart';
import '../pana_rules.dart';

class _Line {
  _Line({required this.id, required this.number, required this.points, required this.session});
  final int id;
  final String number;
  final String points;
  final String session;
}

class TriplePanaBidScreen extends StatefulWidget {
  const TriplePanaBidScreen({super.key, required this.market, required this.title});

  final Map<String, dynamic> market;
  final String title;

  @override
  State<TriplePanaBidScreen> createState() => _TriplePanaBidScreenState();
}

class _TriplePanaBidScreenState extends State<TriplePanaBidScreen> {
  static const _quickPoints = [10, 20, 30, 40, 50];

  static List<String> get _tripleKeys => List.generate(10, (i) => '$i$i$i');

  String _session = 'OPEN';
  String _dateYmd = '';
  double _wallet = 0;

  late final Map<String, TextEditingController> _specialCtrls;

  final List<_Line> _bids = [];
  String _warn = '';

  /// Highlights a quick chip when all rows were set to that value together; cleared on manual edit.
  int? _appliedQuickUniform;

  @override
  void initState() {
    super.initState();
    _session = widget.market['status']?.toString() == 'running' ? 'CLOSE' : 'OPEN';
    _specialCtrls = {for (final k in _tripleKeys) k: TextEditingController()};
    _init();
  }

  Future<void> _init() async {
    final u = await AuthService.instance.getStoredUser();
    final b = u?['balance'] ?? u?['walletBalance'] ?? 0;
    final d = await loadBetSelectedDateOrToday();
    if (mounted) {
      setState(() {
        _wallet = (b is num) ? b.toDouble() : double.tryParse(b.toString()) ?? 0;
        _dateYmd = d;
      });
    }
  }

  @override
  void dispose() {
    for (final c in _specialCtrls.values) {
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

  void _mergeBid(String number, int pts) {
    if (!isValidTriplePana(number) || pts <= 0) return;
    final i = _bids.indexWhere((b) => b.number == number && b.session == _session);
    if (i >= 0) {
      final prev = int.tryParse(_bids[i].points) ?? 0;
      _bids[i] = _Line(id: _bids[i].id, number: number, points: '${prev + pts}', session: _session);
    } else {
      _bids.add(_Line(id: DateTime.now().microsecondsSinceEpoch + _bids.length, number: number, points: '$pts', session: _session));
    }
  }

  void _onSpecialFieldChanged() {
    setState(() {
      if (_appliedQuickUniform != null) {
        final target = _appliedQuickUniform!;
        final allMatch = _tripleKeys.every((k) => (int.tryParse(_specialCtrls[k]!.text.trim()) ?? 0) == target);
        if (!allMatch) _appliedQuickUniform = null;
      }
    });
  }

  void _applyQuickToAll(int points) {
    setState(() {
      for (final c in _specialCtrls.values) {
        c.text = '$points';
      }
      _appliedQuickUniform = points;
    });
  }

  void _masterClear() {
    for (final c in _specialCtrls.values) {
      c.clear();
    }
    setState(() {
      _appliedQuickUniform = null;
      _bids.clear();
    });
  }

  bool get _canMasterClear => _anySpecialPoints() || _bids.isNotEmpty;

  bool _anySpecialPoints() {
    for (final ctrl in _specialCtrls.values) {
      if ((int.tryParse(ctrl.text.trim()) ?? 0) > 0) return true;
    }
    return false;
  }

  int _specialFilledCount() {
    var c = 0;
    for (final ctrl in _specialCtrls.values) {
      if ((int.tryParse(ctrl.text.trim()) ?? 0) > 0) c++;
    }
    return c;
  }

  int _specialPointsSum() {
    var s = 0;
    for (final ctrl in _specialCtrls.values) {
      s += int.tryParse(ctrl.text.trim()) ?? 0;
    }
    return s;
  }

  ({int count, int points}) _liveStats() {
    if (_bids.isNotEmpty) {
      final points = _bids.fold<int>(0, (a, b) => a + (int.tryParse(b.points) ?? 0));
      return (count: _bids.length, points: points);
    }
    return (count: _specialFilledCount(), points: _specialPointsSum());
  }

  void _materializeSpecialToBids() {
    for (final e in _specialCtrls.entries) {
      final pts = int.tryParse(e.value.text.trim()) ?? 0;
      if (pts <= 0) continue;
      _mergeBid(e.key, pts);
      e.value.clear();
    }
    _appliedQuickUniform = null;
  }

  Future<void> _reviewAndPlace() async {
    _materializeSpecialToBids();
    if (mounted) setState(() {});

    if (_bids.isEmpty) {
      _toast('Enter points for at least one triple pana (000–999)');
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
        setState(() => _bids.clear());
      },
      rows: _bids.map((b) => BidRowVm(id: b.id, number: b.number, points: b.points, sessionLabel: b.session)).toList(),
      onConfirm: () async {
        final mid = widget.market['id'] ?? widget.market['_id'];
        final sched = scheduledDateIfFuture(_dateYmd);
        final lines = _bids
            .map(
              (b) => PlaceBetLine(
                betType: 'panna',
                betNumber: b.number,
                amount: int.tryParse(b.points) ?? 0,
                betOn: b.session.toUpperCase() == 'CLOSE' ? 'close' : 'open',
              ),
            )
            .toList();
        final res = await BetsService.instance.placeBet(marketId: mid, lines: lines, scheduledDate: sched);
        if (!res.success) throw Exception(res.message ?? 'Failed');
        await applyNewBalance(res.newBalance);
        await clearBetSelectedDate();
        if (mounted) {
          setState(() {
            _bids.clear();
            if (res.newBalance != null) _wallet = res.newBalance!.toDouble();
          });
        }
        return res;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final live = _liveStats();
    final tile = GameBidUi.betControlExtent(context);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: AppColors.gold.withValues(alpha: 0.45)),
    );
    final w = MediaQuery.sizeOf(context).width;
    final crossAxis = w >= 420 ? 3 : 2;

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
      bidsCount: live.count,
      totalPoints: live.points,
      onSubmit: _reviewAndPlace,
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
              Text('Quick points', style: GameBidUi.sectionLabel),
              const Spacer(),
              TextButton(
                style: GameBidUi.quickPointsClearTextButtonStyle,
                onPressed: !_canMasterClear ? null : _masterClear,
                child: const Text('Clear all'),
              ),
            ],
          ),
          const SizedBox(height: GameBidUi.quickPointsHeaderToChipsGap),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _quickPoints.map((p) {
              final sel = _appliedQuickUniform == p;
              return GameBidUi.quickPointsChip(
                selected: sel,
                label: '$p',
                extent: tile,
                onSelected: (_) => _applyQuickToAll(p),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          Text('Triple panas (000 – 999)', style: GameBidUi.panelTitle.copyWith(fontSize: 13)),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxis,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              mainAxisExtent: tile,
            ),
            itemCount: 10,
            itemBuilder: (context, i) {
              final numStr = _tripleKeys[i];
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GameBidUi.betNumberChip(label: numStr, extent: tile),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: GameBidUi.betPointsRectangleSlot(
                      extent: tile,
                      child: TextField(
                        controller: _specialCtrls[numStr],
                        keyboardType: TextInputType.number,
                        expands: true,
                        minLines: null,
                        maxLines: null,
                        textAlign: TextAlign.center,
                        textAlignVertical: TextAlignVertical.center,
                        onChanged: (_) => _onSpecialFieldChanged(),
                        style: GameBidUi.betInputStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          hintText: 'Pts',
                          isDense: true,
                          constraints: BoxConstraints.tightFor(height: tile),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.inputDenseH,
                            vertical: AppSpacing.inputDenseV,
                          ),
                          enabledBorder: border.copyWith(
                            borderRadius: BorderRadius.circular(GameBidUi.betChipRadius),
                          ),
                          focusedBorder: border.copyWith(
                            borderRadius: BorderRadius.circular(GameBidUi.betChipRadius),
                            borderSide: BorderSide(color: AppColors.gold.withValues(alpha: 0.9), width: 2),
                          ),
                          fillColor: CasinoUi.fieldFill,
                          filled: true,
                          hintStyle: TextStyle(color: CasinoUi.mutedGold(0.45)),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          if (_bids.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 20),
            Text('Your bets', style: GameBidUi.panelTitle.copyWith(fontSize: 15)),
            const SizedBox(height: 6),
            ..._bids.map(
              (b) => ListTile(
                dense: true,
                title: Text(
                  '${b.number} · ${b.session}',
                  style: const TextStyle(color: CasinoUi.lightGold, fontWeight: FontWeight.w600),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('₹${b.points}', style: TextStyle(color: CasinoUi.mutedGold(0.9))),
                    IconButton(
                      onPressed: () => setState(() => _bids.removeWhere((e) => e.id == b.id)),
                      icon: Icon(Icons.close, size: 20, color: AppColors.gold.withValues(alpha: 0.85)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
