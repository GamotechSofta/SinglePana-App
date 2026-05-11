import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../services/auth_service.dart';
import '../../services/bet_history_storage.dart';
import '../../services/bets_service.dart';
import '../../services/markets_service.dart';
import '../../services/wallet_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/bet_verdict.dart';
import '../../utils/nav_pop_or_home.dart';
import '../../utils/wallet_tx_parsing.dart';

const Color _histLightGold = Color(0xFFFEF9E8);

ShapeBorder _historyCardShape() => RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(16),
  side: BorderSide(
    color: Colors.white.withValues(alpha: 0.22),
    width: 1,
  ),
);

/// Local bet cards + verdicts — parity with [frontend/src/pages/BetHistory.jsx].
class BetHistoryView extends StatefulWidget {
  const BetHistoryView({super.key, this.starlineOnly = false});

  final bool starlineOnly;

  @override
  State<BetHistoryView> createState() => _BetHistoryViewState();
}

class _BetHistoryViewState extends State<BetHistoryView> {
  bool _loading = true;
  String? _userId;
  List<Map<String, dynamic>> _entries = [];
  List<Map<String, dynamic>> _markets = [];
  Map<String, dynamic>? _ratesMap;
  final _sessions = <String>[];
  final _statuses = <String>[];
  final _marketKeys = <String>[];
  int _page = 1;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool _inScope(String? marketTitle) {
    final star = isStarlineMarketName(marketTitle);
    if (widget.starlineOnly) return star;
    return !star;
  }

  Future<void> _refresh() async {
    final u = await AuthService.instance.getStoredUser();
    final uid = u?['_id']?.toString() ?? u?['id']?.toString();
    final raw = await BetHistoryStorage.instance.loadAll();
    final scoped = raw.where((x) {
      if (uid != null && x['userId']?.toString() != uid) return false;
      return _inScope(x['marketTitle']?.toString());
    }).toList();

    final markets = await MarketsService.instance.fetchMarkets();
    final ratesRes = await BetsService.instance.fetchRatesCurrent();
    Map<String, dynamic>? ratesData;
    if (ratesRes != null && ratesRes['data'] is Map) {
      ratesData = Map<String, dynamic>.from(ratesRes['data'] as Map);
    }

    final marketByName = <String, Map<String, dynamic>>{};
    for (final m in markets) {
      final n = m['marketName']?.toString();
      if (n != null) marketByName[normalizeMarketName(n)] = m;
    }

    final settlements = <BetSettlement>[];
    for (final x in scoped) {
      final rows = x['rows'];
      if (rows is! List) continue;
      final entryId = x['id']?.toString();
      if (entryId == null) continue;
      for (final raw in rows) {
        final r = Map<String, dynamic>.from(raw as Map);
        final rid = r['id']?.toString();
        if (rid == null) continue;
        if (r['settledState'] != null) continue;
        final marketTitle = (x['marketTitle'] ?? '').toString().trim();
        final m = marketByName[normalizeMarketName(marketTitle)];
        final points =
            num.tryParse(r['points']?.toString() ?? '') ??
            (r['points'] as num?) ??
            0;
        final session = (r['type'] ?? x['session'] ?? '')
            .toString()
            .trim()
            .toUpperCase();
        final v = evaluateBet(
          market: m,
          betNumberRaw: r['number']?.toString(),
          amount: points,
          session: session,
          ratesMap: ratesData,
        );
        if (v.state == 'won' || v.state == 'lost') {
          settlements.add(
            BetSettlement(
              entryId: entryId,
              rowId: rid,
              state: v.state,
              payout: v.payout,
            ),
          );
        }
      }
    }
    if (settlements.isNotEmpty) {
      await BetHistoryStorage.instance.applySettlements(settlements);
    }
    final after = settlements.isNotEmpty
        ? await BetHistoryStorage.instance.loadAll()
        : raw;
    final entries = after.where((x) {
      if (uid != null && x['userId']?.toString() != uid) return false;
      return _inScope(x['marketTitle']?.toString());
    }).toList();

    if (!mounted) return;
    setState(() {
      _loading = false;
      _userId = uid;
      _entries = entries;
      _markets = markets;
      _ratesMap = ratesData;
    });
  }

  String _fmtTime(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    final d = DateTime.tryParse(iso);
    if (d == null) return '-';
    return '${DateFormat('dd-MM-yyyy').format(d)} ${DateFormat.jm().format(d)}';
  }

  String _statusFor(
    Map<String, dynamic> r,
    Map<String, dynamic> x,
    Map<String, dynamic>? m,
    String session,
  ) {
    final points =
        num.tryParse(r['points']?.toString() ?? '') ??
        (r['points'] as num?) ??
        0;
    final computed = evaluateBet(
      market: m,
      betNumberRaw: r['number']?.toString(),
      amount: points,
      session: session,
      ratesMap: _ratesMap,
    );
    final stored = r['settledState']?.toString();
    final st = (stored == 'won' || stored == 'lost') ? stored! : computed.state;
    if (st == 'won') return 'Win';
    if (st == 'lost') return 'Loose';
    return 'Pending';
  }

