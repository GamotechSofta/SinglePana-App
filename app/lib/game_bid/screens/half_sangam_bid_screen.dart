import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/bets_service.dart';
import '../../theme/app_spacing.dart';
import '../../theme/casino_ui.dart';
import '../bet_date_prefs.dart';
import '../bid_review_dialog.dart';
import '../betting_window_scope.dart';
import '../game_bid_layout.dart';
import '../game_bid_ui.dart';
import '../pana_rules.dart';

class _Line {
  _Line({required this.id, required this.number, required this.points, required this.session});
  final String id;
  final String number;
  String points;
  final String session;
}

class HalfSangamBidScreen extends StatefulWidget {
  const HalfSangamBidScreen({super.key, required this.market, required this.title});

  final Map<String, dynamic> market;
  final String title;

  @override
  State<HalfSangamBidScreen> createState() => _HalfSangamBidScreenState();
}

class _HalfSangamBidScreenState extends State<HalfSangamBidScreen> {
  static const _quick = [10, 20, 30, 40, 50];
  String _session = 'OPEN';
  String _dateYmd = '';
  double _wallet = 0;
  String _warn = '';
  bool _flipped = false;
  final _firstCtrl = TextEditingController();
  final _secondCtrl = TextEditingController();
  final _ptsCtrl = TextEditingController();
  final List<_Line> _bids = [];
  Timer? _autoAddDebounce;

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
    _firstCtrl.dispose();
    _secondCtrl.dispose();
    _ptsCtrl.dispose();
    super.dispose();
  }

  void _toast(String m) {
    setState(() => _warn = m);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _warn = '');
    });
  }

  void _add() {
    final p = int.tryParse(_ptsCtrl.text.trim()) ?? 0;
    if (p <= 0) return _toast('Please enter points.');
    final a = _firstCtrl.text.replaceAll(RegExp(r'\D'), '').trim();
    final b = _secondCtrl.text.replaceAll(RegExp(r'\D'), '').trim();
    final pana = _flipped ? b : a;
    final ank = _flipped ? a : b;
    if (!isValidAnyPana(pana)) return _toast('Pana must be valid 3 digits.');
    if (!RegExp(r'^\d$').hasMatch(ank)) return _toast('Ank must be 0-9.');
    final key = _flipped ? '$ank-$pana' : '$pana-$ank';
    setState(() {
      final idx = _bids.indexWhere((e) => e.number == key && e.session == _session);
      if (idx >= 0) {
        final cur = int.tryParse(_bids[idx].points) ?? 0;
        _bids[idx].points = '${cur + p}';
      } else {
        _bids.add(_Line(id: '$key-${DateTime.now().microsecondsSinceEpoch}', number: key, points: '$p', session: _session));
      }
      _firstCtrl.clear();
      _secondCtrl.clear();
      _ptsCtrl.clear();
    });
  }

  void _tryAutoAdd() {
    final p = int.tryParse(_ptsCtrl.text.trim()) ?? 0;
    if (p <= 0) return;

    final a = _firstCtrl.text.replaceAll(RegExp(r'\D'), '').trim();
    final b = _secondCtrl.text.replaceAll(RegExp(r'\D'), '').trim();
    final pana = _flipped ? b : a;
    final ank = _flipped ? a : b;
    if (!isValidAnyPana(pana)) return;
    if (!RegExp(r'^\d$').hasMatch(ank)) return;
    _add();
  }

  void _scheduleAutoAdd() {
    _autoAddDebounce?.cancel();
    _autoAddDebounce = Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      _tryAutoAdd();
    });
  }

  bool _materializePendingBeforeSubmit() {
    final hasPending = _firstCtrl.text.trim().isNotEmpty || _secondCtrl.text.trim().isNotEmpty || _ptsCtrl.text.trim().isNotEmpty;
    if (!hasPending) return true;

    final p = int.tryParse(_ptsCtrl.text.trim()) ?? 0;
    if (p <= 0) {
      _toast('Please enter points.');
      return false;
    }
    final a = _firstCtrl.text.replaceAll(RegExp(r'\D'), '').trim();
    final b = _secondCtrl.text.replaceAll(RegExp(r'\D'), '').trim();
    final pana = _flipped ? b : a;
    final ank = _flipped ? a : b;
    if (!isValidAnyPana(pana)) {
      _toast('Pana must be valid 3 digits.');
      return false;
    }
    if (!RegExp(r'^\d$').hasMatch(ank)) {
      _toast('Ank must be 0-9.');
      return false;
    }
    _add();
    return true;
  }

  Future<void> _submit() async {
    final ok = _materializePendingBeforeSubmit();
    if (!ok) return;
    if (mounted) setState(() {});

    final active = _bids.where((e) => (int.tryParse(e.points) ?? 0) > 0).toList();
    if (active.isEmpty) return _toast('Please add at least one Sangam.');
    final win = BettingWindowScope.of(context);
    final name = (widget.market['gameName'] ?? widget.market['marketName'] ?? widget.title).toString();
    await showBidReviewDialog(
      context: context,
      bettingWindow: win,
      marketTitle: name,
      walletBefore: _wallet,
      labelKey: 'Sangam',
      betCategoryTitle: widget.title,
      historyDateYmd: _dateYmd,
      rows: active.map((r) => BidRowVm(id: r.id.hashCode, number: r.number, points: r.points, sessionLabel: r.session)).toList(),
      onCancel: () {},
      onConfirm: () async {
        final mid = widget.market['id'] ?? widget.market['_id'];
        final sched = scheduledDateIfFuture(_dateYmd);
        final lines = active
            .map((r) => PlaceBetLine(betType: 'half-sangam', betNumber: r.number, amount: int.tryParse(r.points) ?? 0, betOn: r.session.toUpperCase() == 'CLOSE' ? 'close' : 'open'))
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

  void _masterClear() {
    setState(() {
      _firstCtrl.clear();
      _secondCtrl.clear();
      _ptsCtrl.clear();
      _bids.clear();
    });
  }

  bool get _canMasterClear =>
      _bids.isNotEmpty ||
      _firstCtrl.text.trim().isNotEmpty ||
      _secondCtrl.text.trim().isNotEmpty ||
      _ptsCtrl.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final fLabel = _flipped ? 'Open Ank' : 'Open Pana';
    final sLabel = _flipped ? 'Close Pana' : 'Close Ank';
    final fMax = _flipped ? 1 : 3;
    final sMax = _flipped ? 3 : 1;
    final total = _bids.fold<int>(0, (s, e) => s + (int.tryParse(e.points) ?? 0));
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
      onBack: () => Navigator.of(context).pop(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
        children: [
          if (_warn.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(_warn, style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
            ),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: OutlinedButton.icon(
              onPressed: () => setState(() {
                _flipped = !_flipped;
                _firstCtrl.clear();
                _secondCtrl.clear();
                _ptsCtrl.clear();
              }),
              icon: const Icon(Icons.swap_vert, size: 16),
              label: const Text('Flip (O) <-> (C)', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.buttonPaddingH,
                  vertical: AppSpacing.buttonPaddingV,
                ),
                minimumSize: const Size(0, AppSpacing.buttonMinHeight),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _firstCtrl,
            maxLength: fMax,
            keyboardType: TextInputType.number,
            onChanged: (_) {
              setState(() {});
              _scheduleAutoAdd();
            },
            onEditingComplete: _tryAutoAdd,
            onSubmitted: (_) => _tryAutoAdd(),
            decoration: GameBidUi.inputDecoration(
              labelText: fLabel,
              hintText: fMax == 3 ? 'Pana' : 'Ank',
              counterText: '',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _secondCtrl,
            maxLength: sMax,
            keyboardType: TextInputType.number,
            onChanged: (_) {
              setState(() {});
              _scheduleAutoAdd();
            },
            onEditingComplete: _tryAutoAdd,
            onSubmitted: (_) => _tryAutoAdd(),
            decoration: GameBidUi.inputDecoration(
              labelText: sLabel,
              hintText: sMax == 3 ? 'Pana' : 'Ank',
              counterText: '',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _ptsCtrl,
            keyboardType: TextInputType.number,
            onChanged: (_) {
              setState(() {});
              _scheduleAutoAdd();
            },
            onEditingComplete: _tryAutoAdd,
            onSubmitted: (_) => _tryAutoAdd(),
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
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: _quick
                .map(
                  (p) => GameBidUi.quickPointsChip(
                    selected: _ptsCtrl.text.trim() == '$p',
                    label: '$p',
                    extent: tile,
                    onSelected: (_) => setState(() => _ptsCtrl.text = '$p'),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Row(
            children: [
              Expanded(
                flex: 4,
                child: Text('Sangam', textAlign: TextAlign.start, style: GameBidUi.tableHeader),
              ),
              Expanded(
                flex: 2,
                child: Text('Point', textAlign: TextAlign.center, style: GameBidUi.tableHeader),
              ),
              Expanded(
                flex: 2,
                child: Text('Type', textAlign: TextAlign.center, style: GameBidUi.tableHeader),
              ),
              Expanded(
                flex: 1,
                child: Text('Delete', textAlign: TextAlign.center, style: GameBidUi.tableHeader),
              ),
            ],
          ),
          Divider(height: AppSpacing.md, color: Colors.white.withValues(alpha: 0.08)),
          if (_bids.isEmpty)
            Text('No bets yet', style: GameBidUi.emptyHint)
          else
            ..._bids.map(
              (b) => GameBidUi.glassListRow(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 4,
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          b.number,
                          textAlign: TextAlign.start,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: CasinoUi.lightGold),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        b.points,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: CasinoUi.mutedGold(0.92)),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        b.session,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: CasinoUi.mutedGold(0.85)),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: IconButton(
                        alignment: Alignment.center,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        onPressed: () => setState(() => _bids.removeWhere((e) => e.id == b.id)),
                        icon: Icon(Icons.close, size: 18, color: CasinoUi.mutedGold(0.75)),
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
