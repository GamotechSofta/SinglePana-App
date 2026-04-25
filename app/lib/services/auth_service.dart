import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import 'device_id_service.dart';

const _kUserKey = 'user';

/// Auth API aligned with React [Login.jsx] and future signup.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  Future<Map<String, dynamic>?> getStoredUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kUserKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<bool> hasValidSession() async {
    final u = await getStoredUser();
    final token = u?['token'];
    return token != null && token.toString().isNotEmpty;
  }

  Future<void> saveUser(Map<String, dynamic> payload) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserKey, jsonEncode(payload));
  }

  Future<void> clearUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUserKey);
  }

  /// Updates [balance] / [walletBalance] in stored user (same keys as React [updateUserBalance]).
  Future<void> updateStoredBalance(num balance) async {
    final u = await getStoredUser();
    if (u == null) return;
    u['balance'] = balance;
    u['walletBalance'] = balance;
    await saveUser(u);
  }

  /// `POST /users/login` — same body as React.
  Future<AuthResult> login({
    required String phone,
    required String password,
  }) async {
    final deviceId = await DeviceIdService.instance.getOrCreate();
    final uri = Uri.parse('$kApiBaseUrl/users/login');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone': phone,
        'password': password,
        'deviceId': deviceId,
      }),
    );

    return _parseAuthResponse(response);
  }

  /// Not in the React app yet; typical REST name is [register].
  /// Change path here if your backend uses e.g. `/users/signup`.
  Future<AuthResult> register({
    required String phone,
    required String password,
  }) async {
    final deviceId = await DeviceIdService.instance.getOrCreate();
    final uri = Uri.parse('$kApiBaseUrl/users/register');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone': phone,
        'password': password,
        'deviceId': deviceId,
      }),
    );

    return _parseAuthResponse(response);
  }

  AuthResult _parseAuthResponse(http.Response response) {
    Map<String, dynamic>? data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>?;
    } catch (_) {
      return AuthResult(
        ok: false,
        message: 'Invalid response from server. Please try again.',
      );
    }

    final success = data?['success'] == true;
    final message = data?['message']?.toString() ?? 'Something went wrong';
    if (!success) {
      return AuthResult(ok: false, message: message);
    }

    final inner = data?['data'];
    if (inner is! Map<String, dynamic>) {
      return AuthResult(ok: false, message: 'Invalid response from server.');
    }

    return AuthResult(ok: true, message: message, user: inner);
  }
}

class AuthResult {
  const AuthResult({
    required this.ok,
    required this.message,
    this.user,
  });

  final bool ok;
  final String message;
  final Map<String, dynamic>? user;
}
