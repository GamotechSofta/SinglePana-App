import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/markets_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/market_timing.dart';
import '../../utils/nav_pop_or_home.dart';

const Color _resultsLightGold = Color(0xFFFEF9E8);

ShapeBorder _resultsCardShape() => RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(16),
  side: BorderSide(
    color: Colors.white.withValues(alpha: 0.22),
    width: 1,
  ),
);

/// Market name + [displayResult] for a date — [frontend/src/pages/MarketResultHistory.jsx].
class MarketResultsView extends StatefulWidget {
  const MarketResultsView({super.key});

  @override
  State<MarketResultsView> createState() => _MarketResultsViewState();
}

class _MarketResultsViewState extends State<MarketResultsView> {
  DateTime _selectedDay = _parseYmdLocal(getTodayIst());
  bool _loading = true;
  List<({String id, String name, String result})> _rows = [];
  Timer? _timer;

  static DateTime _parseYmdLocal(String ymd) {
    final p = ymd.split('-');
    if (p.length != 3) return DateTime.now();
    final y = int.tryParse(p[0]) ?? DateTime.now().year;
    final m = int.tryParse(p[1]) ?? 1;
    final d = int.tryParse(p[2]) ?? 1;
    return DateTime(y, m, d);
  }

  static String _toYmd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final today = getTodayIst();
    var key = _toYmd(_selectedDay);
    if (key.compareTo(today) > 0) {
      key = today;
      if (mounted) {
        setState(() => _selectedDay = _parseYmdLocal(today));
      }
    }
    final raw = await MarketsService.instance.fetchResultHistory(key);
    if (!mounted) return;
    final mapped = <({String id, String name, String result})>[];
    for (final x in raw) {
      final name = (x['marketName'] ?? '').toString().trim();
      if (name.isEmpty) continue;
      final id = (x['_id']?.toString().isNotEmpty == true)
          ? x['_id'].toString()
          : '${x['marketId']}-${x['dateKey']}';
      final result = (x['displayResult'] ?? '***-**-***').toString().trim();
      mapped.add((id: id, name: name, result: result));
    }
    mapped.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    setState(() {
      _loading = false;
      _rows = mapped;
    });
  }

  Future<void> _pickDate() async {
    final today = _parseYmdLocal(getTodayIst());
    final first = DateTime(today.year - 2, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay.isAfter(today) ? today : _selectedDay,
      firstDate: first,
      lastDate: today,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedDay = picked;
      _loading = true;
    });
    await _load();
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          margin: EdgeInsets.zero,
          color: Colors.transparent,
          elevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          shape: _resultsCardShape(),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Date',
                  style: TextStyle(
                    color: AppColors.goldMuted.withValues(alpha: 0.95),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton(
                    onPressed: _pickDate,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.buttonPaddingH,
                        vertical: AppSpacing.buttonPaddingV,
                      ),
                      minimumSize: const Size(0, AppSpacing.buttonMinHeight),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      shape: const StadiumBorder(),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.18),
                        width: 1,
                      ),
                      foregroundColor: _resultsLightGold,
                    ),
                    child: Text(
                      DateFormat('dd/MM/yyyy').format(_selectedDay),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _resultsLightGold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _rows.isEmpty
              ? Center(
                  child: Card(
                    color: Colors.transparent,
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    surfaceTintColor: Colors.transparent,
                    shape: _resultsCardShape(),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        'No markets found.',
                        style: TextStyle(
                          color: AppColors.goldMuted.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: _rows.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final r = _rows[i];
                    return Card(
                      margin: EdgeInsets.zero,
                      color: Colors.transparent,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      surfaceTintColor: Colors.transparent,
                      shape: _resultsCardShape(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                r.name.toUpperCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3,
                                  color: _resultsLightGold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              r.result,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: _resultsLightGold,
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

class MarketResultHistoryScreen extends StatelessWidget {
  const MarketResultHistoryScreen({super.key});

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
                  'MARKET RESULT HISTORY',
                  style: TextStyle(
                    fontSize: wide ? 22 : 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.4,
                    color: AppColors.gold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: MarketResultsView(),
          ),
        ),
      ],
    );
  }
}
