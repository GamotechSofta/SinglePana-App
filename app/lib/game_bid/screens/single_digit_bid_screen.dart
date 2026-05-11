import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/bets_service.dart';
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

class SingleDigitBidScreen extends StatefulWidget {
  const SingleDigitBidScreen({super.key, required this.market, required this.title});

  final Map<String, dynamic> market;
  final String title;

  @override
  State<SingleDigitBidScreen> createState() => _SingleDigitBidScreenState();
}

class _SingleDigitBidScreenState extends State<SingleDigitBidScreen> {
  static const _quickPoints = [10, 20, 30, 40, 50];
  final bool _special = true;
  String _session = 'OPEN';
  String _dateYmd = '';
  double _wallet = 0;
  final _digitCtrl = TextEditingController();
  final _ptsCtrl = TextEditingController();
  final Map<int, TextEditingController> _spec = {
    for (var i = 0; i < 10; i++) i: TextEditingController(),
  };
  final List<_Line> _bids = [];
  String _warn = '';

  @override
  void initState() {
    super.initState();
    _session = widget.market['status']?.toString() == 'running' ? 'CLOSE' : 'OPEN';
    _load();
  }

  Future<void> _load() async {
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
    _digitCtrl.dispose();
    _ptsCtrl.dispose();
    for (final c in _spec.values) {
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

  void _masterClearSpecial() {
    setState(() {
      for (final c in _spec.values) {
        c.clear();
      }
      _bids.clear();
    });
  }

  bool get _canMasterClearSpecial {
    if (_bids.isNotEmpty) return true;
    for (final c in _spec.values) {
      if (c.text.trim().isNotEmpty) return true;
    }
    return false;
  }

  void _addSpecial() {
    var any = false;
    for (final e in _spec.entries) {
      final pts = int.tryParse(e.value.text) ?? 0;
      if (pts > 0) {
        _bids.add(
          _Line(
            id: DateTime.now().millisecondsSinceEpoch + e.key,
            number: '${e.key}',
            points: '$pts',
            session: _session,
          ),
        );
        e.value.clear();
        any = true;
      }
    }
    if (!any) {
      _toast('Enter points for at least one digit');
      return;
    }
    setState(() {});
  }

  int _materializePendingEasy() {
    final d = _digitCtrl.text.trim();
    final pts = int.tryParse(_ptsCtrl.text.trim()) ?? 0;
    if (!RegExp(r'^[0-9]$').hasMatch(d) || pts <= 0) return 0;
    _bids.add(_Line(id: DateTime.now().millisecondsSinceEpoch, number: d, points: '$pts', session: _session));
    _digitCtrl.clear();
    _ptsCtrl.clear();
    return 1;
  }

  int _materializePendingSpecial() {
    var added = 0;
    for (final e in _spec.entries) {
      final pts = int.tryParse(e.value.text.trim()) ?? 0;
      if (pts > 0) {
        _bids.add(
          _Line(
            id: DateTime.now().millisecondsSinceEpoch + e.key + added,
            number: '${e.key}',
            points: '$pts',
            session: _session,
          ),
        );
        e.value.clear();
        added++;
      }
    }
    return added;
  }

  void _tryAutoAddSpecial() {
    final hasAny = _spec.values.any((c) => (int.tryParse(c.text.trim()) ?? 0) > 0);
    if (!hasAny) return;
    _addSpecial();
  }

  void _applyQuickToAllSpecial(int points) {
    setState(() {
      for (var i = 0; i < 10; i++) {
        _spec[i]!.text = '$points';
      }
    });
  }

  bool _specialQuickChipSelected(int p) => _spec.values.every((c) => c.text.trim() == '$p');

  Future<void> _openReview() async {
    final addedNow = !_special ? _materializePendingEasy() : _materializePendingSpecial();
    if (addedNow > 0 && mounted) {
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
      rows: _bids
          .map(
            (b) => BidRowVm(id: b.id, number: b.number, points: b.points, sessionLabel: b.session),
          )
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
            _dateYmd = DateTime.now().toIso8601String().split('T').first;
            if (res.newBalance != null) _wallet = res.newBalance!.toDouble();
          });
        }
        return res;
      },
    );
  }

  ({int count, int points}) _liveStats() {
    var count = _bids.length;
    var points = _bids.fold<int>(0, (s, b) => s + (int.tryParse(b.points) ?? 0));

    if (!_special) {
      final d = _digitCtrl.text.trim();
      final pts = int.tryParse(_ptsCtrl.text.trim()) ?? 0;
      if (RegExp(r'^[0-9]$').hasMatch(d) && pts > 0) {
        count += 1;
        points += pts;
      }
    } else {
      for (final e in _spec.entries) {
        final pts = int.tryParse(e.value.text.trim()) ?? 0;
        if (pts > 0) {
          count += 1;
          points += pts;
        }
      }
    }

    return (count: count, points: points);
  }

  @override
  Widget build(BuildContext context) {
    final live = _liveStats();
    final tile = GameBidUi.betControlExtent(context);

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
      onSubmit: _openReview,
      onBack: () => Navigator.of(context).pop(),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (_warn.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_warn, style: TextStyle(color: Colors.red.shade700)),
            ),
          const SizedBox(height: 12),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Special Mode',
                      textAlign: TextAlign.center,
                      style: GameBidUi.panelTitle,
                    ),
                    const SizedBox(height: GameBidUi.quickPointsAfterFieldGap),
                    Row(
                      children: [
                        Text('Quick points', style: GameBidUi.sectionLabel),
                        const Spacer(),
                        TextButton(
                          style: GameBidUi.quickPointsClearTextButtonStyle,
                          onPressed: !_canMasterClearSpecial ? null : _masterClearSpecial,
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                    const SizedBox(height: GameBidUi.quickPointsHeaderToChipsGap),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _quickPoints.map((p) {
                        return GameBidUi.quickPointsChip(
                          selected: _specialQuickChipSelected(p),
                          label: '$p',
                          extent: tile,
                          onSelected: (_) => _applyQuickToAllSpecial(p),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        mainAxisExtent: tile,
                      ),
                      itemCount: 10,
                      itemBuilder: (context, i) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            GameBidUi.betNeonPairDigit(digit: '$i', extent: tile),
                            const SizedBox(width: 8),
                            Expanded(
                              child: GameBidUi.betNeonPairPointsField(
                                controller: _spec[i]!,
                                onChanged: (_) => setState(() {}),
                                onSubmitted: (_) => _addSpecial(),
                                onEditingComplete: _tryAutoAddSpecial,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
