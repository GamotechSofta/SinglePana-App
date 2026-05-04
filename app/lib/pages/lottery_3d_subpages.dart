import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../services/auth_service.dart';

class Lottery3DResultPage extends StatefulWidget {
  const Lottery3DResultPage({super.key});

  @override
  State<Lottery3DResultPage> createState() => _Lottery3DResultPageState();
}

class _Lottery3DResultPageState extends State<Lottery3DResultPage> {
  bool _loading = true;
  String _error = '';
  List<Map<String, dynamic>> _rows = const [];
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _dateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _to3(dynamic v) {
    final raw = (v ?? '').toString().replaceAll(RegExp(r'\D'), '');
    if (raw.isEmpty) return '---';
    return raw.padLeft(3, '0').substring(raw.length > 3 ? raw.length - 3 : 0);
  }

  String _setValue(List<dynamic>? results, int quizId) {
    if (results == null) return '---';
    for (final r in results) {
      if (r is! Map) continue;
      final id = int.tryParse('${r['quizId'] ?? ''}');
      if (id != quizId) continue;
      return _to3(r['result']);
    }
    return '---';
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final q = Uri.encodeQueryComponent(_dateKey(_selectedDate));
      final uri = Uri.parse('$kApiBaseUrl/quiz/slot-results?date=$q&mode=3d');
      final res = await http.get(uri);
      final json = jsonDecode(res.body) as Map<String, dynamic>?;
      if (res.statusCode < 200 || res.statusCode >= 300 || json?['success'] != true) {
        setState(() {
          _rows = const [];
          _error = json?['message']?.toString() ?? 'Failed to load 3D results';
          _loading = false;
        });
        return;
      }
      final data = json?['data'];
      final list = data is Map && data['slots'] is List
          ? (data['slots'] as List)
          : (data is List ? data : const []);
      final next = <Map<String, dynamic>>[];
      for (final item in list) {
        if (item is! Map) continue;
        final m = Map<String, dynamic>.from(item);
        final results = m['results'] is List ? (m['results'] as List) : null;
        next.add({
          'draw': '${m['timeLabel'] ?? m['drawLabelEnd'] ?? m['drawLabelCurrent'] ?? '-'}',
          'a': _setValue(results, 1),
          'b': _setValue(results, 2),
          'c': _setValue(results, 3),
        });
      }
      setState(() {
        _rows = next;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _rows = const [];
        _error = 'Failed to load 3D results';
        _loading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
    );
    if (picked == null) return;
    setState(() => _selectedDate = picked);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return _Lottery3DSubPageTemplate(
      title: '3D Result',
      subtitle: 'Latest and previous 3D draw results',
      icon: Icons.emoji_events_rounded,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(
                  child: Text(
                    _error,
                    style: const TextStyle(
                      color: Color(0xFFB91C1C),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              : _rows.isEmpty
                  ? const Center(
                      child: Text(
                        'No result found',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                          child: Row(
                            children: [
                              Text(
                                'Date: ${_dateKey(_selectedDate)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                height: 28,
                                child: ElevatedButton(
                                  onPressed: _pickDate,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0F172A),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  child: const Text('Change Date'),
                                ),
                              ),
                              const SizedBox(width: 6),
                              SizedBox(
                                height: 28,
                                child: ElevatedButton(
                                  onPressed: _load,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1D4ED8),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  child: const Text('Refresh'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.all(8),
                            itemCount: _rows.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 6),
                            itemBuilder: (context, i) {
                              final row = _rows[i];
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: const Color(0xFFD9D9D9)),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 88,
                                      child: Text(
                                        '${row['draw']}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(child: _ResultSetCell(label: 'A', value: '${row['a']}')),
                                    const SizedBox(width: 6),
                                    Expanded(child: _ResultSetCell(label: 'B', value: '${row['b']}')),
                                    const SizedBox(width: 6),
                                    Expanded(child: _ResultSetCell(label: 'C', value: '${row['c']}')),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
    );
  }
}

class Lottery3DQuizPage extends StatefulWidget {
  const Lottery3DQuizPage({super.key});

  @override
  State<Lottery3DQuizPage> createState() => _Lottery3DQuizPageState();
}

class _Lottery3DQuizPageState extends State<Lottery3DQuizPage> {
  int _selectedQuiz = 1;
  Map<String, dynamic>? _slotData;
  String _slotErr = '';
  bool _loading = false;
  String _error = '';
  List<Map<String, dynamic>> _questions = const [];
  Map<String, dynamic>? _hint;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _refreshAll();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => _refreshSlotAndHintOnly());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  bool get _isHintPhase => (_slotData?['phase'] ?? '').toString() == 'hint';

  Future<void> _refreshSlotAndHintOnly() async {
    await _loadSlot();
    if (_isHintPhase) {
      await _loadHint();
    }
  }

  Future<void> _refreshAll() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    await _loadSlot();
    if (_isHintPhase) {
      await _loadHint();
      setState(() {
        _questions = const [];
      });
    } else {
      await _loadQuestions();
      setState(() {
        _hint = null;
      });
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _loadSlot() async {
    try {
      final res = await http.get(Uri.parse('$kApiBaseUrl/quiz/slot'));
      final json = jsonDecode(res.body) as Map<String, dynamic>?;
      if (!mounted) return;
      if (res.statusCode >= 200 && res.statusCode < 300 && json?['success'] == true && json?['data'] is Map) {
        setState(() {
          _slotData = Map<String, dynamic>.from(json!['data'] as Map);
          _slotErr = '';
        });
      } else {
        setState(() => _slotErr = json?['message']?.toString() ?? 'Failed to load slot');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _slotErr = 'Failed to load slot');
    }
  }

  Future<void> _loadQuestions() async {
    try {
      final res = await http.get(Uri.parse('$kApiBaseUrl/quiz/questions/$_selectedQuiz?mode=3d'));
      final json = jsonDecode(res.body) as Map<String, dynamic>?;
      if (!mounted) return;
      if (res.statusCode >= 200 && res.statusCode < 300 && json?['success'] == true) {
        final data = json?['data'];
        final list = data is Map && data['questions'] is List ? (data['questions'] as List) : const [];
        setState(() {
          _questions = [
            for (final q in list)
              if (q is Map) Map<String, dynamic>.from(q),
          ];
          _error = '';
        });
      } else {
        setState(() {
          _questions = const [];
          _error = json?['message']?.toString() ?? 'Failed to load questions';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _questions = const [];
        _error = 'Failed to load questions';
      });
    }
  }

  Future<void> _loadHint() async {
    try {
      final res = await http.get(Uri.parse('$kApiBaseUrl/quiz/hint/$_selectedQuiz?mode=3d'));
      final json = jsonDecode(res.body) as Map<String, dynamic>?;
      if (!mounted) return;
      if (res.statusCode >= 200 && res.statusCode < 300 && json?['success'] == true && json?['data'] is Map) {
        setState(() {
          _hint = Map<String, dynamic>.from(json!['data'] as Map);
          _error = '';
        });
      } else {
        setState(() {
          _hint = null;
          _error = json?['message']?.toString() ?? 'Hint not available';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hint = null;
        _error = 'Hint not available';
      });
    }
  }

  String _slotLabel(dynamic v) {
    final raw = (v ?? '').toString().trim();
    if (raw.isEmpty) return '-';
    final fromIso = DateTime.tryParse(raw);
    if (fromIso != null) {
      final local = fromIso.toLocal();
      final hh = local.hour % 12 == 0 ? 12 : local.hour % 12;
      final mm = local.minute.toString().padLeft(2, '0');
      final ampm = local.hour >= 12 ? 'PM' : 'AM';
      return '$hh:$mm $ampm';
    }
    return raw;
  }

  DateTime _nextQuarter(DateTime now) {
    final base = DateTime(now.year, now.month, now.day, now.hour, now.minute);
    final mins = base.hour * 60 + base.minute;
    final nextQuarterMins = (mins ~/ 15 + 1) * 15;
    final wrapped = nextQuarterMins % (24 * 60);
    final dayCarry = nextQuarterMins >= (24 * 60) ? 1 : 0;
    return DateTime(
      base.year,
      base.month,
      base.day + dayCarry,
      wrapped ~/ 60,
      wrapped % 60,
    );
  }

  List<String> _remainingSlotsForToday() {
    final nextIso = (_slotData?['nextSlotStartIso'] ?? '').toString().trim();
    final nextDt = DateTime.tryParse(nextIso)?.toLocal();
    final now = DateTime.now();
    final start = nextDt ?? _nextQuarter(now);
    final dayEnd = DateTime(start.year, start.month, start.day).add(
      const Duration(days: 1),
    );
    if (!start.isBefore(dayEnd)) return const [];

    final out = <String>[];
    var i = 0;
    while (true) {
      final dt = start.add(Duration(minutes: i * 15));
      if (!dt.isBefore(dayEnd)) break;
      final hh = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final mm = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      out.add('$hh:$mm $ampm');
      i += 1;
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final draw = '${_slotData?['drawLabelCurrent'] ?? _slotLabel(_slotData?['slotStartIso'])}';
    final remainingSlots = _remainingSlotsForToday();
    final secsHint = int.tryParse('${_slotData?['secondsUntilHint'] ?? 0}') ?? 0;
    final secsEnd = int.tryParse('${_slotData?['secondsUntilSlotEnd'] ?? 0}') ?? 0;
    String statusText;
    if (_slotErr.isNotEmpty) {
      statusText = 'Server: $_slotErr';
    } else if (_isHintPhase) {
      statusText = 'Hint phase - Draw: $draw (${(secsEnd ~/ 60)}:${(secsEnd % 60).toString().padLeft(2, '0')})';
    } else {
      statusText = 'Hint in ${(secsHint ~/ 60)}:${(secsHint % 60).toString().padLeft(2, '0')}';
    }

    return _Lottery3DSubPageTemplate(
      title: '3D Quiz',
      subtitle: 'Quiz section for 3D game',
      icon: Icons.quiz_rounded,
      headerTrailing: SizedBox(
        height: 30,
        child: remainingSlots.isEmpty
            ? const Center(
                child: Text(
                  'No remaining slots',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            : ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: remainingSlots.length,
                separatorBuilder: (_, __) => const SizedBox(width: 4),
                itemBuilder: (context, i) => _drawSlotChip(
                  remainingSlots[i],
                  i == 0,
                ),
              ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    statusText,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 28,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: const Text('Play'),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 28,
                  child: ElevatedButton(
                    onPressed: _refreshAll,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1D4ED8),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: const Text('Refresh'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final q in [1, 2, 3]) ...[
                  if (q != 1) const SizedBox(width: 6),
                  Expanded(
                    child: SizedBox(
                      height: 30,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() => _selectedQuiz = q);
                          _refreshAll();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _selectedQuiz == q ? const Color(0xFFF59E0B) : const Color(0xFF334155),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        child: Text(
                          'QUIZ-$q',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error.isNotEmpty && _questions.isEmpty && _hint == null
                      ? Center(
                          child: Text(
                            _error,
                            style: const TextStyle(
                              color: Color(0xFFB91C1C),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      : _isHintPhase
                          ? _QuizHintCard3D(hint: _hint)
                          : _QuizQuestionList3D(questions: _questions),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawSlotChip(String text, bool active) {
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? const Color(0xFFF5E14A) : const Color(0xFF334155),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: active ? Colors.black : Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _QuizHintCard3D extends StatelessWidget {
  const _QuizHintCard3D({required this.hint});

  final Map<String, dynamic>? hint;

  @override
  Widget build(BuildContext context) {
    if (hint == null) {
      return const Center(
        child: Text(
          'Hint not available',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD9D9D9)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hint',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${hint?['questionText'] ?? '-'}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Fairness hash: ${hint?['seedHash'] ?? '-'}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuizQuestionList3D extends StatefulWidget {
  const _QuizQuestionList3D({required this.questions});

  final List<Map<String, dynamic>> questions;

  @override
  State<_QuizQuestionList3D> createState() => _QuizQuestionList3DState();
}

class _QuizQuestionList3DState extends State<_QuizQuestionList3D> {
  final Set<int> _revealed = <int>{};

  String _questionAnswer(Map<String, dynamic> q) {
    final raw = [
      q['answer'],
      q['correctAnswer'],
      q['correct_answer'],
      q['correctOption'],
      q['correct_option'],
      q['rightAnswer'],
      q['result'],
    ]
        .map((e) => (e ?? '').toString().trim())
        .firstWhere((e) => e.isNotEmpty, orElse: () => '');
    return raw.isEmpty ? 'Not available' : raw.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.questions.isEmpty) {
      return const Center(
        child: Text(
          'No questions available',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            itemCount: widget.questions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (context, i) {
              final q = widget.questions[i];
              final options = q['options'] is Map
                  ? Map<String, dynamic>.from(q['options'] as Map)
                  : <String, dynamic>{};
              final answerText = _questionAnswer(q);
              final isRevealed = _revealed.contains(i);
              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFD9D9D9)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            'Q${(i + 1).toString().padLeft(2, '0')}: ${q['question'] ?? ''}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              if (isRevealed) {
                                _revealed.remove(i);
                              } else {
                                _revealed.add(i);
                              }
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1D4ED8),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 26),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 0,
                            ),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            isRevealed ? 'Hide Answer' : 'Show Answer',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      children: [
                        Text(
                          'A: ${options['A'] ?? ''}',
                          style: const TextStyle(fontSize: 11, color: Colors.black),
                        ),
                        Text(
                          'B: ${options['B'] ?? ''}',
                          style: const TextStyle(fontSize: 11, color: Colors.black),
                        ),
                        Text(
                          'C: ${options['C'] ?? ''}',
                          style: const TextStyle(fontSize: 11, color: Colors.black),
                        ),
                        Text(
                          'D: ${options['D'] ?? ''}',
                          style: const TextStyle(fontSize: 11, color: Colors.black),
                        ),
                        Text(
                          isRevealed ? 'Answer: $answerText' : 'Answer: •••',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class Lottery3DTicketListPage extends StatefulWidget {
  const Lottery3DTicketListPage({super.key});

  @override
  State<Lottery3DTicketListPage> createState() => _Lottery3DTicketListPageState();
}

class _Lottery3DTicketListPageState extends State<Lottery3DTicketListPage> {
  bool _loading = true;
  String _error = '';
  List<Map<String, dynamic>> _rows = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<Map<String, String>> _authHeaders() async {
    final user = await AuthService.instance.getStoredUser();
    final token = user?['token']?.toString().trim() ?? '';
    if (token.isEmpty) return const {};
    return {'Authorization': 'Bearer $token'};
  }

  String _fmtSlot(String iso) {
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '-';
    final hh = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final mm = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hh:$mm $ampm';
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final headers = await _authHeaders();
      if (headers.isEmpty) {
        setState(() {
          _rows = const [];
          _error = 'Please login to view tickets.';
          _loading = false;
        });
        return;
      }
      final res = await http.get(Uri.parse('$kApiBaseUrl/quiz/my-quiz-bets?limit=300&mode=3d'), headers: headers);
      final json = jsonDecode(res.body) as Map<String, dynamic>?;
      if (res.statusCode < 200 || res.statusCode >= 300 || json?['success'] != true) {
        setState(() {
          _rows = const [];
          _error = json?['message']?.toString() ?? 'Failed to load ticket list';
          _loading = false;
        });
        return;
      }
      final data = json?['data'];
      final list = data is List
          ? data
          : data is Map && data['rows'] is List
              ? (data['rows'] as List)
              : const [];
      final bySlot = <String, List<Map<String, dynamic>>>{};
      for (final e in list) {
        if (e is! Map) continue;
        final row = Map<String, dynamic>.from(e);
        final slot = (row['slotStartIso'] ?? '').toString().trim();
        if (slot.isEmpty) continue;
        bySlot.putIfAbsent(slot, () => <Map<String, dynamic>>[]).add(row);
      }
      final out = <Map<String, dynamic>>[];
      bySlot.forEach((slotIso, slotRows) {
        num totalPoints = 0;
        var pendingCount = 0;
        final bets = <String>[];
        for (final r in slotRows) {
          final status = (r['status'] ?? '').toString().toLowerCase();
          final amount = num.tryParse('${r['amount'] ?? 0}') ?? 0;
          totalPoints += amount;
          if (status == 'pending' || status.isEmpty) pendingCount += 1;
          final qid = int.tryParse('${r['quizId'] ?? ''}') ?? 1;
          final panel = qid == 1 ? 'A' : qid == 2 ? 'B' : 'C';
          final mode = '${r['betMode'] ?? r['mode'] ?? 'str'}'.toUpperCase();
          final number = (r['number'] ?? '').toString().replaceAll(RegExp(r'\D'), '').padLeft(3, '0');
          bets.add('$panel-$number [$mode] x $amount');
        }
        final createdAt = (slotRows.first['createdAt'] ?? '').toString();
        out.add({
          'slotIso': slotIso,
          'slotLabel': _fmtSlot(slotIso),
          'dateLabel': createdAt,
          'totalPoints': totalPoints,
          'pendingCount': pendingCount,
          'bets': bets,
        });
      });
      out.sort((a, b) {
        final aMs = DateTime.tryParse('${a['slotIso']}')?.millisecondsSinceEpoch ?? 0;
        final bMs = DateTime.tryParse('${b['slotIso']}')?.millisecondsSinceEpoch ?? 0;
        return bMs.compareTo(aMs);
      });
      setState(() {
        _rows = out;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _rows = const [];
        _error = 'Failed to load ticket list';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Lottery3DSubPageTemplate(
      title: '3D Ticket List',
      subtitle: 'Current ticket entries for 3D game',
      icon: Icons.receipt_long_rounded,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(child: Text(_error, style: const TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.w700)))
              : _rows.isEmpty
                  ? const Center(child: Text('No current tickets found'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: _rows.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, i) {
                        final row = _rows[i];
                        final bets = (row['bets'] as List).cast<String>();
                        return Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: const Color(0xFFD1D5DB)),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Slot: ${row['slotLabel']}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Points: ${row['totalPoints']}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Pending: ${row['pendingCount']}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ...bets.take(8).map(
                                    (e) => Padding(
                                      padding: const EdgeInsets.only(bottom: 2),
                                      child: Text(
                                        e,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                  ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}

class Lottery3DHistoryPage extends StatelessWidget {
  const Lottery3DHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _Lottery3DHistoryView();
  }
}

class _Lottery3DHistoryView extends StatefulWidget {
  const _Lottery3DHistoryView();

  @override
  State<_Lottery3DHistoryView> createState() => _Lottery3DHistoryViewState();
}

class _Lottery3DHistoryViewState extends State<_Lottery3DHistoryView> {
  bool _loading = true;
  String _error = '';
  int _limit = 5000;
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _rows = const [];
  String _playerName = 'user';
  String _lastApiInfo = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<Map<String, String>> _authHeaders() async {
    final user = await AuthService.instance.getStoredUser();
    final token = user?['token']?.toString().trim() ?? '';
    if (token.isEmpty) return const {};
    return {'Authorization': 'Bearer $token'};
  }

  String _mongoString(dynamic v) {
    if (v == null) return '';
    if (v is Map) {
      final oid = v[r'$oid'] ?? v['oid'];
      if (oid != null) return '$oid'.trim();
      return '';
    }
    final s = '$v'.trim();
    return s == 'null' ? '' : s;
  }

  /// API `ticketId` only — not mongoose `_id` (avoids two different ids on screen).
  String _rawApiTicketIdFromRow(Map<String, dynamic> row) {
    for (final entry in row.entries) {
      final norm = entry.key.replaceAll('_', '').toLowerCase();
      if (norm != 'ticketid') continue;
      final s = _mongoString(entry.value);
      if (s.isNotEmpty) return s;
    }
    final nested = row['ticket'];
    if (nested is Map) {
      final m = Map<String, dynamic>.from(nested);
      for (final entry in m.entries) {
        final norm = entry.key.replaceAll('_', '').toLowerCase();
        if (norm != 'ticketid') continue;
        final s = _mongoString(entry.value);
        if (s.isNotEmpty) return s;
      }
    }
    return '';
  }

  /// Last 8 chars of API `ticketId`, uppercase only when `ticketId` is present.
  String _apiTicketIdLastEightUpper(Map<String, dynamic> row) {
    final fromApi = _rawApiTicketIdFromRow(row);
    if (fromApi.isEmpty) return '';
    final s = fromApi.length <= 8 ? fromApi : fromApi.substring(fromApi.length - 8);
    return s.toUpperCase();
  }

  /// One ticket id per history card: first `ticketId` found among slot rows.
  String _slotTicketIdsLine(List<Map<String, dynamic>> slotRows) {
    for (final row in slotRows) {
      final id = _apiTicketIdLastEightUpper(row);
      if (id.isNotEmpty) return id;
    }
    return '--------';
  }

  String _fmtDate(dynamic iso) {
    final s = (iso ?? '').toString().trim();
    if (s.isEmpty) return '-';
    final dt = DateTime.tryParse(s);
    if (dt == null) return s;
    final local = dt.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    final y = local.year.toString();
    final hh = (local.hour % 12 == 0 ? 12 : local.hour % 12).toString();
    final mm = local.minute.toString().padLeft(2, '0');
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    return '$d-$m-$y $hh:$mm $ampm';
  }

  String _fmtDateOnly(dynamic iso) {
    final s = (iso ?? '').toString().trim();
    if (s.isEmpty) return '-';
    final dt = DateTime.tryParse(s);
    if (dt == null) return '-';
    final local = dt.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    final y = local.year.toString();
    return '$y-$m-$d';
  }

  String _dateKey(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  String _fmtTimeOnly(dynamic iso) {
    final s = (iso ?? '').toString().trim();
    if (s.isEmpty) return '-';
    final dt = DateTime.tryParse(s);
    if (dt == null) return '-';
    final local = dt.toLocal();
    final hh = (local.hour % 12 == 0 ? 12 : local.hour % 12).toString();
    final mm = local.minute.toString().padLeft(2, '0');
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    return '$hh:$mm $ampm';
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final user = await AuthService.instance.getStoredUser();
      String pickUserField(List<String> keys) {
        for (final k in keys) {
          final v = user?[k];
          if (v == null) continue;
          final s = v.toString().trim();
          if (s.isNotEmpty) return s;
        }
        return '';
      }
      final first = pickUserField(['firstName', 'firstname', 'givenName']);
      final last = pickUserField(['lastName', 'lastname', 'surname']);
      final fullName = '$first $last'.trim();
      final userName = fullName.isNotEmpty
          ? fullName
          : pickUserField(['name', 'fullName', 'userName', 'username', 'phone', 'mobile']);
      final headers = await _authHeaders();
      if (headers.isEmpty) {
        setState(() {
          _rows = const [];
          _error = 'Please login to view history';
          _loading = false;
        });
        return;
      }
      final dateKey =
          '${_selectedDate.year.toString().padLeft(4, '0')}-'
          '${_selectedDate.month.toString().padLeft(2, '0')}-'
          '${_selectedDate.day.toString().padLeft(2, '0')}';
      final uri = Uri.parse(
        '$kApiBaseUrl/quiz/my-quiz-bets?limit=$_limit&mode=3d&date=${Uri.encodeQueryComponent(dateKey)}',
      );
      final res = await http.get(uri, headers: headers);
      final json = jsonDecode(res.body) as Map<String, dynamic>?;
      if (res.statusCode < 200 || res.statusCode >= 300 || json?['success'] != true) {
        setState(() {
          _rows = const [];
          _error = json?['message']?.toString() ?? 'Failed to load 3D history';
          _lastApiInfo = 'HTTP ${res.statusCode}';
          _loading = false;
        });
        return;
      }
      final data = json?['data'];
      final list = data is List
          ? data
          : data is Map && data['rows'] is List
              ? (data['rows'] as List)
              : data is Map && data['bets'] is List
                  ? (data['bets'] as List)
                  : const [];
      final rowsBySlot = <String, List<Map<String, dynamic>>>{};
      for (final e in list) {
        if (e is! Map) continue;
        final row = Map<String, dynamic>.from(e);
        final slotStartIso = (row['slotStartIso'] ?? '').toString().trim().isEmpty
            ? 'unknown-slot'
            : (row['slotStartIso'] ?? '').toString().trim();
        rowsBySlot.putIfAbsent(slotStartIso, () => <Map<String, dynamic>>[]).add(row);
      }

      final mapped = <Map<String, dynamic>>[];
      rowsBySlot.forEach((slotStartIso, slotRows) {
        slotRows.sort((a, b) =>
            DateTime.tryParse('${a['createdAt'] ?? ''}')?.millisecondsSinceEpoch.compareTo(
                  DateTime.tryParse('${b['createdAt'] ?? ''}')?.millisecondsSinceEpoch ?? 0,
                ) ??
                0);
        final first = slotRows.isNotEmpty ? slotRows.first : <String, dynamic>{};
        final createdAt = first['createdAt'];
        final drawDate = _fmtDateOnly(createdAt);
        final drawTime = (first['drawLabelEnd'] ?? '').toString().trim().isNotEmpty
            ? '${first['drawLabelEnd']}'
            : _fmtTimeOnly(createdAt);

        num totalPoints = 0;
        num totalWin = 0;
        bool hasPending = false;
        bool hasWin = false;
        final bets = <Map<String, dynamic>>[];

        for (final row in slotRows) {
          final status = (row['status'] ?? '').toString().toLowerCase();
          final outcome = status == 'win'
              ? 'win'
              : status == 'lose' || status == 'loss'
                  ? 'loss'
                  : status == 'cancelled'
                      ? 'cancelled'
                      : 'pending';
          if (outcome == 'pending') hasPending = true;
          if (outcome == 'win') hasWin = true;
          final qid = int.tryParse('${row['quizId'] ?? ''}') ?? 1;
          final panel = qid == 1 ? 'A' : qid == 2 ? 'B' : 'C';
          final number = (row['number'] ?? '').toString().replaceAll(RegExp(r'\D'), '').padLeft(3, '0');
          final amount = num.tryParse('${row['amount'] ?? 0}') ?? 0;
          final winPayout = num.tryParse('${row['winPayout'] ?? 0}') ?? 0;
          totalPoints += amount;
          totalWin += winPayout;
          bets.add({
            'panel': panel,
            'mode': '${row['betMode'] ?? row['mode'] ?? 'str'}'.toUpperCase(),
            'number': number.length > 3 ? number.substring(number.length - 3) : number,
            'points': amount,
            'outcome': outcome,
            'winAmount': winPayout,
          });
        }

        final outcome = hasPending
            ? 'pending'
            : hasWin
                ? 'win'
                : 'loss';

        final firstCreatedMs =
            DateTime.tryParse('${first['createdAt'] ?? ''}')?.millisecondsSinceEpoch ?? 0;
        final slotStartMs =
            DateTime.tryParse(slotStartIso)?.millisecondsSinceEpoch ?? 0;
        final isAdvanceDraw = slotStartMs > 0 && firstCreatedMs > 0
            ? (slotStartMs - firstCreatedMs) > 60 * 1000
            : false;

        mapped.add({
          'id': 'backend-slot-$slotStartIso',
          'userName': userName.isEmpty ? 'user' : userName,
          'createdAt': createdAt,
          'drawDate': drawDate,
          'drawTime': drawTime,
          'ticketIdDisplay': _slotTicketIdsLine(slotRows),
          'totalPoints': totalPoints,
          'totalWin': totalWin,
          'outcome': outcome,
          'isAdvanceDraw': isAdvanceDraw,
          'bets': bets,
          'slotStartIso': slotStartIso,
        });
      });

      mapped.sort((a, b) {
        final aMs = DateTime.tryParse('${a['slotStartIso'] ?? ''}')?.millisecondsSinceEpoch ?? 0;
        final bMs = DateTime.tryParse('${b['slotStartIso'] ?? ''}')?.millisecondsSinceEpoch ?? 0;
        return bMs.compareTo(aMs);
      });

      final selectedDateKey = _dateKey(_selectedDate);
      final filtered = mapped.where((row) {
        final slotDate = _fmtDateOnly(row['slotStartIso']);
        if (slotDate == selectedDateKey) return true;
        final drawDate = '${row['drawDate'] ?? ''}'.trim();
        if (drawDate == selectedDateKey) return true;
        final createdDate = _fmtDateOnly(row['createdAt']);
        return createdDate == selectedDateKey;
      }).toList();

      setState(() {
        _playerName = userName.isEmpty ? 'user' : userName;
        _rows = filtered;
        _lastApiInfo = '';
        _error = filtered.isEmpty
            ? (json?['message']?.toString() ?? 'No history available for this account yet.')
            : '';
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _rows = const [];
        _error = 'Failed to load 3D history';
        _lastApiInfo = 'Exception while parsing response';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Lottery3DSubPageTemplate(
      title: '3D History',
      subtitle: 'History of 3D game activity',
      icon: Icons.history_rounded,
      headerTrailing: Align(
        alignment: Alignment.centerRight,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              SizedBox(
                height: 30,
                child: OutlinedButton(
                  onPressed: _pickDate,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFD1D5DB)),
                    foregroundColor: Colors.black,
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: Text(_fmtDateOnly(_selectedDate.toIso8601String())),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 30,
                child: ElevatedButton(
                  onPressed: _load,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D4ED8),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: const Text('Refresh'),
                ),
              ),
            ],
          ),
        ),
      ),
      child: Column(
        children: [
          if (_lastApiInfo.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _lastApiInfo,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error.isNotEmpty
                    ? Center(
                        child: Text(
                          _error,
                          style: const TextStyle(
                            color: Color(0xFFB91C1C),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : _rows.isEmpty
                        ? const Center(
                            child: Text(
                              'No 3D history found',
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(8),
                            itemCount: _rows.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 6),
                            itemBuilder: (context, i) {
                              final row = _rows[i];
                              final userName = '${row['userName'] ?? _playerName}';
                              final drawTime = '${row['drawTime'] ?? '-'}';
                              final drawDate = '${row['drawDate'] ?? '-'}';
                              final ticketIdDisplay = '${row['ticketIdDisplay'] ?? '--------'}';
                              final totalPoints = '${row['totalPoints'] ?? 0}';
                              final totalWin = '${row['totalWin'] ?? 0}';
                              final outcome = '${row['outcome'] ?? 'loss'}'.toLowerCase();
                              final isAdvanceDraw = row['isAdvanceDraw'] == true;

                              Color outcomeBg = const Color(0xFFDC2626);
                              String outcomeText = 'Loss';
                              if (outcome == 'win') {
                                outcomeBg = const Color(0xFF19A34A);
                                outcomeText = 'Win';
                              } else if (outcome == 'pending') {
                                outcomeBg = const Color(0xFFD97706);
                                outcomeText = 'Pending';
                              } else if (outcome == 'cancelled') {
                                outcomeBg = const Color(0xFF475569);
                                outcomeText = 'Cancelled';
                              }

                              return Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: const Color(0xFFD1D5DB)),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Wrap(
                                        spacing: 16,
                                        runSpacing: 4,
                                        children: [
                                          _HistoryLine(label: 'User Name', value: userName),
                                          _HistoryLine(label: 'Dr Time', value: drawTime),
                                          _HistoryLine(label: 'Dr Date', value: drawDate),
                                          _HistoryLine(label: 'Ticket ID', value: ticketIdDisplay),
                                          _HistoryLine(label: 'Total Point', value: totalPoints),
                                          _HistoryLine(label: 'Total Win', value: totalWin),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        if (isAdvanceDraw)
                                          Container(
                                            margin: const EdgeInsets.only(bottom: 6),
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF1D4ED8),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'Advance Draw',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: outcomeBg,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            outcomeText,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        SizedBox(
                                          height: 28,
                                          child: ElevatedButton(
                                            onPressed: () => _showTicketDetails(row),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFFDB2F2F),
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                            ),
                                            child: const Text('View'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
    );
    if (picked == null) return;
    setState(() => _selectedDate = picked);
    await _load();
  }

  Future<void> _showTicketDetails(Map<String, dynamic> ticket) async {
    final bets = (ticket['bets'] is List)
        ? List<Map<String, dynamic>>.from((ticket['bets'] as List).whereType<Map>())
        : <Map<String, dynamic>>[];
    await showDialog<void>(
      context: context,
      builder: (_) {
        return Dialog(
          backgroundColor: const Color(0xFFC8C8C8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: SizedBox(
            width: 760,
            height: 460,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFC71616),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'TICKET DATA',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: const Color(0xFFD1D5DB)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _TicketLine(label: 'Agent ID', value: '${ticket['userName'] ?? '-'}'),
                                  _TicketLine(label: 'Coupon Dr Time', value: '${ticket['drawTime'] ?? '-'}'),
                                  _TicketLine(label: 'Coupon Dr Date', value: '${ticket['drawDate'] ?? '-'}'),
                                  _TicketLine(label: 'Total Point', value: '${ticket['totalPoints'] ?? 0}'),
                                  _TicketLine(label: 'Win point', value: '${ticket['totalWin'] ?? 0}'),
                                  _TicketLine(label: 'Ticket ID', value: '${ticket['ticketIdDisplay'] ?? '--------'}'),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: const Color(0xFFD1D5DB)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: ListView.separated(
                              itemCount: bets.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 6),
                              itemBuilder: (context, i) {
                                final b = bets[i];
                                final outcome = '${b['outcome'] ?? 'pending'}'.toLowerCase();
                                final Color bg = outcome == 'win'
                                    ? const Color(0xFFECFDF5)
                                    : outcome == 'cancelled'
                                        ? const Color(0xFFF1F5F9)
                                        : const Color(0xFFD0D0D0);
                                final Color fg = outcome == 'win'
                                    ? const Color(0xFF047857)
                                    : outcome == 'cancelled'
                                        ? const Color(0xFF475569)
                                        : const Color(0xFFC71616);
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: bg,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${b['panel']}${b['number']} [${b['mode']}] x ${b['points']}  |  ${outcome.toUpperCase()}  |  Win: ${b['winAmount']}',
                                    style: TextStyle(
                                      color: fg,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Lottery3DSubPageTemplate extends StatelessWidget {
  const _Lottery3DSubPageTemplate({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.child,
    this.headerTrailing,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? child;
  final Widget? headerTrailing;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(context).textTheme.apply(fontSizeFactor: 0.9),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          ),
        ),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(fontSize: 10),
        child: Container(
          color: Colors.white,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  Row(
                    children: [
                      SizedBox(
                        height: 32,
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.arrow_back, size: 14),
                          label: const Text('Back'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                      ),
                      if (headerTrailing != null) ...[
                        const SizedBox(width: 10),
                        Expanded(child: headerTrailing!),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        border: Border.all(color: const Color(0xFFD9D9D9)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: child ??
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(icon, size: 32, color: const Color(0xFF1E3A8A)),
                                const SizedBox(height: 6),
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  subtitle,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                              ],
                            ),
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
}

class _ResultSetCell extends StatelessWidget {
  const _ResultSetCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final upper = label.toUpperCase();
    final bg = upper == 'A'
        ? const Color(0xFF2563EB)
        : upper == 'B'
            ? const Color(0xFFDC2626)
            : const Color(0xFF059669);
    final border = upper == 'A'
        ? const Color(0xFF1D4ED8)
        : upper == 'B'
            ? const Color(0xFFB91C1C)
            : const Color(0xFF047857);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryLine extends StatelessWidget {
  const _HistoryLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label : $value',
      style: const TextStyle(
        fontSize: 12,
        color: Colors.black,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _TicketLine extends StatelessWidget {
  const _TicketLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        '$label : $value',
        style: const TextStyle(
          fontSize: 13,
          color: Colors.black,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

