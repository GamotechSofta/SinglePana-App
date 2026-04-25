import 'pana_rules.dart';

class DigitValidationResult {
  const DigitValidationResult({required this.valid, required this.message, this.digit});
  final bool valid;
  final String message;
  final String? digit;
}

class DpCommonRow {
  const DpCommonRow({required this.pana, required this.points});
  final String pana;
  final int points;
}

class DpCommonResult {
  const DpCommonResult({required this.success, required this.message, required this.data});
  final bool success;
  final String message;
  final List<DpCommonRow> data;
}

DigitValidationResult validateDigit(String? input) {
  final normalized = (input ?? '').trim();
  if (normalized.isEmpty) {
    return const DigitValidationResult(valid: false, message: 'Please enter a digit.');
  }
  if (normalized.length != 1) {
    return const DigitValidationResult(valid: false, message: 'Only one digit is allowed.');
  }
  if (!RegExp(r'^[0-9]$').hasMatch(normalized)) {
    return const DigitValidationResult(valid: false, message: 'Digit must be between 0 and 9.');
  }
  return DigitValidationResult(valid: true, message: '', digit: normalized);
}

DpCommonResult generateDPCommon({required String digit, required num points}) {
  final safePoints = points.toInt();
  if (safePoints <= 0) {
    return const DpCommonResult(success: false, message: 'Points must be greater than 0.', data: []);
  }
  final check = validateDigit(digit);
  if (!check.valid || check.digit == null) {
    return DpCommonResult(success: false, message: check.message, data: const []);
  }
  final d = check.digit!;
  final rows = allValidDoublePanas()
      .where((pana) => pana.contains(d))
      .map((pana) => DpCommonRow(pana: pana, points: safePoints))
      .toList()
    ..sort((a, b) => int.parse(a.pana).compareTo(int.parse(b.pana)));
  return DpCommonResult(success: true, message: '', data: rows);
}
