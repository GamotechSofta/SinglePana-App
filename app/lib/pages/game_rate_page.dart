import 'package:flutter/material.dart';

import '../services/bets_service.dart';
import '../theme/app_colors.dart';
import '../theme/casino_ui.dart';
import '../utils/nav_pop_or_home.dart';

class GameRatePage extends StatefulWidget {
  const GameRatePage({super.key});

  @override
  State<GameRatePage> createState() => _GameRatePageState();
}

class _GameRatePageState extends State<GameRatePage> {
  static const Map<String, num> _defaultRates = <String, num>{
    'single': 10,
    'oddEven': 10,
    'jodi': 100,
    'singlePatti': 150,
    'doublePatti': 300,
    'triplePatti': 1000,
    'halfSangam': 5000,
    'fullSangam': 10000,
  };

  Map<String, num> _rates = Map<String, num>.from(_defaultRates);
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  num _toRate(dynamic val, num fallback) {
    final n = num.tryParse(val?.toString() ?? '');
    return n != null && n >= 0 ? n : fallback;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await BetsService.instance.fetchRatesCurrent();
    final data = (res?['data'] is Map<String, dynamic>)
        ? (res!['data'] as Map<String, dynamic>)
        : null;
    if (!mounted) return;
    if (data != null) {
      setState(() {
        _rates = <String, num>{
          'single': _toRate(data['single'], _defaultRates['single']!),
          'oddEven': _toRate(
            data['oddEven'] ?? data['odd_even'] ?? data['oddEvenRate'] ?? data['odd_even_rate'],
            _defaultRates['oddEven']!,
          ),
          'jodi': _toRate(data['jodi'], _defaultRates['jodi']!),
          'singlePatti': _toRate(data['singlePatti'], _defaultRates['singlePatti']!),
          'doublePatti': _toRate(data['doublePatti'], _defaultRates['doublePatti']!),
          'triplePatti': _toRate(data['triplePatti'], _defaultRates['triplePatti']!),
          'halfSangam': _toRate(data['halfSangam'], _defaultRates['halfSangam']!),
          'fullSangam': _toRate(data['fullSangam'], _defaultRates['fullSangam']!),
        };
        _loading = false;
      });
      return;
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final tableBorder = CasinoUi.neutralShellBorderColor(alpha: 0.2);
    final rowDivider = CasinoUi.neutralShellBorderColor(alpha: 0.14);
    final headerBg = AppColors.surfaceElevated.withValues(alpha: 0.65);

    final rows = <({String game, num rate})>[
      (game: 'Single Digit', rate: _rates['single'] ?? _defaultRates['single']!),
      (game: 'Odd Even', rate: _rates['oddEven'] ?? _defaultRates['oddEven']!),
      (game: 'Jodi', rate: _rates['jodi'] ?? _defaultRates['jodi']!),
      (game: 'Single Patti', rate: _rates['singlePatti'] ?? _defaultRates['singlePatti']!),
      (game: 'Double Patti', rate: _rates['doublePatti'] ?? _defaultRates['doublePatti']!),
      (game: 'Triple Patti', rate: _rates['triplePatti'] ?? _defaultRates['triplePatti']!),
      (game: 'Half Sangam', rate: _rates['halfSangam'] ?? _defaultRates['halfSangam']!),
      (game: 'Full Sangam', rate: _rates['fullSangam'] ?? _defaultRates['fullSangam']!),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => popOrGoHome(context),
              icon: const Icon(Icons.arrow_back),
              color: CasinoUi.mutedGold(0.95),
            ),
            const Expanded(
              child: Text(
                'Game Rate',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: CasinoUi.lightGold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: tableBorder, width: 1.2),
          ),
          child: _loading
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.gold.withValues(alpha: 0.9),
                    ),
                  ),
                )
              : Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: headerBg,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 72,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                              child: Text(
                                'SR NO',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: CasinoUi.mutedGold(0.95),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                              child: Text(
                                'GAME',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: CasinoUi.mutedGold(0.95),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 110,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                              child: Text(
                                'RATE (1 =)',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: CasinoUi.mutedGold(0.95),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    for (int i = 0; i < rows.length; i++)
                      Container(
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: i == 0 ? tableBorder : rowDivider,
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 72,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                child: Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    fontSize: wide ? 15 : 14,
                                    fontWeight: FontWeight.w600,
                                    color: CasinoUi.mutedGold(0.88),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                child: Text(
                                  rows[i].game,
                                  style: TextStyle(
                                    fontSize: wide ? 18 : 15,
                                    fontWeight: FontWeight.w700,
                                    color: CasinoUi.lightGold,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 110,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                child: Text(
                                  '${rows[i].rate}',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: wide ? 18 : 15,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.gold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