  num _payoutFor(
    Map<String, dynamic> r,
    Map<String, dynamic> x,
    Map<String, dynamic>? m,
    String session,
  ) {
    final points =
        num.tryParse(r['points']?.toString() ?? '') ??
        (r['points'] as num?) ??
        0;
    final computed = evaluateBet(
      market: m,
      betNumberRaw: r['number']?.toString(),
      amount: points,
      session: session,
      ratesMap: _ratesMap,
    );
    final stored = r['settledState']?.toString();
    if (stored == 'won' || stored == 'lost') {
      return num.tryParse(r['settledPayout']?.toString() ?? '') ??
          (r['settledPayout'] as num?) ??
          computed.payout;
    }
    return computed.payout;
  }

  String _stateRaw(
    Map<String, dynamic> r,
    Map<String, dynamic> x,
    Map<String, dynamic>? m,
    String session,
  ) {
    final points =
        num.tryParse(r['points']?.toString() ?? '') ??
        (r['points'] as num?) ??
        0;
    final computed = evaluateBet(
      market: m,
      betNumberRaw: r['number']?.toString(),
      amount: points,
      session: session,
      ratesMap: _ratesMap,
    );
    final stored = r['settledState']?.toString();
    if (stored == 'won' || stored == 'lost') return stored!;
    return computed.state;
  }

  /// Last 8 hex chars of a MongoDB ObjectId (`…` length 24) for compact display in history.
  String _displayBetId(String raw) {
    final t = raw.trim();
    if (t.isEmpty || t == '-') return t;
    if (RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(t)) {
      return t.substring(16);
    }
    return t;
  }

