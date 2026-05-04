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

class _Line {
  _Line({required this.id, required this.number, required this.points, required this.session});
  final int id;
  final String number;
  final String points;
  final String session;
}

class SinglePanaBidScreen extends StatefulWidget {
  const SinglePanaBidScreen({super.key, required this.market, required this.title});

  final Map<String, dynamic> market;
  final String title;

  @override
  State<SinglePanaBidScreen> createState() => _SinglePanaBidScreenState();
}

class _SinglePanaBidScreenState extends State<SinglePanaBidScreen> {
  static const _quickPoints = [10, 20, 30, 40, 50];

  bool _easy = true;
  String _session = 'OPEN';
  String _dateYmd = '';
  double _wallet = 0;
  String _warn = '';

  final _numCtrl = TextEditingController();
  final _ptsCtrl = TextEditingController();
  final List<_Line> _bids = [];

  late final Map<int, List<String>> _sumToPanas;

  @override
  void initState() {
    super.initState();
    _session = widget.market['status']?.toString() == 'running' ? 'CLOSE' : 'OPEN';
    _sumToPanas = {
      for (var i = 0; i < 10; i++) i: [],
    };
    for (final p in validSinglePanas) {
      final d = p.split('').map(int.parse).toList();
      final s = (d[0] + d[1] + d[2]) % 10;
      _sumToPanas[s]!.add(p);
    }
    for (final list in _sumToPanas.values) {
      list.sort((a, b) => int.parse(a).compareTo(int.parse(b)));
    }
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
    _numCtrl.dispose();
    _ptsCtrl.dispose();
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
      _numCtrl.clear();
      _ptsCtrl.clear();
      _bids.clear();
    });
  }

  bool get _canMasterClear =>
      _bids.isNotEmpty || _numCtrl.text.trim().isNotEmpty || _ptsCtrl.text.trim().isNotEmpty;

  void _mergeAdd(String number, int pts) {
    if (!isValidSinglePana(number) || pts <= 0) return;
    final i = _bids.indexWhere((b) => b.number == number && b.session == _session);
    if (i >= 0) {
      final prev = int.tryParse(_bids[i].points) ?? 0;
      _bids[i] = _Line(id: _bids[i].id, number: number, points: '${prev + pts}', session: _session);
    } else {
      _bids.add(_Line(id: DateTime.now().millisecondsSinceEpoch + _bids.length, number: number, points: '$pts', session: _session));
    }
  }

  void _addEasy() {
    final n = _numCtrl.text.trim();
    final pts = int.tryParse(_ptsCtrl.text.trim()) ?? 0;
    if (pts <= 0) return _toast('Enter points');
    if (!isValidSinglePana(n)) return _toast('Invalid single pana');
    setState(() {
      _mergeAdd(n, pts);
      _numCtrl.clear();
      _ptsCtrl.clear();
    });
  }

  void _tryAutoAddEasy() {
    final n = _numCtrl.text.trim();
    final pts = int.tryParse(_ptsCtrl.text.trim()) ?? 0;
    if (n.length != 3 || pts <= 0 || !isValidSinglePana(n)) return;
    setState(() {
      _mergeAdd(n, pts);
      _numCtrl.clear();
      _ptsCtrl.clear();
    });
  }

  void _addBySum(int sumDigit) {
    final pts = int.tryParse(_ptsCtrl.text.trim()) ?? 0;
    if (pts <= 0) return _toast('Enter points first');
    final matches = _sumToPanas[sumDigit] ?? const <String>[];
    if (matches.isEmpty) return _toast('No matching pana');
    setState(() {
      for (final p in matches) {
        _mergeAdd(p, pts);
      }
    });
    _toast('Added ${matches.length} bets');
  }

  int _pointsForSum(int sumDigit) {
    final matches = _sumToPanas[sumDigit] ?? const <String>[];
    var total = 0;
    for (final b in _bids) {
      if (b.session != _session) continue;
      if (matches.contains(b.number)) total += int.tryParse(b.points) ?? 0;
    }
    return total;
  }

  Future<void> _submit() async {
    if (_easy) {
      final n = _numCtrl.text.trim();
      final pText = _ptsCtrl.text.trim();
      final hasPending = n.isNotEmpty || pText.isNotEmpty;
      if (hasPending) {
        final pts = int.tryParse(pText) ?? 0;
        if (pts <= 0) return _toast('Enter points');
        if (!isValidSinglePana(n)) return _toast('Invalid single pana');
        setState(() {
          _mergeAdd(n, pts);
          _numCtrl.clear();
          _ptsCtrl.clear();
        });
      }
    }
    if (_bids.isEmpty) return _toast('Add at least one bet');

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
        if (!mounted) return;
        setState(() {
          _bids.clear();
          if (res.newBalance != null) _wallet = res.newBalance!.toDouble();
        });
      },
    );
  }

  ({int count, int points}) _liveStats() {
    var count = _bids.length;
    var points = _bids.fold<int>(0, (s, b) => s + (int.tryParse(b.points) ?? 0));
    if (_easy) {
      final n = _numCtrl.text.trim();
      final p = int.tryParse(_ptsCtrl.text.trim()) ?? 0;
      if (p > 0 && isValidSinglePana(n)) {
        count += 1;
        points += p;
      }
    }
    return (count: count, points: points);
  }

  @override
  Widget build(BuildContext context) {
    final live = _liveStats();
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
      bidsCount: live.count,
      totalPoints: live.points,
      onSubmit: _submit,
      onBack: () => Navigator.of(context).pop(),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (_warn.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_warn, style: TextStyle(color: Colors.red.shade700))),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _easy = true),
                  style: GameBidUi.modeToggle(_easy),
                  child: const Text('EASY MODE'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _easy = false),
                  style: GameBidUi.modeToggle(!_easy),
                  child: const Text('SPECIAL MODE'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_easy) ...[
            const SizedBox(height: 6),
            TextField(
              controller: _numCtrl,
              keyboardType: TextInputType.number,
              maxLength: 3,
              onChanged: (_) {
                setState(() {});
                _tryAutoAddEasy();
              },
              onEditingComplete: _tryAutoAddEasy,
              onSubmitted: (_) => _addEasy(),
              decoration: GameBidUi.inputDecoration(labelText: 'Enter Pana', hintText: 'Pana', counterText: ''),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _ptsCtrl,
              keyboardType: TextInputType.number,
              onChanged: (_) {
                setState(() {});
                _tryAutoAddEasy();
              },
              onEditingComplete: _tryAutoAddEasy,
              onSubmitted: (_) => _addEasy(),
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
              children: _quickPoints.map((p) {
                final sel = _ptsCtrl.text.trim() == '$p';
                return GameBidUi.quickPointsChip(
                  selected: sel,
                  label: '$p',
                  extent: tile,
                  onSelected: (_) {
                    setState(() => _ptsCtrl.text = '$p');
                    _tryAutoAddEasy();
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
          ] else ...[
            TextField(
              controller: _ptsCtrl,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: GameBidUi.inputDecoration(labelText: 'Enter Points'),
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
              children: _quickPoints.map((p) {
                final sel = _ptsCtrl.text.trim() == '$p';
                return GameBidUi.quickPointsChip(
                  selected: sel,
                  label: '$p',
                  extent: tile,
                  onSelected: (_) => setState(() => _ptsCtrl.text = '$p'),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap any sum digit to add all matching single pana bets',
              textAlign: TextAlign.center,
              style: TextStyle(color: CasinoUi.mutedGold(0.78), fontSize: 12, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
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
                final pts = _pointsForSum(i);
                return InkWell(
                  onTap: () => _addBySum(i),
                  borderRadius: BorderRadius.circular(GameBidUi.betChipRadius),
                  child: DecoratedBox(
                    decoration: GameBidUi.numberChipTileDecoration(selected: pts > 0),
                    child: Stack(
                      children: [
                        Center(
                          child: Text(
                            '$i',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        if (pts > 0)
                          Positioned(
                            right: 4,
                            top: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: CasinoUi.fieldFill,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: GameBidUi.numberChipBorderColor(),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                '$pts',
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
          const Divider(height: 24),
          Text('Your bets', style: GameBidUi.panelTitle.copyWith(fontSize: 15)),
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

