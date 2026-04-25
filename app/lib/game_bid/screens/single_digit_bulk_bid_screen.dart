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

class _Line {
  _Line({required this.id, required this.number, required this.points, required this.session});
  final int id;
  final String number;
  final String points;
  final String session;
}

class SingleDigitBulkBidScreen extends StatefulWidget {
  const SingleDigitBulkBidScreen({super.key, required this.market, required this.title});

  final Map<String, dynamic> market;
  final String title;

  @override
  State<SingleDigitBulkBidScreen> createState() => _SingleDigitBulkBidScreenState();
}

class _SingleDigitBulkBidScreenState extends State<SingleDigitBulkBidScreen> {
  String _session = 'OPEN';
  String _dateYmd = '';
  double _wallet = 0;
  final _pointsCtrl = TextEditingController();
  final List<_Line> _bids = [];
  String _warn = '';

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
    if (mounted) {
      setState(() {
        _wallet = (b is num) ? b.toDouble() : double.tryParse(b.toString()) ?? 0;
        _dateYmd = d;
      });
    }
  }

  @override
  void dispose() {
    _pointsCtrl.dispose();
    super.dispose();
  }

  void _toast(String m) {
    setState(() => _warn = m);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _warn = '');
    });
  }

  void _masterClear() {
    setState(() {
      _pointsCtrl.clear();
      _bids.clear();
    });
  }

  bool get _canMasterClear => _pointsCtrl.text.trim().isNotEmpty || _bids.isNotEmpty;

  /// OPEN / CLOSE from the session stored on each line (matches header session picker).
  String _typeLabel(String session) {
    final u = session.toUpperCase();
    if (u == 'CLOSE') return 'CLOSE';
    if (u == 'OPEN') return 'OPEN';
    return u;
  }

  bool _isAddedDigit(int digit) {
    final n = '$digit';
    return _bids.any((b) => b.number == n && b.session == _session);
  }

  void _addDigitAuto(int digit) {
    final pts = int.tryParse(_pointsCtrl.text.trim()) ?? 0;
    if (pts <= 0) {
      _toast('Enter bet points first');
      return;
    }

    final i = _bids.indexWhere((b) => b.number == '$digit' && b.session == _session);
    if (i >= 0) {
      final prev = int.tryParse(_bids[i].points) ?? 0;
      _bids[i] = _Line(id: _bids[i].id, number: '$digit', points: '${prev + pts}', session: _session);
    } else {
      _bids.add(_Line(id: DateTime.now().millisecondsSinceEpoch + digit, number: '$digit', points: '$pts', session: _session));
    }
    setState(() {});
  }

  Future<void> _submit() async {
    if (_bids.isEmpty) {
      _toast('Add at least one bet');
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
      rows: _bids
          .map((b) => BidRowVm(id: b.id, number: b.number, points: b.points, sessionLabel: b.session))
          .toList(),
      onConfirm: () async {
        final mid = widget.market['id'] ?? widget.market['_id'];
        final sched = scheduledDateIfFuture(_dateYmd);
        final lines = _bids
            .map(
              (b) => PlaceBetLine(
                betType: 'single',
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _bids.fold<int>(0, (s, b) => s + (int.tryParse(b.points) ?? 0));
    final tile = GameBidUi.defaultBetTileExtent(context);
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
      bidsCount: _bids.length,
      totalPoints: total,
      onSubmit: _submit,
      submitLabel: 'Submit Bets',
      onBack: () => Navigator.of(context).pop(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
        children: [
          if (_warn.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_warn, style: TextStyle(color: Colors.red.shade700)),
            ),
          Text('Step 1: Enter bet points', style: GameBidUi.panelTitle.copyWith(fontSize: 14)),
          const SizedBox(height: 10),
          TextField(
            controller: _pointsCtrl,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            onChanged: (_) => setState(() {}),
            decoration: GameBidUi.inputDecoration(labelText: 'Points'),
          ),
          const SizedBox(height: GameBidUi.quickPointsAfterFieldGap),
          Row(
            children: [
              Text('Quick points', style: GameBidUi.sectionLabel),
              const Spacer(),
              TextButton(
                style: GameBidUi.quickPointsClearTextButtonStyle,
                onPressed: !_canMasterClear ? null : _masterClear,
                child: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: GameBidUi.quickPointsHeaderToChipsGap),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [10, 20, 30, 40, 50].map((p) {
              final sel = _pointsCtrl.text.trim() == '$p';
              return GameBidUi.quickPointsChip(
                selected: sel,
                label: '$p',
                extent: tile,
                onSelected: (_) => setState(() => _pointsCtrl.text = '$p'),
              );
            }).toList(),
          ),
          const SizedBox(height: 22),
          Text('Step 2: Select number combinations', style: GameBidUi.panelTitle.copyWith(fontSize: 14)),
          const SizedBox(height: 10),
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
              final selected = _isAddedDigit(i);
              return InkWell(
                onTap: () => _addDigitAuto(i),
                borderRadius: BorderRadius.circular(GameBidUi.betChipRadius),
                child: DecoratedBox(
                  decoration: GameBidUi.numberChipTileDecoration(selected: selected),
                  child: Center(
                    child: Text(
                      '$i',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 22),
          Text('Selected history', style: GameBidUi.panelTitle.copyWith(fontSize: 14)),
          const SizedBox(height: 10),
          if (_bids.isEmpty)
            Text('No bets selected yet', style: GameBidUi.emptyHint)
          else
            ..._bids.map(
              (b) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: ListTile(
                  dense: true,
                  title: Text(
                    'Pana: ${b.number}',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: CasinoUi.lightGold),
                  ),
                  subtitle: Text(
                    'Type: ${_typeLabel(b.session)}',
                    style: TextStyle(fontSize: 13, color: CasinoUi.mutedGold(0.7)),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('₹${b.points}', style: TextStyle(color: CasinoUi.mutedGold(0.9))),
                      IconButton(
                        onPressed: () => setState(() => _bids.removeWhere((e) => e.id == b.id)),
                        icon: Icon(Icons.close, color: AppColors.gold.withValues(alpha: 0.85)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
