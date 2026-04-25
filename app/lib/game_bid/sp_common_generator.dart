import 'pana_rules.dart';

({bool valid, String message, String? digit}) validateDigit(String? digit) {
  final normalized = (digit ?? '').trim();
  if (normalized.isEmpty) return (valid: false, message: 'Please enter a digit.', digit: null);
  if (normalized.length != 1) return (valid: false, message: 'Only one digit is allowed.', digit: null);
  if (!RegExp(r'^[0-9]$').hasMatch(normalized)) {
    return (valid: false, message: 'Digit must be between 0 and 9.', digit: null);
  }
  return (valid: true, message: '', digit: normalized);
}

({bool success, String message, List<({String pana, int points})> data}) generateSPCommon({
  required String? digit,
  required num points,
}) {
  final safePoints = points is int ? points : (num.tryParse(points.toString()) ?? 0);
  if (safePoints <= 0) {
    return (success: false, message: 'Points must be greater than 0.', data: []);
  }
  final dv = validateDigit(digit);
  if (!dv.valid) {
    return (success: false, message: dv.message, data: []);
  }
  final d = dv.digit!;
  final results = validSinglePanas
      .where((pana) => isSinglePatti(pana) && pana.contains(d))
      .map((pana) => (pana: pana, points: safePoints.toInt()))
      .toList()
    ..sort((a, b) => int.parse(a.pana).compareTo(int.parse(b.pana)));
  return (success: true, message: '', data: results);
}
