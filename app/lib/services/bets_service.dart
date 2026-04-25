import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_service.dart';
import 'session_coordinator.dart';

final _objectId = RegExp(r'^[a-fA-F0-9]{24}$');

String? _toObjectIdString(dynamic v) {
  if (v == null) return null;
  if (v is String) return v.trim().isEmpty ? null : v.trim();
  if (v is Map && v[r'$oid'] != null) return v[r'$oid'].toString().trim();
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

bool _isValidObjectId(String? id) => id != null && _objectId.hasMatch(id);

String? _normalizeBetOn(dynamic v) {
  final s = (v ?? '').toString().trim().toLowerCase();
  if (s.isEmpty) return null;
  if (s == 'open' || s == 'openbet') return 'open';
  if (s == 'close' || s == 'closed' || s == 'closebet') return 'close';
  return null;
}

class PlaceBetLine {
  const PlaceBetLine({
    required this.betType,
    required this.betNumber,
    required this.amount,
    this.betOn,
  });

  final String betType;
  final String betNumber;
  final num amount;
  final String? betOn;
}

class PlaceBetResult {
  const PlaceBetResult({
    required this.success,
    this.message,
    this.newBalance,
  });

  final bool success;
  final String? message;
  final num? newBalance;
}

/// `POST /bets/place` — same contract as [frontend/src/api/bets.js] `placeBet`.
class BetsService {
  BetsService._();
  static final BetsService instance = BetsService._();

  Future<PlaceBetResult> placeBet({
    required dynamic marketId,
    required List<PlaceBetLine> lines,
    String? scheduledDate,
  }) async {
    final user = await AuthService.instance.getStoredUser();
    final rawUserId = user?['id'] ?? user?['_id'];
    if (rawUserId == null) {
      return const PlaceBetResult(success: false, message: 'Please log in to place a bet');
    }
    final userId = _toObjectIdString(rawUserId);
    if (!_isValidObjectId(userId)) {
      return const PlaceBetResult(success: false, message: 'Session invalid. Please log in again.');
    }

    final normalizedMarketId = _toObjectIdString(marketId ?? user?['marketId']);
    if (!_isValidObjectId(normalizedMarketId)) {
      return const PlaceBetResult(
        success: false,
        message: 'This market is not available for betting. Please go back and select a market from the list.',
      );
    }

    if (lines.isEmpty) {
      return const PlaceBetResult(success: false, message: 'No bets to place');
    }

    for (final b in lines) {
      final amount = b.amount;
      if (b.betType.trim().isEmpty || b.betNumber.trim().isEmpty || amount <= 0) {
        return const PlaceBetResult(
          success: false,
          message: 'Each bet must have betType, betNumber and amount > 0',
        );
      }
      if (amount > 1000000) {
        return const PlaceBetResult(success: false, message: 'Bet amount cannot exceed ₹10,00,000');
      }
    }

    final total = lines.fold<num>(0, (s, b) => s + b.amount);
    if (total <= 0) {
      return const PlaceBetResult(success: false, message: 'Total bet amount must be greater than 0');
    }

    final token = user?['token']?.toString();
    if (token == null || token.isEmpty) {
      return const PlaceBetResult(success: false, message: 'Please log in to place a bet');
    }

    final payload = <String, dynamic>{
      'userId': userId,
      'marketId': normalizedMarketId,
      'bets': lines
          .map((b) => {
                // Match [frontend/src/api/bets.js]: lowercase betType for server contract.
                'betType': b.betType.trim().toLowerCase(),
                'betNumber': b.betNumber.trim(),
                'amount': b.amount,
                if (_normalizeBetOn(b.betOn) != null) 'betOn': _normalizeBetOn(b.betOn),
              })
          .toList(),
    };
    if (scheduledDate != null && scheduledDate.isNotEmpty) {
      payload['scheduledDate'] = scheduledDate;
    }

    final uri = Uri.parse('$kApiBaseUrl/bets/place');
    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(payload),
    );

    Map<String, dynamic>? data;
    try {
      data = jsonDecode(res.body) as Map<String, dynamic>?;
    } catch (_) {
      return const PlaceBetResult(success: false, message: 'Invalid response from server');
    }

    if (res.statusCode == 401) {
      await SessionCoordinator.instance.forceLogoutToLogin();
      return const PlaceBetResult(success: false, message: 'Session expired. Please log in again.');
    }
    if (data?['success'] != true) {
      return PlaceBetResult(
        success: false,
        message: data?['message']?.toString() ?? 'Failed to place bet',
      );
    }

    num? newBal;
    final inner = data?['data'];
    if (inner is Map<String, dynamic> && inner['newBalance'] != null) {
      newBal = inner['newBalance'] as num?;
    }
    return PlaceBetResult(success: true, message: data?['message']?.toString(), newBalance: newBal);
  }

  Future<Map<String, dynamic>?> fetchRatesCurrent() async {
    final uri = Uri.parse('$kApiBaseUrl/rates/current');
    final res = await http.get(uri);
    try {
      final data = jsonDecode(res.body) as Map<String, dynamic>?;
      if (data?['success'] == true) return data;
    } catch (_) {}
    return null;
  }

  /// `GET /bets/public/top-winners` — [frontend/src/pages/TopWinners.jsx].
  Future<TopWinnersResult> fetchPublicTopWinners({String? timeRange}) async {
    final q = (timeRange != null && timeRange.isNotEmpty && timeRange != 'all')
        ? <String, String>{'timeRange': timeRange}
        : null;
    final uri = Uri.parse('$kApiBaseUrl/bets/public/top-winners').replace(queryParameters: q);
    final res = await http.get(uri);
    try {
      final data = jsonDecode(res.body) as Map<String, dynamic>?;
      if (res.statusCode >= 200 &&
          res.statusCode < 300 &&
          data?['success'] == true &&
          data?['data'] is List) {
        final list = (data!['data'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        return TopWinnersResult(success: true, rows: list);
      }
      return TopWinnersResult(
        success: false,
        message: data?['message']?.toString() ?? 'Failed to load top winners',
      );
    } catch (_) {
      return const TopWinnersResult(success: false, message: 'Failed to load top winners');
    }
  }

  /// `GET /bets/my-statement` — [frontend/src/pages/Profile.jsx].
  Future<StatementDownloadResult> fetchMyStatement({
    required String startDateYmd,
    required String endDateYmd,
  }) async {
    final user = await AuthService.instance.getStoredUser();
    final token = user?['token']?.toString();
    if (token == null || token.isEmpty) {
      return const StatementDownloadResult(success: false, message: 'Please log in to download statement');
    }
    final uri = Uri.parse('$kApiBaseUrl/bets/my-statement').replace(
      queryParameters: {
        'startDate': startDateYmd,
        'endDate': endDateYmd,
      },
    );
    final res = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 401) {
      await SessionCoordinator.instance.forceLogoutToLogin();
      return const StatementDownloadResult(success: false, message: 'Session expired. Please log in again.');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      try {
        final data = jsonDecode(res.body) as Map<String, dynamic>?;
        return StatementDownloadResult(
          success: false,
          message: data?['message']?.toString() ?? 'Failed to download statement',
        );
      } catch (_) {
        return const StatementDownloadResult(success: false, message: 'Failed to download statement');
      }
    }
    return StatementDownloadResult(
      success: true,
      bytes: res.bodyBytes,
      contentType: res.headers['content-type'],
    );
  }
}

class TopWinnersResult {
  const TopWinnersResult({
    required this.success,
    this.message,
    this.rows = const [],
  });

  final bool success;
  final String? message;
  final List<Map<String, dynamic>> rows;
}

class StatementDownloadResult {
  const StatementDownloadResult({
    required this.success,
    this.message,
    this.bytes,
    this.contentType,
  });

  final bool success;
  final String? message;
  final Uint8List? bytes;
  final String? contentType;
}
