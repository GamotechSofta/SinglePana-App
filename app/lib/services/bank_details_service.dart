import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_service.dart';
import 'session_coordinator.dart';

/// `GET/POST/PUT/DELETE /bank-details`, `POST .../set-default` — same as React [BankDetail.jsx].
class BankDetailsService {
  BankDetailsService._();
  static final BankDetailsService instance = BankDetailsService._();

  Future<Map<String, String>> _jsonHeaders() async {
    final u = await AuthService.instance.getStoredUser();
    final t = u?['token']?.toString();
    if (t == null || t.isEmpty) return {};
    return {
      'Authorization': 'Bearer $t',
      'Content-Type': 'application/json',
    };
  }

  Future<({bool success, List<Map<String, dynamic>> data, String? message})> listAccounts() async {
    final h = await _jsonHeaders();
    if (h.isEmpty) {
      return (success: false, data: <Map<String, dynamic>>[], message: 'Please log in');
    }
    final uri = Uri.parse('$kApiBaseUrl/bank-details');
    final res = await http.get(uri, headers: {'Authorization': h['Authorization']!});
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
      message: body?['message']?.toString() ?? 'Failed to load bank details',
    );
  }

  Future<({bool success, String? message})> _boolMessage(http.Response res) async {
    Map<String, dynamic>? body;
    try {
      body = jsonDecode(res.body) as Map<String, dynamic>?;
    } catch (_) {}
    if (res.statusCode == 401) {
      await SessionCoordinator.instance.forceLogoutToLogin();
      return (success: false, message: 'Session expired.');
    }
    if (body?['success'] == true) {
      return (success: true, message: body?['message']?.toString());
    }
    return (success: false, message: body?['message']?.toString() ?? 'Request failed');
  }

  Future<({bool success, String? message})> createAccount(Map<String, dynamic> payload) async {
    final h = await _jsonHeaders();
    if (h.isEmpty) return (success: false, message: 'Please log in');
    final uri = Uri.parse('$kApiBaseUrl/bank-details');
    final res = await http.post(uri, headers: h, body: jsonEncode(payload));
    return _boolMessage(res);
  }

  Future<({bool success, String? message})> updateAccount(String id, Map<String, dynamic> payload) async {
    final h = await _jsonHeaders();
    if (h.isEmpty) return (success: false, message: 'Please log in');
    final uri = Uri.parse('$kApiBaseUrl/bank-details/$id');
    final res = await http.put(uri, headers: h, body: jsonEncode(payload));
    return _boolMessage(res);
  }

  Future<({bool success, String? message})> deleteAccount(String id) async {
    final h = await _jsonHeaders();
    if (h.isEmpty) return (success: false, message: 'Please log in');
    final uri = Uri.parse('$kApiBaseUrl/bank-details/$id');
    final res = await http.delete(uri, headers: h, body: jsonEncode({}));
    return _boolMessage(res);
  }

  Future<({bool success, String? message})> setDefault(String id) async {
    final h = await _jsonHeaders();
    if (h.isEmpty) return (success: false, message: 'Please log in');
    final uri = Uri.parse('$kApiBaseUrl/bank-details/$id/set-default');
    final res = await http.post(uri, headers: h, body: jsonEncode({}));
    return _boolMessage(res);
  }
}
