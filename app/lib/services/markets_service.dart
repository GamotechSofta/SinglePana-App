import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

/// Public markets list — [frontend/src/components/Section1.jsx].
class MarketsService {
  MarketsService._();
  static final MarketsService instance = MarketsService._();

  Future<List<Map<String, dynamic>>> fetchMarkets() async {
    final uri = Uri.parse('$kApiBaseUrl/markets/get-markets');
    final res = await http.get(uri);
    Map<String, dynamic>? data;
    try {
      data = jsonDecode(res.body) as Map<String, dynamic>?;
    } catch (_) {
      return [];
    }
    if (data?['success'] != true) return [];
    final list = data?['data'];
    if (list is! List) return [];
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// `GET /markets/result-history?date=YYYY-MM-DD` — [MarketResultHistory.jsx].
  Future<List<Map<String, dynamic>>> fetchResultHistory(String dateYmd) async {
    final uri = Uri.parse('$kApiBaseUrl/markets/result-history').replace(
      queryParameters: {'date': dateYmd},
    );
    final res = await http.get(uri);
    Map<String, dynamic>? data;
    try {
      data = jsonDecode(res.body) as Map<String, dynamic>?;
    } catch (_) {
      return [];
    }
    if (data?['success'] != true) return [];
    final list = data?['data'];
    if (list is! List) return [];
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
}
