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

class _BidLine {
  _BidLine({required this.id, required this.number, required this.points, required this.sessionLabel});

  final Object id;
  final String number;
  final String points;
  final String sessionLabel;
}

class ListBidScreen extends StatefulWidget {
  const ListBidScreen({
    super.key,
    required this.market,
    required this.title,
    required this.apiBetType,
    required this.maxLength,
    required this.validate,
    this.specialKeys,
    this.lockSessionOpen = false,
    /// Single Pana: special mode uses points + multi-select grid (same flow as Single Digit Bulk).
    this.useBulkSpecialUi = false,
    /// Easy mode: show quick point chips (e.g. Double Pana).
    this.easyQuickPoints = false,
    /// Easy mode: overrides first field label (e.g. "Pana (3 digits)" for Double Pana).
    this.easyNumberLabel,
  });

  final Map<String, dynamic> market;
  final String title;
  final String apiBetType;
  final int maxLength;
  final bool Function(String) validate;
  final List<String>? specialKeys;
  final bool lockSessionOpen;
  final bool useBulkSpecialUi;
  final bool easyQuickPoints;
  final String? easyNumberLabel;

  @override
  State<ListBidScreen> createState() => _ListBidScreenState();
}

class _ListBidScreenState extends State<ListBidScreen> {
  final _numCtrl = TextEditingController();
  final _ptsCtrl = TextEditingController();
  final Map<String, TextEditingController> _specialCtrls = {};
  TextEditingController? _bulkSpecialPtsCtrl;
  final Set<String> _selectedBulkKeys = {};

  String _session = 'OPEN';
  String _dateYmd = '';
  double _wallet = 0;
  final List<_BidLine> _bids = [];
  bool _easy = true;
  String _warn = '';

  static const _quickPoints = [10, 20, 30, 40, 50];

  @override
  void initState() {
    super.initState();
    _session = widget.lockSessionOpen
        ? 'OPEN'
        : (widget.market['status']?.toString() == 'running' ? 'CLOSE' : 'OPEN');
    if (widget.specialKeys != null) {
      if (widget.useBulkSpecialUi) {
        _bulkSpecialPtsCtrl = TextEditingController();
      } else {
        for (final k in widget.specialKeys!) {
          _specialCtrls[k] = TextEditingController();
        }
      }
    }
    _hydrate();
  }

