import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class LotteryOldResultsPage extends StatefulWidget {
  const LotteryOldResultsPage({super.key});

  @override
  State<LotteryOldResultsPage> createState() => _LotteryOldResultsPageState();
}

class _LotteryOldResultsPageState extends State<LotteryOldResultsPage> {
  bool _loading = true;
  String _error = '';
  List<Map<String, dynamic>> _rows = const [];

  @override
  void initState() {
    super.initState();
    _loadTodayResults();
  }

  String _todayKey() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _to2(dynamic value) {
    final s = (value ?? '').toString().replaceAll(RegExp(r'\D'), '');
    if (s.isEmpty) return '--';
    return s.padLeft(2, '0').substring(s.length > 2 ? s.length - 2 : 0);
  }

  String _formatApiDateToUi(String ymd) {
    final p = ymd.split('-');
    if (p.length != 3) return ymd;
    return '${p[2]}-${p[1]}-${p[0]}';
  }

  Future<void> _loadTodayResults() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final date = _todayKey();
      final uri = Uri.parse('$kApiBaseUrl/quiz/slot-results?date=$date&mode=2d');
      final res = await http.get(uri);
      final body = jsonDecode(res.body) as Map<String, dynamic>?;
      if (!mounted) return;

      if (res.statusCode < 200 || res.statusCode >= 300 || body?['success'] != true) {
        setState(() {
          _rows = const [];
          _error = body?['message']?.toString() ?? 'Failed to load old results';
          _loading = false;
        });
        return;
      }

      final data = body?['data'];
      final slots = data is List
          ? data
          : data is Map && data['slots'] is List
              ? (data['slots'] as List)
              : const [];

      final out = <Map<String, dynamic>>[];
      for (final slot in slots) {
        if (slot is! Map) continue;
        final m = Map<String, dynamic>.from(slot);
        final results = m['results'] is List ? (m['results'] as List) : const [];
        final byQuiz = <int, String>{};
        for (final p in results) {
          if (p is! Map) continue;
          final q = int.tryParse('${p['quizId'] ?? ''}');
          if (q == null || q < 1 || q > 30) continue;
          byQuiz[q] = _to2(p['result']);
        }
        out.add({
          'draw': '${m['timeLabel'] ?? m['drawLabelEnd'] ?? m['drawLabelCurrent'] ?? '-'}',
          'byQuiz': byQuiz,
        });
      }

      setState(() {
        _rows = out;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _rows = const [];
        _error = 'Failed to load old results';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateKey = _todayKey();

    return Scaffold(
      backgroundColor: const Color(0xFFE8E8E8),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 54,
              color: const Color(0xFFE85656),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Result',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                      Text(
                        _formatApiDateToUi(dateKey),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ],
                  ),
                  const Spacer(),
                  SizedBox(
                    height: 34,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD63B3B),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(2),
                          side: const BorderSide(color: Color(0xFFBF2E2E)),
                        ),
                      ),
                      child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error.isNotEmpty
                      ? Center(
                          child: Text(
                            _error,
                            style: const TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.w700),
                          ),
                        )
                      : _rows.isEmpty
                          ? const Center(
                              child: Text(
                                'No result found for today.',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(8),
                              itemCount: _rows.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 6),
                              itemBuilder: (context, i) {
                                final row = _rows[i];
                                final byQuiz = (row['byQuiz'] as Map<int, String>);
                                return _slotBlock(draw: '${row['draw']}', byQuiz: byQuiz);
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _slotBlock({required String draw, required Map<int, String> byQuiz}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFC4C4C4)),
      ),
      child: Row(
        children: [
          Container(
            width: 88,
            height: 120,
            alignment: Alignment.center,
            color: const Color(0xFF0B0B0B),
            child: Text(
              draw,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                _setRow(setName: 'Set A', start: 1, end: 10, color: const Color(0xFFF5B7CF), byQuiz: byQuiz),
                _setRow(setName: 'Set B', start: 11, end: 20, color: const Color(0xFFB7D2FF), byQuiz: byQuiz),
                _setRow(setName: 'Set C', start: 21, end: 30, color: const Color(0xFFBDEFC0), byQuiz: byQuiz),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _setRow({
    required String setName,
    required int start,
    required int end,
    required Color color,
    required Map<int, String> byQuiz,
  }) {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          Container(
            width: 56,
            color: const Color(0xFFE85656),
            alignment: Alignment.center,
            child: Text(
              setName,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
            ),
          ),
          Expanded(
            child: Row(
              children: List.generate(end - start + 1, (i) {
                final q = start + i;
                final value = byQuiz[q] ?? '--';
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(left: 2, right: 2, top: 2, bottom: 2),
                    decoration: BoxDecoration(
                      color: color,
                      border: Border.all(color: const Color(0xFFB6B6B6)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Q${q.toString().padLeft(2, '0')}-$value',
                      style: const TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