  Widget _detailRow(
    String label,
    String value, {
    Color? valueColor,
    FontWeight valueWeight = FontWeight.w700,
    bool copyable = false,
    String? copyValue,
  }) {
    final clip = (copyValue ?? value).trim();
    final canCopy = copyable && clip.isNotEmpty && clip != '-';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.goldMuted.withValues(alpha: 0.9),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor ?? _histLightGold,
                fontWeight: valueWeight,
              ),
            ),
          ),
          if (canCopy) ...[
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Copy bet ID',
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              icon: Icon(
                Icons.copy_rounded,
                size: 20,
                color: AppColors.gold.withValues(alpha: 0.9),
              ),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: clip));
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Bet ID copied'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(10),
          child: CircularProgressIndicator(color: AppColors.gold),
        ),
      );
    }

    final marketByName = <String, Map<String, dynamic>>{};
    for (final m in _markets) {
      final n = m['marketName']?.toString();
      if (n != null) marketByName[normalizeMarketName(n)] = m;
    }

    final flat = <Map<String, dynamic>>[];
    for (final x in _entries) {
      final rows = x['rows'];
      if (rows is! List || rows.isEmpty) continue;
      for (final raw in rows) {
        final r = Map<String, dynamic>.from(raw as Map);
        final marketTitle = (x['marketTitle'] ?? '').toString().trim();
        final mk = normalizeMarketName(marketTitle);
        final m = marketByName[mk];
        final session = (r['type'] ?? x['session'] ?? '')
            .toString()
            .trim()
            .toUpperCase();
        if (_sessions.isNotEmpty && !_sessions.contains(session)) continue;
        final st = _statusFor(r, x, m, session);
        if (_statuses.isNotEmpty && !_statuses.contains(st)) continue;
        if (_marketKeys.isNotEmpty && !_marketKeys.contains(mk)) continue;
        flat.add({
          'x': x,
          'r': r,
          'm': m,
          'session': session,
          'marketTitle': marketTitle,
          'mk': mk,
          'st': st,
        });
      }
    }

    final wide = MediaQuery.sizeOf(context).width >= 768;
    final pageSize = wide ? 12 : 10;
    final totalPages = (flat.length / pageSize).ceil().clamp(1, 99999);
    final cur = _page.clamp(1, totalPages);
    final start = (cur - 1) * pageSize;
    final pageItems = flat.skip(start).take(pageSize).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => _openFilter(context),
            icon: Icon(
              Icons.filter_list,
              color: AppColors.goldMuted.withValues(alpha: 0.95),
            ),
            label: Text(
              'Filter By',
              style: TextStyle(
                color: AppColors.goldMuted.withValues(alpha: 0.95),
                fontWeight: FontWeight.w700,
              ),
            ),
            style: TextButton.styleFrom(foregroundColor: AppColors.goldMuted),
          ),
        ),
        Expanded(
          child: _userId == null
              ? Center(
                  child: Text(
                    'Please login to see your bet history.',
                    style: TextStyle(
                      color: AppColors.goldMuted.withValues(alpha: 0.92),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              : pageItems.isEmpty
              ? Center(
                  child: Text(
                    'No bets found.',
                    style: TextStyle(
                      color: AppColors.goldMuted.withValues(alpha: 0.92),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              : (wide
                  ? GridView.builder(
                  padding: const EdgeInsets.only(bottom: 88),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: pageItems.length,
                  itemBuilder: (context, i) {
                    final it = pageItems[i];
                    final x = it['x'] as Map<String, dynamic>;
                    final r = it['r'] as Map<String, dynamic>;
                    final session = it['session'] as String;
                    final marketTitle = it['marketTitle'] as String;
                    final labelKey = (x['labelKey'] ?? 'Bet').toString();
                    final numStr = r['number']?.toString() ?? '-';
                    final points = r['points'];
                    final state = _stateRaw(
                      r,
                      x,
                      it['m'] as Map<String, dynamic>?,
                      session,
                    );
                    final payout = _payoutFor(
                      r,
                      x,
                      it['m'] as Map<String, dynamic>?,
                      session,
                    );
                    final stateLabel = state == 'won'
                        ? 'Win'
                        : (state == 'lost' ? 'Lost' : 'Pending');
                    final pointsText = NumberFormat.decimalPattern(
                      'en_IN',
                    ).format(num.tryParse(points?.toString() ?? '0') ?? 0);
                    final payoutText = state == 'won'
                        ? NumberFormat.decimalPattern('en_IN').format(payout)
                        : '-';
                    final displayNumber = RegExp(r'^\d{2}$').hasMatch(numStr)
                        ? '${numStr[0]} ${numStr[1]}'
                        : numStr;
                    final createdAt = _fmtTime(x['createdAt']?.toString());
                    final betId =
                        r['id']?.toString() ??
                        x['id']?.toString() ??
                        '-';
                    final statusColor = state == 'won'
                        ? Colors.green.shade700
                        : (state == 'lost'
                              ? Colors.red.shade500
                              : AppColors.goldMuted.withValues(alpha: 0.95));

                    return Card(
                      color: Colors.transparent,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      surfaceTintColor: Colors.transparent,
                      shape: _historyCardShape(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(
                              color: Colors.transparent,
                            ),
                            child: Text(
                              '${marketTitle.toUpperCase()}${session.isNotEmpty ? ' ($session)' : ''}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: _histLightGold,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                _detailRow('Bet Type', labelKey),
                                _detailRow('Bet Number', displayNumber),
                                _detailRow('Points', '₹$pointsText'),
                                _detailRow('Session', session.isEmpty ? '-' : session),
                                _detailRow(
                                  'Status',
                                  stateLabel,
                                  valueColor: statusColor,
                                ),
                                _detailRow('Payout', payoutText == '-' ? '-' : '₹$payoutText'),
                                _detailRow('Placed At', createdAt),
                                _detailRow(
                                  'Bet ID',
                                  _displayBetId(betId),
                                  copyable: true,
                                  copyValue: betId,
                                ),
                              ],
                            ),
                          ),
                          Divider(
                            height: 1,
                            color: AppColors.gold.withValues(alpha: 0.3),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Text(
                              'Transaction: $createdAt',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.goldMuted.withValues(
                                  alpha: 0.85,
                                ),
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Divider(
                            height: 1,
                            color: AppColors.gold.withValues(alpha: 0.3),
                          ),
                          if (state == 'won')
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                'Congratulations, You Won ${payout > 0 ? '₹${NumberFormat.decimalPattern('en_IN').format(payout)}' : ''}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          else if (state == 'lost')
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                'Better Luck Next time',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.red.shade500,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                'Bet Placed',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: pageItems.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final it = pageItems[i];
                    final x = it['x'] as Map<String, dynamic>;
                    final r = it['r'] as Map<String, dynamic>;
                    final session = it['session'] as String;
                    final marketTitle = it['marketTitle'] as String;
                    final labelKey = (x['labelKey'] ?? 'Bet').toString();
                    final numStr = r['number']?.toString() ?? '-';
                    final points = r['points'];
                    final state = _stateRaw(
                      r,
                      x,
                      it['m'] as Map<String, dynamic>?,
                      session,
                    );
                    final payout = _payoutFor(
                      r,
                      x,
                      it['m'] as Map<String, dynamic>?,
                      session,
                    );
                    final stateLabel = state == 'won'
                        ? 'Win'
                        : (state == 'lost' ? 'Lost' : 'Pending');
                    final pointsText = NumberFormat.decimalPattern(
                      'en_IN',
                    ).format(num.tryParse(points?.toString() ?? '0') ?? 0);
                    final payoutText = state == 'won'
                        ? NumberFormat.decimalPattern('en_IN').format(payout)
                        : '-';
                    final displayNumber = RegExp(r'^\d{2}$').hasMatch(numStr)
                        ? '${numStr[0]} ${numStr[1]}'
                        : numStr;
                    final createdAt = _fmtTime(x['createdAt']?.toString());
                    final betId =
                        r['id']?.toString() ??
                        x['id']?.toString() ??
                        '-';
                    final statusColor = state == 'won'
                        ? Colors.green.shade700
                        : (state == 'lost'
                              ? Colors.red.shade500
                              : AppColors.goldMuted.withValues(alpha: 0.95));

                    return Card(
                      color: Colors.transparent,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      surfaceTintColor: Colors.transparent,
                      shape: _historyCardShape(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(
                              color: Colors.transparent,
                            ),
                            child: Text(
                              '${marketTitle.toUpperCase()}${session.isNotEmpty ? ' ($session)' : ''}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: _histLightGold,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                _detailRow('Bet Type', labelKey),
                                _detailRow('Bet Number', displayNumber),
                                _detailRow('Points', '₹$pointsText'),
                                _detailRow('Session', session.isEmpty ? '-' : session),
                                _detailRow(
                                  'Status',
                                  stateLabel,
                                  valueColor: statusColor,
                                ),
                                _detailRow('Payout', payoutText == '-' ? '-' : '₹$payoutText'),
                                _detailRow('Placed At', createdAt),
                                _detailRow(
                                  'Bet ID',
                                  _displayBetId(betId),
                                  copyable: true,
                                  copyValue: betId,
                                ),
                              ],
                            ),
                          ),
                          Divider(
                            height: 1,
                            color: AppColors.gold.withValues(alpha: 0.3),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Text(
                              'Transaction: $createdAt',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.goldMuted.withValues(
                                  alpha: 0.85,
                                ),
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Divider(
                            height: 1,
                            color: AppColors.gold.withValues(alpha: 0.3),
                          ),
                          if (state == 'won')
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                'Congratulations, You Won ${payout > 0 ? '₹${NumberFormat.decimalPattern('en_IN').format(payout)}' : ''}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          else if (state == 'lost')
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                'Better Luck Next time',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.red.shade500,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                'Bet Placed',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                )
              )
        ),
        if (flat.length > pageSize)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: cur <= 1
                      ? null
                      : () => setState(() => _page = cur - 1),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.goldMuted,
                    disabledForegroundColor: AppColors.gold.withValues(
                      alpha: 0.3,
                    ),
                  ),
                  child: const Text('PREV'),
                ),
                Text(
                  '$cur / $totalPages',
                  style: const TextStyle(
                    color: _histLightGold,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextButton(
                  onPressed: cur >= totalPages
                      ? null
                      : () => setState(() => _page = cur + 1),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.goldMuted,
                    disabledForegroundColor: AppColors.gold.withValues(
                      alpha: 0.3,
                    ),
                  ),
                  child: const Text('NEXT'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _openFilter(BuildContext context) async {
    final fromApi = _markets
        .map((m) => m['marketName']?.toString())
        .whereType<String>()
        .toList();
    final fromHist = _entries
        .map((x) => x['marketTitle']?.toString())
        .whereType<String>()
        .toList();
    final labels = {...fromApi, ...fromHist}.where((n) => _inScope(n)).toList()
      ..sort();
    final options = labels
        .map((label) => MapEntry(normalizeMarketName(label), label))
        .toList();

    var ds = List<String>.from(_sessions);
    var dst = List<String>.from(_statuses);
    var dm = List<String>.from(_marketKeys);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1810),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.65,
              maxChildSize: 0.9,
              builder: (_, scroll) {
                return Theme(
                  data: Theme.of(ctx).copyWith(
                    listTileTheme: ListTileThemeData(
                      iconColor: AppColors.goldMuted,
                      textColor: _histLightGold,
                    ),
                    checkboxTheme: CheckboxThemeData(
                      fillColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return AppColors.gold;
                        }
                        return Colors.transparent;
                      }),
                      checkColor: WidgetStateProperty.all(const Color(0xFF1A1810)),
                      side: WidgetStateBorderSide.resolveWith((states) {
                        return BorderSide(
                          color: AppColors.gold.withValues(alpha: 0.65),
                        );
                      }),
                    ),
                  ),
                  child: ListView(
                    controller: scroll,
                    padding: const EdgeInsets.all(10),
                    children: [
                      Text(
                        'Filter Type',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _histLightGold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'By session',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.goldMuted.withValues(alpha: 0.95),
                        ),
                      ),
                      CheckboxListTile(
                        title: Text(
                          'OPEN',
                          style: TextStyle(
                            color: _histLightGold.withValues(alpha: 0.92),
                          ),
                        ),
                        value: ds.contains('OPEN'),
                        onChanged: (v) => setModal(() {
                          if (v == true) {
                            ds = [...ds, 'OPEN'];
                          } else {
                            ds = ds.where((e) => e != 'OPEN').toList();
                          }
                        }),
                      ),
                      CheckboxListTile(
                        title: Text(
                          'CLOSE',
                          style: TextStyle(
                            color: _histLightGold.withValues(alpha: 0.92),
                          ),
                        ),
                        value: ds.contains('CLOSE'),
                        onChanged: (v) => setModal(() {
                          if (v == true) {
                            ds = [...ds, 'CLOSE'];
                          } else {
                            ds = ds.where((e) => e != 'CLOSE').toList();
                          }
                        }),
                      ),
                      Divider(color: AppColors.gold.withValues(alpha: 0.3)),
                      Text(
                        'By status',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.goldMuted.withValues(alpha: 0.95),
                        ),
                      ),
                      for (final s in ['Win', 'Loose', 'Pending'])
                        CheckboxListTile(
                          title: Text(
                            s,
                            style: TextStyle(
                              color: _histLightGold.withValues(alpha: 0.92),
                            ),
                          ),
                          value: dst.contains(s),
                          onChanged: (v) => setModal(() {
                            if (v == true) {
                              dst = [...dst, s];
                            } else {
                              dst = dst.where((e) => e != s).toList();
                            }
                          }),
                        ),
                      Divider(color: AppColors.gold.withValues(alpha: 0.3)),
                      Text(
                        'By market',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.goldMuted.withValues(alpha: 0.95),
                        ),
                      ),
                      for (final e in options)
                        CheckboxListTile(
                          title: Text(
                            e.value,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _histLightGold.withValues(alpha: 0.92),
                            ),
                          ),
                          value: dm.contains(e.key),
                          onChanged: (v) => setModal(() {
                            if (v == true) {
                              dm = [...dm, e.key];
                            } else {
                              dm = dm.where((k) => k != e.key).toList();
                            }
                          }),
                        ),
                      const SizedBox(height: 10),
                      FilledButton(
                        onPressed: () {
                          setState(() {
                            _sessions
                              ..clear()
                              ..addAll(ds);
                            _statuses
                              ..clear()
                              ..addAll(dst);
                            _marketKeys
                              ..clear()
                              ..addAll(dm);
                            _page = 1;
                          });
                          Navigator.pop(ctx);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: const Color(0xFF1A1408),
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.buttonPaddingV,
                            horizontal: AppSpacing.buttonPaddingH,
                          ),
                          minimumSize: const Size(0, AppSpacing.buttonMinHeight),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('Apply'),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class BetHistoryScreen extends StatelessWidget {
  const BetHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 720;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
          child: Row(
            children: [
              IconButton(
                onPressed: () => popOrGoHome(context),
                icon: const Icon(Icons.arrow_back),
                color: AppColors.goldMuted,
              ),
              Expanded(
                child: Text(
                  'Bet History',
                  style: TextStyle(
                    fontSize: wide ? 22 : 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.gold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: BetHistoryView(),
          ),
        ),
      ],
    );
  }
}

class GameBetHistoryScreen extends StatelessWidget {
  const GameBetHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 720;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
          child: Row(
            children: [
              IconButton(
                onPressed: () => popOrGoHome(context),
                icon: const Icon(Icons.arrow_back),
                color: AppColors.goldMuted,
              ),
              Expanded(
                child: Text(
                  'Game Bet History',
                  style: TextStyle(
                    fontSize: wide ? 22 : 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.gold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: GameBetHistoryView(),
          ),
        ),
      ],
    );
  }
}

class GameBetHistoryView extends StatefulWidget {
  const GameBetHistoryView({super.key});

  @override
  State<GameBetHistoryView> createState() => _GameBetHistoryViewState();
}

class _GameBetHistoryViewState extends State<GameBetHistoryView> {
  bool _loading = true;
  String? _userId;
  String _error = '';
  List<Map<String, dynamic>> _transactions = const [];
  String _typeFilter = 'all';
  String _gameFilter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    final u = await AuthService.instance.getStoredUser();
    final uid = u?['_id']?.toString() ?? u?['id']?.toString();
    if (uid == null || uid.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _userId = null;
        _transactions = const [];
      });
      return;
    }

    final res = await WalletService.instance.fetchMyTransactions(
      limit: 500,
      includeBet: true,
    );
    if (!mounted) return;

    if (!res.success) {
      setState(() {
        _loading = false;
        _userId = uid;
        _transactions = const [];
        _error = res.message ?? 'Failed to load game transactions';
      });
      return;
    }

    final gameScoped = res.data.where(_isGameTransactionBase).toList();
    final scopedRefs = <String>{
      for (final tx in gameScoped)
        if ((tx['referenceId']?.toString().trim() ?? '').isNotEmpty)
          tx['referenceId'].toString().trim(),
    };
    final filtered = res.data.where((tx) {
      if (_isGameTransactionBase(tx)) return true;
      final ref = tx['referenceId']?.toString().trim() ?? '';
      return ref.isNotEmpty && scopedRefs.contains(ref);
    }).toList();
    setState(() {
      _loading = false;
      _userId = uid;
      _transactions = filtered;
      if (_gameFilter != 'all' &&
          !_availableGameCodes(filtered).contains(_gameFilter)) {
        _gameFilter = 'all';
      }
    });
  }

  bool _isGameTransactionBase(Map<String, dynamic> tx) {
    final gameCode = _extractGameCode(tx);
    if (gameCode.isNotEmpty) return true;

    final source = (tx['source'] ??
            tx['module'] ??
            tx['category'] ??
            tx['context'] ??
            tx['transactionFor'] ??
            tx['referenceType'] ??
            tx['entryType'])
        .toString()
        .toLowerCase()
        .trim();
    if (source.contains('game')) return true;

    final desc = (tx['description'] ?? '').toString().toLowerCase();
    if (desc.contains('game') || desc.contains('casino') || desc.contains('slot')) {
      return true;
    }
    final hasGameIds = (tx['gameId'] ?? tx['roundId'] ?? tx['providerRoundId']) != null;
    if (hasGameIds) return true;
    final bet = tx['bet'];
    if (bet is Map) {
      final keys = bet.keys.map((k) => k.toString().toLowerCase()).join('|');
      if (keys.contains('game')) return true;
    }
    return false;
  }

  String _extractGameCode(Map<String, dynamic> tx) {
    String read(dynamic v) => v?.toString().trim() ?? '';
    final bet = tx['bet'] is Map<String, dynamic>
        ? tx['bet'] as Map<String, dynamic>
        : (tx['bet'] is Map ? Map<String, dynamic>.from(tx['bet'] as Map) : null);
    final game = tx['game'] is Map<String, dynamic>
        ? tx['game'] as Map<String, dynamic>
        : (tx['game'] is Map ? Map<String, dynamic>.from(tx['game'] as Map) : null);

    final candidates = <String>[
      read(tx['gameCode']),
      read(tx['providerGameCode']),
      read(tx['externalGameCode']),
      read(game?['gameCode']),
      read(game?['providerGameCode']),
      read(game?['code']),
      read(bet?['gameCode']),
      read(bet?['providerGameCode']),
      read(bet?['code']),
    ].where((e) => e.isNotEmpty).toList();

    if (candidates.isNotEmpty) return candidates.first.toUpperCase();

    final desc = (tx['description'] ?? '').toString();
    final match = RegExp(
      r'(?:game\s*code|gameCode|providerGameCode)\s*[:=-]\s*([A-Za-z0-9_-]+)',
      caseSensitive: false,
    ).firstMatch(desc);
    if (match != null) {
      return (match.group(1) ?? '').toUpperCase();
    }

    final blob = [
      tx['description'],
      tx['source'],
      tx['module'],
      tx['category'],
      tx['context'],
      tx['transactionFor'],
      tx['referenceType'],
      tx['entryType'],
    ].map((v) => v?.toString().toLowerCase() ?? '').join(' ');
    if (blob.contains('aviator')) return 'AVIATOR';
    if (blob.contains('funtimer') || blob.contains('fun timer')) return 'FUNTIMER';
    if (blob.contains('roulette') || blob.contains('roullete')) return 'ROULETTE';
    return '';
  }

  String _normalizedGameKey(String code) {
    final c = code.trim().toUpperCase();
    if (c.isEmpty) return '';
    if (c.contains('AVIATOR')) return 'AVIATOR';
    if (c.contains('FUNTIMER') || c.contains('FUN TIMER')) return 'FUNTIMER';
    if (c.contains('ROULETTE') || c.contains('ROULLETE')) return 'ROULETTE';
    return c;
  }

  bool _matchesGameFilter(String code, String selected) {
    if (selected == 'all') return true;
    final c = code.trim().toUpperCase();
    final s = selected.trim().toUpperCase();
    if (c.isEmpty) return false;
    if (c == s) return true;

    final ck = _normalizedGameKey(c);
    final sk = _normalizedGameKey(s);
    if (ck.isNotEmpty && ck == sk) return true;

    return c.contains(s) || s.contains(c);
  }

  String _txTypeLabel(Map<String, dynamic> tx) {
    final t = (tx['type'] ?? '').toString().toLowerCase().trim();
    if (t == 'credit') return 'Credit';
    if (t == 'debit') return 'Debit';
    return t.isEmpty ? '-' : t[0].toUpperCase() + t.substring(1);
  }

  String _txTypeRaw(Map<String, dynamic> tx) =>
      (tx['type'] ?? '').toString().toLowerCase().trim();

  String _amountText(Map<String, dynamic> tx) {
    final amount =
        num.tryParse(tx['amount']?.toString() ?? '') ?? (tx['amount'] as num?) ?? 0;
    final type = (tx['type'] ?? '').toString().toLowerCase();
    final isCredit = type == 'credit';
    final sign = isCredit ? '+' : '-';
    return '$sign₹${NumberFormat('#,##0.00', 'en_IN').format(amount)}';
  }

  Color _amountColor(Map<String, dynamic> tx) {
    final isCredit = (tx['type'] ?? '').toString().toLowerCase() == 'credit';
    return isCredit ? Colors.green.shade700 : Colors.red.shade500;
  }

  String _txDateTime(Map<String, dynamic> tx) => formatTxTime(tx['createdAt']?.toString());

  String _txRef(Map<String, dynamic> tx) {
    final id = tx['referenceId']?.toString().trim();
    if (id != null && id.isNotEmpty) return id;
    final txId = tx['_id']?.toString().trim() ?? tx['id']?.toString().trim() ?? '';
    return txId.isEmpty ? '-' : txId;
  }

  String _gameNameForDescription(Map<String, dynamic> tx, String gameCode) {
    String read(dynamic v) => v?.toString().trim() ?? '';
    final bet = tx['bet'] is Map<String, dynamic>
        ? tx['bet'] as Map<String, dynamic>
        : (tx['bet'] is Map ? Map<String, dynamic>.from(tx['bet'] as Map) : null);
    final game = tx['game'] is Map<String, dynamic>
        ? tx['game'] as Map<String, dynamic>
        : (tx['game'] is Map ? Map<String, dynamic>.from(tx['game'] as Map) : null);

    final candidates = <String>[
      read(tx['gameName']),
      read(tx['providerGameName']),
      read(tx['externalGameName']),
      read(game?['name']),
      read(game?['gameName']),
      read(game?['title']),
      read(bet?['gameName']),
      read(bet?['name']),
      read(bet?['title']),
    ];
    for (final name in candidates) {
      if (name.isNotEmpty) return name;
    }

    final desc = (tx['description'] ?? '').toString();
    final match = RegExp(
      r'game\s*[:=-]\s*([A-Za-z0-9 _-]+)',
      caseSensitive: false,
    ).firstMatch(desc);
    final fromDesc = match?.group(1)?.trim() ?? '';
    if (fromDesc.isNotEmpty) return fromDesc;

    final blob = [
      tx['description'],
      tx['source'],
      tx['module'],
      tx['category'],
      tx['context'],
      tx['transactionFor'],
      tx['referenceType'],
      tx['entryType'],
    ].map((v) => v?.toString().toLowerCase() ?? '').join(' ');
    if (blob.contains('aviator')) return 'Aviator';
    if (blob.contains('funtimer') || blob.contains('fun timer')) return 'Funtimer';
    if (blob.contains('roulette') || blob.contains('roullete')) return 'Roulette';

    if (gameCode.isNotEmpty) return gameCode;
    return '-';
  }

  String _roundKey(Map<String, dynamic> tx) {
    String read(dynamic v) => v?.toString().trim() ?? '';
    final bet = tx['bet'] is Map<String, dynamic>
        ? tx['bet'] as Map<String, dynamic>
        : (tx['bet'] is Map ? Map<String, dynamic>.from(tx['bet'] as Map) : null);
    final candidates = <String>[
      read(tx['roundId']),
      read(tx['providerRoundId']),
      read(tx['gameRoundId']),
      read(bet?['roundId']),
      read(bet?['providerRoundId']),
      read(tx['referenceId']),
      read(tx['_id']),
      read(tx['id']),
    ];
    for (final v in candidates) {
      if (v.isNotEmpty) return v;
    }
    return '-';
  }

  num _txAmount(Map<String, dynamic> tx) =>
      num.tryParse(tx['amount']?.toString() ?? '') ?? (tx['amount'] as num?) ?? 0;

  String _currency(num value) =>
      '₹${NumberFormat('#,##0.00', 'en_IN').format(value)}';

  ({num credited, num debited}) _roundTotals(List<Map<String, dynamic>> txs) {
    var credited = 0.0;
    var debited = 0.0;
    for (final tx in txs) {
      final amount = _txAmount(tx).toDouble();
      final type = _txTypeRaw(tx);
      if (type == 'credit') credited += amount;
      if (type == 'debit') debited += amount;
    }
    return (credited: credited, debited: debited);
  }

  String _roundOutcome(String gameCode, num credited, num debited) {
    final g = gameCode.toUpperCase();
    final isAviator = g.contains('AVIATOR');
    final isFunTimer = g.contains('FUNTIMER');
    final isRoulette = g.contains('ROULETTE') || g.contains('ROULLETE');

    if (isAviator) {
      if (credited > debited) return 'Won';
      if (debited > credited) return 'Lost';
      return 'Pending';
    }
    if (isFunTimer || isRoulette) {
      if (credited > 0) return 'Won';
      if (debited > 0) return 'Lost';
      return 'Pending';
    }
    if (credited > debited) return 'Won';
    if (debited > credited) return 'Lost';
    return 'Pending';
  }

  Color _outcomeColor(String outcome) {
    if (outcome == 'Won') return Colors.green.shade700;
    if (outcome == 'Lost') return Colors.red.shade500;
    return AppColors.goldMuted.withValues(alpha: 0.95);
  }

  Widget _cell(String label, String value, {Color? valueColor, bool copyable = false}) {
    final canCopy =
        copyable && value.trim().isNotEmpty && value.trim() != '-';
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.goldMuted.withValues(alpha: 0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  value,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: valueColor ?? _histLightGold,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (canCopy)
                IconButton(
                  tooltip: 'Copy Round ID',
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: Icon(
                    Icons.copy_rounded,
                    size: 18,
                    color: AppColors.gold.withValues(alpha: 0.9),
                  ),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: value.trim()));
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Round ID copied'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  List<String> _availableGameCodes([List<Map<String, dynamic>>? from]) {
    final source = from ?? _transactions;
    final out = <String>{};
    for (final tx in source) {
      final code = _extractGameCode(tx);
      if (code.isNotEmpty) out.add(code);
    }
    final list = out.toList()..sort();
    return list;
  }

  List<Map<String, dynamic>> get _visibleTransactions {
    return _transactions.where((tx) {
      final rawType = _txTypeRaw(tx);
      if (_typeFilter != 'all' && rawType != _typeFilter) return false;
      if (_gameFilter != 'all' &&
          !_matchesGameFilter(_extractGameCode(tx), _gameFilter)) {
        return false;
      }
      return true;
    }).toList();
  }

  List<Map<String, dynamic>> get _visibleRoundGroups {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final tx in _transactions) {
      final key = _roundKey(tx);
      grouped.putIfAbsent(key, () => <Map<String, dynamic>>[]).add(tx);
    }

    final out = grouped.entries.map((entry) {
      final txs = entry.value;
      final totals = _roundTotals(txs);
      txs.sort((a, b) {
        final ad = DateTime.tryParse(a['createdAt']?.toString() ?? '');
        final bd = DateTime.tryParse(b['createdAt']?.toString() ?? '');
        if (ad == null && bd == null) return 0;
        if (ad == null) return 1;
        if (bd == null) return -1;
        return bd.compareTo(ad);
      });
      final latest = txs.first;
      final gameCode = txs
          .map(_extractGameCode)
          .firstWhere((code) => code.isNotEmpty, orElse: () => '');
      final outcome = _roundOutcome(gameCode, totals.credited, totals.debited);
      final gameMatched = _matchesGameFilter(gameCode, _gameFilter);
      final typeMatched = _typeFilter == 'all'
          ? true
          : txs.any((tx) => _txTypeRaw(tx) == _typeFilter);
      return <String, dynamic>{
        'roundKey': entry.key,
        'transactions': txs,
        'latest': latest,
        'gameCode': gameCode,
        'credited': totals.credited,
        'debited': totals.debited,
        'outcome': outcome,
        'gameMatched': gameMatched,
        'typeMatched': typeMatched,
      };
    }).where((round) {
      return round['typeMatched'] == true && round['gameMatched'] == true;
    }).toList();

    out.sort((a, b) {
      final ad = DateTime.tryParse(a['latest']?['createdAt']?.toString() ?? '');
      final bd = DateTime.tryParse(b['latest']?['createdAt']?.toString() ?? '');
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return bd.compareTo(ad);
    });
    return out;
  }

  Widget _filters() {
    final gameCodes = _availableGameCodes();
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
        color: Colors.white.withValues(alpha: 0.02),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _typeFilter,
                  decoration: const InputDecoration(
                    labelText: 'Filter by Type',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All')),
                    DropdownMenuItem(value: 'credit', child: Text('Credit')),
                    DropdownMenuItem(value: 'debit', child: Text('Debit')),
                  ],
                  onChanged: (value) => setState(() => _typeFilter = value ?? 'all'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _gameFilter,
                  decoration: const InputDecoration(
                    labelText: 'Filter by Game',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: 'all', child: Text('All Games')),
                    ...gameCodes.map(
                      (code) => DropdownMenuItem(value: code, child: Text(code)),
                    ),
                  ],
                  onChanged: (value) => setState(() => _gameFilter = value ?? 'all'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(10),
          child: CircularProgressIndicator(color: AppColors.gold),
        ),
      );
    }

    if (_userId == null) {
      return Center(
        child: Text(
          'Please login to see your game transactions.',
          style: TextStyle(
            color: AppColors.goldMuted.withValues(alpha: 0.92),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    if (_error.isNotEmpty && _transactions.isEmpty) {
      return Center(
        child: Text(
          _error,
          style: TextStyle(
            color: Colors.red.shade300,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    if (_transactions.isEmpty) {
      return Center(
        child: Text(
          'No game transactions found.',
          style: TextStyle(
            color: AppColors.goldMuted.withValues(alpha: 0.92),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final roundGroups = _visibleRoundGroups;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 88),
        children: [
          _filters(),
          const SizedBox(height: 8),
          if (roundGroups.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Center(
                child: Text(
                  'No transactions found for selected filters.',
                  style: TextStyle(
                    color: AppColors.goldMuted.withValues(alpha: 0.92),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          else
            ...roundGroups.map((round) {
          final latest = Map<String, dynamic>.from(round['latest'] as Map);
          final gameCode = (round['gameCode'] ?? '').toString();
          final roundKey = (round['roundKey'] ?? '-').toString();
          final credited = round['credited'] as num? ?? 0;
          final debited = round['debited'] as num? ?? 0;
          final outcome = (round['outcome'] ?? 'Pending').toString();
          final count = (round['transactions'] as List).length;
          final dateTime = _txDateTime(latest);
          final gameName = _gameNameForDescription(latest, gameCode);

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  color: Colors.transparent,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  shape: _historyCardShape(),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Game Round',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.gold.withValues(alpha: 0.98),
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                            Text(
                              outcome,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: _outcomeColor(outcome),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _cell('Game Code', gameCode.isEmpty ? '-' : gameCode),
                            const SizedBox(width: 12),
                            _cell('Round ID', roundKey, copyable: true),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _cell('Debited', _currency(debited), valueColor: Colors.red.shade500),
                            const SizedBox(width: 12),
                            _cell('Credited', _currency(credited), valueColor: Colors.green.shade700),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _cell('Transactions', '$count'),
                            const SizedBox(width: 12),
                            _cell('Last Update', dateTime),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _cell(
                              'Outcome',
                              outcome,
                              valueColor: _outcomeColor(outcome),
                            ),
                            const SizedBox(width: 12),
                            _cell('Description', 'Game: $gameName'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
