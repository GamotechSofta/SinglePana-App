import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'lottery_2d_advance_page.dart';
import '../services/auth_service.dart';
import '../services/wallet_service.dart';

class LotteryPage extends StatefulWidget {
  const LotteryPage({super.key});

  @override
  State<LotteryPage> createState() => _LotteryPageState();
}

class _LotteryPageState extends State<LotteryPage> {
  static const double _baseWidth = 1536;
  static const double _baseHeight = 864;
  static const int _defaultTimerSeconds = 900;

  Timer? _clockTicker;
  Timer? _marqueeTicker;
  Timer? _slotTicker;
  DateTime _now = DateTime.now();
  double _marqueeOffset = 0;
  String _lotteryNews = 'Welcome Diamond';

  int _activeQuiz = 1;
  bool _multi = false;
  Set<int> _selectedQuizzes = {1};

  _Target? _pendingTarget;
  String _activeFilter = 'all';
  String _amountDraft = '0';
  int _enteredAmount = 2;

  final Map<String, int> _selectedMap = {};
  final Map<String, int> _appliedAmountByTarget = {};
  final List<String> _rowPointDisplay = List.filled(10, '');
  final List<String> _colPointDisplay = List.filled(10, '');
  bool _restoringPortrait = false;
  num _walletBalance = 0;
  String _slotSyncErr = '';
  Map<String, dynamic>? _serverSlot;
  bool _buying = false;
  Map<int, int?> _lastSlotByQuiz = {};
  String _previousSlotTimeLabel = '';
  List<String> _selectedAdvanceSlots = const [];
  final TransformationController _zoomController = TransformationController();
  bool _isZoomedIn = false;

  @override
  void initState() {
    super.initState();
    _zoomController.addListener(_handleZoomTransformChanged);
    unawaited(_configureOrientationForLottery());
    unawaited(_loadWalletBalance());
    unawaited(_syncQuizSlot());
    unawaited(_syncLastSlotResult());
    unawaited(_loadLotteryNews());
    _slotTicker = Timer.periodic(const Duration(seconds: 4), (_) {
      unawaited(_syncQuizSlot());
      unawaited(_syncLastSlotResult());
    });
    _clockTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
    _marqueeTicker = Timer.periodic(const Duration(milliseconds: 35), (_) {
      if (!mounted) return;
      setState(() {
        _marqueeOffset += 1.2;
        if (_marqueeOffset >= 800) _marqueeOffset = 0;
      });
    });
  }

  @override
  void dispose() {
    _clockTicker?.cancel();
    _marqueeTicker?.cancel();
    _slotTicker?.cancel();
    _zoomController.removeListener(_handleZoomTransformChanged);
    _zoomController.dispose();
    super.dispose();
  }

