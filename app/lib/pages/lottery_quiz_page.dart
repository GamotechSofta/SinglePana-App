import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../services/auth_service.dart';
import '../utils/devanagari_text.dart';

class LotteryQuizPage extends StatefulWidget {
  const LotteryQuizPage({super.key});

  @override
  State<LotteryQuizPage> createState() => _LotteryQuizPageState();
}

class _LotteryQuizPageState extends State<LotteryQuizPage> {
  static const _questionRevealStaggerMs = 8100;

  int _selectedQuiz = 1;
  Map<String, dynamic>? _slotData;
  String _slotErr = '';
  bool _questionsLoading = false;
  String _questionsErr = '';
  List<Map<String, dynamic>> _questions = const [];
  int _visibleQuestionCount = 0;
  Map<String, bool> _answerRevealed = {};
  String? _questionsSlotLoaded;
  int? _questionsQuizLoaded;
  bool _fetchingQuestions = false;
  Map<String, dynamic>? _hintData;
  List<_BetLine> _betLines = const [_BetLine()];
  String? _guessFeedback;
  Map<String, dynamic>? _fairnessResult;
  bool _submitting = false;

  Timer? _slotPoll;
  Timer? _revealTicker;
  Timer? _hintPoll;
  Map<String, dynamic>? _quizSettings;

  @override
  void initState() {
    super.initState();
    unawaited(_configureLandscape());
    unawaited(_loadQuizSettings());
    unawaited(_pollSlotOnce());
    _slotPoll = Timer.periodic(const Duration(seconds: 2), (_) => unawaited(_pollSlotOnce()));
  }

  @override
  void dispose() {
    _slotPoll?.cancel();
    _revealTicker?.cancel();
    _hintPoll?.cancel();
    super.dispose();
  }

  Future<void> _configureLandscape() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<Map<String, String>> _authHeaders() async {
    final user = await AuthService.instance.getStoredUser();
    final token = user?['token']?.toString().trim() ?? '';
    if (token.isEmpty) return const {};
    return {'Authorization': 'Bearer $token'};
  }

  Future<void> _pollSlotOnce() async {
    try {
      final res = await http.get(Uri.parse('$kApiBaseUrl/quiz/slot'));
      final json = jsonDecode(res.body) as Map<String, dynamic>?;
      if (!mounted) return;
      if (res.statusCode >= 200 && res.statusCode < 300 && json?['success'] == true && json?['data'] is Map) {
        final next = Map<String, dynamic>.from(json!['data'] as Map);
        final changedSlot = _slotData?['slotStartIso'] != next['slotStartIso'];
        final changedPhase = _slotData?['phase'] != next['phase'];
        setState(() {
          _slotData = next;
          _slotErr = '';
        });
        if (changedSlot || changedPhase) {
          _resetForNewSlot();
        }
        if (_slotData?['phase'] == 'study') {
          unawaited(_ensureQuestionsForCurrentSlot());
        } else {
          setState(() {
            _questionsLoading = false;
            _questionsErr = '';
          });
        }
        _startRevealTicker();
        _setupHintPoll();
      } else {
        setState(() => _slotErr = json?['message']?.toString() ?? 'Slot sync failed');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _slotErr = 'Slot sync failed');
    }
  }

  Future<void> _loadQuizSettings() async {
    try {
      final res = await http.get(Uri.parse('$kApiBaseUrl/quiz/settings?mode=2d'));
      final json = jsonDecode(res.body) as Map<String, dynamic>?;
      if (!mounted) return;
      if (res.statusCode >= 200 && res.statusCode < 300 && json?['success'] == true && json?['data'] is Map) {
        setState(() => _quizSettings = Map<String, dynamic>.from(json!['data'] as Map));
      }
    } catch (_) {
      // Keep existing behavior if settings are temporarily unavailable.
    }
  }

