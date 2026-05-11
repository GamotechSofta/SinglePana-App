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

class _Line {
  _Line({required this.id, required this.number, required this.points, required this.session});
  final int id;
  final String number;
  final String points;
  final String session;
}

class TriplePanaBulkBidScreen extends StatefulWidget {
  const TriplePanaBulkBidScreen({super.key, required this.market, required this.title});

  final Map<String, dynamic> market;
  final String title;

  @override
  State<TriplePanaBulkBidScreen> createState() => _TriplePanaBulkBidScreenState();
}

class _TriplePanaBulkBidScreenState extends State<TriplePanaBulkBidScreen> {
  static const _quickPoints = [10, 20, 30, 40, 50];

  String _session = 'OPEN';
  String _dateYmd = '';
  double _wallet = 0;
  String _warn = '';

  final _numCtrl = TextEditingController();
  final _ptsCtrl = TextEditingController();
  final _pointsFocus = FocusNode();
  final List<_Line> _bids = [];
  Timer? _autoAddDebounce;

  bool _updatingNumber = false;
  String _prevNumber = '';

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
    _autoAddDebounce?.cancel();
    _numCtrl.dispose();
    _ptsCtrl.dispose();
    _pointsFocus.dispose();
    super.dispose();
  }

  bool _isValidTriple(String s) => RegExp(r'^\d{3}$').hasMatch(s) && s[0] == s[1] && s[1] == s[2];

  void _toast(String m) {
    setState(() => _warn = m);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _warn = '');
    });
  }

  void _handleNumberChange(String value) {
    if (_updatingNumber) return;
    final raw = value.replaceAll(RegExp(r'\D'), '').substring(0, value.replaceAll(RegExp(r'\D'), '').length.clamp(0, 3));
    String next = '';
    if (raw.length < _prevNumber.length) {
      next = '';
    } else if (raw.isEmpty) {
      next = '';
    } else {
      final d = raw[0];
      next = '$d$d$d';
    }
    _prevNumber = next;
    if (_numCtrl.text != next) {
      _updatingNumber = true;
      _numCtrl.value = TextEditingValue(text: next, selection: TextSelection.collapsed(offset: next.length));
      _updatingNumber = false;
    }
    if (next.length == 3) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pointsFocus.requestFocus();
      });
    }
    setState(() {});
  }

  void _mergeAdd(String number, int points) {
    final i = _bids.indexWhere((b) => b.number == number && b.session == _session);
    if (i >= 0) {
      final prev = int.tryParse(_bids[i].points) ?? 0;
      _bids[i] = _Line(id: _bids[i].id, number: number, points: '${prev + points}', session: _session);
    } else {
      _bids.add(_Line(id: DateTime.now().millisecondsSinceEpoch + _bids.length, number: number, points: '$points', session: _session));
    }
  }

  void _addToList() {
    final pts = int.tryParse(_ptsCtrl.text.trim()) ?? 0;
    final n = _numCtrl.text.trim();
    if (pts <= 0) return _toast('Please enter points.');
    if (n.isEmpty) return _toast('Please enter triple pana (000-999).');
    if (!_isValidTriple(n)) return _toast('Invalid triple pana. Use 000, 111, 222 ... 999.');
    setState(() {
      _mergeAdd(n, pts);
      _numCtrl.clear();
      _ptsCtrl.clear();
      _prevNumber = '';
    });
  }

  void _tryAutoAdd() {
    final pts = int.tryParse(_ptsCtrl.text.trim()) ?? 0;
    final n = _numCtrl.text.trim();
    if (pts <= 0 || !_isValidTriple(n)) return;
    _addToList();
  }

  void _scheduleAutoAdd() {
    _autoAddDebounce?.cancel();
    _autoAddDebounce = Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      _tryAutoAdd();
    });
  }

  void _clearAll() {
    final today = DateTime.now().toIso8601String().split('T').first;
    setState(() {
      _bids.clear();
      _numCtrl.clear();
      _ptsCtrl.clear();
      _prevNumber = '';
      _dateYmd = today;
    });
  }

  ({int count, int amount}) _displayStats() {
    if (_bids.isNotEmpty) {
      final total = _bids.fold<int>(0, (s, b) => s + (int.tryParse(b.points) ?? 0));
      return (count: _bids.length, amount: total);
    }
    final p = int.tryParse(_ptsCtrl.text.trim()) ?? 0;
    final n = _numCtrl.text.trim();
    final ok = _isValidTriple(n) && p > 0;
    return (count: ok ? 1 : 0, amount: ok ? p : 0);
  }

  Future<void> _openReview() async {
    _tryAutoAdd();
    if (_bids.isEmpty) return;
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
        setState(() {
          _bids.clear();
          _numCtrl.clear();
          _ptsCtrl.clear();
          _prevNumber = '';
        });
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
    final stats = _displayStats();
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
      bidsCount: stats.count,
      totalPoints: stats.amount,
      hideFooter: true,
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
                child: _statCard('Count', '${stats.count}'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statCard('Bet Amount', '${stats.amount}'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _numCtrl,
            keyboardType: TextInputType.number,
            maxLength: 3,
            onChanged: (v) {
              _handleNumberChange(v);
              _scheduleAutoAdd();
            },
            decoration: GameBidUi.inputDecoration(
              labelText: 'Enter Pana:',
              hintText: 'Pana',
              counterText: '',
            ),
          ),
          TextField(
            controller: _ptsCtrl,
            focusNode: _pointsFocus,
            keyboardType: TextInputType.number,
            onChanged: (_) {
              setState(() {});
              _scheduleAutoAdd();
            },
            decoration: GameBidUi.inputDecoration(
              labelText: 'Enter Points',
              hintText: 'Points',
            ),
          ),
          const SizedBox(height: GameBidUi.quickPointsAfterFieldGap),
          Row(
            children: [
              Text('Quick points', style: GameBidUi.sectionLabel),
              const Spacer(),
              TextButton(
                style: GameBidUi.quickPointsClearTextButtonStyle,
                onPressed: (_numCtrl.text.isEmpty && _ptsCtrl.text.isEmpty && _bids.isEmpty) ? null : _clearAll,
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
                  _scheduleAutoAdd();
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _openReview,
              style: GameBidUi.primaryFilled(),
              child: const Text('Submit Bet'),
            ),
          ),
          const Divider(height: 24),
          Text('Your bets', style: GameBidUi.panelTitle.copyWith(fontSize: 15)),
          if (_bids.isEmpty)
            Text('No bets yet', style: GameBidUi.emptyHint)
          else
            ..._bids
                .map(
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

  Widget _statCard(String label, String value) {
    return GameBidUi.glassListRow(
      radius: 10,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: CasinoUi.mutedGold(0.65), fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: CasinoUi.lightGold)),
        ],
      ),
    );
  }
}

