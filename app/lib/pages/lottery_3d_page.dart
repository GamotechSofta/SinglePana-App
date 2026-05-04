import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'lottery_3d_account_page.dart';
import 'lottery_3d_advance_page.dart';
import 'lottery_3d_subpages.dart';
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
  bool _keepLandscapeOnExit = false;
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
  final TransformationController _zoomController = TransformationController();
  bool _isZoomedIn = false;

  @override
  void initState() {
    super.initState();
    _zoomController.addListener(_handleZoomTransformChanged);
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
    _zoomController.removeListener(_handleZoomTransformChanged);
    _zoomController.dispose();
    if (!_keepLandscapeOnExit) {
      unawaited(_restorePortraitOrientation());
    }
    super.dispose();
  }

  void _handleZoomTransformChanged() {
    final zoomed = _zoomController.value.getMaxScaleOnAxis() > 1.01;
    if (!mounted || zoomed == _isZoomedIn) return;
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
    await SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    _restoringPortrait = false;
  }

  Future<void> _exit3D() async {
    await _restorePortraitOrientation();
    if (!mounted) return;
    try {
      await Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    } catch (_) {
      if (!mounted) return;
      await Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  Future<void> _goBackTo2DGame() async {
    _keepLandscapeOnExit = true;
    await _configureOrientationForLottery();
    if (!mounted) return;
    await Navigator.of(context).pushNamedAndRemoveUntil(
      '/lottery',
      (route) {
        final name = route.settings.name;
        return name == '/' || name == '/home';
      },
    );
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
      String pick(List<String> keys) {
        for (final k in keys) {
          final v = user?[k];
          if (v == null) continue;
          final s = v.toString().trim();
          if (s.isNotEmpty) return s;
        }
        return '';
      }
      final first = pick(['firstName', 'firstname', 'givenName']);
      final last = pick(['lastName', 'lastname', 'surname']);
      final full = '$first $last'.trim();
      final id = full.isNotEmpty ? full : pick(['name', 'fullName', 'userName', 'username', 'phone', 'mobile']);
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
        final incoming = Map<String, dynamic>.from(body!['data'] as Map);
        setState(() {
          _serverSlot = incoming;
          // Frontend-like behavior: try to derive top A/B/C from current slot payload too.
          _applyTopResultsFromSlotMap(incoming);
          final possibleResultsKeys = [
            'results',
            'lastResults',
            'currentResults',
            'slotResults',
            'quizResults',
          ];
          for (final key in possibleResultsKeys) {
            final raw = incoming[key];
            if (raw is List) {
              _applyTopResultsFromSlotMap(<String, dynamic>{'results': raw, ...incoming});
            }
          }
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

  bool _applyTopResultsFromSlotMap(Map<String, dynamic> slot) {
    final results = <String, String>{
      'A': _topResults['A'] ?? '---',
      'B': _topResults['B'] ?? '---',
      'C': _topResults['C'] ?? '---',
    };
    var changed = false;
    final rawResults = slot['results'];
    if (rawResults is List) {
      for (final e in rawResults) {
        if (e is! Map) continue;
        final m = Map<String, dynamic>.from(e);
        final quizId = int.tryParse('${m['quizId'] ?? m['quiz_id'] ?? m['quiz'] ?? ''}');
        final panelRaw = '${m['panel'] ?? m['set'] ?? m['label'] ?? ''}'.trim().toUpperCase();
        final result = '${m['result'] ?? m['value'] ?? m['number'] ?? ''}';
        if ((quizId == 1 || panelRaw == 'A') && result.trim().isNotEmpty) {
          results['A'] = _to3(result);
          changed = true;
        }
        if ((quizId == 2 || panelRaw == 'B') && result.trim().isNotEmpty) {
          results['B'] = _to3(result);
          changed = true;
        }
        if ((quizId == 3 || panelRaw == 'C') && result.trim().isNotEmpty) {
          results['C'] = _to3(result);
          changed = true;
        }
      }
    }
    final fallbackA = slot['a'] ?? slot['A'] ?? slot['setA'] ?? slot['set_a'] ?? slot['resultA'] ?? slot['result_a'];
    final fallbackB = slot['b'] ?? slot['B'] ?? slot['setB'] ?? slot['set_b'] ?? slot['resultB'] ?? slot['result_b'];
    final fallbackC = slot['c'] ?? slot['C'] ?? slot['setC'] ?? slot['set_c'] ?? slot['resultC'] ?? slot['result_c'];
    if (fallbackA != null && '$fallbackA'.trim().isNotEmpty) {
      results['A'] = _to3('$fallbackA');
      changed = true;
    }
    if (fallbackB != null && '$fallbackB'.trim().isNotEmpty) {
      results['B'] = _to3('$fallbackB');
      changed = true;
    }
    if (fallbackC != null && '$fallbackC'.trim().isNotEmpty) {
      results['C'] = _to3('$fallbackC');
      changed = true;
    }
    if (changed) {
      _topResults
        ..clear()
        ..addAll(results);
      _lastDrawLabel = (slot['drawLabelEnd'] ?? slot['timeLabel'] ?? _lastDrawLabel).toString();
      _lastResultUpdatedAt = DateTime.now();
    }
    return changed;
  }

  Future<void> _syncLastSlotResult() async {
    try {
      final res = await http.get(Uri.parse('$kApiBaseUrl/quiz/slot-results?limit=1&mode=3d'));
      final body = jsonDecode(res.body) as Map<String, dynamic>?;
      if (!mounted) return;
      if (res.statusCode < 200 || res.statusCode >= 300 || body?['success'] != true) return;
      final data = body?['data'];
      List<dynamic> slotList;
      if (data is List) {
        slotList = data;
      } else if (data is Map && data['slots'] is List) {
        slotList = data['slots'] as List;
      } else {
        return;
      }
      if (slotList.isEmpty || slotList.first is! Map) return;
      final slot = Map<String, dynamic>.from(slotList.first as Map);
      var updated = false;
      setState(() {
        updated = _applyTopResultsFromSlotMap(slot);
      });
      // React page also uses date-based slot fetch fallback; do same when latest endpoint has no values.
      if (!updated) {
        final now = DateTime.now();
        final dayKey =
            '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        final res2 = await http.get(Uri.parse('$kApiBaseUrl/quiz/slot-results?date=$dayKey&mode=3d&limit=96'));
        final body2 = jsonDecode(res2.body) as Map<String, dynamic>?;
        if (!mounted) return;
        if (res2.statusCode >= 200 && res2.statusCode < 300 && body2?['success'] == true) {
          final data2 = body2?['data'];
          final slotList2 = data2 is Map && data2['slots'] is List
              ? (data2['slots'] as List)
              : (data2 is List ? data2 : const []);
          if (slotList2.isNotEmpty && slotList2.first is Map) {
            final slot2 = Map<String, dynamic>.from(slotList2.first as Map);
            setState(() {
              _applyTopResultsFromSlotMap(slot2);
            });
          }
        }
      }
    } catch (_) {}
  }

  int get _timerSeconds {
    final elapsed = (_now.minute % 15) * 60 + _now.second;
    final rem = _intervalSeconds - elapsed;
    return rem <= 0 ? _intervalSeconds : rem;
  }

  String _formatTimer(int s) => '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  String _formatTimeNoSeconds(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final ampm = t.hour >= 12 ? 'PM' : 'AM';
    return '$h:${t.minute.toString().padLeft(2, '0')} $ampm';
  }

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

  DateTime _nextDrawAt() {
    final nextIso = (_serverSlot?['nextSlotStartIso'] ?? '').toString().trim();
    final nextDt = DateTime.tryParse(nextIso);
    if (nextDt != null) return nextDt.toLocal();
    return _nextDraw(_now);
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

  Future<void> _openAdvancePage() async {
    final slots = _buildAdvanceSlots();
    if (slots.isEmpty) {
      _addToast('No upcoming slots available.');
      return;
    }
    final selected = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(
        builder: (_) => Lottery3DAdvancePage(
          currentLabel: _formatTimeNoSeconds(_now),
          nextLabel: _formatTimeNoSeconds(_nextDrawAt()),
          slotOptions: slots,
          selectedSlots: _selectedAdvanceSlots,
        ),
      ),
    );
    if (!mounted || selected == null) return;
    setState(() => _selectedAdvanceSlots = selected);
    _addToast(
      selected.isEmpty ? 'Advance draw cleared' : 'Advance slots selected: ${selected.length}',
    );
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

  List<String> _rangeNumbers(String from, String to) {
    final f = int.tryParse(from);
    final t = int.tryParse(to);
    if (f == null || t == null || f > t || f < 0 || t > 999 || (t - f + 1) > 1000) return [];
    return [for (int i = f; i <= t; i++) i.toString().padLeft(3, '0')];
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
    _addToast('Bet added');
  }

  void _addBet() {
    final pts = _selectedRate;
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
    var autoAdd = false;
    setState(() {
      String append(String v, int max) {
        final next = '$v$d'.replaceAll(RegExp(r'\D'), '');
        return next.substring(0, math.min(max, next.length));
      }
      final before = _inputNumber.length;
      _inputNumber = append(_inputNumber, 3);
      if (before < 3 && _inputNumber.length == 3) autoAdd = true;
      _validationMsg = '';
    });
    if (autoAdd) {
      Future<void>.delayed(const Duration(milliseconds: 10), () {
        if (!mounted) return;
        _addBet();
      });
    }
  }

  void _deleteOne() {
    setState(() {
      _inputNumber = _inputNumber.substring(0, math.max(0, _inputNumber.length - 1));
      _validationMsg = '';
    });
  }

  void _clearActive() {
    setState(() {
      _inputNumber = '';
      _validationMsg = '';
    });
  }

  void _adjustActive(int delta) {
    final current = int.tryParse(_inputNumber) ?? 0;
    setState(() => _inputNumber = math.max(0, math.min(999, current + delta)).toString());
  }

  bool get _slotOpenForBuy {
    if (_serverSlot == null) return true;
    final acceptsBets = _serverSlot?['acceptsBets'];
    if (acceptsBets is bool) return acceptsBets;
    final phase = (_serverSlot?['phase'] ?? '').toString().toLowerCase();
    return phase == 'hint';
  }

  Future<void> _buy() async {
    final proceed = await _showBetPreviewDialog3d();
    if (proceed != true) return;
    await _executeBuy();
  }

  Future<void> _executeBuy() async {
    if (_buying) return;
    if (_bets.isEmpty) {
      setState(() => _validationMsg = 'Add at least one bet before BUY.');
      return;
    }
    final total = _bets.fold<int>(0, (sum, e) => sum + e.points);
    if (_walletBalance < total) {
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
      final targetSlots = _selectedAdvanceSlots.isNotEmpty ? List<String>.from(_selectedAdvanceSlots) : <String>[];
      num? parsedBalance;
      for (final slotStartIso in (targetSlots.isEmpty ? <String?>[null] : targetSlots)) {
        final payload = <String, dynamic>{'rounds': rounds, 'mode': '3d'};
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
          setState(() => _validationMsg = body?['message']?.toString() ?? 'BUY failed');
          return;
        }
        final data = body?['data'] is Map ? Map<String, dynamic>.from(body!['data'] as Map) : <String, dynamic>{};
        final b = data['balance'] is num ? data['balance'] as num : num.tryParse('${data['balance'] ?? ''}');
        if (b != null) parsedBalance = b;
      }
      if (parsedBalance != null) {
        final balance = parsedBalance;
        await AuthService.instance.updateStoredBalance(balance);
        if (mounted) setState(() => _walletBalance = balance);
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
        _validationMsg = '';
      });
      if (!mounted) return;
      await _showSuccessDialog3d(gameId, total);
    } catch (_) {
      setState(() => _validationMsg = 'BUY failed');
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  Future<void> _cancelLatestPending() async {
    final idx = _tickets.indexWhere((t) => t.status == 'pending');
    if (idx < 0) {
      _addToast('No active ticket to cancel before draw time.');
      return;
    }
    final t = _tickets[idx];
    final confirmed = await _showCancelBetDialog(t);
    if (confirmed != true) return;
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

  void _resetAllFields() {
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
      _tickets.clear();
      _selectedAdvanceSlots = const [];
    });
  }

  void _headerAction(String label) {
    if (label == 'Refresh') {
      _resetAllFields();
      unawaited(_syncQuizSlot());
      unawaited(_syncLastSlotResult());
      unawaited(_loadWalletBalance());
      _addToast('All fields cleared');
      return;
    }
    if (label == 'Quiz') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const Lottery3DQuizPage()),
      );
      return;
    }
    if (label == 'Cancel Bet') {
      unawaited(_cancelLatestPending());
      return;
    }
    if (label == 'Result') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const Lottery3DResultPage()),
      );
      return;
    }
    if (label == 'Account') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const Lottery3DAccountPage()),
      );
      return;
    }
    if (label == 'History') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const Lottery3DHistoryPage()),
      );
      return;
    }
    if (label == 'Ticket List') {
      if (_bets.isNotEmpty) {
        unawaited(_showCurrentBetsTicketDialog());
      } else {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const Lottery3DTicketListPage()),
        );
      }
      return;
    }
    _addToast(label);
  }

  Future<void> _showCurrentBetsTicketDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        final total = _bets.fold<int>(0, (sum, e) => sum + e.points);
        return AlertDialog(
          title: const Text('Current Bets'),
          content: SizedBox(
            width: 420,
            height: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total Bets: ${_bets.length}'),
                Text('Total Points: $total'),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _bets.length,
                    itemBuilder: (context, i) {
                      final b = _bets[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text('${b.panel}-${b.number} [${b.mode.toUpperCase()}] x ${b.points}'),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<bool?> _showBetPreviewDialog3d() {
    final total = _bets.fold<int>(0, (sum, e) => sum + e.points);
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: const Color(0xFF171717),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 540),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('You want to place bet?', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text('Total Bets: ${_bets.length}    Amount: $total', style: const TextStyle(color: Color(0xFFD4D4D4), fontSize: 12)),
                  const SizedBox(height: 10),
                  Flexible(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F0F0F),
                        border: Border.all(color: const Color(0xFF3F3F46)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _bets.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFF27272A)),
                        itemBuilder: (context, i) {
                          final b = _bets[i];
                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                            title: Text('${b.number} (${b.panel})', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                            subtitle: Text('${b.mode.toUpperCase()}  x  ${b.points}', style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 11)),
                            trailing: IconButton(
                              icon: const Icon(Icons.close, size: 16, color: Color(0xFFF87171)),
                              onPressed: () => setState(() => _bets.removeAt(i)),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF52525B)),
                            foregroundColor: const Color(0xFFE5E7EB),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          child: const Text('Cancel', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          child: const Text('Buy Tickets', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
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
  }

  Future<void> _showSuccessDialog3d(String gameId, int total) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF171717),
          title: const Text('Bets Placed Successfully', style: TextStyle(color: Colors.white, fontSize: 14)),
          content: Text('Ticket: $gameId\nAmount: $total', style: const TextStyle(color: Color(0xFFD4D4D8), fontSize: 12)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK', style: TextStyle(color: Color(0xFF60A5FA))),
            ),
          ],
        );
      },
    );
  }

  Future<bool?> _showCancelBetDialog(_TicketEntry t) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF171717),
          title: const Text('Cancel Ticket Bet', style: TextStyle(color: Colors.white, fontSize: 14)),
          content: Text(
            'Ticket ID: ${t.gameId}\nDraw Time: ${_timeToDrawText()}\nAmount: ${t.totalPoints}\nRefund: ${t.totalPoints}',
            style: const TextStyle(color: Color(0xFFD4D4D8), fontSize: 12),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No', style: TextStyle(color: Color(0xFFA1A1AA))),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
              child: const Text('Yes, Cancel'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final timer = _formatTimer(_timerSeconds);
    final totalPoints = _bets.fold<int>(0, (sum, e) => sum + e.points);
    final lastTicket = _tickets.isEmpty ? null : _tickets.first;
    final resultFresh = _lastResultUpdatedAt != null && DateTime.now().difference(_lastResultUpdatedAt!).inSeconds < 2;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        unawaited(_goBackTo2DGame());
      },
      child: Theme(
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
          child: Stack(
            children: [
              InteractiveViewer(
                transformationController: _zoomController,
                minScale: 1,
                maxScale: 2.5,
                panEnabled: true,
                scaleEnabled: true,
                clipBehavior: Clip.hardEdge,
                child: Container(
                  color: const Color(0xFF0B1223),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: _booting
                          ? const _ThreeDLoadingView()
                          : Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(2),
                      child: Column(
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
                          const SizedBox(height: 2),
                          _sectionFrame(child: _buildStatRow(timer, lastTicket)),
                          const SizedBox(height: 2),
                          _sectionFrame(child: _buildMenuRow()),
                          const SizedBox(height: 2),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              minHeight: _timerSeconds <= 300 ? 6 : 4,
                              value: _timerSeconds / _intervalSeconds,
                              color: _timerSeconds <= 300 ? const Color(0xFFD4372F) : const Color(0xFF2E59C6),
                              backgroundColor: _timerSeconds <= 300 ? const Color(0xFFFECDD3) : const Color(0xFFE8E8E8),
                            ),
                          ),
                          const SizedBox(height: 2),
                          _sectionFrame(child: _buildPanelDigitRow()),
                          const SizedBox(height: 2),
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(child: _buildLeftSection(totalPoints)),
                                const SizedBox(width: 4),
                                SizedBox(width: 184, child: _buildRightSection()),
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
                    onPressed: () => _zoomController.value = Matrix4.identity(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xAA000000),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: Color(0xFF4C4C4C)),
                      ),
                    ),
                    icon: const Icon(Icons.center_focus_strong, size: 14),
                    label: const Text('Reset Zoom'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopRow(bool resultFresh) {
    Widget panel(String title, String value, Color base) {
      return Expanded(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: resultFresh ? const Color(0xFFFBBF24) : Colors.transparent, width: 2),
          ),
          child: Column(
            children: [
              Container(
                height: 16,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: base,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                ),
                child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(2),
                  color: base.withValues(alpha: 0.92),
                  child: Row(
                    children: value.padLeft(3, '-').substring(0, 3).split('').map((d) {
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                          child: Text(d, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
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
      height: 42,
      child: Row(
        children: [
          Container(
            width: 150,
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
          panel('SET A', _topResults['A'] ?? '---', const Color(0xFF2563EB)),
          const SizedBox(width: 4),
          panel('SET B', _topResults['B'] ?? '---', const Color(0xFFDC2626)),
          const SizedBox(width: 4),
          panel('SET C', _topResults['C'] ?? '---', const Color(0xFF059669)),
          const SizedBox(width: 4),
          SizedBox(
            width: 70,
            child: ElevatedButton.icon(
              onPressed: _exit3D,
              icon: const Icon(Icons.home, size: 10),
              label: const Text('Home'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF78350F), foregroundColor: Colors.white),
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
          height: 32,
          decoration: BoxDecoration(color: const Color(0xFFF8FAFC), border: Border.all(color: const Color(0xFF8B9AB3)), borderRadius: BorderRadius.circular(6)),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
            const SizedBox(height: 1),
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
        stat('Last Win', _lastWinAmount.toString()),
        const SizedBox(width: 4),
        SizedBox(
          width: 130,
          height: 32,
          child: ElevatedButton(
            onPressed: _goBackTo2DGame,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 32),
              maximumSize: const Size(double.infinity, 32),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: const Text(
              'Go back to 2D game',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuRow() {
    const labels = ['Result', 'Account', 'Quiz', 'Ticket List', 'Cancel Bet', 'Refresh', 'History'];
    return SizedBox(
      height: 28,
      child: Row(
      children: labels.map((label) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 0),
            child: ElevatedButton(
              onPressed: () => _headerAction(label),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF3EDE3),
                foregroundColor: const Color(0xFF5B3B1F),
                side: const BorderSide(color: Color(0xFF6B7280)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                minimumSize: const Size(0, 26),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Center(
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
      ),
    );
  }

  Widget _sectionFrame({required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.all(1),
      child: child,
    );
  }

  Widget _buildPanelDigitRow() {
    return SizedBox(
      height: 34,
      child: Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        border: Border.all(color: const Color(0xFFD1D5DB)),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
      child: Row(
        children: [
          Row(
            children: [
              _selectorButton(
                label: 'All',
                selected: _selectedPanels.length == 3,
                onTap: () => setState(() => _selectedPanels.length == 3 ? _selectedPanels.clear() : _selectedPanels.addAll(panelOptions)),
                minWidth: 30,
                fontSize: 11,
                selectedColor: const Color(0xFF2563EB),
                withCheck: true,
              ),
              const SizedBox(width: 2),
              for (final p in panelOptions) ...[
                _selectorButton(
                  label: p,
                  selected: _selectedPanels.contains(p),
                  onTap: () => setState(() => _selectedPanels.contains(p) ? _selectedPanels.remove(p) : _selectedPanels.add(p)),
                  selectedColor: const Color(0xFF065F46),
                  minWidth: 26,
                  fontSize: 11,
                  withCheck: true,
                ),
                const SizedBox(width: 2),
              ],
            ],
          ),
          const VerticalDivider(width: 8, color: Color(0xFFCBD5E1)),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _selectorButton(
                    label: 'All',
                    selected: _selectedDigits.length == 10,
                    onTap: () => setState(() => _selectedDigits.length == 10 ? _selectedDigits.clear() : _selectedDigits.addAll(digitOptions)),
                    minWidth: 30,
                    fontSize: 11,
                    selectedColor: const Color(0xFF4F46E5),
                    withCheck: true,
                  ),
                  const SizedBox(width: 2),
                  for (final d in digitOptions)
                    Padding(
                      padding: const EdgeInsets.only(right: 2),
                      child: _selectorButton(
                        label: d,
                        selected: _selectedDigits.contains(d),
                        onTap: () => setState(() => _selectedDigits.contains(d) ? _selectedDigits.remove(d) : _selectedDigits.add(d)),
                        minWidth: 24,
                        fontSize: 11,
                        selectedColor: const Color(0xFF4F46E5),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 2),
          SizedBox(
            width: 60,
            height: 24,
            child: ElevatedButton(
              onPressed: () {
                final pool = _selectedDigits.isEmpty ? digitOptions : _selectedDigits.toList();
                final r = math.Random();
                final nums = <String>[];
                for (int i = 0; i < 5; i++) {
                  nums.add('${pool[r.nextInt(pool.length)]}${pool[r.nextInt(pool.length)]}${pool[r.nextInt(pool.length)]}');
                }
                _appendBets(nums, _normalizedModes().isEmpty ? ['box'] : _normalizedModes(), _selectedRate);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              child: const Text('Motor', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(width: 2),
          SizedBox(
            width: 68,
            height: 24,
            child: ElevatedButton(
              onPressed: () {
                final q = (int.tryParse(_qty) ?? 10).clamp(1, 50);
                final nums = _luckyNumbers(q, _lPickType);
                _appendBets(nums, [_lPickType], _selectedRate);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFBBF24),
                foregroundColor: const Color(0xFF78350F),
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              child: const Text('Lucky Pick', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildLeftSection(int totalPoints) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFD9D9D9)),
            borderRadius: BorderRadius.circular(8),
            color: const Color(0xFFFFFBEB),
          ),
          padding: const EdgeInsets.all(2),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  for (final m in modeOptions) ...[
                    _selectorButton(
                      label: m.toUpperCase(),
                      selected: _selectedModes.contains(m),
                      selectedColor: const Color(0xFF065F46),
                      withCheck: true,
                      minWidth: 44,
                      onTap: () {
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
                    ),
                    const SizedBox(width: 4),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              border: Border.all(color: const Color(0xFFD1D5DB)),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(2),
            child: Row(
              children: [
                Expanded(child: _buildBetList(totalPoints)),
                const SizedBox(width: 4),
                Expanded(child: _buildFormAndTotals(totalPoints)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _pillField(String label, String value, _InputTarget target) {
    final active = target == _InputTarget.number;
    return InkWell(
      onTap: () => setState(() => _activeTarget = _InputTarget.number),
      child: Container(
        height: 24,
        width: label == 'ADD NUMBER' ? 118 : 58,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: active ? const Color(0xFF2E59C6) : const Color(0xFFD1D5DB), width: active ? 2 : 1),
        ),
        child: Text(value.isEmpty ? label : value, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: value.isEmpty ? Colors.grey : Colors.black)),
      ),
    );
  }

  Widget _buildFormAndTotals(int totalPoints) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: const Color(0xFFD9D9D9)), borderRadius: BorderRadius.circular(8), color: Colors.white),
      padding: const EdgeInsets.all(2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Row(children: [
                _labeledInput('ADD NUMBER', _pillField('ADD NUMBER', _inputNumber, _InputTarget.number)),
                const SizedBox(width: 6),
                _labeledInput('RANGE', _pillField('NUM.', _rangeFrom, _InputTarget.rangeFrom)),
                const SizedBox(width: 6),
                _labeledInput('TO', _pillField('NUM.', _rangeTo, _InputTarget.rangeTo)),
              ]),
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              _labeledInput(
                'L-PICK',
                Container(
                  height: 26,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFD1D5DB)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _lPickType,
                      isDense: true,
                      dropdownColor: Colors.white,
                      style: const TextStyle(fontSize: 10, color: Colors.black, fontWeight: FontWeight.w700),
                      items: luckyPickModes
                          .map((e) => DropdownMenuItem(
                                value: e,
                                child: Text(
                                  e.toUpperCase(),
                                  style: const TextStyle(color: Colors.black),
                                ),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _lPickType = v);
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _labeledInput('QTY', _pillField('Qty', _qty, _InputTarget.qty)),
              const SizedBox(width: 8),
              SizedBox(
                height: 24,
                child: ElevatedButton(
                  onPressed: _addBet,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF111827),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                      side: const BorderSide(color: Color(0xFF334155)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  ),
                  child: const Text(
                    'ADD',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          const Text('Rates:', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800)),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final r in rateOptions) ...[
                  _rateChip(r),
                  const SizedBox(width: 3),
                ],
              ],
            ),
          ),
          const SizedBox(height: 2),
          if (_validationMsg.isNotEmpty)
            Text(_validationMsg, style: const TextStyle(color: Color(0xFFD4372F), fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
        ],
      ),
    );
  }

  Widget _labeledInput(String label, Widget child) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Color(0xFF374151))),
        const SizedBox(height: 2),
        child,
      ],
    );
  }

  Widget _rateChip(int rate) {
    final selected = _selectedRate == rate;
    return InkWell(
      onTap: () => setState(() {
        _selectedRate = rate;
        _points = '$rate';
      }),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        width: 38,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF065F46) : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? const Color(0xFF047857) : const Color(0xFF1F2937)),
        ),
        child: Text(
          '$rate',
          style: TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _selectorButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    Color selectedColor = const Color(0xFF111827),
    bool withCheck = false,
    double minWidth = 48,
    double fontSize = 9,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: BoxConstraints(minWidth: minWidth),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? selectedColor : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF1F2937)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (withCheck && selected) ...[
              const Icon(Icons.check, size: 12, color: Colors.white),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHintDialog() {
    final hint = (_serverSlot?['hint'] ?? '').toString().trim();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hint'),
        content: Text(hint.isEmpty ? 'No hint available for current quiz.' : hint),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
        ],
      ),
    );
  }

  Widget _keypadButton(String key, {Color? backgroundColor, Color? textColor}) {
    return ElevatedButton(
      onPressed: () {
        if (key == 'X') {
          _deleteOne();
          return;
        }
        if (key == 'C') {
          _clearActive();
          return;
        }
        _digitInput(key);
      },
      style: ElevatedButton.styleFrom(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(3),
          side: BorderSide(color: (backgroundColor ?? const Color(0xFFF4F4F4)) == const Color(0xFFF04438) ? const Color(0xFFD63F35) : const Color(0xFF9CA3AF)),
        ),
        backgroundColor: backgroundColor ?? const Color(0xFFF4F4F4),
        foregroundColor: textColor ?? Colors.black,
        padding: EdgeInsets.zero,
        minimumSize: const Size(double.infinity, 30),
      ),
      child: Text(
        key,
        style: TextStyle(
          fontSize: key == 'C' || key == 'X' ? 10 : 11,
          fontWeight: FontWeight.w800,
        ),
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
                      return Container(
                        decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(10), color: const Color(0xFFF8FAFC)),
                        child: Column(
                          children: [
                            Container(height: 14, decoration: BoxDecoration(color: head, borderRadius: const BorderRadius.vertical(top: Radius.circular(9))), alignment: Alignment.center, child: Text(b.panel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 8))),
                            const SizedBox(height: 2),
                            Text(
                              b.number,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: Colors.black,
                              ),
                            ),
                            Text(b.mode.toUpperCase(), style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                            Text('Price ${b.rate}', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                          ],
                        ),
                      );
                    },
                  ),
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
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('BUY', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => setState(() => _bets.clear()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE11D48),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Clear', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: ElevatedButton(
                  onPressed: _openAdvancePage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    _selectedAdvanceSlots.isEmpty ? 'Advance' : 'Advance (${_selectedAdvanceSlots.length})',
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 50,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(border: Border.all(color: const Color(0xFFFCD34D), width: 2), borderRadius: BorderRadius.circular(8), color: const Color(0xFFFFFBEB)),
                child: Text(
                  '$totalPoints',
                  style: const TextStyle(
                    fontSize: 9,
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
    final centerValue = _inputNumber.isEmpty ? '0' : _inputNumber;

    return Column(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              border: Border.all(color: const Color(0xFF9CA3AF)),
              borderRadius: BorderRadius.circular(6),
            ),
            padding: const EdgeInsets.all(4),
            child: Column(
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 30,
                      height: 26,
                      child: ElevatedButton(
                        onPressed: () => _adjustActive(-1),
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: const Color(0xFF475569),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: const BorderSide(color: Color(0xFF334155)),
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        child: const Text('-', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Container(
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          border: Border.all(color: const Color(0xFF9CA3AF)),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          centerValue,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    SizedBox(
                      width: 30,
                      height: 26,
                      child: ElevatedButton(
                        onPressed: () => _adjustActive(1),
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: const Color(0xFF22C55E),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: const BorderSide(color: Color(0xFF16A34A)),
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        child: const Text('+', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: GridView.count(
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 3,
                          mainAxisSpacing: 1.5,
                          crossAxisSpacing: 1.5,
                          childAspectRatio: 2.45,
                          children: [
                            _keypadButton('1'),
                            _keypadButton('2'),
                            _keypadButton('3'),
                            _keypadButton('4'),
                            _keypadButton('5'),
                            _keypadButton('6'),
                            _keypadButton('7'),
                            _keypadButton('8'),
                            _keypadButton('9'),
                            _keypadButton('0'),
                            _keypadButton(
                              'X',
                              backgroundColor: const Color(0xFFF04438),
                              textColor: Colors.white,
                            ),
                            const SizedBox.shrink(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                SizedBox(
                  width: double.infinity,
                  height: 26,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_inputNumber.isNotEmpty || _rangeFrom.isNotEmpty || _rangeTo.isNotEmpty || _qty.isNotEmpty) {
                        _addBet();
                        return;
                      }
                      _addToast('Enter Add Number');
                    },
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: const Color(0xFF4F46E5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(2),
                        side: const BorderSide(color: Color(0xFF4338CA)),
                      ),
                    ),
                    child: const Text(
                      'NEXT',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
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
      color: const Color(0xFF0B1223),
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
      width: 40,
      height: 40,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: border),
        ),
        child: TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            padding: EdgeInsets.zero,
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}