  Future<void> _hydrate() async {
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
    _numCtrl.dispose();
    _ptsCtrl.dispose();
    _bulkSpecialPtsCtrl?.dispose();
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

  void _mergeAdd(String number, String points, String sessionLabel) {
    final pts = int.tryParse(points) ?? 0;
    if (pts <= 0) {
      _toast('Enter valid points');
      return;
    }
    if (!widget.validate(number)) {
      _toast('Invalid number');
      return;
    }
    final i = _bids.indexWhere((b) => b.number == number && b.sessionLabel == sessionLabel);
    if (i >= 0) {
      final prev = int.tryParse(_bids[i].points) ?? 0;
      _bids[i] = _BidLine(
        id: _bids[i].id,
        number: number,
        points: '${prev + pts}',
        sessionLabel: sessionLabel,
      );
    } else {
      _bids.add(_BidLine(id: DateTime.now().millisecondsSinceEpoch, number: number, points: '$pts', sessionLabel: sessionLabel));
    }
    setState(() {});
  }

  void _addEasy() {
    final n = _numCtrl.text.trim();
    final p = _ptsCtrl.text.trim();
    if (p.isEmpty) {
      _toast('Enter points');
      return;
    }
    if (widget.maxLength == 2 && n.length != 2) {
      _toast('Enter 2-digit number (00-99)');
      return;
    }
    _mergeAdd(n, p, _session);
    _numCtrl.clear();
    _ptsCtrl.clear();
  }

  void _addSpecial() {
    var any = false;
    for (final e in _specialCtrls.entries) {
      final pts = int.tryParse(e.value.text) ?? 0;
      if (pts > 0) {
        _mergeAdd(e.key, e.value.text, _session);
        e.value.clear();
        any = true;
      }
    }
    if (!any) _toast('Enter points for at least one row');
  }

  void _upsertBulkBidWithPoints(String key, int points) {
    final i = _bids.indexWhere((b) => b.number == key && b.sessionLabel == _session);
    if (points <= 0) {
      if (i >= 0) _bids.removeAt(i);
      return;
    }
    if (i >= 0) {
      _bids[i] = _BidLine(
        id: _bids[i].id,
        number: key,
        points: '$points',
        sessionLabel: _session,
      );
    } else {
      _bids.add(
        _BidLine(
          id: DateTime.now().millisecondsSinceEpoch + _bids.length,
          number: key,
          points: '$points',
          sessionLabel: _session,
        ),
      );
    }
  }

  void _syncSelectedBulkPointsFromInput() {
    final pts = int.tryParse(_bulkSpecialPtsCtrl?.text.trim() ?? '') ?? 0;
    if (_selectedBulkKeys.isEmpty) {
      setState(() {});
      return;
    }
    setState(() {
      for (final key in _selectedBulkKeys) {
        _upsertBulkBidWithPoints(key, pts);
      }
    });
  }

  void _toggleBulkKey(String k) {
    final c = _bulkSpecialPtsCtrl;
    final pts = int.tryParse(c?.text.trim() ?? '') ?? 0;
    if (pts <= 0) {
      _toast('Enter bet points first');
      return;
    }
    setState(() {
      if (_selectedBulkKeys.remove(k)) {
        _bids.removeWhere((b) => b.sessionLabel == _session && b.number == k);
      } else {
        _selectedBulkKeys.add(k);
        _upsertBulkBidWithPoints(k, pts);
      }
    });
  }

  int _currentPointsForBulkKey(String key) {
    final i = _bids.lastIndexWhere((b) => b.number == key && b.sessionLabel == _session);
    if (i < 0) return 0;
    return int.tryParse(_bids[i].points) ?? 0;
  }

  void _clearSelectedBulkCombinations() {
    if (_selectedBulkKeys.isEmpty) return;
    setState(() {
      _bids.removeWhere((b) => b.sessionLabel == _session && _selectedBulkKeys.contains(b.number));
      _selectedBulkKeys.clear();
    });
  }

  bool _hasMasterClearTargets() {
    if (_bids.isNotEmpty) return true;
    if (_numCtrl.text.trim().isNotEmpty) return true;
    if (_ptsCtrl.text.trim().isNotEmpty) return true;
    if (_bulkSpecialPtsCtrl?.text.trim().isNotEmpty ?? false) return true;
    if (_selectedBulkKeys.isNotEmpty) return true;
    for (final c in _specialCtrls.values) {
      if (c.text.trim().isNotEmpty) return true;
    }
    return false;
  }

  void _masterClear() {
    setState(() {
      _bids.clear();
      _numCtrl.clear();
      _ptsCtrl.clear();
      _selectedBulkKeys.clear();
      _bulkSpecialPtsCtrl?.clear();
      for (final c in _specialCtrls.values) {
        c.clear();
      }
    });
  }

  Widget _quickPointsChips(TextEditingController ctrl, double tileExtent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: GameBidUi.quickPointsAfterFieldGap),
        Row(
          children: [
            Text(
              'Quick points',
              style: GameBidUi.sectionLabel,
            ),
            const Spacer(),
            TextButton(
              style: GameBidUi.quickPointsClearTextButtonStyle,
              onPressed: !_hasMasterClearTargets() ? null : _masterClear,
              child: const Text('Clear'),
            ),
          ],
        ),
        const SizedBox(height: GameBidUi.quickPointsHeaderToChipsGap),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _quickPoints.map((p) {
            final sel = ctrl.text.trim() == '$p';
            return GameBidUi.quickPointsChip(
              selected: sel,
              label: '$p',
              extent: tileExtent,
              onSelected: (_) {
                setState(() => ctrl.text = '$p');
                // In bulk special mode, chip taps must also update selected combo amounts.
                if (widget.useBulkSpecialUi && identical(ctrl, _bulkSpecialPtsCtrl)) {
                  _syncSelectedBulkPointsFromInput();
                }
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  bool _specialQuickChipSelected(int p) {
    if (_specialCtrls.isEmpty) return false;
    return _specialCtrls.values.every((c) => c.text.trim() == '$p');
  }

  void _applyQuickToAllSpecial(int points) {
    setState(() {
      for (final c in _specialCtrls.values) {
        c.text = '$points';
      }
    });
  }

  Widget _specialQuickPoints(double tileExtent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: GameBidUi.quickPointsAfterFieldGap),
        Row(
          children: [
            Text('Quick points', style: GameBidUi.sectionLabel),
            const Spacer(),
            TextButton(
              style: GameBidUi.quickPointsClearTextButtonStyle,
              onPressed: !_hasMasterClearTargets() ? null : _masterClear,
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
              extent: tileExtent,
              onSelected: (_) => _applyQuickToAllSpecial(p),
            );
          }).toList(),
        ),
      ],
    );
  }

  ({int count, int points}) _liveStats() {
    var count = _bids.length;
    var points = _bids.fold<int>(0, (s, b) => s + (int.tryParse(b.points) ?? 0));

    if (_easy || widget.specialKeys == null) {
      final n = _numCtrl.text.trim();
      final p = int.tryParse(_ptsCtrl.text.trim()) ?? 0;
      if (p > 0 && widget.validate(n)) {
        count += 1;
        points += p;
      }
    } else if (!widget.useBulkSpecialUi) {
      for (final c in _specialCtrls.values) {
        final p = int.tryParse(c.text.trim()) ?? 0;
        if (p > 0) {
          count += 1;
          points += p;
        }
      }
    }

    return (count: count, points: points);
  }

  void _materializePendingBeforeSubmit() {
    if (_easy || widget.specialKeys == null) {
      final n = _numCtrl.text.trim();
      final p = _ptsCtrl.text.trim();
      if ((int.tryParse(p) ?? 0) > 0 && widget.validate(n)) {
        _mergeAdd(n, p, _session);
        _numCtrl.clear();
        _ptsCtrl.clear();
      }
      return;
    }

    if (!widget.useBulkSpecialUi) {
      for (final e in _specialCtrls.entries) {
        final pts = int.tryParse(e.value.text.trim()) ?? 0;
        if (pts > 0) {
          final i = _bids.indexWhere((b) => b.number == e.key && b.sessionLabel == _session);
          if (i >= 0) {
            _bids[i] = _BidLine(id: _bids[i].id, number: e.key, points: '$pts', sessionLabel: _session);
          } else {
            _bids.add(_BidLine(id: DateTime.now().millisecondsSinceEpoch + _bids.length, number: e.key, points: '$pts', sessionLabel: _session));
          }
          e.value.clear();
        }
      }
    } else {
      final pts = int.tryParse(_bulkSpecialPtsCtrl?.text.trim() ?? '') ?? 0;
      if (pts > 0 && _selectedBulkKeys.isNotEmpty) {
        final sorted = _selectedBulkKeys.toList()..sort((a, b) => a.compareTo(b));
        for (final k in sorted) {
          _upsertBulkBidWithPoints(k, pts);
        }
      }
    }
  }

  Future<void> _submit() async {
    _materializePendingBeforeSubmit();
    if (_bids.isEmpty) {
      _toast('Add at least one bet');
      return;
    }
    final win = BettingWindowScope.of(context);
    final marketTitle = (widget.market['gameName'] ?? widget.market['marketName'] ?? widget.title).toString();
    await showBidReviewDialog(
      context: context,
      bettingWindow: win,
      marketTitle: marketTitle,
      walletBefore: _wallet,
      labelKey: widget.apiBetType == 'jodi' ? 'Jodi' : 'Pana',
      betCategoryTitle: widget.title,
      historyDateYmd: _dateYmd,
      onCancel: () {
        if (!mounted) return;
        setState(() => _bids.clear());
      },
      rows: _bids
          .map(
            (b) => BidRowVm(
              id: b.id,
              number: b.number,
              points: b.points,
              sessionLabel: b.sessionLabel,
            ),
          )
          .toList(),
      onConfirm: () async {
        final mid = widget.market['id'] ?? widget.market['_id'];
        final sched = scheduledDateIfFuture(_dateYmd);
        final lines = _bids
            .map(
              (b) => PlaceBetLine(
                betType: widget.apiBetType,
                betNumber: b.number,
                amount: int.tryParse(b.points) ?? 0,
                betOn: b.sessionLabel.toUpperCase() == 'CLOSE' ? 'close' : 'open',
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
    final specialTile = GameBidUi.betTileExtentForColumns(MediaQuery.sizeOf(context).width, columns: 8);
    final specialGridHeight = MediaQuery.sizeOf(context).height * 0.56;

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
      sessionOptionsOverride: widget.lockSessionOpen ? ['OPEN'] : null,
      lockSession: widget.lockSessionOpen,
      bidsCount: live.count,
      totalPoints: live.points,
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
          if (widget.specialKeys != null) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _easy = false),
                    style: GameBidUi.modeToggle(!_easy),
                    child: const Text('SPECIAL'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _easy = true),
                    style: GameBidUi.modeToggle(_easy),
                    child: const Text('EASY'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (_easy || widget.specialKeys == null) ...[
            TextField(
              controller: _numCtrl,
              keyboardType: TextInputType.number,
              maxLength: widget.maxLength,
              onSubmitted: (_) {
                if (_ptsCtrl.text.trim().isNotEmpty) _addEasy();
              },
              decoration: GameBidUi.inputDecoration(
                labelText: widget.easyNumberLabel ??
                    (widget.maxLength == 2 ? 'Number (00-99)' : 'Number (${widget.maxLength} digits)'),
                hintText: widget.easyNumberLabel != null ? 'Pana' : null,
                counterText: '',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _ptsCtrl,
              keyboardType: TextInputType.number,
              onChanged: (widget.useBulkSpecialUi || widget.easyQuickPoints) ? (_) => setState(() {}) : null,
              onSubmitted: (_) => _addEasy(),
              decoration: GameBidUi.inputDecoration(labelText: 'Points'),
            ),
            if (widget.useBulkSpecialUi || widget.easyQuickPoints) ...[
              _quickPointsChips(_ptsCtrl, tile),
            ],
          ] else if (widget.useBulkSpecialUi && _bulkSpecialPtsCtrl != null) ...[
            Text('Step 1: Enter bet points', style: GameBidUi.panelTitle.copyWith(fontSize: 14)),
            const SizedBox(height: 12),
            TextField(
              controller: _bulkSpecialPtsCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              onChanged: (_) => _syncSelectedBulkPointsFromInput(),
              decoration: GameBidUi.inputDecoration(labelText: 'Points'),
            ),
            _quickPointsChips(_bulkSpecialPtsCtrl!, tile),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text('Step 2: Select pana combinations', style: GameBidUi.panelTitle.copyWith(fontSize: 14)),
                ),
                TextButton(
                  onPressed: _selectedBulkKeys.isEmpty ? null : _clearSelectedBulkCombinations,
                  child: const Text('Clear selected'),
                ),
              ],
            ),
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
              itemCount: widget.specialKeys!.length,
              itemBuilder: (context, i) {
                final k = widget.specialKeys![i];
                final selected = _selectedBulkKeys.contains(k);
                return InkWell(
                  onTap: () => _toggleBulkKey(k),
                  borderRadius: BorderRadius.circular(GameBidUi.betChipRadius),
                  child: DecoratedBox(
                    decoration: GameBidUi.numberChipTileDecoration(selected: selected),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          k,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '₹${_currentPointsForBulkKey(k)}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: selected ? 0.9 : 0.65),
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            GameBidUi.glassListRow(
              radius: 10,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              child: Text(
                'Tap any pana to auto add to list',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w600, color: CasinoUi.mutedGold(0.88)),
              ),
            ),
          ] else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.easyQuickPoints) _specialQuickPoints(specialTile),
                if (widget.easyQuickPoints) const SizedBox(height: 12),
                const Text(
                  'Jodi combinations',
                  style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 14),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: specialGridHeight,
                  child: GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                      mainAxisExtent: specialTile,
                    ),
                    itemCount: widget.specialKeys!.length,
                    itemBuilder: (context, i) {
                      final k = widget.specialKeys![i];
                      final c = _specialCtrls[k]!;
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          GameBidUi.betNumberChip(
                            label: k,
                            extent: specialTile,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: GameBidUi.betPointsRectangleSlot(
                              extent: specialTile,
                              child: TextField(
                                controller: c,
                                keyboardType: TextInputType.number,
                                onChanged: (_) => setState(() {}),
                                onSubmitted: (_) => _addSpecial(),
                                style: GameBidUi.betInputStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                decoration: GameBidUi.inlinePointsDecoration().copyWith(hintText: 'pts'),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          if (!(widget.apiBetType == 'jodi' && !_easy)) ...[
            const Divider(height: 24),
            Text('Your bets', style: GameBidUi.panelTitle.copyWith(fontSize: 15)),
            ..._bids.map(
              (b) => ListTile(
                title: Text(
                  '${b.number} · ${b.sessionLabel}',
                  style: const TextStyle(color: CasinoUi.lightGold, fontWeight: FontWeight.w600),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('₹${b.points}', style: TextStyle(color: CasinoUi.mutedGold(0.9))),
                    IconButton(
                      onPressed: () => setState(() => _bids.removeWhere((e) => e.id == b.id)),
                      icon: Icon(Icons.close, color: AppColors.gold.withValues(alpha: 0.85)),
                      tooltip: 'Remove',
                    ),
                  ],
                ),
                dense: true,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
