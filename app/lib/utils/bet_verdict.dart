// Port of [frontend/src/pages/Bids.jsx] evaluateBet / rates helpers for local bet history UI.

String normalizeMarketName(String? s) => (s ?? '').trim().toLowerCase();

bool isStarlineMarketName(String? s) {
  final k = normalizeMarketName(s);
  return k.contains('starline') ||
      k.contains('startline') ||
      k.contains('star line') ||
      k.contains('start line');
}

int _sumDigits(String str) => str.split('').fold<int>(0, (a, c) => a + (int.tryParse(c) ?? 0));

int _lastDigit(String str) => _sumDigits(str) % 10;

String _inferBetKind(String? betNumberRaw) {
  final s = (betNumberRaw ?? '').trim();
  if (s.isEmpty) return 'unknown';
  if (s.contains('-')) {
    final parts = s.split('-').map((x) => x.trim()).toList();
    if (parts.length < 2) return 'unknown';
    final a = parts[0];
    final b = parts[1];
    if (RegExp(r'^\d{3}$').hasMatch(a) && RegExp(r'^\d{3}$').hasMatch(b)) return 'full-sangam';
    if (RegExp(r'^\d{3}$').hasMatch(a) && RegExp(r'^\d$').hasMatch(b)) return 'half-sangam-open';
    if (RegExp(r'^\d$').hasMatch(a) && RegExp(r'^\d{3}$').hasMatch(b)) return 'half-sangam-close';
    return 'unknown';
  }
  if (RegExp(r'^\d$').hasMatch(s)) return 'digit';
  if (RegExp(r'^\d{2}$').hasMatch(s)) return 'jodi';
  if (RegExp(r'^\d{3}$').hasMatch(s)) return 'panna';
  return 'unknown';
}

const _defaultRates = <String, num>{
  'single': 10,
  'jodi': 100,
  'singlePatti': 150,
  'doublePatti': 300,
  'triplePatti': 1000,
  'halfSangam': 5000,
  'fullSangam': 10000,
};

num _rateNum(dynamic val, num def) {
  final n = num.tryParse(val?.toString() ?? '') ?? (val is num ? val : null);
  if (n == null || !n.isFinite || n < 0) return def;
  return n;
}

num getPayoutMultiplier(String kind, String? betNumberRaw, Map<String, dynamic>? ratesMap) {
  final r = ratesMap ?? {};
  if (kind == 'digit') return _rateNum(r['single'], _defaultRates['single']!);
  if (kind == 'jodi') return _rateNum(r['jodi'], _defaultRates['jodi']!);
  if (kind == 'half-sangam-open' || kind == 'half-sangam-close') {
    return _rateNum(r['halfSangam'], _defaultRates['halfSangam']!);
  }
  if (kind == 'full-sangam') return _rateNum(r['fullSangam'], _defaultRates['fullSangam']!);
  if (kind == 'panna') {
    final s = (betNumberRaw ?? '').trim();
    if (RegExp(r'^\d{3}$').hasMatch(s)) {
      final a = s[0], b = s[1], c = s[2];
      final allSame = a == b && b == c;
      final twoSame = a == b || b == c || a == c;
      if (allSame) return _rateNum(r['triplePatti'], _defaultRates['triplePatti']!);
      if (twoSame) return _rateNum(r['doublePatti'], _defaultRates['doublePatti']!);
      return _rateNum(r['singlePatti'], _defaultRates['singlePatti']!);
    }
  }
  return 0;
}

/// won | lost | pending
({String state, String kind, num payout}) evaluateBet({
  required Map<String, dynamic>? market,
  required String? betNumberRaw,
  required num amount,
  required String session,
  Map<String, dynamic>? ratesMap,
}) {
  final openingRaw = market?['openingNumber']?.toString().trim();
  final closingRaw = market?['closingNumber']?.toString().trim();
  final opening = openingRaw != null && RegExp(r'^\d{3}$').hasMatch(openingRaw) ? openingRaw : null;
  final closing = closingRaw != null && RegExp(r'^\d{3}$').hasMatch(closingRaw) ? closingRaw : null;
  final openDigit = opening != null ? _lastDigit(opening).toString() : null;
  final closeDigit = closing != null ? _lastDigit(closing).toString() : null;
  final jodi = openDigit != null && closeDigit != null ? '$openDigit$closeDigit' : null;

  final betNumber = (betNumberRaw ?? '').trim();
  final kind = _inferBetKind(betNumber);
  final sess = session.trim().toUpperCase();

  final declared = () {
    if (kind == 'digit') {
      if (sess == 'OPEN') return openDigit != null;
      if (sess == 'CLOSE') return closeDigit != null;
      return openDigit != null && closeDigit != null;
    }
    if (kind == 'panna') {
      if (sess == 'OPEN') return opening != null;
      if (sess == 'CLOSE') return closing != null;
      return opening != null && closing != null;
    }
    if (kind == 'jodi') return jodi != null;
    if (kind == 'half-sangam-open') return opening != null && openDigit != null;
    if (kind == 'half-sangam-close' || kind == 'full-sangam') {
      return opening != null && closing != null;
    }
    return false;
  }();

  if (!declared) return (state: 'pending', kind: kind, payout: 0);

  var won = false;
  if (kind == 'digit') {
    if (sess == 'OPEN') {
      won = betNumber == openDigit;
    } else if (sess == 'CLOSE') {
      won = betNumber == closeDigit;
    } else {
      won = betNumber == openDigit || betNumber == closeDigit;
    }
  } else if (kind == 'jodi') {
    won = betNumber == jodi;
  } else if (kind == 'panna') {
    if (sess == 'OPEN') {
      won = betNumber == opening;
    } else if (sess == 'CLOSE') {
      won = betNumber == closing;
    } else {
      won = betNumber == opening || betNumber == closing;
    }
  } else if (kind == 'full-sangam') {
    won = betNumber == '$opening-$closing';
  } else if (kind == 'half-sangam-open') {
    won = betNumber == '$opening-$openDigit';
  } else if (kind == 'half-sangam-close') {
    won = betNumber == '$openDigit-$closing';
  }

  if (!won) return (state: 'lost', kind: kind, payout: 0);

  final mul = getPayoutMultiplier(kind, betNumber, ratesMap);
  final payout = mul > 0 ? amount * mul : 0;
  return (state: 'won', kind: kind, payout: payout);
}
