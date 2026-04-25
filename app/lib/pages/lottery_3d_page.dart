import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'lottery_3d_advance_page.dart';
import '../services/auth_service.dart';
import '../services/wallet_service.dart';

class Lottery3DPage extends StatefulWidget {
  const Lottery3DPage({super.key});

  @override
  State<Lottery3DPage> createState() => _Lottery3DPageState();
}

enum _InputTarget { points, number, rangeFrom, rangeTo, qty }

class _BetEntry {
  const _BetEntry({
    required this.id,
    required this.number,
    required this.mode,
    required this.points,
    required this.rate,
    required this.panel,
  });

  final String id;
  final String number;
  final String mode;
  final int points;
  final int rate;
  final String panel;
}

class _TicketEntry {
  const _TicketEntry({
    required this.id,
    required this.createdAt,
    required this.totalPoints,
    required this.gameId,
    required this.status,
  });

  final String id;
  final DateTime createdAt;
  final int totalPoints;
  final String gameId;
  final String status;
}

class _Lottery3DPageState extends State<Lottery3DPage> {
  static const int _intervalSeconds = 15 * 60;
  static const modeOptions = [
    'all',
    'box',
    'str',
    'sp',
    'fp',
    'bp',
    'ap',
    'single',
    'duplicates',
    'triples',
  ];
  static const quickModes = ['box', 'str', 'sp', 'fp', 'bp', 'ap'];
  static const panelOptions = ['A', 'B', 'C'];
  static const digitOptions = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
  static const rateOptions = [10, 20, 30, 50, 100, 200];
  static const luckyPickModes = ['single', 'box', 'str', 'sp', 'fp', 'bp', 'ap', 'duplicates', 'triples'];

  Timer? _clockTicker;
  Timer? _slotTicker;
  bool _restoringPortrait = false;
  bool _booting = true;

  DateTime _now = DateTime.now();
  String _slotSyncErr = '';
  Map<String, dynamic>? _serverSlot;
  bool _buying = false;
  num _walletBalance = 0;
  String _playerId = 'user';
  String _lastTxnId = 'GM00000000000000';
  int _lastWinAmount = 0;

  final Map<String, String> _topResults = {'A': '---', 'B': '---', 'C': '---'};
  DateTime? _lastResultUpdatedAt;
  String _lastDrawLabel = '-';

  final Set<String> _selectedModes = {'box'};
  final Set<String> _selectedPanels = {'A'};
  final Set<String> _selectedDigits = {};
  int _selectedRate = 10;
  String _inputNumber = '';
  String _points = '10';
  String _rangeFrom = '';
  String _rangeTo = '';
  String _qty = '';
  String _lPickType = 'box';
  _InputTarget _activeTarget = _InputTarget.number;

  String _toast = '';
  String _validationMsg = '';

