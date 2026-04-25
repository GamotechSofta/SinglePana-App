import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/api_config.dart';
import 'auth_service.dart';
import 'session_coordinator.dart';

/// `GET /payments/config`, `POST /payments/deposit`, `POST /payments/withdraw`,
/// `GET /payments/my-deposits`, `GET /payments/my-withdrawals` — React funds pages.
class PaymentsService {
  PaymentsService._();
  static final PaymentsService instance = PaymentsService._();

  Future<Map<String, String>> _authOnly() async {
    final u = await AuthService.instance.getStoredUser();
    final t = u?['token']?.toString();
    if (t == null || t.isEmpty) return {};
    return {'Authorization': 'Bearer $t'};
  }

  Future<Map<String, String>> _jsonHeaders() async {
    final h = await _authOnly();
    if (h.isEmpty) return {};
    return {...h, 'Content-Type': 'application/json'};
  }

  Future<({bool success, Map<String, dynamic>? data, String? message})> fetchConfig() async {
    final uri = Uri.parse('$kApiBaseUrl/payments/config');
    final res = await http.get(uri);
    Map<String, dynamic>? body;
    try {
      body = jsonDecode(res.body) as Map<String, dynamic>?;
    } catch (_) {}
    if (body?['success'] == true && body?['data'] is Map) {
      return (
        success: true,
        data: Map<String, dynamic>.from(body!['data'] as Map),
        message: null,
      );
    }
    return (
      success: false,
      data: null,
      message: body?['message']?.toString() ?? 'Failed to load payment config',
    );
  }

  Future<({bool success, String? message})> submitDeposit({
    required double amount,
    required String upiTransactionId,
    required String screenshotPath,
  }) async {
    final auth = await _authOnly();
    if (auth.isEmpty) return (success: false, message: 'Please log in');

    final uri = Uri.parse('$kApiBaseUrl/payments/deposit');
    final req = http.MultipartRequest('POST', uri);
    req.headers.addAll(auth);
    req.fields['amount'] = amount == amount.roundToDouble() ? amount.toInt().toString() : amount.toString();
    final txId = upiTransactionId.trim();
    req.fields['upiTransactionId'] = txId;
    // Keep both keys for API compatibility across server versions.
    req.fields['transactionId'] = txId;
    req.files.add(
      await http.MultipartFile.fromPath(
        'screenshot',
        screenshotPath,
        contentType: _imageContentTypeForPath(screenshotPath),
      ),
    );

    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
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
    return (success: false, message: body?['message']?.toString() ?? 'Deposit request failed');
  }

  MediaType _imageContentTypeForPath(String path) {
    final p = path.toLowerCase();
    if (p.endsWith('.png')) return MediaType('image', 'png');
    if (p.endsWith('.webp')) return MediaType('image', 'webp');
    if (p.endsWith('.jpg') || p.endsWith('.jpeg')) return MediaType('image', 'jpeg');
    return MediaType('application', 'octet-stream');
  }

  Future<({bool success, String? message})> submitWithdraw({
    required double amount,
    required String bankDetailId,
    String userNote = '',
  }) async {
    final h = await _jsonHeaders();
    if (h.isEmpty) return (success: false, message: 'Please log in');
    final uri = Uri.parse('$kApiBaseUrl/payments/withdraw');
    final res = await http.post(
      uri,
      headers: h,
      body: jsonEncode({
        'amount': amount,
        'bankDetailId': bankDetailId,
        'userNote': userNote,
      }),
    );
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
    return (success: false, message: body?['message']?.toString() ?? 'Withdrawal failed');
  }

  Future<({bool success, List<Map<String, dynamic>> data, String? message})> fetchMyDeposits() async {
    final h = await _authOnly();
    if (h.isEmpty) return (success: false, data: <Map<String, dynamic>>[], message: 'Please log in');
    final uri = Uri.parse('$kApiBaseUrl/payments/my-deposits');
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
      message: body?['message']?.toString() ?? 'Failed to load deposits',
    );
  }

  Future<({bool success, List<Map<String, dynamic>> data, String? message})> fetchMyWithdrawals() async {
    final h = await _authOnly();
    if (h.isEmpty) return (success: false, data: <Map<String, dynamic>>[], message: 'Please log in');
    final uri = Uri.parse('$kApiBaseUrl/payments/my-withdrawals');
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
      message: body?['message']?.toString() ?? 'Failed to load withdrawals',
    );
  }
}
