import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/bets_service.dart';
import '../../theme/app_spacing.dart';
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

class OddEvenBidScreen extends StatefulWidget {
  const OddEvenBidScreen({super.key, required this.market, required this.title});

  final Map<String, dynamic> market;
  final String title;

  @override
  State<OddEvenBidScreen> createState() => _OddEvenBidScreenState();
}

class _OddEvenBidScreenState extends State<OddEvenBidScreen> {
  static const _oddDigits = [1, 3, 5, 7, 9];
  static const _evenDigits = [0, 2, 4, 6, 8];
  static const _quickPoints = [10, 20, 30, 40, 50];

  String _session = 'OPEN';
  String _dateYmd = '';
  double _wallet = 0;
  bool _sideIsOdd = true;
  final Map<int, TextEditingController> _ctrl = {};
  final List<_Line> _bids = [];
  String _warn = '';

  @override
  void initState() {
    super.initState();
    _session = widget.market['status']?.toString() == 'running' ? 'CLOSE' : 'OPEN';
    for (final d in [..._oddDigits, ..._evenDigits]) {
      _ctrl[d] = TextEditingController();
    }
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
    for (final c in _ctrl.values) {
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

  void _addToList() {
    final digits = _sideIsOdd ? _oddDigits : _evenDigits;
    var any = false;
    for (final d in digits) {
      final pts = int.tryParse(_ctrl[d]!.text.trim()) ?? 0;
      if (pts > 0) {
        final idx = _bids.indexWhere((b) => b.number == '$d' && b.session == _session);
        if (idx >= 0) {
          final prev = int.tryParse(_bids[idx].points) ?? 0;
          _bids[idx] = _Line(
            id: _bids[idx].id,
            number: '$d',
            points: '${prev + pts}',
            session: _session,
          );
        } else {
          _bids.add(_Line(id: DateTime.now().millisecondsSinceEpoch + d, number: '$d', points: '$pts', session: _session));
        }
        _ctrl[d]!.clear();
        any = true;
      }
    }
    if (!any) {
      _toast('Enter points for at least one ${_sideIsOdd ? "odd" : "even"} digit');
      return;
    }
    setState(() {});
  }

  int _materializePendingAllSides() {
    var added = 0;
    final allDigits = [..._oddDigits, ..._evenDigits];
    for (final d in allDigits) {
      final pts = int.tryParse(_ctrl[d]!.text.trim()) ?? 0;
      if (pts <= 0) continue;
      final idx = _bids.indexWhere((b) => b.number == '$d' && b.session == _session);
      if (idx >= 0) {
        final prev = int.tryParse(_bids[idx].points) ?? 0;
        _bids[idx] = _Line(
          id: _bids[idx].id,
          number: '$d',
          points: '${prev + pts}',
          session: _session,
        );
      } else {
        _bids.add(_Line(id: DateTime.now().millisecondsSinceEpoch + d, number: '$d', points: '$pts', session: _session));
      }
      _ctrl[d]!.clear();
      added += 1;
    }
    return added;
  }

  void _tryAutoAddCurrentSide() {
    final digits = _sideIsOdd ? _oddDigits : _evenDigits;
    final hasAny = digits.any((d) => (int.tryParse(_ctrl[d]!.text.trim()) ?? 0) > 0);
    if (!hasAny) return;
    _addToList();
  }

  void _applyQuickToCurrentSide(int p) {
    final digits = _sideIsOdd ? _oddDigits : _evenDigits;
    setState(() {
      for (final d in digits) {
        _ctrl[d]!.text = '$p';
      }
    });
  }

  void _masterClear() {
    setState(() {
      for (final c in _ctrl.values) {
        c.clear();
      }
      _bids.clear();
    });
  }

  bool _canMasterClear() {
    if (_bids.isNotEmpty) return true;
    for (final c in _ctrl.values) {
      if (c.text.trim().isNotEmpty) return true;
    }
    return false;
  }

  Future<void> _submitReview() async {
    final added = _materializePendingAllSides();
    if (added > 0 && mounted) {
      setState(() {});
    }
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
      labelKey: 'Digit',
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

  ({int count, int points}) _liveStats() {
    var count = _bids.length;
    var points = _bids.fold<int>(0, (s, b) => s + (int.tryParse(b.points) ?? 0));

    // Include pending typed values from both tabs so footer updates immediately.
    final pendingByDigit = <String, int>{};
    for (final d in [..._oddDigits, ..._evenDigits]) {
      final p = int.tryParse(_ctrl[d]!.text.trim()) ?? 0;
      if (p > 0) pendingByDigit['$d'] = p;
    }

    for (final e in pendingByDigit.entries) {
      final idx = _bids.indexWhere((b) => b.number == e.key && b.session == _session);
      if (idx >= 0) {
        points += e.value;
      } else {
        count += 1;
        points += e.value;
      }
    }

    return (count: count, points: points);
  }

  @override
  Widget build(BuildContext context) {
    final live = _liveStats();
    final tile = GameBidUi.betControlExtent(context);
    final digits = _sideIsOdd ? _oddDigits : _evenDigits;
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
      onSubmit: _submitReview,
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
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _sideIsOdd = true),
                  style: GameBidUi.modeToggle(_sideIsOdd),
                  child: const Text('ODD'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _sideIsOdd = false),
                  style: GameBidUi.modeToggle(!_sideIsOdd),
                  child: const Text('EVEN'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('Quick points', style: GameBidUi.sectionLabel),
              const Spacer(),
              TextButton(
                style: GameBidUi.quickPointsClearTextButtonStyle,
                onPressed: _canMasterClear() ? _masterClear : null,
                child: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: GameBidUi.quickPointsHeaderToChipsGap),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _quickPoints.map((p) {
              final sel = digits.every((d) => _ctrl[d]!.text.trim() == '$p');
              return GameBidUi.quickPointsChip(
                selected: sel,
                label: '$p',
                extent: tile,
                onSelected: (_) => _applyQuickToCurrentSide(p),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          ...digits.map(
            (d) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  GameBidUi.betNumberChip(
                    label: '$d',
                    extent: tile,
                    textStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: GameBidUi.betPointsRectangleSlot(
                      extent: tile,
                      child: TextField(
                        controller: _ctrl[d],
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => _tryAutoAddCurrentSide(),
                        onEditingComplete: _tryAutoAddCurrentSide,
                        decoration: GameBidUi.inputDecoration(labelText: 'Points'),
                      ),
                    ),
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