  void _handleZoomTransformChanged() {
    final zoomed = _zoomController.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed == _isZoomedIn || !mounted) return;
    setState(() => _isZoomedIn = zoomed);
  }

  Future<void> _configureOrientationForLottery() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _restorePortraitOrientation() async {
    if (_restoringPortrait) return;
    _restoringPortrait = true;
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);
    _restoringPortrait = false;
  }

  Future<void> _exitLottery() async {
    await _restorePortraitOrientation();
    if (!mounted) return;
    await Navigator.of(context).maybePop();
  }

  Future<void> _openMyBets2D() async {
    if (!mounted) return;
    await Navigator.of(context).pushNamed('/lottery/my-bets-2d');
  }

  Future<void> _openThreeD() async {
    if (!mounted) return;
    await Navigator.of(context).pushNamed('/lottery/3d');
  }

  Future<Map<String, String>> _authHeaders() async {
    final user = await AuthService.instance.getStoredUser();
    final token = user?['token']?.toString().trim() ?? '';
    if (token.isEmpty) return const {};
    return {'Authorization': 'Bearer $token'};
  }

  Future<void> _loadWalletBalance() async {
    try {
      final result = await WalletService.instance.fetchBalance();
      if (!mounted) return;
      if (result.success && result.balance != null) {
        setState(() => _walletBalance = result.balance!);
        return;
      }

      final user = await AuthService.instance.getStoredUser();
      final fallback =
          user?['balance'] ?? user?['walletBalance'] ?? user?['wallet'] ?? 0;
      final parsed = fallback is num
          ? fallback
          : num.tryParse(fallback.toString()) ?? 0;
      if (!mounted) return;
      setState(() => _walletBalance = parsed);
    } catch (_) {
      if (!mounted) return;
      setState(() => _walletBalance = 0);
    }
  }

  Future<void> _syncQuizSlot() async {
    try {
      final uri = Uri.parse('$kApiBaseUrl/quiz/slot');
      final res = await http.get(uri);
      final body = jsonDecode(res.body) as Map<String, dynamic>?;
      if (!mounted) return;
      if (res.statusCode >= 200 &&
          res.statusCode < 300 &&
          body?['success'] == true &&
          body?['data'] is Map) {
        setState(() {
          _serverSlot = Map<String, dynamic>.from(body!['data'] as Map);
          _slotSyncErr = '';
        });
      } else {
        setState(() {
          _slotSyncErr = body?['message']?.toString() ?? 'Failed to sync slot';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _slotSyncErr = 'Failed to sync slot');
    }
  }

  Future<void> _syncLastSlotResult() async {
    try {
      final uri = Uri.parse('$kApiBaseUrl/quiz/slot-results?limit=1&mode=2d');
      final res = await http.get(uri);
      final body = jsonDecode(res.body) as Map<String, dynamic>?;
      if (!mounted) return;
      if (res.statusCode < 200 ||
          res.statusCode >= 300 ||
          body?['success'] != true) {
        setState(() {
          _lastSlotByQuiz = {};
          _previousSlotTimeLabel = '';
        });
        return;
      }

      final data = body?['data'];
      if (data is! List || data.isEmpty || data.first is! Map) {
        setState(() {
          _lastSlotByQuiz = {};
          _previousSlotTimeLabel = '';
        });
        return;
      }

      final slot = Map<String, dynamic>.from(data.first as Map);
      final picks = slot['picks'];
      final next = <int, int?>{};
      if (picks is List) {
        for (final p in picks) {
          if (p is! Map) continue;
          final quizId = int.tryParse('${p['quizId'] ?? ''}');
          if (quizId == null || quizId < 1 || quizId > 30) continue;
          final winning = int.tryParse('${p['winningPosition'] ?? ''}');
          next[quizId] = (winning != null && winning >= 0 && winning <= 99)
              ? winning
              : null;
        }
      }

      final drawLabel = (slot['drawLabelEnd'] ?? '').toString().trim();
      setState(() {
        _lastSlotByQuiz = next;
        _previousSlotTimeLabel = drawLabel;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _lastSlotByQuiz = {};
        _previousSlotTimeLabel = '';
      });
    }
  }

  String _extractLotteryNews(Map<String, dynamic>? body) {
    if (body == null) return '';
    final data = body['data'];
    if (data is String && data.trim().isNotEmpty) return data.trim();
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      for (final key in [
        'lotteryNews',
        'lottery_news',
        'news',
        'message',
        'text',
        'title',
        'content',
      ]) {
        final v = map[key]?.toString().trim() ?? '';
        if (v.isNotEmpty) return v;
      }
    }
    for (final key in ['lotteryNews', 'lottery_news', 'message', 'news']) {
      final v = body[key]?.toString().trim() ?? '';
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  Future<void> _loadLotteryNews() async {
    try {
      final uri = Uri.parse('$kApiBaseUrl/banner-settings/lottery-news');
      final res = await http.get(uri);
      final body = jsonDecode(res.body) as Map<String, dynamic>?;
      if (!mounted) return;
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final text = _extractLotteryNews(body);
        if (text.isNotEmpty) {
          setState(() => _lotteryNews = text);
        }
      }
    } catch (_) {
      // keep fallback text if API fails
    }
  }

  bool get _slotOpenForBuy {
    if (_serverSlot == null) return false;
    final acceptsBets = _serverSlot?['acceptsBets'];
    if (acceptsBets is bool) return acceptsBets;
    final phase = (_serverSlot?['phase'] ?? '').toString().toLowerCase();
    return phase == 'hint';
  }

  Future<void> _handleBoardBuy() async {
    if (_buying) return;
    if (_totalAmount <= 0) {
      _showNote('Please add amount on board first.');
      return;
    }
    if (_slotSyncErr.isNotEmpty || _serverSlot == null) {
      _showNote('Server slot not available. Please try again.');
      return;
    }
    if (!_slotOpenForBuy) {
      _showNote(
        'BUY works only while the current 15-minute draw slot is open.',
      );
      return;
    }

    final grouped = <int, Map<int, int>>{};
    _selectedMap.forEach((key, amount) {
      if (amount <= 0) return;
      final parts = key.split('-');
      if (parts.length != 2) return;
      final quizId = int.tryParse(parts[0]) ?? -1;
      final num = int.tryParse(parts[1]) ?? -1;
      if (quizId < 1 || quizId > 30 || num < 0 || num > 99) return;
      final byNum = grouped.putIfAbsent(quizId, () => <int, int>{});
      byNum[num] = (byNum[num] ?? 0) + amount;
    });

    if (grouped.isEmpty) {
      _showNote('Please add amount on board first.');
      return;
    }

    final previewLines = <_BetPreviewLine>[
      for (final entry in grouped.entries)
        for (final bet in entry.value.entries)
          _BetPreviewLine(quizId: entry.key, number: bet.key, amount: bet.value),
    ]..sort((a, b) {
        final quizCmp = a.quizId.compareTo(b.quizId);
        if (quizCmp != 0) return quizCmp;
        return a.number.compareTo(b.number);
      });

    final approvedLines = await _showBetPreviewDialog(previewLines);
    if (approvedLines == null) return;
    if (approvedLines.isEmpty) {
      _showNote('Please keep at least one bet line.');
      return;
    }

    final regrouped = <int, Map<int, int>>{};
    for (final line in approvedLines) {
      final byNum = regrouped.putIfAbsent(line.quizId, () => <int, int>{});
      byNum[line.number] = line.amount;
    }

    // Reflect removals made in preview immediately on board data.
    setState(() {
      _selectedMap
        ..clear()
        ..addEntries(
          approvedLines.map(
            (line) => MapEntry('${line.quizId}-${line.number}', line.amount),
          ),
        );
    });

    final rounds = regrouped.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final payloadRounds = [
      for (final entry in rounds)
        {
          'quizId': entry.key,
          'bets': [
            for (final bet in entry.value.entries)
              {'number': bet.key, 'amount': bet.value},
          ],
        },
    ];

    setState(() => _buying = true);
    try {
      final headers = await _authHeaders();
      final targetSlots = _selectedAdvanceSlots.isNotEmpty
          ? List<String>.from(_selectedAdvanceSlots)
          : <String>[];
      num? parsedBalance;
      var placedLines = 0;
      for (final slotStartIso in (targetSlots.isEmpty ? <String?>[null] : targetSlots)) {
        final payload = <String, dynamic>{'rounds': payloadRounds, 'mode': '2d'};
        if (slotStartIso != null && slotStartIso.isNotEmpty) {
          payload['slotStartIso'] = slotStartIso;
        }
        final res = await http.post(
          Uri.parse('$kApiBaseUrl/quiz/bet-batch'),
          headers: {'Content-Type': 'application/json', ...headers},
          body: jsonEncode(payload),
        );
        final body = jsonDecode(res.body) as Map<String, dynamic>?;
        if (res.statusCode < 200 || res.statusCode >= 300) {
          _showNote(body?['message']?.toString() ?? 'BUY failed');
          return;
        }
        final data = (body?['data'] is Map)
            ? Map<String, dynamic>.from(body!['data'] as Map)
            : <String, dynamic>{};
        final nextBalance = data['balance'];
        final b = nextBalance is num
            ? nextBalance
            : num.tryParse('${nextBalance ?? ''}');
        if (b != null) parsedBalance = b;
        final lines = int.tryParse('${data['linesProcessed'] ?? data['totalBetsPlaced'] ?? 0}') ?? 0;
        placedLines += lines;
      }
      if (parsedBalance != null) {
        await AuthService.instance.updateStoredBalance(parsedBalance);
        if (mounted) setState(() => _walletBalance = parsedBalance!);
      } else {
        await _loadWalletBalance();
      }

      if (!mounted) return;
      _handleResetAll();
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text(
            'Bet Success',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          content: Text(
            targetSlots.isNotEmpty
                ? 'Ticket submitted successfully.\nAdvance slots: ${targetSlots.length}'
                : 'Ticket submitted successfully.',
            style: const TextStyle(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK', style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
      );
    } catch (_) {
      _showNote('BUY failed');
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  Future<List<_BetPreviewLine>?> _showBetPreviewDialog(
    List<_BetPreviewLine> lines,
  ) async {
    final draft = List<_BetPreviewLine>.from(lines);
    return showDialog<List<_BetPreviewLine>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final total = draft.fold<int>(0, (sum, e) => sum + e.amount);
            final drawTime = _formatTimeNoSeconds(_nextDrawAt());
            return Dialog(
              backgroundColor: const Color(0xFF0E1A37),
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: Color(0xFF1D2A4C)),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 760,
                  maxHeight: MediaQuery.of(ctx).size.height * 0.88,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                      const Text(
                        'You want to place bet?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            color: Color(0xFFD1D5DB),
                            fontSize: 12,
                          ),
                          children: [
                            TextSpan(text: 'Total Bets: ${draft.length} | Total Amount: '),
                            TextSpan(
                              text: '₹$total',
                              style: const TextStyle(
                                color: Color(0xFFFACC15),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            color: Color(0xFFD1D5DB),
                            fontSize: 12,
                          ),
                          children: [
                            const TextSpan(text: 'Draw Time: '),
                            TextSpan(
                              text: drawTime,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 260),
                        decoration: BoxDecoration(
                          color: const Color(0xFF07132E),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF2A3A60)),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: draft.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, color: Color(0xFF2A3A60)),
                          itemBuilder: (context, index) {
                            final line = draft[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Quiz ${line.quizId.toString().padLeft(2, '0')}  |  No. ${line.number.toString().padLeft(2, '0')}  |  ₹${line.amount}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    height: 36,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        setModalState(() => draft.removeAt(index));
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFB91C1C),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          side: const BorderSide(color: Color(0xFFEF4444)),
                                        ),
                                      ),
                                      child: const Text(
                                        'Remove',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
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
                      const SizedBox(height: 14),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 42,
                              child: OutlinedButton(
                                onPressed: () => Navigator.of(ctx).pop(null),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFF3B4A72)),
                                  foregroundColor: Colors.white,
                                  backgroundColor: const Color(0xFF1A2746),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 0,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    height: 1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SizedBox(
                              height: 42,
                              child: ElevatedButton(
                                onPressed: draft.isEmpty
                                    ? null
                                    : () => Navigator.of(ctx).pop(
                                          List<_BetPreviewLine>.from(draft),
                                        ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF38BDF8),
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Color(0xFF0EA5E9)),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 0,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'BUY',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    height: 1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _pad2(int n) => n.toString().padLeft(2, '0');
  String _cellKey(int quiz, int num) => '$quiz-$num';

  int get _timerSeconds {
    final elapsed = (_now.minute % 15) * 60 + _now.second;
    final remaining = _defaultTimerSeconds - elapsed;
    return remaining <= 0 ? _defaultTimerSeconds : remaining;
  }

  String _formatTimer(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  String _formatDate(DateTime d) {
    return '${_pad2(d.day)}/${_pad2(d.month)}/${d.year}';
  }

  String _formatTime(DateTime d) {
    final hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final suffix = d.hour >= 12 ? 'PM' : 'AM';
    return '${_pad2(hour12)}:${_pad2(d.minute)}:${_pad2(d.second)} $suffix';
  }

  String _formatTimeNoSeconds(DateTime d) {
    final hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final suffix = d.hour >= 12 ? 'PM' : 'AM';
    return '${_pad2(hour12)}:${_pad2(d.minute)} $suffix';
  }

  DateTime get _nextQuarter {
    final next = DateTime(
      _now.year,
      _now.month,
      _now.day,
      _now.hour,
      _now.minute,
    );
    final currentMinutes = next.hour * 60 + next.minute;
    final nextQuarterMinutes = (currentMinutes ~/ 15 + 1) * 15;
    final wrapped = nextQuarterMinutes % (24 * 60);
    final dayCarry = nextQuarterMinutes >= (24 * 60) ? 1 : 0;
    return DateTime(
      next.year,
      next.month,
      next.day + dayCarry,
      wrapped ~/ 60,
      wrapped % 60,
    );
  }

  bool _isVisible(int num) {
    if (_activeFilter == 'even') return num % 2 == 0;
    if (_activeFilter == 'odd') return num % 2 != 0;
    return true;
  }

  void _showNote(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _handleQuizToggle(int quizNo) {
    setState(() {
      _activeQuiz = quizNo;
      if (!_multi) {
        _selectedQuizzes = {quizNo};
      } else {
        if (_selectedQuizzes.contains(quizNo)) {
          if (_selectedQuizzes.length > 1) _selectedQuizzes.remove(quizNo);
        } else {
          _selectedQuizzes.add(quizNo);
        }
      }
      _appliedAmountByTarget.clear();
    });
  }

  void _handleAllToggle(bool checked) {
    setState(() {
      _appliedAmountByTarget.clear();
      if (checked) {
        _multi = true;
        _selectedQuizzes = {for (var i = 1; i <= 30; i++) i};
      } else {
        _selectedQuizzes = {_activeQuiz};
      }
    });
  }

  void _handleMultiToggle(bool checked) {
    setState(() {
      _multi = checked;
      if (!checked) _selectedQuizzes = {_activeQuiz};
      _appliedAmountByTarget.clear();
    });
  }

  bool _isSetChecked(int start, int end) {
    for (var quizNo = start; quizNo <= end; quizNo++) {
      if (!_selectedQuizzes.contains(quizNo)) return false;
    }
    return true;
  }

  void _handleSetToggle({
    required int start,
    required int end,
    required bool checked,
  }) {
    setState(() {
      _appliedAmountByTarget.clear();
      if (checked) {
        _multi = true;
        _activeQuiz = start;
        for (var quizNo = start; quizNo <= end; quizNo++) {
          _selectedQuizzes.add(quizNo);
        }
      } else {
        for (var quizNo = start; quizNo <= end; quizNo++) {
          _selectedQuizzes.remove(quizNo);
        }
        if (_selectedQuizzes.isEmpty) {
          _multi = false;
          _activeQuiz = start;
          _selectedQuizzes = {_activeQuiz};
        }
      }

      if (!_selectedQuizzes.contains(_activeQuiz)) {
        final sorted = _selectedQuizzes.toList()..sort();
        _activeQuiz = sorted.first;
      }
    });
  }

  void _setAmountFromNumber(int value) {
    final safe = value < 1 ? 1 : value;
    setState(() {
      _enteredAmount = safe;
      _amountDraft = '$safe';
    });
  }

  String _targetKey(_Target? target) {
    if (target == null) return '';
    final sorted = (_multi ? _selectedQuizzes.toList() : [_activeQuiz])..sort();
    final qKey = sorted.join(',');
    return '$qKey-${target.type.name}-${target.index}';
  }

  void _selectTarget(_Target target) {
    final currentKey = _targetKey(_pendingTarget);
    final nextKey = _targetKey(target);
    setState(() {
      if (currentKey != nextKey) {
        _enteredAmount = 0;
        _amountDraft = '';
      }
      _pendingTarget = target;
    });
  }

  void _applyAmountToTarget(int amount, _Target? target) {
    final safe = amount;
    if (safe <= 0 || target == null) return;
    if (target.type == _TargetType.cell && !_isVisible(target.index)) return;
    if (target.type == _TargetType.col) {
      final hasVisible = List.generate(
        10,
        (row) => row * 10 + target.index,
      ).any(_isVisible);
      if (!hasVisible) return;
    }

    final targetKey = _targetKey(target);
    final prevApplied = _appliedAmountByTarget[targetKey] ?? 0;
    final delta = safe - prevApplied;
    if (delta <= 0) {
      _appliedAmountByTarget[targetKey] = safe;
      return;
    }

    final quizzes = _multi ? _selectedQuizzes.toList() : [_activeQuiz];
    if (target.type == _TargetType.cell) {
      for (final q in quizzes) {
        final key = _cellKey(q, target.index);
        _selectedMap[key] = (_selectedMap[key] ?? 0) + delta;
      }
    } else if (target.type == _TargetType.row) {
      _rowPointDisplay[target.index] = '$safe';
      for (var col = 0; col < 10; col++) {
        final num = target.index * 10 + col;
        if (!_isVisible(num)) continue;
        for (final q in quizzes) {
          final key = _cellKey(q, num);
          _selectedMap[key] = (_selectedMap[key] ?? 0) + delta;
        }
      }
    } else {
      _colPointDisplay[target.index] = '$safe';
      for (var row = 0; row < 10; row++) {
        final num = row * 10 + target.index;
        if (!_isVisible(num)) continue;
        for (final q in quizzes) {
          final key = _cellKey(q, num);
          _selectedMap[key] = (_selectedMap[key] ?? 0) + delta;
        }
      }
    }
    _appliedAmountByTarget[targetKey] = safe;
  }

  void _handleKeypad(String key) {
    if (key == 'X') {
      setState(() {
        _amountDraft = _amountDraft.isEmpty
            ? ''
            : _amountDraft.substring(0, _amountDraft.length - 1);
      });
      return;
    }

    setState(() {
      if (_amountDraft.isEmpty && key == '0') return;
      final next = (_amountDraft == '0' ? key : '$_amountDraft$key');
      _amountDraft = next.length > 3 ? next.substring(0, 3) : next;
    });
  }

  void _handleEnterAmount() {
    _submitEnteredAmount(_amountDraft);
  }

  void _submitEnteredAmount(String draft) {
    final parsed = int.tryParse(draft.isEmpty ? '0' : draft) ?? 0;
    if (parsed < 1 || parsed > 999) {
      _showNote('Please enter an amount between 1 and 999.');
      return;
    }
    setState(() {
      if (_pendingTarget != null) {
        _applyAmountToTarget(
          parsed,
          _pendingTarget,
        );
        _appliedAmountByTarget.clear();
        _pendingTarget = null;
      }
      _amountDraft = '';
      _enteredAmount = 0;
    });
  }

  void _handleResetAll() {
    setState(() {
      _selectedMap.clear();
      _pendingTarget = null;
      _amountDraft = '';
      _enteredAmount = 0;
      _multi = false;
      _selectedQuizzes = {_activeQuiz};
      _selectedAdvanceSlots = const [];
      _appliedAmountByTarget.clear();
      for (var i = 0; i < 10; i++) {
        _rowPointDisplay[i] = '';
        _colPointDisplay[i] = '';
      }
    });
  }

  void _handleAdvanceDraw() {
    unawaited(_openAdvancePage());
  }

  Future<void> _openAdvancePage() async {
    final slots = _buildAdvanceSlots();
    if (slots.isEmpty) {
      _showNote('No upcoming slots available.');
      return;
    }
    final selected = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(
        builder: (_) => Lottery2DAdvancePage(
          currentLabel: _formatTime(_now),
          nextLabel: _formatTimeNoSeconds(_nextDrawAt()),
          slotOptions: slots,
          selectedSlots: _selectedAdvanceSlots,
        ),
      ),
    );
    if (!mounted || selected == null) return;
    setState(() {
      _selectedAdvanceSlots = selected;
    });
    _showNote(
      selected.isEmpty
          ? 'Advance draw cleared'
          : 'Advance slots selected: ${selected.length}',
    );
  }

  DateTime _nextDrawAt() {
    final nextIso = (_serverSlot?['nextSlotStartIso'] ?? '').toString().trim();
    final nextDt = DateTime.tryParse(nextIso);
    if (nextDt != null) return nextDt.toLocal();
    return _nextQuarter;
  }

  List<Map<String, String>> _buildAdvanceSlots() {
    final base = _nextDrawAt();
    final sameDate = DateTime(base.year, base.month, base.day);
    final endOfDate = sameDate.add(const Duration(days: 1));
    final out = <Map<String, String>>[];
    var i = 0;
    while (true) {
      final dt = base.add(Duration(minutes: i * 15));
      if (!dt.isBefore(endOfDate)) break;
      final hh = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final mm = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      out.add({'slotStartIso': dt.toUtc().toIso8601String(), 'label': '$hh:$mm $ampm'});
      i += 1;
    }
    return out;
  }

  int get _totalAmount {
    return _selectedMap.values.fold<int>(0, (sum, v) => sum + (v));
  }

  _SetTotals get _setTotals {
    var aCount = 0,
        aAmount = 0,
        bCount = 0,
        bAmount = 0,
        cCount = 0,
        cAmount = 0;
    _selectedMap.forEach((key, value) {
      if (value <= 0) return;
      final quizNo = int.tryParse(key.split('-').first) ?? 0;
      if (quizNo >= 1 && quizNo <= 10) {
        aCount++;
        aAmount += value;
      } else if (quizNo >= 11 && quizNo <= 20) {
        bCount++;
        bAmount += value;
      } else if (quizNo >= 21 && quizNo <= 30) {
        cCount++;
        cAmount += value;
      }
    });
    return _SetTotals(
      setACount: aCount,
      setAAmount: aAmount,
      setBCount: bCount,
      setBAmount: bAmount,
      setCCount: cCount,
      setCAmount: cAmount,
    );
  }

  @override
  Widget build(BuildContext context) {
    final nextDraw = _nextQuarter;
    final nowDate = _formatDate(_now);
    final nowTime = _formatTime(_now);
    final drawTime = _formatTimeNoSeconds(nextDraw);
    final buyDisabled =
        _totalAmount <= 0 ||
        _buying ||
        _slotSyncErr.isNotEmpty ||
        _serverSlot == null ||
        !_slotOpenForBuy;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) return;
        unawaited(_restorePortraitOrientation());
      },
      child: ColoredBox(
        color: const Color(0xFF111111),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return ClipRect(
              child: Stack(
                children: [
                  InteractiveViewer(
                    transformationController: _zoomController,
                    minScale: 1,
                    maxScale: 2.5,
                    panEnabled: true,
                    scaleEnabled: true,
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox.expand(
                      child: FittedBox(
                        fit: BoxFit.fill,
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: _baseWidth,
                          height: _baseHeight,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0xFF111111),
                              border: Border.all(color: const Color(0xFF4C4C4C)),
                            ),
                            child: Column(
                              children: [
                                _TopHeader(
                                  dateText: nowDate,
                                  drawTimeText: drawTime,
                                  currentDateText: nowDate,
                                  currentTimeText: nowTime,
                                  walletBalance: _walletBalance,
                                  onOpenQuiz: () => unawaited(
                                    Navigator.of(context).pushNamed('/lottery/quiz'),
                                  ),
                                  onOpenThreeD: () => unawaited(_openThreeD()),
                                  onOpenMyBets: () => unawaited(_openMyBets2D()),
                                  onBack: _exitLottery,
                                ),
                                _QuizSelector(
                                  activeQuiz: _activeQuiz,
                                  selectedQuizzes: _selectedQuizzes,
                                  multi: _multi,
                                  lastDrawByQuiz: _lastSlotByQuiz,
                                  previousSlotTimeLabel: _previousSlotTimeLabel,
                                  onToggleQuiz: _handleQuizToggle,
                                  onToggleMulti: _handleMultiToggle,
                                  onToggleAll: _handleAllToggle,
                                  isSetChecked: _isSetChecked,
                                  onToggleSet: _handleSetToggle,
                                  onOpenResult: () => unawaited(Navigator.of(context).pushNamed('/lottery/old-results')),
                                ),
                                _StatusStrip(
                                  offset: _marqueeOffset,
                                  message: _lotteryNews,
                                ),
                                Expanded(
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: _NumberBoard(
                                          activeQuiz: _activeQuiz,
                                          selectedMap: _selectedMap,
                                          activeTarget: _pendingTarget,
                                          amountDraft: _amountDraft,
                                          activeFilter: _activeFilter,
                                          rowPointDisplay: _rowPointDisplay,
                                          colPointDisplay: _colPointDisplay,
                                          onSelectTarget: (target) =>
                                              setState(() => _selectTarget(target)),
                                        ),
                                      ),
                                      _SummaryPanel(
                                        totalAmount: _totalAmount,
                                        totals: _setTotals,
                                        onBuy: () => unawaited(_handleBoardBuy()),
                                        buyDisabled: buyDisabled,
                                      ),
                                      _ControlPanel(
                                        timerText: _formatTimer(_timerSeconds),
                                        amountDraft: (_amountDraft.isEmpty
                                            ? '0'
                                            : _amountDraft),
                                        activeFilter: _activeFilter,
                                        onAdvanceDraw: _handleAdvanceDraw,
                                        onResetAll: _handleResetAll,
                                        onApplyFilter: (f) => setState(() {
                                          _activeFilter = f;
                                          if (_pendingTarget?.type ==
                                                  _TargetType.cell &&
                                              !_isVisible(_pendingTarget!.index)) {
                                            _pendingTarget = null;
                                            _amountDraft = '';
                                            _enteredAmount = 0;
                                          }
                                        }),
                                        onIncrease: () => _setAmountFromNumber(
                                          (int.tryParse(_amountDraft) ??
                                                  _enteredAmount) +
                                              1,
                                        ),
                                        onDecrease: () => _setAmountFromNumber(
                                          ((int.tryParse(_amountDraft) ??
                                                      _enteredAmount) -
                                                  1)
                                              .clamp(1, 9999),
                                        ),
                                        onKeypad: _handleKeypad,
                                        onEnterAmount: () =>
                                            setState(_handleEnterAmount),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_isZoomedIn)
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _zoomController.value = Matrix4.identity();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xAA000000),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: const BorderSide(color: Color(0xFF4C4C4C)),
                          ),
                        ),
                        icon: const Icon(Icons.center_focus_strong, size: 16),
                        label: const Text('Reset Zoom'),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TopHeader extends StatelessWidget {
  const _TopHeader({
    required this.dateText,
    required this.drawTimeText,
    required this.currentDateText,
    required this.currentTimeText,
    required this.walletBalance,
    required this.onOpenQuiz,
    required this.onOpenThreeD,
    required this.onOpenMyBets,
    required this.onBack,
  });

  final String dateText;
  final String drawTimeText;
  final String currentDateText;
  final String currentTimeText;
  final num walletBalance;
  final VoidCallback onOpenQuiz;
  final VoidCallback onOpenThreeD;
  final VoidCallback onOpenMyBets;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(bottom: BorderSide(color: Color(0xFF3F3F3F))),
      ),
      child: Stack(
        children: [
          Row(
            children: [
              SizedBox(
                width: 120,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: const Text(
                      'DR DATE',
                      style: TextStyle(
                        color: Color(0xFFE5E5E5),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 160,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: const Text(
                      'Time To Draw',
                      style: TextStyle(
                        color: Color(0xFFE5E5E5),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _ActionButton(
                      width: 192,
                      label: 'Check Here Quiz To Play',
                      bg: const Color(0xFF2D9DE8),
                      border: const Color(0xFF1C87CD),
                      fontSize: 18,
                      onTap: onOpenQuiz,
                    ),
                    const SizedBox(width: 6),
                    _ActionButton(
                      width: 156,
                      label: 'My Bets / Ticket',
                      bg: const Color(0xFF3D9B5C),
                      border: const Color(0xFF2A7A4A),
                      fontSize: 18,
                      onTap: onOpenMyBets,
                    ),
                    const SizedBox(width: 6),
                    _ActionButton(
                      width: 118,
                      label: 'Play 3D Quiz',
                      bg: const Color(0xFFF28B1D),
                      border: const Color(0xFFD97816),
                      fontSize: 18,
                      onTap: onOpenThreeD,
                    ),
                    const SizedBox(width: 6),
                    Container(
                      height: 40,
                      width: 168,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F0F0F),
                        border: Border.all(color: const Color(0xFF3F3F3F)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.account_balance_wallet_rounded,
                            color: Color(0xFFF3C36B),
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${walletBalance is int ? walletBalance : walletBalance.round()}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          currentDateText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          currentTimeText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    _ActionButton(
                      width: 92,
                      label: 'Back',
                      bg: const Color(0xFF5B5B5B),
                      border: Colors.white,
                      fontSize: 15,
                      onTap: onBack,
                    ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            left: 8,
            top: 29,
            child: Text(
              dateText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1,
              ),
            ),
          ),
          Positioned(
            left: 128,
            top: 29,
            child: Text(
              drawTimeText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.width,
    required this.label,
    required this.bg,
    required this.border,
    required this.fontSize,
    required this.onTap,
  });

  final double width;
  final String label;
  final Color bg;
  final Color border;
  final double fontSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 40,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: bg,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
            side: BorderSide(color: border),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                height: 1,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class _QuizSelector extends StatelessWidget {
  const _QuizSelector({
    required this.activeQuiz,
    required this.selectedQuizzes,
    required this.multi,
    required this.lastDrawByQuiz,
    required this.previousSlotTimeLabel,
    required this.onToggleQuiz,
    required this.onToggleMulti,
    required this.onToggleAll,
    required this.isSetChecked,
    required this.onToggleSet,
    required this.onOpenResult,
  });

  final int activeQuiz;
  final Set<int> selectedQuizzes;
  final bool multi;
  final Map<int, int?> lastDrawByQuiz;
  final String previousSlotTimeLabel;
  final ValueChanged<int> onToggleQuiz;
  final ValueChanged<bool> onToggleMulti;
  final ValueChanged<bool> onToggleAll;
  final bool Function(int start, int end) isSetChecked;
  final void Function({
    required int start,
    required int end,
    required bool checked,
  })
  onToggleSet;
  final VoidCallback onOpenResult;

  @override
  Widget build(BuildContext context) {
    const groups = [('Set A', 1, 10), ('Set B', 11, 20), ('Set C', 21, 30)];
    final allChecked = selectedQuizzes.length == 30;
    final timeLabel = previousSlotTimeLabel.trim();
    final timeMatch = RegExp(r'^(.+)\s([AaPp][Mm])$').firstMatch(timeLabel);
    final timeMain = timeLabel.isEmpty
        ? '—'
        : (timeMatch?.group(1)?.trim() ?? timeLabel);
    final timeSuffix = (timeMatch?.group(2) ?? '').toUpperCase();
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFEFEFEF),
        border: Border(bottom: BorderSide(color: Color(0xFF5F5F5F))),
      ),
      child: Row(
        children: [
          Container(
            width: 76,
            decoration: BoxDecoration(
              color: const Color(0xFFFFE8A3),
              border: Border.all(color: const Color(0xFFD4B45C)),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  timeMain,
                  style: const TextStyle(
                    color: Color(0xFF111111),
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (timeSuffix.isNotEmpty)
                  Text(
                    timeSuffix,
                    style: const TextStyle(
                      color: Color(0xFF111111),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: groups.map((group) {
                final setName = group.$1;
                final setDisplayName = setName.toUpperCase();
                final start = group.$2;
                final end = group.$3;
                final setChecked = isSetChecked(start, end);
                return SizedBox(
                  height: 48,
                  child: Row(
                    children: [
                      Container(
                        width: 86,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE95757),
                          border: Border.all(color: const Color(0xFFD1D1D1)),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => onToggleSet(
                              start: start,
                              end: end,
                              checked: !setChecked,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IgnorePointer(
                                  child: Checkbox(
                                    value: setChecked,
                                    onChanged: (_) {},
                                    activeColor: Colors.black87,
                                    side: const BorderSide(
                                      color: Color(0xFFD9D9D9),
                                    ),
                                    visualDensity: const VisualDensity(
                                      horizontal: -4,
                                      vertical: -4,
                                    ),
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                                Flexible(
                                  child: Text(
                                    setDisplayName,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Row(
                          children: List.generate(end - start + 1, (idx) {
                            final quizNo = start + idx;
                            final isActive = multi
                                ? selectedQuizzes.contains(quizNo)
                                : activeQuiz == quizNo;
                            final prevResult = lastDrawByQuiz[quizNo];
                            Color bg = Colors.white;
                            Color border = const Color(0xFF8F8F8F);
                            if (isActive) {
                              if (setName == 'Set A') {
                                bg = const Color(0xFFF4A7C8);
                                border = const Color(0xFFBF6F95);
                              } else if (setName == 'Set B') {
                                bg = const Color(0xFFA9C9FF);
                                border = const Color(0xFF6E94D1);
                              } else {
                                bg = const Color(0xFFB8E6B8);
                                border = const Color(0xFF77B077);
                              }
                            }
                            return Expanded(
                              child: SizedBox(
                                height: 48,
                                child: OutlinedButton(
                                  onPressed: () => onToggleQuiz(quizNo),
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: bg,
                                    foregroundColor: Colors.black,
                                    side: BorderSide(color: border),
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.zero,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 2,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          'Quiz${quizNo.toString().padLeft(2, '0')}',
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 2,
                                        ),
                                        child: Text(
                                          '-',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF6B6B6B),
                                          ),
                                        ),
                                      ),
                                      Text(
                                        prevResult == null
                                            ? '—'
                                            : prevResult.toString().padLeft(
                                                2,
                                                '0',
                                              ),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF2D9DE8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                      Container(
                        width: 136,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFEFEF),
                          border: Border.all(color: const Color(0xFF8F8F8F)),
                        ),
                        child: _QuizRightAction(
                          setName: setName,
                          allChecked: allChecked,
                          multi: multi,
                          onToggleAll: onToggleAll,
                          onToggleMulti: onToggleMulti,
                          onOpenResult: onOpenResult,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuizRightAction extends StatelessWidget {
  const _QuizRightAction({
    required this.setName,
    required this.allChecked,
    required this.multi,
    required this.onToggleAll,
    required this.onToggleMulti,
    required this.onOpenResult,
  });

  final String setName;
  final bool allChecked;
  final bool multi;
  final ValueChanged<bool> onToggleAll;
  final ValueChanged<bool> onToggleMulti;
  final VoidCallback onOpenResult;

  @override
  Widget build(BuildContext context) {
    if (setName == 'Set C') {
      return SizedBox.expand(
        child: ElevatedButton(
          onPressed: onOpenResult,
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: const Color(0xFF2D9DE8),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
              side: BorderSide(color: Color(0xFF1C87CD)),
            ),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
          ),
          child: const Text(
            'Old Results',
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }
    final isAll = setName == 'Set A';
    final checked = isAll ? allChecked : multi;
    return Container(
      color: const Color(0xFFEB4F4F),
      child: Row(
        children: [
          Checkbox(
            value: checked,
            onChanged: (v) {
              final next = v ?? false;
              if (isAll) {
                onToggleAll(next);
              } else {
                onToggleMulti(next);
              }
            },
            activeColor: Colors.black87,
            side: const BorderSide(color: Color(0xFFD9D9D9)),
            visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          Text(
            isAll ? 'All' : 'Multi',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({
    required this.offset,
    required this.message,
  });

  final double offset;
  final String message;

  @override
  Widget build(BuildContext context) {
    final base = message.trim().isEmpty ? 'Welcome Diamond' : message.trim();
    final marqueeText = List.filled(10, base).join('        ');
    return Container(
      height: 28,
      decoration: const BoxDecoration(
        color: Color(0xFF2EB34F),
        border: Border(
          top: BorderSide(color: Color(0xFF6F6F6F)),
          bottom: BorderSide(color: Color(0xFF6F6F6F)),
        ),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          Positioned(
            left: -offset,
            top: 0,
            bottom: 0,
            child: Center(
              child: Text(
                '$marqueeText    $marqueeText',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberBoard extends StatelessWidget {
  const _NumberBoard({
    required this.activeQuiz,
    required this.selectedMap,
    required this.activeTarget,
    required this.amountDraft,
    required this.activeFilter,
    required this.rowPointDisplay,
    required this.colPointDisplay,
    required this.onSelectTarget,
  });

  final int activeQuiz;
  final Map<String, int> selectedMap;
  final _Target? activeTarget;
  final String amountDraft;
  final String activeFilter;
  final List<String> rowPointDisplay;
  final List<String> colPointDisplay;
  final ValueChanged<_Target> onSelectTarget;

  bool _isVisible(int num) {
    if (activeFilter == 'even') return num % 2 == 0;
    if (activeFilter == 'odd') return num % 2 != 0;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFD7D7D7),
        border: Border(right: BorderSide(color: Color(0xFF8A8A8A))),
      ),
      padding: const EdgeInsets.fromLTRB(6, 10, 6, 10),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 104,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 4),
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'BLOCK',
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      color: Color(0xFF3799D5),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ),
              ),
              ...List.generate(10, (i) {
                final hasVisibleInCol = List.generate(
                  10,
                  (row) => row * 10 + i,
                ).any(_isVisible);
                final selected =
                    activeTarget?.type == _TargetType.col &&
                    activeTarget?.index == i;
                final colDisplay = selected && amountDraft.isNotEmpty
                    ? amountDraft
                    : colPointDisplay[i];
                Color border = const Color(0xFF3EA1DE);
                Color bg = Colors.white;
                if (!hasVisibleInCol) {
                  border = const Color(0xFFBDBDBD);
                  bg = const Color(0xFFE9E9E9);
                } else if (selected) {
                  border = const Color(0xFF4ABA4F);
                  bg = const Color(0xFFEFFFE8);
                }
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 9),
                    child: SizedBox(
                      height: 34,
                      child: OutlinedButton(
                        onPressed: hasVisibleInCol
                            ? () => onSelectTarget(_Target.col(i))
                            : null,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: bg,
                          side: BorderSide(color: border, width: 2),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        child: Text(
                          colDisplay,
                          style: const TextStyle(
                            color: Color(0xFFD4A5B0),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const rowGap = 6.0;
                final rowHeight = (constraints.maxHeight - (rowGap * 9)) / 10;
                final safeRowHeight = rowHeight.clamp(32.0, 120.0);
                final rowPickerHeight = math.min(34.0, safeRowHeight);

                return Column(
                  children: List.generate(10, (row) {
                    final rowNums = List.generate(10, (c) => row * 10 + c);
                    final rowSelected =
                        activeTarget?.type == _TargetType.row &&
                        activeTarget?.index == row;
                    final rowDisplay = rowSelected && amountDraft.isNotEmpty
                        ? amountDraft
                        : rowPointDisplay[row];
                    return Padding(
                      padding: EdgeInsets.only(bottom: row == 9 ? 0 : rowGap),
                      child: SizedBox(
                        height: safeRowHeight,
                        child: Row(
                          children: [
                            SizedBox(
                              width: 104,
                              child: SizedBox(
                                height: rowPickerHeight,
                                child: OutlinedButton(
                                  onPressed: () =>
                                      onSelectTarget(_Target.row(row)),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: rowSelected
                                          ? const Color(0xFF4ABA4F)
                                          : const Color(0xFF3EA1DE),
                                      width: 2,
                                    ),
                                    backgroundColor: rowSelected
                                        ? const Color(0xFFEFFFE8)
                                        : Colors.white,
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.zero,
                                    ),
                                    padding: EdgeInsets.zero,
                                  ),
                                  child: Text(
                                    rowDisplay,
                                    style: const TextStyle(
                                      color: Color(0xFFD4A5B0),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            ...rowNums.map((num) {
                              final visible = _isVisible(num);
                              final key = '$activeQuiz-$num';
                              final committedValue = selectedMap[key];
                              final isActiveCell =
                                  activeTarget?.type == _TargetType.cell &&
                                  activeTarget?.index == num;
                              final draftValue = isActiveCell && amountDraft.isNotEmpty
                                  ? int.tryParse(amountDraft)
                                  : null;
                              final value = draftValue ?? committedValue;
                              final selected = value != null && value > 0;
                              final targetSelected =
                                  (activeTarget?.type == _TargetType.cell &&
                                      activeTarget?.index == num) ||
                                  (activeTarget?.type == _TargetType.row &&
                                      (num ~/ 10) == activeTarget?.index) ||
                                  (activeTarget?.type == _TargetType.col &&
                                      (num % 10) == activeTarget?.index);

                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 9),
                                  child: visible
                                      ? _BoardCell(
                                          quizNo: activeQuiz,
                                          num: num,
                                          value: value,
                                          selected: selected,
                                          targetSelected: targetSelected,
                                          cellHeight: safeRowHeight,
                                          onTap: () =>
                                              onSelectTarget(_Target.cell(num)),
                                        )
                                      : SizedBox(height: safeRowHeight),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BoardCell extends StatefulWidget {
  const _BoardCell({
    required this.quizNo,
    required this.num,
    required this.value,
    required this.selected,
    required this.targetSelected,
    required this.cellHeight,
    required this.onTap,
  });

  final int quizNo;
  final int num;
  final int? value;
  final bool selected;
  final bool targetSelected;
  final double cellHeight;
  final VoidCallback onTap;

  @override
  State<_BoardCell> createState() => _BoardCellState();
}

class _BoardCellState extends State<_BoardCell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color border = const Color(0xFF1F1F1F);
    Color bg = const Color(0xFFFBFBFB);
    Color text = Colors.transparent;
    if (widget.selected) {
      border = const Color(0xFF2EA73F);
      bg = const Color(0xFFDCFFD1);
      text = const Color(0xFF0F172A);
    } else if (widget.targetSelected) {
      border = const Color(0xFF4ABA4F);
      bg = const Color(0xFFF7FFF4);
    }

    final amountBoxHeight = math.min(
      34.0,
      math.max(20.0, widget.cellHeight - 20.0),
    );
    final spacing = widget.cellHeight > 36 ? 2.0 : 1.0;
    const labelFontSize = 18.0;
    final valueFontSize = widget.cellHeight > 44 ? 14.0 : 12.0;

    return SizedBox(
      height: widget.cellHeight,
      child: TextButton(
        onPressed: widget.onTap,
        style: TextButton.styleFrom(
          backgroundColor: Colors.transparent,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          padding: const EdgeInsets.fromLTRB(1, 1, 1, 0),
        ),
        child: Column(
          children: [
            Container(
              height: amountBoxHeight,
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: bg,
                border: Border.all(color: border, width: 2),
              ),
              child: widget.selected
                  ? Text(
                      '${widget.value}',
                      style: TextStyle(
                        color: text,
                        fontSize: valueFontSize,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : widget.targetSelected
                  ? FadeTransition(
                      opacity: Tween<double>(begin: 1, end: 0).animate(_blink),
                      child: Text(
                        '|',
                        style: TextStyle(
                          color: const Color(0xFF111111),
                          fontSize: valueFontSize,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            SizedBox(height: spacing),
            Text(
              'Q${widget.quizNo.toString().padLeft(2, '0')}-${widget.num.toString().padLeft(2, '0')}',
              style: TextStyle(
                color: const Color(0xFF111111),
                fontSize: labelFontSize,
                fontWeight: FontWeight.w600,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({
    required this.totalAmount,
    required this.totals,
    required this.onBuy,
    required this.buyDisabled,
  });

  final int totalAmount;
  final _SetTotals totals;
  final VoidCallback onBuy;
  final bool buyDisabled;

  @override
  Widget build(BuildContext context) {
    final rows = [
      (totals.setACount, totals.setAAmount),
      (totals.setBCount, totals.setBAmount),
      (totals.setCCount, totals.setCAmount),
    ];
    return Container(
      width: 148,
      decoration: const BoxDecoration(
        color: Color(0xFFB8C7DF),
        border: Border(right: BorderSide(color: Color(0xFF7F8EA2))),
      ),
      child: Column(
        children: [
          Container(
            height: 56,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFF2CA7E8),
              border: Border(bottom: BorderSide(color: Color(0xFF9AA4B2))),
            ),
            child: const Text(
              'TOTAL',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w600,
                height: 1,
              ),
            ),
          ),
          ...List.generate(rows.length, (idx) {
            final bg = idx.isEven
                ? const Color(0xFFC3D4EB)
                : const Color(0xFFA9BEDE);
            return _SummaryDoubleRow(
              height: 56,
              bg: bg,
              left: '${rows[idx].$1}',
              right: '${rows[idx].$2}',
              textColor: Colors.black,
              textSize: 30,
            );
          }),
          ...List.generate(
            5,
            (_) => const _SummaryDoubleRow(
              height: 54,
              bg: Color(0xFF98ACCF),
              left: '0',
              right: '0',
              textColor: Colors.black,
              textSize: 28,
            ),
          ),
          _SummaryDoubleRow(
            height: 56,
            bg: const Color(0xFFD0D0D0),
            left: 'TOTAL',
            right: '$totalAmount',
            leftBold: true,
            rightBold: true,
            textColor: Colors.black,
            leftTextColor: Colors.black,
            textSize: 26,
            leftTextSize: 20,
          ),
          SizedBox(
            width: double.infinity,
            height: 62,
            child: ElevatedButton(
              onPressed: buyDisabled ? null : onBuy,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                disabledBackgroundColor: const Color(
                  0xFFD0D0D0,
                ).withValues(alpha: 0.5),
                backgroundColor: const Color(0xFFD0D0D0),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                  side: BorderSide(color: Color(0xFF8A8A8A)),
                ),
              ),
              child: const Text(
                'BUY',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 38,
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryDoubleRow extends StatelessWidget {
  const _SummaryDoubleRow({
    required this.height,
    required this.bg,
    required this.left,
    required this.right,
    required this.textColor,
    required this.textSize,
    this.leftTextColor,
    this.leftTextSize,
    this.leftBold = false,
    this.rightBold = false,
  });

  final double height;
  final Color bg;
  final String left;
  final String right;
  final Color textColor;
  final double textSize;
  final Color? leftTextColor;
  final double? leftTextSize;
  final bool leftBold;
  final bool rightBold;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      color: bg,
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 0.8),
              ),
              alignment: Alignment.center,
              child: Text(
                left,
                style: TextStyle(
                  color: leftTextColor ?? textColor,
                  fontSize: leftTextSize ?? textSize,
                  fontWeight: leftBold ? FontWeight.w600 : FontWeight.w400,
                  height: 1,
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 0.8),
              ),
              alignment: Alignment.center,
              child: Text(
                right,
                style: TextStyle(
                  color: textColor,
                  fontSize: textSize,
                  fontWeight: rightBold ? FontWeight.w600 : FontWeight.w400,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlPanel extends StatelessWidget {
  const _ControlPanel({
    required this.timerText,
    required this.amountDraft,
    required this.onAdvanceDraw,
    required this.onResetAll,
    required this.onApplyFilter,
    required this.activeFilter,
    required this.onIncrease,
    required this.onDecrease,
    required this.onKeypad,
    required this.onEnterAmount,
  });

  final String timerText;
  final String amountDraft;
  final VoidCallback onAdvanceDraw;
  final VoidCallback onResetAll;
  final ValueChanged<String> onApplyFilter;
  final String activeFilter;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final ValueChanged<String> onKeypad;
  final VoidCallback onEnterAmount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(
        color: Color(0xFFD5D5D5),
        border: Border(left: BorderSide(color: Color(0xFF8B8B8B))),
      ),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.black,
              border: Border.all(color: const Color(0xFF656565)),
            ),
            child: Column(
              children: [
                Container(
                  height: 28,
                  alignment: Alignment.center,
                  child: const Text(
                    'Timer',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    timerText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 54,
                      height: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _RedBigButton(label: 'ADVANCE DRAW', onTap: onAdvanceDraw),
          const SizedBox(height: 4),
          _RedBigButton(label: 'RESET ALL', onTap: onResetAll),
          const SizedBox(height: 8),
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.black,
              border: Border.all(color: const Color(0xFF5D5D5D)),
            ),
            child: Row(
              children: [
                _FilterOption(
                  label: 'All',
                  checked: activeFilter == 'all',
                  onTap: () => onApplyFilter('all'),
                ),
                _FilterOption(
                  label: 'Even',
                  checked: activeFilter == 'even',
                  onTap: () => onApplyFilter('even'),
                ),
                _FilterOption(
                  label: 'Odd',
                  checked: activeFilter == 'odd',
                  onTap: () => onApplyFilter('odd'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _GradientSquareButton(
                label: '-',
                gradient: const LinearGradient(
                  colors: [Color(0xFF4B5563), Color(0xFF374151)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                border: const Color(0xFF2F3946),
                onTap: onDecrease,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F7F7),
                    border: Border.all(color: const Color(0xFF8A8A8A)),
                  ),
                  child: Text(
                    amountDraft,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 44,
                      height: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _GradientSquareButton(
                label: '+',
                gradient: const LinearGradient(
                  colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                border: const Color(0xFF15803D),
                onTap: onIncrease,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const spacing = 5.0;
                final tileHeight =
                    (constraints.maxHeight - (spacing * 3)) / 4;

                Widget keypadButton(String k, {int flex = 1}) {
                  final isRed = k == 'X';
                  return Expanded(
                    flex: flex,
                    child: SizedBox(
                      height: tileHeight,
                      child: ElevatedButton(
                        onPressed: () => onKeypad(k),
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(2),
                            side: BorderSide(
                              color: isRed
                                  ? const Color(0xFFD63F35)
                                  : const Color(0xFF8A8A8A),
                            ),
                          ),
                          backgroundColor: isRed
                              ? const Color(0xFFF04438)
                              : const Color(0xFFF4F4F4),
                          foregroundColor: isRed ? Colors.white : Colors.black,
                          padding: EdgeInsets.zero,
                        ),
                        child: Text(
                          k,
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    Row(
                      children: [
                        keypadButton('1'),
                        const SizedBox(width: spacing),
                        keypadButton('2'),
                        const SizedBox(width: spacing),
                        keypadButton('3'),
                      ],
                    ),
                    const SizedBox(height: spacing),
                    Row(
                      children: [
                        keypadButton('4'),
                        const SizedBox(width: spacing),
                        keypadButton('5'),
                        const SizedBox(width: spacing),
                        keypadButton('6'),
                      ],
                    ),
                    const SizedBox(height: spacing),
                    Row(
                      children: [
                        keypadButton('7'),
                        const SizedBox(width: spacing),
                        keypadButton('8'),
                        const SizedBox(width: spacing),
                        keypadButton('9'),
                      ],
                    ),
                    const SizedBox(height: spacing),
                    Row(
                      children: [
                        keypadButton('0'),
                        const SizedBox(width: spacing),
                        keypadButton('X', flex: 2),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 72,
            child: ElevatedButton(
              onPressed: onEnterAmount,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: const Color(0xFFEF3F34),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(2),
                  side: const BorderSide(color: Color(0xFFD4372F)),
                ),
              ),
              child: const Text(
                'ENTER',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 42,
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RedBigButton extends StatelessWidget {
  const _RedBigButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: const Color(0xFFEF3F34),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(2),
            side: const BorderSide(color: Color(0xFFD4372F)),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterOption extends StatelessWidget {
  const _FilterOption({
    required this.label,
    required this.checked,
    required this.onTap,
  });

  final String label;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Checkbox(
                value: checked,
                onChanged: (_) => onTap(),
                activeColor: Colors.white,
                checkColor: Colors.black,
                side: const BorderSide(color: Colors.white),
                visualDensity: const VisualDensity(
                  horizontal: -4,
                  vertical: -4,
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GradientSquareButton extends StatelessWidget {
  const _GradientSquareButton({
    required this.label,
    required this.gradient,
    required this.border,
    required this.onTap,
  });

  final String label;
  final Gradient gradient;
  final Color border;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border),
        ),
        child: TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: EdgeInsets.zero,
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _SetTotals {
  const _SetTotals({
    required this.setACount,
    required this.setAAmount,
    required this.setBCount,
    required this.setBAmount,
    required this.setCCount,
    required this.setCAmount,
  });

  final int setACount;
  final int setAAmount;
  final int setBCount;
  final int setBAmount;
  final int setCCount;
  final int setCAmount;
}

class _BetPreviewLine {
  const _BetPreviewLine({
    required this.quizId,
    required this.number,
    required this.amount,
  });

  final int quizId;
  final int number;
  final int amount;
}

enum _TargetType { cell, row, col }

class _Target {
  const _Target(this.type, this.index);

  const _Target.cell(int i) : this(_TargetType.cell, i);
  const _Target.row(int i) : this(_TargetType.row, i);
  const _Target.col(int i) : this(_TargetType.col, i);

  final _TargetType type;
  final int index;
}
