// Ported from frontend/src/pages/GameBid/bids/panaRules.js

/// Exported for SP Common / list UIs.
const validSinglePanas = <String>{
  '127', '136', '145', '190', '235', '280', '370', '389', '460', '479', '569', '578',
  '128', '137', '146', '236', '245', '290', '380', '470', '489', '560', '579', '678',
  '129', '138', '147', '156', '237', '246', '345', '390', '480', '570', '589', '679',
  '120', '139', '148', '157', '238', '247', '256', '346', '490', '580', '670', '689',
  '130', '149', '158', '167', '239', '248', '257', '347', '356', '590', '680', '789',
  '140', '159', '168', '230', '249', '258', '267', '348', '357', '456', '690', '780',
  '123', '150', '169', '178', '240', '259', '268', '349', '358', '367', '457', '790',
  '124', '160', '179', '250', '269', '278', '340', '359', '368', '458', '467', '890',
  '125', '134', '170', '189', '260', '279', '350', '369', '378', '459', '468', '567',
  '126', '135', '180', '234', '270', '289', '360', '379', '450', '469', '478', '568',
};

bool isValidSinglePana(String? n) {
  final s = (n ?? '').trim();
  if (!RegExp(r'^\d{3}$').hasMatch(s)) return false;
  return validSinglePanas.contains(s);
}

bool isValidDoublePana(String? n) {
  if (n == null || n.isEmpty) return false;
  final str = n.trim();
  if (!RegExp(r'^\d{3}$').hasMatch(str)) return false;
  final digits = str.split('').map(int.parse).toList();
  final first = digits[0];
  final second = digits[1];
  final third = digits[2];
  final hasConsecutiveSame = first == second || second == third;
  if (!hasConsecutiveSame) return false;
  if (first == 0) return false;
  if (second == 0 && third == 0) return true;
  if (first == second && third == 0) return true;
  if (third <= first) return false;
  return true;
}

bool isValidTriplePana(String? n) {
  final s = (n ?? '').trim();
  if (!RegExp(r'^\d{3}$').hasMatch(s)) return false;
  return s[0] == s[1] && s[1] == s[2];
}

bool isValidAnyPana(String? n) =>
    isValidSinglePana(n) || isValidDoublePana(n) || isValidTriplePana(n);

List<String> allValidDoublePanas() {
  final out = <String>[];
  for (var i = 0; i <= 999; i++) {
    final str = i.toString().padLeft(3, '0');
    if (isValidDoublePana(str)) out.add(str);
  }
  return out;
}

List<String> generateSinglePanaCombinations(String digitStr) {
  final digits = digitStr.replaceAll(RegExp(r'\D'), '').split('').toSet().toList()..sort();
  if (digits.length < 3) return [];
  final out = <String>[];
  for (var i = 0; i < digits.length - 2; i++) {
    for (var j = i + 1; j < digits.length - 1; j++) {
      for (var k = j + 1; k < digits.length; k++) {
        final pana = '${digits[i]}${digits[j]}${digits[k]}';
        if (isValidSinglePana(pana)) out.add(pana);
      }
    }
  }
  return out;
}

String sanitizeMotorDigitsUnique(String? value, {int maxLen = 10}) {
  final raw = (value ?? '').replaceAll(RegExp(r'\D'), '');
  final seen = <String>{};
  final buf = StringBuffer();
  for (final ch in raw.split('')) {
    if (seen.contains(ch)) continue;
    seen.add(ch);
    buf.write(ch);
    if (buf.length >= maxLen) break;
  }
  return buf.toString();
}

List<String> generateSpMotorSinglePanas(String digitStr) {
  final digits = sanitizeMotorDigitsUnique(digitStr).split('').toList()..sort();
  if (digits.length < 3) return [];
  final found = <String>{};
  for (var i = 0; i < digits.length - 2; i++) {
    for (var j = i + 1; j < digits.length - 1; j++) {
      for (var k = j + 1; k < digits.length; k++) {
        final t = [digits[i], digits[j], digits[k]];
        final perms = [
          [0, 1, 2],
          [0, 2, 1],
          [1, 0, 2],
          [1, 2, 0],
          [2, 0, 1],
          [2, 1, 0],
        ];
        for (final p in perms) {
          final pana = '${t[p[0]]}${t[p[1]]}${t[p[2]]}';
          if (isValidSinglePana(pana)) found.add(pana);
        }
      }
    }
  }
  final out = found.toList()..sort((a, b) => int.parse(a).compareTo(int.parse(b)));
  return out;
}

bool isSinglePatti(String patti) {
  final s = patti.trim();
  if (s.length != 3 || !RegExp(r'^\d{3}$').hasMatch(s)) return false;
  return s[0] != s[1] && s[1] != s[2] && s[0] != s[2];
}
