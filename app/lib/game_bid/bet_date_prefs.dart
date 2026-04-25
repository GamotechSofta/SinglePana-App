import 'package:shared_preferences/shared_preferences.dart';

import '../utils/market_timing.dart';

const _kBetDateKey = 'betSelectedDate';

Future<String> loadBetSelectedDateOrToday() async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString(_kBetDateKey);
  final today = getTodayIst();
  if (saved != null && saved.compareTo(today) > 0) return saved;
  return today;
}

Future<void> saveBetSelectedDate(String ymd) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kBetDateKey, ymd);
}

Future<void> clearBetSelectedDate() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_kBetDateKey);
}

/// Returns [scheduledDate] only if selected day is strictly after IST today.
String? scheduledDateIfFuture(String selectedYmd) {
  final today = getTodayIst();
  if (selectedYmd.compareTo(today) > 0) return selectedYmd;
  return null;
}
