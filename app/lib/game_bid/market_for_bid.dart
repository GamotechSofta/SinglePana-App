import '../utils/market_timing.dart';

bool isThreeDigits(dynamic v) {
  if (v == null) return false;
  return RegExp(r'^\d{3}$').hasMatch(v.toString().trim());
}

/// UI status string like React [Section1] `getMarketStatus`.
String computeMarketUiStatus(Map<String, dynamic> market) {
  if (isPastClosingTime(market)) return 'closed';
  if (isThreeDigits(market['openingNumber']) && isThreeDigits(market['closingNumber'])) {
    return 'closed';
  }
  if (isThreeDigits(market['openingNumber']) && !isThreeDigits(market['closingNumber'])) {
    return 'running';
  }
  return 'open';
}

/// Ensures [gameName], [status], [id] exist for bid flows.
Map<String, dynamic> normalizeMarketForBid(Map<String, dynamic> raw) {
  final m = Map<String, dynamic>.from(raw);
  m['gameName'] = (m['gameName'] ?? m['marketName'] ?? '').toString();
  m['status'] = computeMarketUiStatus(m);
  m['id'] = m['id'] ?? m['_id'];
  return m;
}