  void _resetForNewSlot() {
    setState(() {
      _betLines = const [_BetLine()];
      _guessFeedback = null;
      _fairnessResult = null;
      _hintData = null;
      _questions = const [];
      _visibleQuestionCount = 0;
      _answerRevealed = {};
      _questionsSlotLoaded = null;
      _questionsQuizLoaded = null;
    });
  }

  void _startRevealTicker() {
    _revealTicker?.cancel();
    if (_slotData?['slotStartIso'] == null) {
      setState(() => _visibleQuestionCount = 0);
      return;
    }
    void tick() {
      if (!mounted) return;
      final slotStart = DateTime.tryParse('${_slotData?['slotStartIso'] ?? ''}');
      if (slotStart == null || _questions.isEmpty) {
        setState(() => _visibleQuestionCount = 0);
        return;
      }
      final elapsed = DateTime.now().difference(slotStart).inMilliseconds;
      final count = (elapsed <= 0) ? 4 : ((elapsed ~/ _questionRevealStaggerMs) + 1);
      final withMinimum = count < 4 ? 4 : count;
      setState(() => _visibleQuestionCount = withMinimum.clamp(1, _questions.length));
    }

    tick();
    _revealTicker = Timer.periodic(const Duration(milliseconds: 250), (_) => tick());
  }

  void _setupHintPoll() {
    _hintPoll?.cancel();
    if (_slotData?['phase'] != 'hint') {
      setState(() => _hintData = null);
      return;
    }
    Future<void> loadHint() async {
      try {
        final uri = Uri.parse('$kApiBaseUrl/quiz/hint/$_selectedQuiz?mode=2d');
        final res = await http.get(uri);
        final json = jsonDecode(res.body) as Map<String, dynamic>?;
        if (!mounted) return;
        if (res.statusCode >= 200 && res.statusCode < 300 && json?['success'] == true && json?['data'] is Map) {
          setState(() => _hintData = Map<String, dynamic>.from(json!['data'] as Map));
        }
      } catch (_) {}
    }

    unawaited(loadHint());
    _hintPoll = Timer.periodic(const Duration(milliseconds: 2500), (_) => unawaited(loadHint()));
  }

  Future<void> _ensureQuestionsForCurrentSlot() async {
    final slotIso = '${_slotData?['slotStartIso'] ?? ''}';
    if (slotIso.isEmpty || _fetchingQuestions) return;
    final alreadyLoaded =
        _questionsSlotLoaded == slotIso &&
        _questionsQuizLoaded == _selectedQuiz &&
        _questions.isNotEmpty;
    if (alreadyLoaded) return;
    await _loadQuestions(resetExisting: _questionsQuizLoaded != _selectedQuiz || _questionsSlotLoaded != slotIso);
  }

