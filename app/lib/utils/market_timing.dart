// IST market closing logic — ported from frontend/src/utils/marketTiming.js

const _kIstOffset = Duration(hours: 5, minutes: 30);

String _istYmdFromUtc(DateTime utc) {
  final i = utc.add(_kIstOffset);
  return '${i.year.toString().padLeft(4, '0')}-'
      '${i.month.toString().padLeft(2, '0')}-'
      '${i.day.toString().padLeft(2, '0')}';
}

/// Today's calendar date in Asia/Kolkata (yyyy-MM-dd).
String getTodayIst() => _istYmdFromUtc(DateTime.now().toUtc());

int? _parseIstDateTimeMs(String isoStr) => DateTime.tryParse(isoStr)?.millisecondsSinceEpoch;

String _normalizeTimeStr(String timeStr) {
  final parts = timeStr.split(':');
  final h = int.tryParse(parts.isNotEmpty ? parts[0] : '0') ?? 0;
  final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
  final s = int.tryParse(parts.length > 2 ? parts[2] : '0') ?? 0;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

/// True after the market's closing instant in IST.
bool isPastClosingTime(Map<String, dynamic> market, [DateTime? now]) {
  final closeStr = (market['closingTime'] ?? '').toString().trim();
  if (closeStr.isEmpty) return false;

  final todayIst = getTodayIst();
  final startStr = (market['startingTime'] ?? '').toString().trim();

  final openIso = startStr.isNotEmpty
      ? '${todayIst}T${_normalizeTimeStr(startStr)}+05:30'
      : '${todayIst}T00:00:00+05:30';
  var closeIso = '${todayIst}T${_normalizeTimeStr(closeStr)}+05:30';

  final openAt = _parseIstDateTimeMs(openIso);
  var closeAt = _parseIstDateTimeMs(closeIso);

  if (openAt == null || closeAt == null) return false;

  final nowMs = (now ?? DateTime.now()).millisecondsSinceEpoch;

  if (closeAt <= openAt) {
    final noonIst = DateTime.parse('${todayIst}T12:00:00+05:30');
    final nextNoon = noonIst.add(const Duration(days: 1));
    final nextDayStr = _istYmdFromUtc(nextNoon.toUtc());
    closeAt = _parseIstDateTimeMs('${nextDayStr}T${_normalizeTimeStr(closeStr)}+05:30');
    if (closeAt == null) return false;
    return nowMs > closeAt;
  }

  return nowMs > closeAt;
}

/// `{ openAt, closeAt }` in ms for today's IST session, or null if invalid.
({int openAt, int closeAt})? _marketOpenCloseMs(Map<String, dynamic> market) {
  final closeStr = (market['closingTime'] ?? '').toString().trim();
  if (closeStr.isEmpty) return null;
  final todayIst = getTodayIst();
  final startStr = (market['startingTime'] ?? '').toString().trim();
  final openIso = startStr.isNotEmpty
      ? '${todayIst}T${_normalizeTimeStr(startStr)}+05:30'
      : '${todayIst}T00:00:00+05:30';
  var closeIso = '${todayIst}T${_normalizeTimeStr(closeStr)}+05:30';
  var openAt = _parseIstDateTimeMs(openIso);
  var closeAt = _parseIstDateTimeMs(closeIso);
  if (openAt == null || closeAt == null) return null;
  if (closeAt <= openAt) {
    final noonIst = DateTime.parse('${todayIst}T12:00:00+05:30');
    final nextNoon = noonIst.add(const Duration(days: 1));
    final nextDayStr = _istYmdFromUtc(nextNoon.toUtc());
    closeAt = _parseIstDateTimeMs('${nextDayStr}T${_normalizeTimeStr(closeStr)}+05:30');
    if (closeAt == null) return null;
  }
  return (openAt: openAt, closeAt: closeAt);
}

/// Betting window — ported from [frontend/src/utils/marketTiming.js] `isBettingAllowed`.
BettingWindowResult isBettingAllowed(Map<String, dynamic> market, [DateTime? now]) {
  final closeStr = (market['closingTime'] ?? '').toString().trim();
  final betClosureSec = int.tryParse((market['betClosureTime'] ?? '0').toString()) ?? 0;
  final closureSec = betClosureSec >= 0 ? betClosureSec : 0;

  if (closeStr.isEmpty) {
    return const BettingWindowResult(allowed: false, closeOnly: false, message: 'Market timing not configured.');
  }

  final oc = _marketOpenCloseMs(market);
  if (oc == null) {
    return const BettingWindowResult(allowed: false, closeOnly: false, message: 'Invalid market time.');
  }

  final lastBetAt = oc.closeAt - closureSec * 1000;
  final nowMs = (now ?? DateTime.now()).millisecondsSinceEpoch;

  if (nowMs > lastBetAt) {
    return BettingWindowResult(
      allowed: false,
      closeOnly: false,
      message: closureSec > 0
          ? 'Betting closed. Closing time has passed.'
          : 'Betting closed. Closing time has passed.',
    );
  }
  if (nowMs >= oc.openAt) {
    return const BettingWindowResult(allowed: true, closeOnly: true, message: null);
  }
  return const BettingWindowResult(allowed: true, closeOnly: false, message: null);
}

class BettingWindowResult {
  const BettingWindowResult({
    required this.allowed,
    required this.closeOnly,
    this.message,
  });

  final bool allowed;
  final bool closeOnly;
  final String? message;
}
