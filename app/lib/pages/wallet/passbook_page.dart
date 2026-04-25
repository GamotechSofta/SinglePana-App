import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/auth_service.dart';
import '../../services/wallet_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/casino_ui.dart';
import '../../utils/nav_pop_or_home.dart';

/// Same APIs as React [Passbook.jsx] — balance summary + grouped transaction list.
class PassbookPage extends StatefulWidget {
  const PassbookPage({super.key});

  @override
  State<PassbookPage> createState() => _PassbookPageState();
}

class _PassbookPageState extends State<PassbookPage> {
  bool _loading = true;
  bool _refreshing = false;
  String _filter = 'all';
  List<Map<String, dynamic>> _transactions = [];
  num? _balance;

  @override
  void initState() {
    super.initState();
    _fetch(initial: true);
  }

  Future<void> _fetch({bool initial = false}) async {
    final u = await AuthService.instance.getStoredUser();
    if ((u?['id'] ?? u?['_id']) == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (initial) {
      setState(() => _loading = true);
    } else {
      setState(() => _refreshing = true);
    }
    final tx = await WalletService.instance.fetchMyTransactions(
      limit: 500,
      includeBet: false,
    );
    final bal = await WalletService.instance.fetchBalance();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _refreshing = false;
      if (tx.success) _transactions = tx.data;
      if (bal.success) _balance = bal.balance;
    });
  }

  List<Map<String, dynamic>> get _filtered {
    if (_filter == 'all') return _transactions;
    return _transactions
        .where((t) => (t['type'] ?? '').toString().toLowerCase() == _filter)
        .toList();
  }

  ({num totalCredit, num totalDebit, int creditCount, int debitCount})
  get _stats {
    num c = 0, d = 0;
    int cc = 0, dc = 0;
    for (final t in _transactions) {
      final amt =
          num.tryParse(t['amount']?.toString() ?? '') ??
          (t['amount'] as num?) ??
          0;
      final type = (t['type'] ?? '').toString().toLowerCase();
      if (type == 'credit') {
        c += amt;
        cc++;
      } else {
        d += amt;
        dc++;
      }
    }
    return (totalCredit: c, totalDebit: d, creditCount: cc, debitCount: dc);
  }

  String _fmt(num v) => NumberFormat('#,##0.00', 'en_IN').format(v);

  String _dateHeader(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return DateFormat('dd MMM yyyy').format(d);
  }

  String _timeOnly(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    return DateFormat.jm().format(d);
  }

  @override
  Widget build(BuildContext context) {
    final s = _stats;
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final t in _filtered) {
      final key = _dateHeader(t['createdAt']?.toString() ?? '');
      grouped.putIfAbsent(key, () => []).add(t);
    }
    final keys = grouped.keys.toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              IconButton(
                onPressed: () => popOrGoHome(context),
                icon: const Icon(Icons.arrow_back),
                color: CasinoUi.mutedGold(0.95),
              ),
              const Expanded(
                child: Text(
                  'Passbook',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: CasinoUi.lightGold,
                  ),
                ),
              ),
              IconButton(
                onPressed: _refreshing ? null : () => _fetch(),
                color: CasinoUi.mutedGold(0.9),
                icon: _refreshing
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.gold,
                        ),
                      )
                    : const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.gold),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  children: [
                    _balanceCard(s),
                    const SizedBox(height: 10),
                    _filterRow(s),
                    const SizedBox(height: 10),
                    Text(
                      'TRANSACTION HISTORY',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                        color: CasinoUi.mutedGold(0.88),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Center(
                          child: Text(
                            _transactions.isEmpty
                                ? 'Your transaction history will appear here'
                                : 'No ${_filter == 'credit' ? 'credit' : 'withdrawal'} transactions yet',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: CasinoUi.mutedGold(0.85)),
                          ),
                        ),
                      )
                    else
                      ...keys.expand((k) {
                        final txs = grouped[k]!;
                        return [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 4,
                            ),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: CasinoUi.neutralShellBorderColor(alpha: 0.14),
                                ),
                              ),
                            ),
                            child: Text(
                              k.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                                color: CasinoUi.mutedGold(0.7),
                              ),
                            ),
                          ),
                          ...txs.map((tx) {
                            final isCredit =
                                (tx['type'] ?? '').toString().toLowerCase() ==
                                'credit';
                            final amt =
                                num.tryParse(tx['amount']?.toString() ?? '') ??
                                (tx['amount'] as num?) ??
                                0;
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 4,
                              ),
                              leading: CircleAvatar(
                                backgroundColor: isCredit
                                    ? Colors.green.shade50
                                    : Colors.red.shade50,
                                child: Icon(
                                  isCredit
                                      ? Icons.north_east
                                      : Icons.south_west,
                                  color: isCredit
                                      ? Colors.green.shade700
                                      : Colors.red.shade700,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                tx['description']?.toString() ??
                                    (isCredit
                                        ? 'Amount Credited'
                                        : 'Amount Withdrawn'),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: CasinoUi.lightGold,
                                ),
                              ),
                              subtitle: Text(
                                _timeOnly(tx['createdAt']?.toString() ?? ''),
                                style: TextStyle(
                                  color: CasinoUi.mutedGold(0.55),
                                ),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${isCredit ? '+' : '-'}₹${_fmt(amt)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isCredit
                                          ? Colors.green.shade700
                                          : Colors.red.shade700,
                                    ),
                                  ),
                                  Text(
                                    isCredit ? 'CREDIT' : 'DEBIT',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isCredit
                                          ? Colors.green.shade600
                                          : Colors.red.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ];
                      }),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _balanceCard(
    ({num totalCredit, num totalDebit, int creditCount, int debitCount}) s,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: CasinoUi.neutralShellBorderColor(alpha: 0.16),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CURRENT BALANCE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: CasinoUi.mutedGold(0.75),
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _balance == null ? '---' : '₹${_fmt(_balance!)}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: CasinoUi.lightGold,
                    ),
                  ),
                ],
              ),
              Icon(
                Icons.account_balance_wallet_outlined,
                size: 40,
                color: CasinoUi.mutedGold(0.55),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CREDITED',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.green.shade700,
                        ),
                      ),
                      Text(
                        '₹${_fmt(s.totalCredit)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'WITHDRAWN',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.red.shade700,
                        ),
                      ),
                      Text(
                        '₹${_fmt(s.totalDebit)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterRow(
    ({num totalCredit, num totalDebit, int creditCount, int debitCount}) s,
  ) {
    Widget chip(String key, String label, int count) {
      final on = _filter == key;
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: () => setState(() => _filter = key),
              borderRadius: BorderRadius.circular(16),
              splashColor: Colors.white.withValues(alpha: 0.08),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: on
                        ? CasinoUi.neutralShellBorderColor(alpha: 0.42)
                        : CasinoUi.neutralShellBorderColor(alpha: 0.14),
                    width: on ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: on
                            ? CasinoUi.lightGold
                            : CasinoUi.mutedGold(0.75),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: on
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: CasinoUi.neutralShellBorderColor(
                            alpha: on ? 0.28 : 0.12,
                          ),
                        ),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 12,
                          color: on
                              ? CasinoUi.lightGold
                              : CasinoUi.mutedGold(0.65),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        chip('all', 'All', _transactions.length),
        chip('credit', 'Credited', s.creditCount),
        chip('debit', 'Withdrawn', s.debitCount),
      ],
    );
  }
}