  final List<_BetEntry> _bets = [];
  final List<_TicketEntry> _tickets = [];
  List<String> _selectedAdvanceSlots = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap3D());
  }

  Future<void> _bootstrap3D() async {
    await _configureOrientationForLottery();
    await Future<void>.delayed(const Duration(milliseconds: 350));
    await _loadWalletBalance();
    await _loadCurrentUserInfo();
    await _syncQuizSlot();
    await _syncLastSlotResult();
    if (!mounted) return;
    _clockTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
    _slotTicker = Timer.periodic(const Duration(seconds: 4), (_) {
      unawaited(_syncQuizSlot());
      unawaited(_syncLastSlotResult());
    });
    setState(() => _booting = false);
  }

  @override
  void dispose() {
    _clockTicker?.cancel();
    _slotTicker?.cancel();
    super.dispose();
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
    await SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    _restoringPortrait = false;
  }

  Future<void> _exit3D() async {
    if (!mounted) return;
    await _restorePortraitOrientation();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  Future<void> _goBackTo2DInLandscape() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    if (!mounted) return;
    await Navigator.of(context).pushReplacementNamed('/lottery');
  }

  Future<Map<String, String>> _authHeaders() async {
    final user = await AuthService.instance.getStoredUser();
    final token = user?['token']?.toString().trim() ?? '';
    if (token.isEmpty) return const {};
    return {'Authorization': 'Bearer $token'};
  }

  Future<void> _loadCurrentUserInfo() async {
    try {
      final user = await AuthService.instance.getStoredUser();
      final id = [
        user?['userName'],
        user?['name'],
        user?['fullName'],
        user?['username'],
        user?['phone'],
        user?['id'],
        user?['_id'],
      ].map((e) => e?.toString().trim() ?? '').firstWhere((e) => e.isNotEmpty, orElse: () => '');
      if (!mounted) return;
      if (id.isNotEmpty) {
        setState(() => _playerId = id);
      }
    } catch (_) {}
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
      final fallback = user?['balance'] ?? user?['walletBalance'] ?? user?['wallet'] ?? 0;
      final parsed = fallback is num ? fallback : num.tryParse(fallback.toString()) ?? 0;
      if (!mounted) return;
      setState(() => _walletBalance = parsed);
    } catch (_) {
      if (!mounted) return;
      setState(() => _walletBalance = 0);
    }
  }

  Future<void> _syncQuizSlot() async {
    try {
      final res = await http.get(Uri.parse('$kApiBaseUrl/quiz/slot'));
      final body = jsonDecode(res.body) as Map<String, dynamic>?;
      if (!mounted) return;
      if (res.statusCode >= 200 && res.statusCode < 300 && body?['success'] == true && body?['data'] is Map) {
        setState(() {
          _serverSlot = Map<String, dynamic>.from(body!['data'] as Map);
          _slotSyncErr = '';
        });
      } else {
        setState(() => _slotSyncErr = body?['message']?.toString() ?? 'Failed to sync slot');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _slotSyncErr = 'Failed to sync slot');
    }
  }

  String _to3(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '---';
    return digits.padLeft(3, '0').substring(math.max(0, digits.length - 3));
  }

  Future<void> _syncLastSlotResult() async {
    try {
      final now = DateTime.now();
      final dateKey =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final res = await http.get(
        Uri.parse('$kApiBaseUrl/quiz/slot-results?date=${Uri.encodeQueryComponent(dateKey)}&maxSlots=1&mode=3d'),
      );
      final body = jsonDecode(res.body) as Map<String, dynamic>?;
      if (!mounted) return;
      if (res.statusCode < 200 || res.statusCode >= 300 || body?['success'] != true) return;
      final data = body?['data'];
      Map<String, dynamic>? slot;
      if (data is List && data.isNotEmpty && data.first is Map) {
        slot = Map<String, dynamic>.from(data.first as Map);
      } else if (data is Map && data['slots'] is List) {
        final slots = data['slots'] as List;
        if (slots.isNotEmpty && slots.first is Map) {
          slot = Map<String, dynamic>.from(slots.first as Map);
        }
      }
      if (slot == null) return;
      final resolvedSlot = slot;
      final results = <String, String>{'A': '---', 'B': '---', 'C': '---'};
      final rawResults = resolvedSlot['results'];
      if (rawResults is List) {
        for (final e in rawResults) {
          if (e is! Map) continue;
          final quizId = int.tryParse('${e['quizId'] ?? ''}');
          final result = '${e['result'] ?? ''}';
          if (quizId == 1) results['A'] = _to3(result);
          if (quizId == 2) results['B'] = _to3(result);
          if (quizId == 3) results['C'] = _to3(result);
        }
      }
      setState(() {
        _topResults
          ..clear()
          ..addAll(results);
        _lastDrawLabel = (resolvedSlot['drawLabelEnd'] ?? resolvedSlot['timeLabel'] ?? '-').toString();
        _lastResultUpdatedAt = DateTime.now();
      });
    } catch (_) {}
  }

  int get _timerSeconds {
    final elapsed = (_now.minute % 15) * 60 + _now.second;
    final rem = _intervalSeconds - elapsed;
    return rem <= 0 ? _intervalSeconds : rem;
  }

  String _formatTimer(int s) => '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  String _formatClock(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final ampm = t.hour >= 12 ? 'PM' : 'AM';
    return '$h:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')} $ampm';
  }

  DateTime _nextDraw(DateTime now) {
    final d = DateTime(now.year, now.month, now.day, now.hour, now.minute);
    final m = d.minute;
    final next = (m ~/ 15) * 15 + 15;
    return DateTime(now.year, now.month, now.day, now.hour, next % 60).add(Duration(hours: next >= 60 ? 1 : 0));
  }

  String _timeToDrawText() {
    final d = _nextDraw(_now);
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    return '$h:${d.minute.toString().padLeft(2, '0')} $ampm';
  }

  bool _validateNumberForMode(String number, String mode) {
    final n = number.replaceAll(RegExp(r'\D'), '').padLeft(3, '0').substring(0, 3);
    final unique = n.split('').toSet().length;
    if (mode == 'duplicates') return unique == 2;
    if (mode == 'triples') return unique == 1;
    return true;
  }

  List<String> _normalizedModes() {
    return _selectedModes
        .map((m) => m == 'all' ? quickModes : [m])
        .expand((x) => x)
        .map((m) => m == 'single' ? 'str' : m)
        .toSet()
        .toList();
  }

  void _addToast(String msg) {
    setState(() => _toast = msg);
    Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _toast = '');
    });
  }

  ({int from, int to})? _resolveRangeBounds(String from, String to) {
    final fromDigits = from.replaceAll(RegExp(r'\D'), '');
    final toDigits = to.replaceAll(RegExp(r'\D'), '');
    final f = int.tryParse(fromDigits);
    final t = int.tryParse(toDigits);
    if (f == null || t == null || f < 0 || f > 999) return null;
    final fromInt = f;
    var toInt = t;

    // If RANGE has 1-2 digits but TO is 3-digit+, start from 100.
    if (fromInt < 100 && toInt > 99) {
      return (from: 100, to: toInt);
    }

    // Convenience input: when FROM is 100+ and TO is 1-2 digits, treat TO as same-hundreds suffix.
    // Example: FROM=100, TO=5 => range 100..105 (instead of invalid 100..005).
    if (fromInt > 99 && toDigits.length < 3) {
      final baseHundreds = (fromInt ~/ 100) * 100;
      toInt = baseHundreds + toInt;
      while (toInt < fromInt && toInt + 100 <= 999) {
        toInt += 100;
      }
    }

    if (toInt > 999 || fromInt > toInt || (toInt - fromInt + 1) > 1000) return null;
    return (from: fromInt, to: toInt);
  }

  List<String> _rangeNumbers(String from, String to) {
    final bounds = _resolveRangeBounds(from, to);
    if (bounds == null) return [];
    return [for (int i = bounds.from; i <= bounds.to; i++) i.toString().padLeft(3, '0')];
  }

  List<String> _luckyNumbers(int qty, String mode) {
    final r = math.Random();
    final out = <String>{};
    int tries = 0;
    while (out.length < qty && tries < qty * 60) {
      tries += 1;
      final n = r.nextInt(1000).toString().padLeft(3, '0');
      if (_validateNumberForMode(n, mode)) out.add(n);
    }
    return out.toList();
  }

  void _appendBets(List<String> numbers, List<String> modes, int points) {
    final panels = _selectedPanels.isEmpty ? ['A', 'B', 'C'] : _selectedPanels.toList();
    final created = <_BetEntry>[];
    for (final n in numbers) {
      for (final mode in modes) {
        if (!_validateNumberForMode(n, mode)) continue;
        for (final panel in panels) {
          created.add(
            _BetEntry(
              id: '${DateTime.now().millisecondsSinceEpoch}-${created.length}',
              number: n,
              mode: mode,
              points: points,
              rate: _selectedRate,
              panel: panel,
            ),
          );
        }
      }
    }
    if (created.isEmpty) {
      setState(() => _validationMsg = 'No valid bet generated for selected mode and number.');
      return;
    }
    setState(() {
      _bets.addAll(created);
      _inputNumber = '';
      _points = '$_selectedRate';
      _rangeFrom = '';
      _rangeTo = '';
      _qty = '';
      _validationMsg = '';
    });
    _addToast('Bet Added Successfully');
  }

  void _addBet() {
    final pts = int.tryParse(_points) ?? _selectedRate;
    if (pts <= 0) {
      setState(() => _validationMsg = 'Points must be greater than 0.');
      return;
    }
    final modes = _normalizedModes();
    if (modes.isEmpty) {
      setState(() => _validationMsg = 'Please select at least one mode.');
      return;
    }
    if ((_rangeFrom.isNotEmpty && _rangeTo.isEmpty) || (_rangeFrom.isEmpty && _rangeTo.isNotEmpty)) {
      if (_rangeFrom.isNotEmpty && _rangeTo.isEmpty) {
        // Shortcut: RANGE=5 + ADD => 100..105
        final short = int.tryParse(_rangeFrom.replaceAll(RegExp(r'\D'), ''));
        if (short != null && short >= 0 && short <= 99) {
          final nums = _rangeNumbers('100', '${100 + short}');
          if (nums.isNotEmpty) {
            _appendBets(nums, modes, pts);
            return;
          }
        }
      }
      setState(() => _validationMsg = 'Please enter complete range (FROM and TO).');
      return;
    }
    if (_rangeFrom.isNotEmpty && _rangeTo.isNotEmpty) {
      final nums = _rangeNumbers(_rangeFrom, _rangeTo);
      if (nums.isEmpty) {
        setState(() => _validationMsg = 'Invalid range.');
        return;
      }
      _appendBets(nums, modes, pts);
      return;
    }
    if (_qty.isNotEmpty) {
      final q = int.tryParse(_qty) ?? 0;
      if (q <= 0 || q > 1000) {
        setState(() => _validationMsg = 'Qty must be 1-1000.');
        return;
      }
      final nums = _luckyNumbers(q, _lPickType);
      if (nums.isEmpty) {
        setState(() => _validationMsg = 'Failed to generate lucky pick.');
        return;
      }
      _appendBets(nums, [_lPickType], pts);
      return;
    }
    final n = _inputNumber.replaceAll(RegExp(r'\D'), '');
    if (n.isEmpty) {
      setState(() => _validationMsg = 'Please enter a number.');
      return;
    }
    final num3 = n.padLeft(3, '0').substring(math.max(0, n.length - 3));
    _appendBets([num3], modes, pts);
  }

  void _digitInput(String d) {
    bool shouldAutoAdd = false;
    setState(() {
      String append(String v, int max) => '$v$d'.replaceAll(RegExp(r'\D'), '').substring(0, math.min(max, ('$v$d'.replaceAll(RegExp(r'\D'), '')).length));
      switch (_activeTarget) {
        case _InputTarget.points:
          _points = append(_points == '0' ? '' : _points, 4);
          if (_points.isEmpty) _points = '0';
          break;
        case _InputTarget.number:
          _inputNumber = append(_inputNumber, 3);
          final parsed = int.tryParse(_inputNumber) ?? -1;
          shouldAutoAdd = parsed > 99 && _rangeFrom.isEmpty && _rangeTo.isEmpty && _qty.isEmpty;
          break;
        case _InputTarget.rangeFrom:
          _rangeFrom = append(_rangeFrom, 3);
          break;
        case _InputTarget.rangeTo:
          _rangeTo = append(_rangeTo, 3);
          final fromRaw = int.tryParse(_rangeFrom.replaceAll(RegExp(r'\D'), '')) ?? -1;
          final toRaw = int.tryParse(_rangeTo.replaceAll(RegExp(r'\D'), '')) ?? -1;
          final bounds = _resolveRangeBounds(_rangeFrom, _rangeTo);
          shouldAutoAdd = bounds != null && fromRaw > 99 && toRaw > fromRaw && _qty.isEmpty;
          break;
        case _InputTarget.qty:
          _qty = append(_qty, 3);
          break;
      }
      _validationMsg = '';
    });
    if (shouldAutoAdd) {
      _addBet();
    }
  }

  void _deleteOne() {
    setState(() {
      switch (_activeTarget) {
        case _InputTarget.points:
          _points = _points.isEmpty ? '0' : _points.substring(0, math.max(0, _points.length - 1));
          if (_points.isEmpty) _points = '0';
          break;
        case _InputTarget.number:
          _inputNumber = _inputNumber.substring(0, math.max(0, _inputNumber.length - 1));
          break;
        case _InputTarget.rangeFrom:
          _rangeFrom = _rangeFrom.substring(0, math.max(0, _rangeFrom.length - 1));
          break;
        case _InputTarget.rangeTo:
          _rangeTo = _rangeTo.substring(0, math.max(0, _rangeTo.length - 1));
          break;
        case _InputTarget.qty:
          _qty = _qty.substring(0, math.max(0, _qty.length - 1));
          break;
      }
      _validationMsg = '';
    });
  }

  void _clearActive() {
    setState(() {
      switch (_activeTarget) {
        case _InputTarget.points:
          _points = '0';
          break;
        case _InputTarget.number:
          _inputNumber = '';
          break;
        case _InputTarget.rangeFrom:
          _rangeFrom = '';
          break;
        case _InputTarget.rangeTo:
          _rangeTo = '';
          break;
        case _InputTarget.qty:
          _qty = '';
          break;
      }
      _validationMsg = '';
    });
  }

  void _adjustActive(int delta) {
    int current;
    switch (_activeTarget) {
      case _InputTarget.points:
        current = int.tryParse(_points) ?? 0;
        setState(() => _points = math.max(0, current + delta).toString());
        break;
      case _InputTarget.number:
        current = int.tryParse(_inputNumber) ?? 0;
        setState(() => _inputNumber = math.max(0, math.min(999, current + delta)).toString());
        break;
      case _InputTarget.rangeFrom:
        current = int.tryParse(_rangeFrom) ?? 0;
        setState(() => _rangeFrom = math.max(0, math.min(999, current + delta)).toString());
        break;
      case _InputTarget.rangeTo:
        current = int.tryParse(_rangeTo) ?? 0;
        setState(() => _rangeTo = math.max(0, math.min(999, current + delta)).toString());
        break;
      case _InputTarget.qty:
        current = int.tryParse(_qty) ?? 0;
        setState(() => _qty = math.max(0, math.min(999, current + delta)).toString());
        break;
    }
  }

  bool get _slotOpenForBuy {
    if (_serverSlot == null) return true;
    final acceptsBets = _serverSlot?['acceptsBets'];
    if (acceptsBets is bool) return acceptsBets;
    final phase = (_serverSlot?['phase'] ?? '').toString().toLowerCase();
    return phase == 'hint';
  }

  DateTime get _nextDrawAt {
    if (_serverSlot != null) {
      final nextIso = (_serverSlot?['nextSlotStartIso'] ?? '').toString().trim();
      final nextDt = DateTime.tryParse(nextIso);
      if (nextDt != null) return nextDt.toLocal();
      final startIso = (_serverSlot?['slotStartIso'] ?? '').toString().trim();
      final startDt = DateTime.tryParse(startIso);
      if (startDt != null) return startDt.toLocal().add(const Duration(minutes: 15));
    }
    return DateTime.now().add(const Duration(minutes: 15));
  }

  String _formatAdvanceSlotLabel(DateTime dateTime) {
    final local = dateTime.toLocal();
    final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final m = local.minute.toString().padLeft(2, '0');
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }

  List<Map<String, String>> get _advanceDrawSlots {
    final base = _nextDrawAt;
    final sameDate = DateTime(base.year, base.month, base.day);
    final endOfDate = sameDate.add(const Duration(days: 1));
    final slots = <Map<String, String>>[];
    var i = 0;
    while (true) {
      final dt = base.add(Duration(minutes: i * 15));
      if (!dt.isBefore(endOfDate)) break;
      slots.add({
        'slotStartIso': dt.toUtc().toIso8601String(),
        'label': _formatAdvanceSlotLabel(dt),
      });
      i += 1;
    }
    return slots;
  }

  Future<void> _openAdvancePage() async {
    final selected = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(
        builder: (_) => Lottery3DAdvancePage(
          currentLabel: _formatClock(_now),
          nextLabel: _timeToDrawText(),
          slotOptions: _advanceDrawSlots,
          selectedSlots: _selectedAdvanceSlots,
        ),
      ),
    );
    if (!mounted || selected == null) return;
    setState(() {
      _selectedAdvanceSlots = selected;
      _validationMsg = selected.isNotEmpty
          ? 'Advance slot selected (${selected.length})'
          : 'No advance slot selected';
    });
  }

  Future<void> _buy() async {
    if (_buying) return;
    if (_bets.isEmpty) {
      setState(() => _validationMsg = 'Add at least one bet before BUY.');
      return;
    }
    final total = _bets.fold<int>(0, (sum, e) => sum + e.points);
    final slotCount = _selectedAdvanceSlots.isNotEmpty ? _selectedAdvanceSlots.length : 1;
    final requiredBalance = total * slotCount;
    if (_walletBalance < requiredBalance) {
      setState(() => _validationMsg = 'Insufficient balance');
      return;
    }
    if (_slotSyncErr.isNotEmpty || !_slotOpenForBuy) {
      setState(() => _validationMsg = 'Current draw is not accepting bets.');
      return;
    }

    final grouped = <String, Map<int, int>>{};
    for (final b in _bets) {
      final q = b.panel == 'A' ? 1 : b.panel == 'B' ? 2 : 3;
      final key = '$q|${b.mode}';
      final map = grouped.putIfAbsent(key, () => <int, int>{});
      final num = int.tryParse(b.number) ?? 0;
      map[num] = (map[num] ?? 0) + b.points;
    }
    final rounds = grouped.entries.map((e) {
      final parts = e.key.split('|');
      return {
        'quizId': int.parse(parts[0]),
        'bets': e.value.entries.map((x) => {'number': x.key, 'amount': x.value, 'betMode': parts[1]}).toList(),
      };
    }).toList();

    setState(() => _buying = true);
    try {
      final headers = await _authHeaders();
      final targetSlots =
          _selectedAdvanceSlots.isNotEmpty ? List<String>.from(_selectedAdvanceSlots) : <String>[_nextDrawAt.toUtc().toIso8601String()];
      num? parsedBalance;
      for (final slotStartIso in targetSlots) {
        final res = await http.post(
          Uri.parse('$kApiBaseUrl/quiz/bet-batch'),
          headers: {'Content-Type': 'application/json', ...headers},
          body: jsonEncode({'rounds': rounds, 'mode': '3d', 'slotStartIso': slotStartIso}),
        );
        final body = jsonDecode(res.body) as Map<String, dynamic>?;
        if (res.statusCode < 200 || res.statusCode >= 300) {
          setState(() => _validationMsg = body?['message']?.toString() ?? 'BUY failed');
          return;
        }
        final data = body?['data'] is Map ? Map<String, dynamic>.from(body!['data'] as Map) : <String, dynamic>{};
        final b = data['balance'] is num ? data['balance'] as num : num.tryParse('${data['balance'] ?? ''}');
        if (b != null) parsedBalance = b;
      }
      if (parsedBalance != null) {
        final nextBalance = parsedBalance;
        await AuthService.instance.updateStoredBalance(nextBalance);
        if (mounted) setState(() => _walletBalance = nextBalance);
      } else {
        await _loadWalletBalance();
      }

      final ticketId = DateTime.now().millisecondsSinceEpoch.toString();
      final gameId = 'GM${ticketId.substring(math.max(0, ticketId.length - 12))}';
      setState(() {
        _lastTxnId = gameId;
        _tickets.insert(
          0,
          _TicketEntry(id: ticketId, createdAt: DateTime.now(), totalPoints: total, gameId: gameId, status: 'pending'),
        );
        _bets.clear();
        _selectedAdvanceSlots = const [];
        _validationMsg = slotCount > 1
            ? 'Status: pending. Scheduled for $slotCount future slots.'
            : 'Status: pending. Result will be shown after draw time.';
      });
      _addToast(slotCount > 1 ? 'Advance draw bets scheduled successfully' : 'Bet placed successfully');
      if (mounted) {
        final message = slotCount > 1
            ? 'Bet placed successfully for $slotCount slots.'
            : 'Bet placed successfully.';
        unawaited(
          showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Bet Success'),
              content: Text(message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          ),
        );
      }
    } catch (_) {
      setState(() => _validationMsg = 'BUY failed');
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  void _cancelLatestPending() {
    final idx = _tickets.indexWhere((t) => t.status == 'pending');
    if (idx < 0) {
      _addToast('No active ticket to cancel before draw time.');
      return;
    }
    final t = _tickets[idx];
    setState(() {
      _tickets[idx] = _TicketEntry(
        id: t.id,
        createdAt: t.createdAt,
        totalPoints: t.totalPoints,
        gameId: t.gameId,
        status: 'cancelled',
      );
      _walletBalance += t.totalPoints;
      _validationMsg = 'Ticket ${t.gameId} cancelled. Refund ${t.totalPoints}.';
    });
    _addToast('Ticket cancelled');
  }

  void _headerAction(String label) {
    if (label == 'Refresh') {
      setState(() {
        _selectedModes
          ..clear()
          ..add('box');
        _selectedPanels
          ..clear()
          ..add('A');
        _selectedDigits.clear();
        _selectedRate = 10;
        _inputNumber = '';
        _points = '10';
        _rangeFrom = '';
        _rangeTo = '';
        _qty = '';
        _lPickType = 'box';
        _activeTarget = _InputTarget.number;
        _validationMsg = '';
        _toast = '';
        _bets.clear();
      });
      unawaited(_syncQuizSlot());
      unawaited(_syncLastSlotResult());
      unawaited(_loadWalletBalance());
      _addToast('Refreshed and cleared');
      return;
    }
    if (label == 'Result') {
      Navigator.of(context).pushNamed('/lottery/3d/result');
      return;
    }
    if (label == 'Account') {
      Navigator.of(context).pushNamed('/lottery/3d/account');
      return;
    }
    if (label == 'Quiz') {
      Navigator.of(context).pushNamed('/lottery/3d/quiz');
      return;
    }
    if (label == 'Ticket List') {
      Navigator.of(context).pushNamed('/lottery/3d/ticket-list');
      return;
    }
    if (label == 'History') {
      Navigator.of(context).pushNamed('/lottery/3d/history');
      return;
    }
    if (label == 'Cancel Bet') {
      _cancelLatestPending();
      return;
    }
    _addToast('$label opened');
  }

  @override
  Widget build(BuildContext context) {
    final timer = _formatTimer(_timerSeconds);
    final totalPoints = _bets.fold<int>(0, (sum, e) => sum + e.points);
    final lastTicket = _tickets.isEmpty ? null : _tickets.first;
    final resultFresh = _lastResultUpdatedAt != null && DateTime.now().difference(_lastResultUpdatedAt!).inSeconds < 2;

    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(context).textTheme.apply(fontSizeFactor: 1).copyWith(
              bodyLarge: const TextStyle(fontSize: 10),
              bodyMedium: const TextStyle(fontSize: 10),
              bodySmall: const TextStyle(fontSize: 10),
              titleLarge: const TextStyle(fontSize: 10),
              titleMedium: const TextStyle(fontSize: 10),
              titleSmall: const TextStyle(fontSize: 10),
              labelLarge: const TextStyle(fontSize: 10),
              labelMedium: const TextStyle(fontSize: 10),
              labelSmall: const TextStyle(fontSize: 10),
            ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          ),
        ),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(fontSize: 10),
        child: Container(
          color: Colors.white,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: _booting
                  ? const _ThreeDLoadingView()
                  : Column(
                children: [
                  if (_toast.isNotEmpty)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _toast,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
                  _buildTopRow(resultFresh),
                  const SizedBox(height: 1),
                  _buildStatRow(timer, lastTicket),
                  const SizedBox(height: 1),
                  _buildMenuRow(),
                  const SizedBox(height: 1),
                  LinearProgressIndicator(
                    minHeight: _timerSeconds <= 300 ? 6 : 4,
                    value: _timerSeconds / _intervalSeconds,
                    color: _timerSeconds <= 300 ? const Color(0xFFD4372F) : const Color(0xFF2E59C6),
                    backgroundColor: _timerSeconds <= 300 ? const Color(0xFFFECDD3) : const Color(0xFFE8E8E8),
                  ),
                  const SizedBox(height: 1),
                  _buildPanelDigitRow(),
                  const SizedBox(height: 1),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(child: _buildLeftSection(totalPoints)),
                        const SizedBox(width: 4),
                        SizedBox(width: 220, child: _buildRightSection()),
                      ],
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

  Widget _buildTopRow(bool resultFresh) {
    Widget panel(String title, String value, Color base) {
      final setLabel = 'SET $title';
      return Expanded(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: resultFresh ? const Color(0xFFFBBF24) : Colors.transparent, width: 2),
          ),
          child: Column(
            children: [
              Container(
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: base,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                ),
                child: Text(setLabel, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                  color: base.withValues(alpha: 0.92),
                  child: Row(
                    children: value.padLeft(3, '-').substring(0, 3).split('').map((d) {
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                          child: Text(d, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 54,
      child: Row(
        children: [
          Container(
            width: 132,
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              border: Border.all(color: const Color(0xFFE5C177)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('3D Quiz', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF9F1239))),
                Text('Last Draw: $_lastDrawLabel', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.black)),
                Text('Wallet: ${_walletBalance.toStringAsFixed(0)}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF15803D))),
              ],
            ),
          ),
          const SizedBox(width: 4),
          panel('A', _topResults['A'] ?? '---', const Color(0xFF2563EB)),
          const SizedBox(width: 4),
          panel('B', _topResults['B'] ?? '---', const Color(0xFFDC2626)),
          const SizedBox(width: 4),
          panel('C', _topResults['C'] ?? '---', const Color(0xFF059669)),
          const SizedBox(width: 4),
          SizedBox(
            width: 70,
            height: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _exit3D,
              icon: const Icon(Icons.home, size: 10),
              label: const Text('Home'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF78350F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String timer, _TicketEntry? lastTicket) {
    Widget stat(String t, String v) {
      return Expanded(
        child: Container(
          height: 34,
          decoration: BoxDecoration(color: const Color(0xFFF8FAFC), border: Border.all(color: const Color(0xFF8B9AB3)), borderRadius: BorderRadius.circular(6)),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
            const SizedBox(height: 3),
            Text(v, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF1F2937))),
          ]),
        ),
      );
    }

    return Row(
      children: [
        stat('Time To Draw', timer),
        const SizedBox(width: 4),
        stat('Dr.Time', _timeToDrawText()),
        const SizedBox(width: 4),
        stat('Id', _playerId),
        const SizedBox(width: 4),
        stat('Time', _formatClock(_now)),
        const SizedBox(width: 4),
        stat('Last Ticket', (lastTicket?.status ?? '-').toUpperCase()),
        const SizedBox(width: 4),
        stat('Last Trn', _lastTxnId),
        const SizedBox(width: 4),
        stat('Last Win', _lastWinAmount.toString()),
      ],
    );
  }

  Widget _buildMenuRow() {
    const labels = ['Result', 'Account', 'Quiz', 'Ticket List', 'Cancel Bet', 'Refresh', 'History'];
    return Row(
      children: labels.map((label) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: SizedBox(
              height: 28,
              child: ElevatedButton(
                onPressed: () => _headerAction(label),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF7ECDE),
                  foregroundColor: const Color(0xFF6B4423),
                  side: const BorderSide(color: Colors.black),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPanelDigitRow() {
    return Row(
      children: [
        Wrap(
          spacing: 3,
          children: [
            FilterChip(
              selected: _selectedPanels.length == 3,
              onSelected: (_) => setState(() => _selectedPanels.length == 3 ? _selectedPanels.clear() : _selectedPanels.addAll(panelOptions)),
              label: const Text('All', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
              visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              labelPadding: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 0),
            ),
            for (final p in panelOptions)
              FilterChip(
                selected: _selectedPanels.contains(p),
                onSelected: (_) => setState(() => _selectedPanels.contains(p) ? _selectedPanels.remove(p) : _selectedPanels.add(p)),
                label: Text(p, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                labelPadding: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 0),
              ),
          ],
        ),
        const VerticalDivider(width: 8),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  selected: _selectedDigits.length == 10,
                  onSelected: (_) => setState(() => _selectedDigits.length == 10 ? _selectedDigits.clear() : _selectedDigits.addAll(digitOptions)),
                  label: const Text('All', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                  visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 0),
                ),
                const SizedBox(width: 3),
                for (final d in digitOptions)
                  Padding(
                    padding: const EdgeInsets.only(right: 2),
                    child: ChoiceChip(
                      selected: _selectedDigits.contains(d),
                      onSelected: (_) => setState(() => _selectedDigits.contains(d) ? _selectedDigits.remove(d) : _selectedDigits.add(d)),
                      label: Text(d, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                      visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 4),
        ElevatedButton(
          onPressed: _goBackTo2DInLandscape,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0F172A),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          child: const Text('Go back to 2D game'),
        ),
      ],
    );
  }

  Widget _buildLeftSection(int totalPoints) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(border: Border.all(color: const Color(0xFFD9D9D9)), borderRadius: BorderRadius.circular(8), color: Colors.white),
          padding: const EdgeInsets.all(2),
          child: Row(
            children: [
              for (int i = 0; i < modeOptions.length; i++) ...[
                if (i != 0) const SizedBox(width: 3),
                Expanded(
                  child: FilterChip(
                    selected: _selectedModes.contains(modeOptions[i]),
                    onSelected: (_) {
                      final m = modeOptions[i];
                      setState(() {
                        if (m == 'all') {
                          if (_selectedModes.contains('all')) {
                            _selectedModes.clear();
                          } else {
                            _selectedModes
                              ..clear()
                              ..add('all')
                              ..addAll(quickModes);
                          }
                        } else if (_selectedModes.contains(m)) {
                          _selectedModes.remove(m);
                          _selectedModes.remove('all');
                        } else {
                          _selectedModes.add(m);
                          if (quickModes.every(_selectedModes.contains)) _selectedModes.add('all');
                        }
                      });
                    },
                    label: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          modeOptions[i].toUpperCase(),
                          maxLines: 1,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ),
                    ),
                    visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 0),
                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 2),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _buildBetList(totalPoints)),
              const SizedBox(width: 4),
              Expanded(child: _buildFormAndTotals()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pillField(String label, String value, _InputTarget target) {
    final active = _activeTarget == target;
    String display = value;
    if (target == _InputTarget.number || target == _InputTarget.rangeFrom || target == _InputTarget.rangeTo) {
      final digits = value.replaceAll(RegExp(r'\D'), '');
      display = digits.isEmpty ? '' : digits.padLeft(3, '0');
    }
    return InkWell(
      onTap: () => setState(() => _activeTarget = target),
      child: Container(
        height: 24,
        width: label == 'ADD NUMBER'
            ? 76
            : (label == 'NUM' || label == 'RANGE' || label == 'TO')
                ? 50
                : 58,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: active ? const Color(0xFF2E59C6) : const Color(0xFFD1D5DB), width: active ? 2 : 1),
        ),
        child: Text(display.isEmpty ? label : display, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: display.isEmpty ? Colors.grey : Colors.black)),
      ),
    );
  }

  Widget _buildFormAndTotals() {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: const Color(0xFFD9D9D9)), borderRadius: BorderRadius.circular(8), color: Colors.white),
      padding: const EdgeInsets.all(2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: Inputs (split into two horizontal rows)
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(6),
              color: const Color(0xFFF8FAFC),
            ),
            padding: const EdgeInsets.all(4),
            child: Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _pillField('ADD NUMBER', _inputNumber, _InputTarget.number),
                      const SizedBox(width: 6),
                      _pillField('RANGE', _rangeFrom, _InputTarget.rangeFrom),
                      const SizedBox(width: 4),
                      _pillField('TO', _rangeTo, _InputTarget.rangeTo),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Container(
                        height: 24,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: const Color(0xFFD1D5DB)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _lPickType,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                            dropdownColor: Colors.white,
                            items: luckyPickModes.map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase()))).toList(),
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() => _lPickType = v);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      _pillField('QTY', _qty, _InputTarget.qty),
                      const SizedBox(width: 6),
                      ElevatedButton(onPressed: _addBet, child: const Text('ADD')),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Section 2: Rates
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(6),
              color: const Color(0xFFF8FAFC),
            ),
            padding: const EdgeInsets.all(4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Rates:',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: rateOptions
                      .map((r) => ChoiceChip(
                            selected: _selectedRate == r,
                            onSelected: (_) => setState(() {
                              _selectedRate = r;
                              _points = '$r';
                              _activeTarget = _InputTarget.points;
                            }),
                            label: SizedBox(
                              width: 22,
                              child: Center(
                                child: Text(
                                  '$r',
                                  style: const TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            labelPadding: const EdgeInsets.symmetric(horizontal: 1),
                            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          if (_validationMsg.isNotEmpty)
            Text(_validationMsg, style: const TextStyle(color: Color(0xFFD4372F), fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildBetList(int totalPoints) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: const Color(0xFFD9D9D9), width: 2), borderRadius: BorderRadius.circular(8), color: Colors.white),
      padding: const EdgeInsets.all(2),
      child: Column(
        children: [
          Expanded(
            child: _bets.isEmpty
                ? const Center(child: Text('No bets placed yet', style: TextStyle(fontSize: 9, color: Color(0xFF9A9A9A))))
                : GridView.builder(
                    itemCount: _bets.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 4,
                      crossAxisSpacing: 4,
                      childAspectRatio: 1.25,
                    ),
                    itemBuilder: (context, i) {
                      final b = _bets[i];
                      final head = b.panel == 'A' ? const Color(0xFF2563EB) : b.panel == 'B' ? const Color(0xFFDC2626) : const Color(0xFF059669);
                      final numberDigits = b.number.replaceAll(RegExp(r'\D'), '');
                      final visibleNumber = numberDigits.isEmpty ? '---' : numberDigits.padLeft(3, '0').substring(numberDigits.length > 3 ? numberDigits.length - 3 : 0);
                      return Container(
                        decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(10), color: const Color(0xFFF8FAFC)),
                        child: Column(
                          children: [
                            Container(height: 14, decoration: BoxDecoration(color: head, borderRadius: const BorderRadius.vertical(top: Radius.circular(9))), alignment: Alignment.center, child: Text(b.panel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 8))),
                            const SizedBox(height: 2),
                            Text(visibleNumber, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black)),
                            Text(b.mode.toUpperCase(), style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: Colors.black87)),
                            Text('Price ${b.rate}', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: Colors.black87)),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerRight,
            child: Text('Total Count: ${_bets.length}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _buying ? null : _buy,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                    minimumSize: const Size(0, 26),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: const Text('BUY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => setState(() => _bets.clear()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE11D48),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                    minimumSize: const Size(0, 26),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: const Text('Clear', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: ElevatedButton(
                  onPressed: _openAdvancePage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                    minimumSize: const Size(0, 26),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: const Text('Advance', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 40,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFFCD34D), width: 1.5),
                  borderRadius: BorderRadius.circular(4),
                  color: const Color(0xFFFFFBEB),
                ),
                child: Text(
                  '$totalPoints',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRightSection() {
    String centerValue;
    switch (_activeTarget) {
      case _InputTarget.points:
        centerValue = _points;
        break;
      case _InputTarget.number:
        centerValue = _inputNumber.isEmpty ? '0' : _inputNumber;
        break;
      case _InputTarget.rangeFrom:
        centerValue = _rangeFrom.isEmpty ? '0' : _rangeFrom;
        break;
      case _InputTarget.rangeTo:
        centerValue = _rangeTo.isEmpty ? '0' : _rangeTo;
        break;
      case _InputTarget.qty:
        centerValue = _qty.isEmpty ? '0' : _qty;
        break;
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  final pool = _selectedDigits.isEmpty ? digitOptions : _selectedDigits.toList();
                  final r = math.Random();
                  final nums = <String>[];
                  for (int i = 0; i < 5; i++) {
                    nums.add('${pool[r.nextInt(pool.length)]}${pool[r.nextInt(pool.length)]}${pool[r.nextInt(pool.length)]}');
                  }
                  _appendBets(nums, _normalizedModes().isEmpty ? ['box'] : _normalizedModes(), int.tryParse(_points) ?? _selectedRate);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: const Text('Motor', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  final q = (int.tryParse(_qty) ?? 10).clamp(1, 50);
                  final nums = _luckyNumbers(q, _lPickType);
                  _appendBets(nums, [_lPickType], int.tryParse(_points) ?? _selectedRate);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFBBF24),
                  foregroundColor: const Color(0xFF78350F),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: const Text('Lucky Pick', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFD5D5D5),
              border: Border.all(color: const Color(0xFF8B8B8B)),
              borderRadius: BorderRadius.circular(2),
            ),
            padding: const EdgeInsets.all(6),
            child: Column(
              children: [
                Row(
                  children: [
                    _ThreeDGradientSquareButton(
                      label: '-',
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4B5563), Color(0xFF374151)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      border: const Color(0xFF2F3946),
                      onTap: () => _adjustActive(-1),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Container(
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F7F7),
                          border: Border.all(color: const Color(0xFF8A8A8A)),
                        ),
                        child: Text(
                          centerValue,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _ThreeDGradientSquareButton(
                      label: '+',
                      gradient: const LinearGradient(
                        colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      border: const Color(0xFF15803D),
                      onTap: () => _adjustActive(1),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0', 'C', 'X'];
                      const spacing = 4.0;
                      const columns = 4.0;
                      const rows = 3.0;
                      final tileWidth = (constraints.maxWidth - ((columns - 1) * spacing)) / columns;
                      final tileHeight = (constraints.maxHeight - ((rows - 1) * spacing)) / rows;
                      final ratio = tileWidth > 0 && tileHeight > 0 ? tileWidth / tileHeight : 1.0;
                      return GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: keys.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns.toInt(),
                          crossAxisSpacing: spacing,
                          mainAxisSpacing: spacing,
                          childAspectRatio: ratio,
                        ),
                        itemBuilder: (context, index) {
                          final k = keys[index];
                          final isRed = k == 'C' || k == 'X';
                          return ElevatedButton(
                            onPressed: () {
                              if (k == 'C') {
                                _clearActive();
                                return;
                              }
                              if (k == 'X') {
                                _deleteOne();
                                return;
                              }
                              _digitInput(k);
                            },
                            style: ElevatedButton.styleFrom(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(2),
                                side: BorderSide(
                                  color: isRed ? const Color(0xFFD63F35) : const Color(0xFF8A8A8A),
                                ),
                              ),
                              backgroundColor: isRed ? const Color(0xFFF04438) : const Color(0xFFF4F4F4),
                              foregroundColor: isRed ? Colors.white : Colors.black,
                              padding: EdgeInsets.zero,
                            ),
                            child: Text(
                              k,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  height: 30,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_inputNumber.isNotEmpty || _rangeFrom.isNotEmpty || _rangeTo.isNotEmpty || _qty.isNotEmpty) {
                        _addBet();
                        return;
                      }
                      setState(() {
                        _activeTarget = _InputTarget.values[(_activeTarget.index + 1) % _InputTarget.values.length];
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: const Color(0xFF4F46E5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(2),
                        side: const BorderSide(color: Color(0xFF3730A3)),
                      ),
                    ),
                    child: const Text(
                      'NEXT',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ThreeDLoadingView extends StatelessWidget {
  const _ThreeDLoadingView();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.white,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 26,
            width: 26,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF93C5FD)),
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Preparing 3D in landscape...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThreeDGradientSquareButton extends StatelessWidget {
  const _ThreeDGradientSquareButton({
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
      width: 36,
      height: 36,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
        ),
        child: TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: EdgeInsets.zero,
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}
