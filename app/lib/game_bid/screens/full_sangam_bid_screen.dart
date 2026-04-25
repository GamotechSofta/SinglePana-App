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

class _Line {
  _Line({required this.id, required this.number, required this.points, required this.session});
  final int id;
  final String number;
  final String points;
  final String session;
}

class FullSangamBidScreen extends StatefulWidget {
  const FullSangamBidScreen({super.key, required this.market, required this.title});

  final Map<String, dynamic> market;
  final String title;

  @override
  State<FullSangamBidScreen> createState() => _FullSangamBidScreenState();
}

class _FullSangamBidScreenState extends State<FullSangamBidScreen> {
  static const _quickPoints = [10, 20, 30, 40, 50];
  static const _session = 'OPEN';

  String _dateYmd = '';
  double _wallet = 0;
  final _openCtrl = TextEditingController();
  final _closeCtrl = TextEditingController();
  final _ptsCtrl = TextEditingController();
  final _closeFocus = FocusNode();
  final _ptsFocus = FocusNode();
  final List<_Line> _bids = [];
  String _warn = '';
  Timer? _autoAddDebounce;

  @override
  void initState() {
    super.initState();
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
    _autoAddDebounce?.cancel();
    _openCtrl.dispose();
    _closeCtrl.dispose();
    _ptsCtrl.dispose();
    _closeFocus.dispose();
    _ptsFocus.dispose();
    super.dispose();
  }

  void _toast(String m) {
    setState(() => _warn = m);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _warn = '');
    });
  }

  void _add() {
    final o = _openCtrl.text.trim();
    final c = _closeCtrl.text.trim();
    final pts = int.tryParse(_ptsCtrl.text.trim()) ?? 0;
    if (pts <= 0) {
      _toast('Enter points');
      return;
    }
    if (!isValidAnyPana(o)) {
      _toast('Open pana must be valid (3 digits)');
      return;
    }
    if (!isValidAnyPana(c)) {
      _toast('Close pana must be valid (3 digits)');
      return;
    }
    final key = '$o-$c';
    final i = _bids.indexWhere((b) => b.number == key);
    if (i >= 0) {
      final prev = int.tryParse(_bids[i].points) ?? 0;
      _bids[i] = _Line(id: _bids[i].id, number: key, points: '${prev + pts}', session: _session);
    } else {
      _bids.add(_Line(id: DateTime.now().microsecondsSinceEpoch, number: key, points: '$pts', session: _session));
    }
    _openCtrl.clear();
    _closeCtrl.clear();
    _ptsCtrl.clear();
    setState(() {});
  }

  void _tryAutoAdd() {
    final pts = int.tryParse(_ptsCtrl.text.trim()) ?? 0;
    if (_openCtrl.text.trim().isEmpty || _closeCtrl.text.trim().isEmpty || pts <= 0) return;
    _add();
  }

  void _scheduleAutoAdd() {
    _autoAddDebounce?.cancel();
    _autoAddDebounce = Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      _tryAutoAdd();
    });
  }

  void _masterClear() {
    setState(() {
      _openCtrl.clear();
      _closeCtrl.clear();
      _ptsCtrl.clear();
      _bids.clear();
    });
  }

  bool get _canMasterClear =>
      _bids.isNotEmpty ||
      _openCtrl.text.trim().isNotEmpty ||
      _closeCtrl.text.trim().isNotEmpty ||
      _ptsCtrl.text.trim().isNotEmpty;

  Future<void> _place() async {
    _tryAutoAdd();
    if (_bids.isEmpty) {
      _toast('Add at least one sangam');
      return;
    }
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
                betType: 'full-sangam',
                betNumber: b.number,
                amount: int.tryParse(b.points) ?? 0,
                betOn: 'open',
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
      onSessionChanged: (_) {},
      sessionOptionsOverride: const ['OPEN'],
      lockSession: true,
      selectedDateYmd: _dateYmd,
      onDateChanged: (v) async {
        setState(() => _dateYmd = v);
        await saveBetSelectedDate(v);
      },
      bidsCount: _bids.length,
      totalPoints: total,
      onSubmit: _place,
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
          TextField(
            controller: _openCtrl,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            maxLength: 3,
            onChanged: (v) {
              final raw = v.replaceAll(RegExp(r'\D'), '');
              if (raw.length == 3 && isValidAnyPana(raw)) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) FocusScope.of(context).requestFocus(_closeFocus);
                });
              }
              setState(() {});
              _scheduleAutoAdd();
            },
            onEditingComplete: () => FocusScope.of(context).requestFocus(_closeFocus),
            onSubmitted: (_) => FocusScope.of(context).requestFocus(_closeFocus),
            decoration: GameBidUi.inputDecoration(labelText: 'Open pana', counterText: ''),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _closeCtrl,
            focusNode: _closeFocus,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            maxLength: 3,
            onChanged: (v) {
              final raw = v.replaceAll(RegExp(r'\D'), '');
              if (raw.length == 3 && isValidAnyPana(raw)) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) FocusScope.of(context).requestFocus(_ptsFocus);
                });
              }
              setState(() {});
              _scheduleAutoAdd();
            },
            onEditingComplete: () => FocusScope.of(context).requestFocus(_ptsFocus),
            onSubmitted: (_) => FocusScope.of(context).requestFocus(_ptsFocus),
            decoration: GameBidUi.inputDecoration(labelText: 'Close pana', counterText: ''),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ptsCtrl,
            focusNode: _ptsFocus,
            keyboardType: TextInputType.number,
            onChanged: (_) {
              setState(() {});
              _scheduleAutoAdd();
            },
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _tryAutoAdd(),
            onEditingComplete: _tryAutoAdd,
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
                  _scheduleAutoAdd();
                },
              );
            }).toList(),
          ),
          const Divider(height: 24),
          ..._bids.map(
            (b) => ListTile(
              dense: true,
              title: Text(b.number, style: const TextStyle(color: CasinoUi.lightGold)),
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
      ),
    );
  }
}