  Future<void> _loadQuestions({required bool resetExisting}) async {
    _fetchingQuestions = true;
    setState(() {
      _questionsLoading = true;
      _questionsErr = '';
      if (resetExisting) {
        _questions = const [];
        _answerRevealed = {};
        _visibleQuestionCount = 0;
      }
    });
    try {
      final uri = Uri.parse('$kApiBaseUrl/quiz/questions/$_selectedQuiz?mode=2d');
      final res = await http.get(uri);
      final json = jsonDecode(res.body) as Map<String, dynamic>?;
      if (!mounted) return;
      if (res.statusCode >= 200 && res.statusCode < 300 && json?['success'] == true) {
        final data = json?['data'];
        final list = (data is Map && data['questions'] is List) ? (data['questions'] as List) : const [];
        final fetched = <Map<String, dynamic>>[
          for (final e in list)
            if (e is Map) Map<String, dynamic>.from(e),
        ];
        setState(() {
          if (resetExisting || _questions.isEmpty) {
            _questions = fetched;
          } else if (fetched.length > _questions.length) {
            // Append only newly available rows instead of reloading all rows every poll.
            _questions = [..._questions, ...fetched.sublist(_questions.length)];
          }
          _questionsSlotLoaded = '${_slotData?['slotStartIso'] ?? ''}';
          _questionsQuizLoaded = _selectedQuiz;
          _questionsLoading = false;
        });
        _startRevealTicker();
      } else {
        setState(() {
          _questionsLoading = false;
          _questionsErr = json?['message']?.toString() ?? 'Failed to load questions';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _questionsLoading = false;
        _questionsErr = 'Failed to load questions';
      });
    }
    _fetchingQuestions = false;
  }

  bool get _hintPhase => (_slotData?['phase'] ?? '') == 'hint';
  bool get _studyPhase => (_slotData?['phase'] ?? '') == 'study';

  bool get _slotOpenForBuy {
    if (_slotData?['slotStartIso'] == null) return false;
    final acceptsBets = _slotData?['acceptsBets'];
    if (acceptsBets is bool) return acceptsBets;
    return _hintPhase;
  }

  String _formatCountdown(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  int _toNonNegativeSeconds(dynamic raw) {
    final value = raw is num ? raw.toInt() : int.tryParse('${raw ?? ''}');
    if (value == null || value < 0) return 0;
    return value;
  }

  int _settingsHintLeadSeconds() {
    final settings = _quizSettings;
    if (settings == null) return 0;
    const keys = [
      'secondsUntilHint',
      'hintLeadSeconds',
      'hintSeconds',
      'hintCountdownSeconds',
      'hintDurationSeconds',
      'hintDurationSec',
    ];
    for (final key in keys) {
      final v = _toNonNegativeSeconds(settings[key]);
      if (v > 0) return v;
    }
    return 0;
  }

  int _secondsUntilHint() {
    final slotSeconds = _toNonNegativeSeconds(_slotData?['secondsUntilHint']);
    if (slotSeconds > 0) return slotSeconds;

    final nextIso = '${_slotData?['nextSlotStartIso'] ?? ''}'.trim();
    final nextSlotStart = DateTime.tryParse(nextIso)?.toLocal();
    if (nextSlotStart != null) {
      final diff = nextSlotStart.difference(DateTime.now()).inSeconds;
      final fallback = _settingsHintLeadSeconds();
      if (diff > 0 && fallback > 0) {
        final derived = diff - fallback;
        if (derived > 0) return derived;
      }
    }
    return 0;
  }

  String _hintQuestionText(Map<String, dynamic>? hint) {
    if (hint == null) return '';
    const keys = ['questionText', 'question', 'text', 'hintQuestion'];
    for (final key in keys) {
      final value = '${hint[key] ?? ''}'.trim();
      if (value.isNotEmpty) return value;
    }
    final nested = hint['questionData'];
    if (nested is Map) {
      for (final key in keys) {
        final value = '${nested[key] ?? ''}'.trim();
        if (value.isNotEmpty) return value;
      }
    }
    return '';
  }

  Future<void> _submitQuizBets() async {
    if (_submitting) return;
    if (!_slotOpenForBuy) {
      setState(() => _guessFeedback = 'Current draw slot is closed or loading. Please wait.');
      return;
    }
    final parsed = <Map<String, int>>[];
    for (final line in _betLines) {
      final numberRaw = line.number.replaceAll(RegExp(r'\D'), '').padLeft(2, '0');
      final amountNum = int.tryParse(line.amount.replaceAll(RegExp(r'\D'), '')) ?? 0;
      final isBlank = line.number.trim().isEmpty && line.amount.trim().isEmpty;
      if (isBlank) continue;
      if (numberRaw.length != 2) {
        setState(() => _guessFeedback = 'For each line, enter a 2-digit number (00-99).');
        return;
      }
      final n = int.tryParse(numberRaw) ?? -1;
      if (n < 0 || n > 99 || amountNum < 1) {
        setState(() => _guessFeedback = 'Each bet must have number 00-99 and minimum amount 1.');
        return;
      }
      parsed.add({'number': n, 'amount': amountNum});
    }
    if (parsed.isEmpty) {
      setState(() => _guessFeedback = 'Enter at least one bet (number + amount).');
      return;
    }
    final seen = <int>{};
    for (final p in parsed) {
      final n = p['number']!;
      if (seen.contains(n)) {
        setState(() => _guessFeedback = 'Duplicate numbers are not allowed in the same slot.');
        return;
      }
      seen.add(n);
    }

    setState(() => _submitting = true);
    try {
      final headers = await _authHeaders();
      if (headers.isEmpty) {
        setState(() => _guessFeedback = 'Please login to place bets.');
        return;
      }
      final res = await http.post(
        Uri.parse('$kApiBaseUrl/quiz/bet'),
        headers: {'Content-Type': 'application/json', ...headers},
        body: jsonEncode({'quizId': _selectedQuiz, 'bets': parsed, 'mode': '2d'}),
      );
      final json = jsonDecode(res.body) as Map<String, dynamic>?;
      if (res.statusCode < 200 || res.statusCode >= 300) {
        setState(() => _guessFeedback = json?['message']?.toString() ?? 'Bet submission failed.');
        return;
      }

      final slotStartIso = '${_slotData?['slotStartIso'] ?? ''}';
      try {
        final resultRes = await http.get(
          Uri.parse('$kApiBaseUrl/quiz/result/$_selectedQuiz?slotStartIso=${Uri.encodeComponent(slotStartIso)}&mode=2d'),
        );
        final resultJson = jsonDecode(resultRes.body) as Map<String, dynamic>?;
        if (resultRes.statusCode >= 200 && resultRes.statusCode < 300 && resultJson?['success'] == true && resultJson?['data'] is Map) {
          final data = Map<String, dynamic>.from(resultJson!['data'] as Map);
          final idx = '${data['questionIndex'] ?? ''}'.padLeft(2, '0');
          final hit = parsed.any((e) => '${e['number']}'.padLeft(2, '0') == idx);
          setState(() {
            _fairnessResult = {
              'quizId': _selectedQuiz,
              'seed': data['seed'],
              'seedHash': data['seedHash'],
              'questionIndex': idx,
            };
            _guessFeedback = hit
                ? 'Bet submitted. Correct number $idx (winnings credited after slot closes).'
                : 'Bet submitted. Winning number $idx.';
          });
        } else {
          setState(() => _guessFeedback = 'Bet submitted. Result will be shown after slot ends.');
        }
      } catch (_) {
        setState(() => _guessFeedback = 'Bet submitted. Result will be shown after slot ends.');
      }
    } catch (_) {
      setState(() => _guessFeedback = 'Bet submission failed.');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Widget _buildQuizSelector() {
    return GridView.builder(
      padding: const EdgeInsets.all(0),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 30,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 15,
        mainAxisSpacing: 3,
        crossAxisSpacing: 3,
        mainAxisExtent: 24,
      ),
      itemBuilder: (context, i) {
        final n = i + 1;
        final selected = _selectedQuiz == n;
        return ElevatedButton(
          onPressed: () {
            setState(() {
              _selectedQuiz = n;
              _hintData = null;
              _guessFeedback = null;
              _fairnessResult = null;
              _questions = const [];
              _answerRevealed = {};
              _visibleQuestionCount = 0;
              _questionsQuizLoaded = null;
            });
            if (_studyPhase) {
              unawaited(_ensureQuestionsForCurrentSlot());
            }
            _setupHintPoll();
          },
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: selected ? const Color(0xFFF5E14A) : const Color(0xFF5C2222),
            foregroundColor: selected ? Colors.black : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
              side: BorderSide(color: selected ? const Color(0xFFC9B429) : const Color(0xFF3D1515), width: 1.5),
            ),
            padding: EdgeInsets.zero,
          ),
          child: Text(
            'Q-${n.toString().padLeft(2, '0')}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 9),
          ),
        );
      },
    );
  }

  Widget _buildQuestionsOptionsPanel(String drawCurrent) {
    if (_questionsLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_questionsErr.isNotEmpty) {
      return Center(
        child: Text(
          _questionsErr,
          style: const TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.w700, fontSize: 11),
        ),
      );
    }
    if (_questions.isEmpty) {
      return const Center(
        child: Text(
          'No questions available.',
          style: TextStyle(color: Color(0xFF5C2222), fontWeight: FontWeight.w700, fontSize: 11),
        ),
      );
    }

    final orderHint = _studyQuestionSourceIndices();
    return ListView.builder(
      padding: const EdgeInsets.all(6),
      itemCount: _visibleQuestionCount.clamp(0, orderHint.length),
      itemBuilder: (context, i) {
        final srcIdx = orderHint[i];
        final row = _questions[srcIdx];
        final rowId = '${row['id'] ?? srcIdx}';
        final options = (row['options'] is Map) ? Map<String, dynamic>.from(row['options'] as Map) : <String, dynamic>{};
        final revealed = _answerRevealed[rowId] ?? false;
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFF8B7355)),
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.all(6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Q${(srcIdx + 1).toString().padLeft(_questions.length > 99 ? 3 : 2, '0')} · $drawCurrent',
                      style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: Color(0xFF1A4D2E)),
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () => setState(() => _answerRevealed[rowId] = !revealed),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Color(0xFF8B7355)),
                    ),
                    child: Text(
                      revealed ? 'HIDE ANS' : 'SHOW ANS',
                      style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Container(
                width: double.infinity,
                color: const Color(0xFFFCD4DC),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                child: Text(
                  '${row['question'] ?? ''}',
                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Colors.black),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                color: const Color(0xFFCFE9F6),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 2,
                  children: ['A', 'B', 'C', 'D']
                      .map(
                        (k) => Text(
                          '$k: ${options[k] ?? ''}',
                          style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: Colors.black),
                        ),
                      )
                      .toList(),
                ),
              ),
              if (revealed)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    'Answer: ${row['answer'] ?? '-'}',
                    style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: Color(0xFF1A4A7A)),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final drawCurrent = '${_slotData?['drawLabelCurrent'] ?? '-'}';
    final remainingSlots = _remainingSlotsForToday();
    final secsHint = _secondsUntilHint();
    final secsEnd = _toNonNegativeSeconds(_slotData?['secondsUntilSlotEnd']);
    final quizLabel = 'QUIZ${_selectedQuiz.toString().padLeft(2, '0')}';

    return ColoredBox(
      color: const Color(0xFFEFE6D5),
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: const TextScaler.linear(0.9),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
          children: [
            Container(
              color: const Color(0xFFEFE6D5),
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
              child: Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text('2D'),
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: const Color(0xFF5C2222),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: Color(0xFF3D1515), width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _slotErr.isNotEmpty
                          ? 'Server: $_slotErr'
                          : _hintPhase
                              ? 'Hint phase - Draw: $drawCurrent (${_formatCountdown(secsEnd)})'
                              : 'Hint in ${_formatCountdown(secsHint)}',
                      style: const TextStyle(
                        color: Color(0xFF5C2222),
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 360,
                    height: 30,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: remainingSlots.isEmpty
                          ? const Center(
                              child: Text(
                                'No remaining slots',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                          : ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: remainingSlots.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 4),
                              itemBuilder: (context, i) => _drawBadge(
                                remainingSlots[i],
                                i == 0,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Column(
                  children: [
                    Text(
                      _hintPhase
                          ? 'Each quiz gets a unique question and result per slot. Select Q-01...Q-30 below to view hint.'
                          : 'Study: Select a quiz below - 100 questions each.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF5C2222),
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 0),
                    SizedBox(
                      height: 51,
                      child: _buildQuizSelector(),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: _hintPhase
                          ? _buildHintCard(drawCurrent)
                          : _buildStudyTable(quizLabel, drawCurrent),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 34,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: const Color(0xFFF5E14A),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                            side: const BorderSide(color: Color(0xFFB8A01E), width: 2),
                          ),
                        ),
                        child: const Text('PLAY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }

  Widget _drawBadge(String label, bool active) {
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? const Color(0xFFF5E14A) : const Color(0xFF5C2222),
        border: Border.all(color: active ? const Color(0xFFC9B429) : const Color(0xFF3D1515), width: 2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? Colors.black : Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 11.5,
        ),
      ),
    );
  }

  Widget _buildHintCard(String drawCurrent) {
    final hintLoading =
        _hintData == null || int.tryParse('${_hintData?['quizId'] ?? ''}') != _selectedQuiz;
    final questionText = _hintQuestionText(_hintData);

    if (hintLoading) {
      return const Center(
        child: Text(
          'Loading hint...',
          style: TextStyle(
            color: Color(0xFF5C2222),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFF8B7355)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hint · $drawCurrent · QUIZ-${_selectedQuiz.toString().padLeft(2, '0')}',
            style: quizDevanagariTextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1A6B2E),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'या प्रश्नाचा योग्य क्रमांक काय आहे?',
            style: quizDevanagariTextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF4A1515),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            questionText.isEmpty ? '-' : questionText,
            style: quizDevanagariTextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
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

  List<int> _studyQuestionSourceIndices() {
    final n = _questions.length;
    if (n == 0) return const [];
    final order = List<int>.generate(n, (i) => i);
    order.sort((a, b) {
      final aq = int.tryParse('${_questions[a]['questionNo'] ?? ''}');
      final bq = int.tryParse('${_questions[b]['questionNo'] ?? ''}');
      if (aq != null && bq != null) return bq.compareTo(aq);
      if (aq != null) return -1;
      if (bq != null) return 1;
      return b.compareTo(a);
    });
    return order;
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

  Widget _buildStudyTable(String quizLabel, String drawCurrent) {
    final order = _studyQuestionSourceIndices();
    final totalRows = _visibleQuestionCount.clamp(0, order.length);
    const borderColor = Color(0xFFCFB187);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF8B7355)),
        color: Colors.white,
      ),
      child: _questionsLoading
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          : _questionsErr.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(_questionsErr, style: const TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.w700)),
                )
              : Column(
                  children: [
                    SizedBox(
                      height: 28,
                      child: Row(
                        children: [
                          Expanded(
                            flex: 16,
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Color(0xFFF79B3A),
                                border: Border(right: BorderSide(color: borderColor), bottom: BorderSide(color: borderColor)),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                quizLabel,
                                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 10.5),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 74,
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Color(0xFFF79B3A),
                                border: Border(right: BorderSide(color: borderColor), bottom: BorderSide(color: borderColor)),
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                'QUESTION',
                                style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 10.5),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 34,
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Color(0xFFF79B3A),
                                border: Border(right: BorderSide(color: borderColor), bottom: BorderSide(color: borderColor)),
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                'OPTIONS',
                                style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 10.5),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 8,
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Color(0xFFF79B3A),
                                border: Border(bottom: BorderSide(color: borderColor)),
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                'ANS',
                                style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 10.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: totalRows,
                        itemBuilder: (context, i) {
                          final srcIdx = order[i];
                          final row = _questions[srcIdx];
                          final id = '${row['id'] ?? srcIdx}';
                          final qnPad = _questions.length > 99 ? 3 : 2;
                          final questionNo = int.tryParse('${row['questionNo'] ?? ''}');
                          final options = (row['options'] is Map) ? Map<String, dynamic>.from(row['options'] as Map) : <String, dynamic>{};
                          final reveal = _answerRevealed[id] ?? false;
                          return SizedBox(
                            height: 64,
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 16,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFB8E6A8),
                                      border: Border(right: BorderSide(color: borderColor), bottom: BorderSide(color: borderColor)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Question No. ${((questionNo ?? (srcIdx + 1))).toString().padLeft(qnPad, '0')}',
                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.black),
                                        ),
                                        Text(
                                          drawCurrent,
                                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.black),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 74,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFFCD4DC),
                                      border: Border(right: BorderSide(color: borderColor), bottom: BorderSide(color: borderColor)),
                                    ),
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      '${row['question'] ?? ''}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.black),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 34,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFCFE9F6),
                                      border: Border(right: BorderSide(color: borderColor), bottom: BorderSide(color: borderColor)),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('A: ${options['A'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.black)),
                                              Text('C: ${options['C'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.black)),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('B: ${options['B'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.black)),
                                              Text('D: ${options['D'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.black)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 8,
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF1A4A7A),
                                      border: Border(bottom: BorderSide(color: borderColor)),
                                    ),
                                    alignment: Alignment.center,
                                    child: TextButton(
                                      onPressed: () => setState(() => _answerRevealed[id] = !reveal),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                                        minimumSize: const Size(0, 0),
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: Text(
                                        reveal ? '${row['answer'] ?? ''}' : 'HIDE',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10.5),
                                      ),
                                    ),
                                  ),
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

  Widget _buildHintAndBetPanel() {
    final hintLoading = _hintPhase && (_hintData == null || int.tryParse('${_hintData?['quizId'] ?? ''}') != _selectedQuiz);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF8B7355)),
        color: const Color(0xFFF5F0E6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_hintPhase && !hintLoading && _hintData != null) ...[
            Row(
              children: [
                Container(
                  width: 92,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8F5E9),
                    border: Border(right: BorderSide(color: Color(0xFF8B7355))),
                  ),
                  child: const Text('Hint', style: TextStyle(color: Color(0xFF1A6B2E), fontWeight: FontWeight.w800, fontSize: 18)),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('या प्रश्नाचे उत्तर या प्रश्नाचा क्रमांक आहे', style: TextStyle(color: Color(0xFF4A1515), fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text('${_hintData?['questionText'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if ((_hintData?['seedHash'] ?? '').toString().isNotEmpty)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Color(0xFFF0F4FF),
                  border: Border(top: BorderSide(color: Color(0xFFDDBBCC))),
                ),
                child: Text(
                  'Fairness hash: ${_hintData?['seedHash'] ?? ''}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF1A2A5C), fontWeight: FontWeight.w700),
                ),
              ),
          ],
          if (hintLoading)
            const Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'Loading hint...',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF5C2222), fontWeight: FontWeight.w700),
              ),
            ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFF8B7355))),
            ),
            child: Column(
              children: [
                for (int i = 0; i < _betLines.length; i++) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          key: ValueKey('n_${i}_${_betLines[i].number}'),
                          initialValue: _betLines[i].number,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Number (00-99)',
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
                          onChanged: (v) => _betLines[i] = _betLines[i].copyWith(number: v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          key: ValueKey('a_${i}_${_betLines[i].amount}'),
                          initialValue: _betLines[i].amount,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Amount',
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                          onChanged: (v) => _betLines[i] = _betLines[i].copyWith(amount: v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _betLines.length == 1
                            ? null
                            : () => setState(() => _betLines = [..._betLines]..removeAt(i)),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _betLines = [..._betLines, const _BetLine()]),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Row'),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _submitting ? null : () => unawaited(_submitQuizBets()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF3F34),
                          foregroundColor: Colors.white,
                        ),
                        child: Text(_submitting ? 'Submitting...' : 'Submit Bet'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_guessFeedback != null && _guessFeedback!.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              color: const Color(0xFFEFE6D5),
              child: Text(_guessFeedback!, style: const TextStyle(color: Color(0xFF3D1515), fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }

  Widget _buildFairnessPanel() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF8F0),
        border: Border.all(color: const Color(0xFF7A9E5C)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fairness (after slot closes) · QUIZ${(_fairnessResult?['quizId'] ?? 0).toString().padLeft(2, '0')}',
            style: const TextStyle(color: Color(0xFF1A4D2E), fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text('Winning number: ${_fairnessResult?['questionIndex'] ?? '-'}', style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('Seed hash: ${_fairnessResult?['seedHash'] ?? '-'}', style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _BetLine {
  const _BetLine({this.number = '', this.amount = ''});

  final String number;
  final String amount;

  _BetLine copyWith({String? number, String? amount}) {
    return _BetLine(
      number: number ?? this.number,
      amount: amount ?? this.amount,
    );
  }
}

