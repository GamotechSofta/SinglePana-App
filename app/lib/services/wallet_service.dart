import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_service.dart';
import 'session_coordinator.dart';

/// `GET /wallet/balance`, `GET /wallet/my-transactions` — same as [frontend/src/api/bets.js].
class WalletService {
  WalletService._();
  static final WalletService instance = WalletService._();

  /// Fetches server balance and writes to stored user (header wallet).
  Future<void> refreshBalanceInStorage() async {
    final r = await fetchBalance();
    if (r.success && r.balance != null) {
      await AuthService.instance.updateStoredBalance(r.balance!);
    }
  }

  Future<Map<String, String>> _headers() async {
    final u = await AuthService.instance.getStoredUser();
    final t = u?['token']?.toString();
    if (t == null || t.isEmpty) return {};
    return {'Authorization': 'Bearer $t'};
  }

  Future<({bool success, num? balance, String? message})> fetchBalance() async {
    final h = await _headers();
    if (h.isEmpty) {
      return (success: false, balance: null, message: 'Please log in');
    }
    final uri = Uri.parse('$kApiBaseUrl/wallet/balance');
    final res = await http.get(uri, headers: h);
    Map<String, dynamic>? data;
    try {
      data = jsonDecode(res.body) as Map<String, dynamic>?;
    } catch (_) {}
    if (res.statusCode == 401) {
      await SessionCoordinator.instance.forceLogoutToLogin();
      return (success: false, balance: null, message: 'Session expired.');
    }
    if (data?['success'] == true && data?['data'] is Map) {
      final inner = data!['data'] as Map<String, dynamic>;
      final b = inner['balance'];
      final n = b is num ? b : num.tryParse(b.toString());
      return (success: true, balance: n, message: null);
    }
    return (
      success: false,
      balance: null,
      message: data?['message']?.toString() ?? 'Failed to fetch balance',
    );
  }

  Future<({bool success, List<Map<String, dynamic>> data, String? message})> fetchMyTransactions({
    int limit = 500,
    bool includeBet = true,
  }) async {
    final h = await _headers();
    if (h.isEmpty) {
      return (success: false, data: <Map<String, dynamic>>[], message: 'Please log in');
    }
    final uri = Uri.parse(
      '$kApiBaseUrl/wallet/my-transactions?limit=$limit&includeBet=${includeBet ? 1 : 0}',
    );
    final res = await http.get(uri, headers: h);
    Map<String, dynamic>? body;
    try {
      body = jsonDecode(res.body) as Map<String, dynamic>?;
    } catch (_) {}
    if (res.statusCode == 401) {
      await SessionCoordinator.instance.forceLogoutToLogin();
      return (success: false, data: <Map<String, dynamic>>[], message: 'Session expired.');
    }
    if (body?['success'] == true && body?['data'] is List) {
      final raw = body!['data'] as List;
      final list = <Map<String, dynamic>>[
        for (final e in raw) Map<String, dynamic>.from(e as Map),
      ];
      return (success: true, data: list, message: null);
    }
    return (
      success: false,
      data: <Map<String, dynamic>>[],
      message: body?['message']?.toString() ?? 'Failed to fetch transactions',
    );
  }
}
