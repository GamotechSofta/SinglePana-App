import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/casino_ui.dart';
import '../../utils/nav_pop_or_home.dart';
import 'funds_tabs.dart';

/// Shell matching React [Funds.jsx] — menu + detail; `arguments: {'tab': 'bank-detail'}` from drawer.
class FundsPage extends StatefulWidget {
  const FundsPage({super.key});

  @override
  State<FundsPage> createState() => _FundsPageState();
}

class _MenuItem {
  const _MenuItem({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final String key;
  final String title;
  final String subtitle;
  final Color color;
}

class _FundsPageState extends State<FundsPage> {
  static const _items = <_MenuItem>[
    _MenuItem(
      key: 'add-fund',
      title: 'Add Fund',
      subtitle: 'You can add fund to your wallet',
      color: AppColors.navy,
    ),
    _MenuItem(
      key: 'withdraw-fund',
      title: 'Withdraw Fund',
      subtitle: 'You can withdraw winnings',
      color: Color(0xFFEF4444),
    ),
    _MenuItem(
      key: 'bank-detail',
      title: 'Bank Detail',
      subtitle: 'Add your bank detail for withdrawals',
      color: Color(0xFF3B82F6),
    ),
    _MenuItem(
      key: 'add-fund-history',
      title: 'Add Fund History',
      subtitle: 'Check your add point history',
      color: Color(0xFF1E3A8A),
    ),
    _MenuItem(
      key: 'withdraw-fund-history',
      title: 'Withdraw Fund History',
      subtitle: 'Check your withdraw history',
      color: Color(0xFFF59E0B),
    ),
  ];

  String _selectedKey = 'add-fund';
  String? _mobileDetail;
  bool _routeSynced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_routeSynced) return;
    _routeSynced = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['tab'] != null) {
      final t = args['tab'].toString();
      if (_items.any((e) => e.key == t)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _selectedKey = t;
              _mobileDetail = t;
            });
          }
        });
      }
    }
  }

  void _goTab(String k) {
    setState(() {
      _selectedKey = k;
      _mobileDetail = k;
    });
  }

  Widget _panel(String key) {
    switch (key) {
      case 'add-fund':
        return AddFundTab(
          onSubmittedGoHistory: () => _goTab('add-fund-history'),
        );
      case 'withdraw-fund':
        return const WithdrawFundTab();
      case 'bank-detail':
        return const BankDetailTab();
      case 'add-fund-history':
        return const AddFundHistoryTab();
      case 'withdraw-fund-history':
        return const WithdrawFundHistoryTab();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final active = _items.firstWhere(
      (e) => e.key == _selectedKey,
      orElse: () => _items.first,
    );

    if (wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => popOrGoHome(context),
                  icon: const Icon(Icons.arrow_back),
                  color: CasinoUi.mutedGold(0.95),
                ),
                const Text(
                  'Funds',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: CasinoUi.lightGold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 300,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 0, 8, 100),
                    children: _items.map((item) {
                      final sel = item.key == _selectedKey;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            onTap: () =>
                                setState(() => _selectedKey = item.key),
                            borderRadius: BorderRadius.circular(16),
                            splashColor: Colors.white.withValues(alpha: 0.08),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: sel
                                      ? CasinoUi.neutralShellBorderColor(alpha: 0.42)
                                      : CasinoUi.neutralShellBorderColor(alpha: 0.14),
                                  width: sel ? 2 : 1,
                                ),
                              ),
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: item.color,
                                    child: item.key == 'add-fund'
                                        ? const Text(
                                            '₹',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          )
                                        : Icon(
                                            item.key == 'withdraw-fund'
                                                ? Icons.arrow_downward
                                                : item.key == 'bank-detail'
                                                ? Icons.account_balance
                                                : Icons.history,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: CasinoUi.lightGold,
                                          ),
                                        ),
                                        Text(
                                          item.subtitle,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: CasinoUi.mutedGold(0.75),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    color: sel
                                        ? CasinoUi.lightGold
                                        : CasinoUi.mutedGold(0.5),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(0, 0, 12, 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: CasinoUi.neutralShellBorderColor(alpha: 0.16),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: active.color,
                              child: active.key == 'add-fund'
                                  ? const Text(
                                      '₹',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : Icon(
                                      active.key == 'withdraw-fund'
                                          ? Icons.arrow_downward
                                          : active.key == 'bank-detail'
                                          ? Icons.account_balance
                                          : Icons.history,
                                      color: Colors.white,
                                    ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    active.title,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: CasinoUi.lightGold,
                                    ),
                                  ),
                                  Text(
                                    active.subtitle,
                                    style: TextStyle(
                                      color: CasinoUi.mutedGold(0.78),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Divider(
                          height: 24,
                          color: CasinoUi.neutralShellBorderColor(alpha: 0.14),
                        ),
                        Expanded(child: _panel(_selectedKey)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Mobile: list or detail
    if (_mobileDetail == null) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => popOrGoHome(context),
                  icon: const Icon(Icons.arrow_back),
                  color: CasinoUi.mutedGold(0.95),
                ),
                const Text(
                  'Funds',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: CasinoUi.lightGold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
              itemCount: _items.length,
              itemBuilder: (context, i) {
                final item = _items[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      onTap: () => setState(() => _mobileDetail = item.key),
                      borderRadius: BorderRadius.circular(16),
                      splashColor: Colors.white.withValues(alpha: 0.08),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: CasinoUi.neutralShellBorderColor(alpha: 0.14),
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: item.color,
                              child: item.key == 'add-fund'
                                  ? const Text(
                                      '₹',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : Icon(
                                      item.key == 'withdraw-fund'
                                          ? Icons.arrow_downward
                                          : item.key == 'bank-detail'
                                          ? Icons.account_balance
                                          : Icons.history,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: CasinoUi.lightGold,
                                    ),
                                  ),
                                  Text(
                                    item.subtitle,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: CasinoUi.mutedGold(0.72),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: CasinoUi.mutedGold(0.55),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    }

    final m = _items.firstWhere(
      (e) => e.key == _mobileDetail,
      orElse: () => _items.first,
    );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
          child: Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _mobileDetail = null),
                icon: const Icon(Icons.arrow_back),
                color: CasinoUi.mutedGold(0.95),
              ),
              Expanded(
                child: Text(
                  m.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: CasinoUi.lightGold,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: _panel(_mobileDetail!),
          ),
        ),
      ],
    );
  }
}
