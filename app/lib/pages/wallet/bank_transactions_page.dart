import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/wallet_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/casino_ui.dart';
import '../../utils/nav_pop_or_home.dart';
import '../../utils/wallet_tx_parsing.dart';

/// Same data as React [Bank.jsx] — detailed bet-style rows + running balance (bottom nav "Bank").
class BankTransactionsPage extends StatefulWidget {
  const BankTransactionsPage({super.key});

  @override
  State<BankTransactionsPage> createState() => _BankTransactionsPageState();
}

class _ComputedTx {
  _ComputedTx({
    required this.id,
    required this.typeLabel,
    required this.amount,
    required this.time,
    required this.description,
    required this.bet,
    required this.previousBalance,
    required this.transactionAmount,
    required this.currentBalance,
  });

  final String id;
  final String typeLabel;
  final num amount;
  final String time;
  final String description;
  final Map<String, dynamic>? bet;
  final num? previousBalance;
  final num transactionAmount;
  final num? currentBalance;
}

class _BankTransactionsPageState extends State<BankTransactionsPage> {
  bool _loading = true;
  bool _loggedIn = false;
  String _error = '';
  num _balance = 0;
  bool _balanceOk = false;
  List<Map<String, dynamic>> _txs = [];
  int _page = 1;

  static const _pageSize = 10;

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
    final uid = u?['id'] ?? u?['_id'];
    if (uid == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loggedIn = false;
          _error = '';
        });
      }
      return;
    }
    if (mounted) setState(() => _loggedIn = true);

    final b = await WalletService.instance.fetchBalance();
    final t = await WalletService.instance.fetchMyTransactions(limit: 500);
    if (!mounted) return;

    if (!b.success && b.message != null) {
      setState(() {
        _loading = false;
        _error = t.message ?? b.message ?? '';
        _balanceOk = false;
      });
      return;
    }

    setState(() {
      _loading = false;
      if (b.success && b.balance != null) {
        _balance = b.balance!;
        _balanceOk = true;
      } else {
        _balanceOk = false;
      }
      if (t.success) {
        _txs = t.data;
        if (t.message != null && t.message!.isNotEmpty && _error.isEmpty) {
          _error = '';
        }
      } else {
        _error = t.message ?? 'Failed to load';
      }
    });
  }

  List<_ComputedTx> _computed() {
    var running = _balance;
    final out = <_ComputedTx>[];
    for (final tx in _txs) {
      final amt =
          num.tryParse(tx['amount']?.toString() ?? '') ??
          (tx['amount'] as num?) ??
          0;
      final type = (tx['type'] ?? '').toString().toLowerCase();
      final currentBalance = _balanceOk ? running : null;
      final previousBalance = _balanceOk
          ? (type == 'debit'
                ? (currentBalance ?? 0) + amt
                : (currentBalance ?? 0) - amt)
          : null;
      final transactionAmount = type == 'debit' ? -amt : amt;
      if (_balanceOk) {
        running = previousBalance ?? running;
      }
      final id =
          tx['_id']?.toString() ??
          tx['id']?.toString() ??
          '${tx['createdAt']}-$type-$amt-${tx['referenceId']}';
      out.add(
        _ComputedTx(
          id: id,
          typeLabel: type == 'credit' ? 'Credit' : 'Debit',
          amount: amt,
          time: formatTxTime(tx['createdAt']?.toString()),
          description: (tx['description'] ?? '').toString(),
          bet: tx['bet'] is Map
              ? Map<String, dynamic>.from(tx['bet'] as Map)
              : null,
          previousBalance: previousBalance,
          transactionAmount: transactionAmount,
          currentBalance: currentBalance,
        ),
      );
    }
    return out;
  }

  String _fmt(num v) {
    if (!v.isFinite) return '0.00';
    return v.toStringAsFixed(2);
  }

  String _inr(num v) => '₹${_fmt(v)}';

  @override
  Widget build(BuildContext context) {
    final titleWide = MediaQuery.sizeOf(context).width >= 720;
    final computed = _computed();
    final totalPages = (computed.length / _pageSize).ceil().clamp(1, 999999);
    final currentPage = _page.clamp(1, totalPages);
    final start = (currentPage - 1) * _pageSize;
    final visible = computed.skip(start).take(_pageSize).toList();

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.surfaceElevated, AppColors.cardSurfaceBottom],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => popOrGoHome(context),
                  icon: const Icon(Icons.arrow_back),
                  color: CasinoUi.mutedGold(0.95),
                ),
                Expanded(
                  child: Text(
                    'Transaction History',
                    style: TextStyle(
                      fontSize: titleWide ? 22 : 20,
                      fontWeight: FontWeight.bold,
                      color: CasinoUi.lightGold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: CasinoUi.lightGold),
                  )
                : !_loggedIn
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        'Please login to see your transaction history.',
                        style: TextStyle(
                          fontSize: 13,
                          color: CasinoUi.mutedGold(0.78),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : _error.isNotEmpty && computed.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        _error,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.red.shade300,
                        ),
                      ),
                    ),
                  )
                : visible.isEmpty
                ? Center(
                    child: Text(
                      'No transactions found.',
                      style: TextStyle(
                        fontSize: 13,
                        color: CasinoUi.mutedGold(0.78),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 72),
                    itemCount: visible.length,
                    itemBuilder: (context, i) {
                      final tx = visible[i];
                      final betTypeRaw = tx.bet?['betType']?.toString() ?? '';
                      final betNumber =
                          tx.bet?['betNumber']?.toString().trim() ?? '';
                      final marketName =
                          tx.bet?['marketName']?.toString().trim() ?? '';
                      final betOnRaw = tx.bet?['betOn']?.toString();
                      final parsed = parseTxDescription(tx.description);
                      final bidPlay = betNumber.isNotEmpty
                          ? betNumber
                          : parsed.bidPlay;
                      final game = marketName.isNotEmpty
                          ? marketName
                          : parsed.game;
                      final typeLabel = humanBetType(betTypeRaw).isNotEmpty
                          ? humanBetType(betTypeRaw)
                          : parsed.type;
                      var marketLabel = formatBetSessionFromBetOn(betOnRaw);
                      if (marketLabel.isEmpty) {
                        final inf = inferSession(betTypeRaw);
                        if (inf.isNotEmpty) {
                          marketLabel = inf == 'open' ? 'OPEN' : 'CLOSE';
                        } else {
                          final pm = parsed.market;
                          final pl = pm.toLowerCase();
                          if (pl == 'open') {
                            marketLabel = 'OPEN';
                          } else if (pl == 'close') {
                            marketLabel = 'CLOSE';
                          } else {
                            marketLabel = pm;
                          }
                        }
                      }
                      final topColor = tx.typeLabel == 'Credit'
                          ? Colors.green.shade700
                          : Colors.red.shade700;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: CasinoUi.backdropBlur(
                          borderRadius: BorderRadius.circular(16),
                          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                          fill: AppColors.surfaceCard.withValues(alpha: 0.7),
                          border: Border.all(
                            color: CasinoUi.neutralShellBorderColor(alpha: 0.16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${tx.typeLabel} ${_inr(tx.amount)}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: topColor,
                                    ),
                                  ),
                                  Text(
                                    tx.time,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: CasinoUi.mutedGold(0.72),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              _grid2(
                                'Bid Play',
                                bidPlay,
                                'Game',
                                game.toUpperCase(),
                              ),
                              const SizedBox(height: 8),
                              _grid2('Type', typeLabel, 'Market', marketLabel),
                              Divider(
                                height: 18,
                                thickness: 1,
                                color: CasinoUi.neutralShellBorderColor(alpha: 0.14),
                              ),
                              _grid2(
                                'Previous Balance',
                                tx.previousBalance == null
                                    ? '—'
                                    : _inr(tx.previousBalance!),
                                'Transaction Amount',
                                '${tx.transactionAmount >= 0 ? '+' : '-'} ${_inr(tx.transactionAmount.abs())}',
                                rightColor: tx.transactionAmount >= 0
                                    ? Colors.green.shade700
                                    : Colors.red.shade700,
                              ),
                              if (tx.currentBalance != null) ...[
                                Divider(
                                  height: 14,
                                  thickness: 1,
                                  color: CasinoUi.neutralShellBorderColor(alpha: 0.14),
                                ),
                                Text(
                                  'Current Balance : ${_fmt(tx.currentBalance!)} ₹',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 22,
                                    color: CasinoUi.lightGold,
                                  ),
                                ),
                              ],
                              if (parsed.raw != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  parsed.raw!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: CasinoUi.mutedGold(0.72),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (computed.length > _pageSize)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: CasinoUi.neutralShellBorderColor(alpha: 0.16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: currentPage <= 1
                              ? null
                              : () => setState(() => _page = currentPage - 1),
                          style: TextButton.styleFrom(
                            foregroundColor: CasinoUi.mutedGold(0.95),
                            disabledForegroundColor: CasinoUi.mutedGold(0.35),
                          ),
                          child: const Text(
                            'PREV',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        CircleAvatar(
                          backgroundColor: Colors.white.withValues(alpha: 0.12),
                          child: Text(
                            '$currentPage',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: CasinoUi.lightGold,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: currentPage >= totalPages
                              ? null
                              : () => setState(() => _page = currentPage + 1),
                          style: TextButton.styleFrom(
                            foregroundColor: CasinoUi.mutedGold(0.95),
                            disabledForegroundColor: CasinoUi.mutedGold(0.35),
                          ),
                          child: const Text(
                            'NEXT',
                            style: TextStyle(
                              fontSize: 12,
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
        ],
      ),
    );
  }

  Widget _grid2(
    String l1,
    String v1,
    String l2,
    String v2, {
    Color? rightColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: [
              Text(
                l1,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: CasinoUi.mutedGold(0.72),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                v1,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: CasinoUi.lightGold,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                l2,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: CasinoUi.mutedGold(0.72),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                v2,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: rightColor ?? CasinoUi.lightGold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
