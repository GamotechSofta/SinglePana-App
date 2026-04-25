import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/bets_service.dart';
import '../theme/app_colors.dart';
import '../theme/casino_ui.dart';
import '../utils/nav_pop_or_home.dart';

/// Leaderboard — [frontend/src/pages/TopWinners.jsx].
class TopWinnersPage extends StatefulWidget {
  const TopWinnersPage({super.key});

  @override
  State<TopWinnersPage> createState() => _TopWinnersPageState();
}

class _TopWinnersPageState extends State<TopWinnersPage> {
  static const _ranges = <({String key, String label})>[
    (key: 'today', label: 'Today'),
    (key: 'week', label: '7 Days'),
    (key: 'month', label: '30 Days'),
    (key: 'all', label: 'All'),
  ];

  String _range = 'today';
  bool _loading = true;
  String _error = '';
  List<_WinnerRow> _rows = [];

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
    final r = await BetsService.instance.fetchPublicTopWinners(
      timeRange: _range,
    );
    if (!mounted) return;
    if (!r.success) {
      setState(() {
        _loading = false;
        _error = r.message ?? 'Failed to load';
        _rows = [];
      });
      return;
    }
    final out = <_WinnerRow>[];
    for (var i = 0; i < r.rows.length; i++) {
      final row = r.rows[i];
      final uid = row['userId'];
      final u = row['user'];
      String username = 'User';
      if (uid is Map && uid['username'] != null) {
        username = uid['username'].toString();
      } else if (u is Map && u['username'] != null) {
        username = u['username'].toString();
      }
      final tw =
          num.tryParse(row['totalWinnings']?.toString() ?? '') ??
          (row['totalWinnings'] as num?) ??
          0;
      final wins =
          num.tryParse(row['totalWins']?.toString() ?? '') ??
          (row['totalWins'] as num?) ??
          0;
      final wr = row['winRate']?.toString();
      out.add(
        _WinnerRow(
          rank: i + 1,
          username: username,
          totalWinnings: tw,
          totalWins: wins,
          winRate: wr,
        ),
      );
    }
    setState(() {
      _loading = false;
      _rows = out;
    });
  }

  LinearGradient _medalGradient(int rank) {
    if (rank == 1) {
      return const LinearGradient(
        colors: [Color(0xFFD4AF37), Color(0xFFB8941F)],
      );
    }
    if (rank == 2) {
      return const LinearGradient(
        colors: [Color(0xFFCBD5E1), Color(0xFF64748B)],
      );
    }
    if (rank == 3) {
      return const LinearGradient(
        colors: [Color(0xFFF59E0B), Color(0xFF92400E)],
      );
    }
    return const LinearGradient(colors: [Color(0xFF2A2D32), Color(0xFF15171B)]);
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'en_IN');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 12, 8),
          child: Row(
            children: [
              IconButton(
                onPressed: () => popOrGoHome(context),
                icon: const Icon(Icons.arrow_back),
                color: CasinoUi.mutedGold(0.95),
              ),
              const Expanded(
                child: Text(
                  'Top Winners',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.gold,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _ranges.map((t) {
              final active = t.key == _range;
              return ChoiceChip(
                label: Text(t.label),
                selected: active,
                onSelected: (_) {
                  setState(() => _range = t.key);
                  _load();
                },
                selectedColor: AppColors.gold.withValues(alpha: 0.25),
                labelStyle: TextStyle(
                  color: active ? CasinoUi.lightGold : CasinoUi.mutedGold(0.85),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                side: BorderSide(
                  color: active
                      ? CasinoUi.neutralShellBorderColor(alpha: 0.28)
                      : CasinoUi.neutralShellBorderColor(alpha: 0.12),
                ),
                backgroundColor: Colors.transparent,
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        if (_error.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Material(
              color: AppColors.accentRose.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _error,
                  style: TextStyle(color: Colors.red.shade300, fontSize: 13),
                ),
              ),
            ),
          ),
        Expanded(
          child: _loading
              ? ListView(
                  padding: const EdgeInsets.all(12),
                  children: List.generate(
                    6,
                    (_) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        height: 76,
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: CasinoUi.neutralShellBorderColor(alpha: 0.14),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              : _rows.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(
                      'No winners found.',
                      style: TextStyle(color: CasinoUi.mutedGold(0.88)),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  itemCount: _rows.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final r = _rows[i];
                    return Card(
                      color: Colors.transparent,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      surfaceTintColor: Colors.transparent,
                      shape: CasinoUi.supportCardShape(),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                gradient: _medalGradient(r.rank),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.25),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${r.rank}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          r.username,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: CasinoUi.lightGold,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '₹ ${fmt.format(r.totalWinnings)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: CasinoUi.lightGold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    [
                                      'Wins: ${fmt.format(r.totalWins)}',
                                      if (r.winRate != null &&
                                          r.winRate!.isNotEmpty)
                                        'Win rate: ${r.winRate!.contains('%') ? r.winRate! : '${r.winRate}%'}',
                                    ].join('   '),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: CasinoUi.mutedGold(0.65),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _WinnerRow {
  const _WinnerRow({
    required this.rank,
    required this.username,
    required this.totalWinnings,
    required this.totalWins,
    this.winRate,
  });

  final int rank;
  final String username;
  final num totalWinnings;
  final num totalWins;
  final String? winRate;
}
