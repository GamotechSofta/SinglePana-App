// Shared helpers aligned with frontend Bank.jsx transaction cards.

String formatTxTime(String? iso) {
  if (iso == null || iso.isEmpty) return '-';
  final d = DateTime.tryParse(iso);
  if (d == null) return '-';
  final date =
      '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
  final h = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
  final ampm = d.hour >= 12 ? 'PM' : 'AM';
  final time =
      '${h.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} $ampm'.toUpperCase();
  return '$date $time';
}

String humanBetType(String? betType) {
  final t = (betType ?? '').toLowerCase().trim();
  if (t == 'single') return 'Single Ank';
  if (t == 'jodi') return 'Jodi';
  if (t == 'panna' || t == 'pana') return 'Panna';
  if (t == 'half-sangam') return 'Half Sangam';
  if (t == 'full-sangam') return 'Full Sangam';
  if (t == 'sp-common') return 'SP Common';
  if (t == 'sp-motor') return 'SP Motor';
  if (t == 'dp-motor') return 'DP Motor';
  return '';
}

/// OPEN / CLOSE from API [betOn] when present.
String formatBetSessionFromBetOn(String? betOn) {
  final s = (betOn ?? '').toString().trim().toLowerCase();
  if (s == 'open' || s == 'openbet') return 'OPEN';
  if (s == 'close' || s == 'closed' || s == 'closebet') return 'CLOSE';
  return '';
}

/// Fallback when [betOn] is missing: backend convention (single/panna → open; else close).
String inferSession(String? betType) {
  final t = (betType ?? '').toLowerCase();
  if (t == 'single' || t == 'panna' || t == 'pana') return 'open';
  if (t.isNotEmpty) return 'close';
  return '';
}

({String bidPlay, String game, String type, String market, String? raw}) parseTxDescription(String? desc) {
  final s = (desc ?? '').trim();
  if (s.isEmpty) {
    return (bidPlay: '-', game: '-', type: '-', market: '-', raw: null);
  }

  final win = RegExp(r'^Win\s*–\s*(.+?)\s*\((.+)\)\s*$', caseSensitive: false).firstMatch(s);
  if (win != null) {
    final marketName = win.group(1)?.trim() ?? '';
    final inner = win.group(2)?.trim() ?? '';
    final parts = inner.split(RegExp(r'\s+'));
    final kindRaw = parts.isNotEmpty ? parts.first.trim() : '';
    final number = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    final innerLower = inner.toLowerCase();
    String kind;
    String betType = '';
    if (kindRaw.toLowerCase() == 'single') {
      kind = 'Single Ank';
      betType = 'single';
    } else if (kindRaw.toLowerCase() == 'jodi') {
      kind = 'Jodi';
      betType = 'jodi';
    } else if (kindRaw.toLowerCase() == 'panna') {
      kind = 'Panna';
      betType = 'panna';
    } else if (innerLower.contains('half')) {
      kind = 'Half Sangam';
      betType = 'half-sangam';
    } else if (innerLower.contains('full')) {
      kind = 'Full Sangam';
      betType = 'full-sangam';
    } else {
      kind = inner;
    }
    return (
      bidPlay: number.isEmpty ? '-' : number,
      game: marketName.isEmpty ? '-' : marketName,
      type: kind,
      market: inferSession(betType),
      raw: null,
    );
  }

  final placed = RegExp(r'^Bet\s*placed\s*–\s*(.+?)\s*\((\d+)\s*bet', caseSensitive: false).firstMatch(s);
  if (placed != null) {
    final marketName = placed.group(1)?.trim() ?? '';
    final count = int.tryParse(placed.group(2) ?? '0') ?? 0;
    return (
      bidPlay: count > 1 ? '$count Bets' : '1 Bet',
      game: marketName.isEmpty ? '-' : marketName,
      type: 'Bet Placed',
      market: '-',
      raw: null,
    );
  }

  return (bidPlay: '-', game: '-', type: '-', market: '-', raw: s);
}
