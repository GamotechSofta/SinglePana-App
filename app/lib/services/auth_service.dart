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

  /// `POST /users/logout-device` — same payload as backend (phone, password, deviceId).
  Future<AuthResult> logoutDevice({
    required String phone,
    required String password,
    String? deviceId,
  }) async {
    final id = deviceId ?? await DeviceIdService.instance.getOrCreate();
    final uri = Uri.parse('$kApiBaseUrl/users/logout-device');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone': phone.trim(),
        'password': password,
        'deviceId': id,
      }),
    );

    return _parseAuthResponse(response, requireUserData: false);
  }

  /// `POST /users/login` — same body as React ([phone], [password], [deviceId]).
  /// When [logoutOtherDevices] is true, calls [logoutDevice] first, then logs in.
  Future<AuthResult> login({
    required String phone,
    required String password,
    bool logoutOtherDevices = false,
  }) async {
    final phoneTrim = phone.trim();
    final deviceId = await DeviceIdService.instance.getOrCreate();

    if (logoutOtherDevices) {
      final cleared = await logoutDevice(
        phone: phoneTrim,
        password: password,
        deviceId: deviceId,
      );
      if (!cleared.ok) return cleared;
    }

    final uri = Uri.parse('$kApiBaseUrl/users/login');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone': phoneTrim,
        'password': password,
        'deviceId': deviceId,
      }),
    );

    return _parseAuthResponse(response);
  }

  /// `POST /users/signup` — [firstName], [lastName], [phone], [password], [deviceId].
  Future<AuthResult> register({
    required String firstName,
    required String lastName,
    required String phone,
    required String password,
  }) async {
    final deviceId = await DeviceIdService.instance.getOrCreate();
    final uri = Uri.parse('$kApiBaseUrl/users/signup');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'phone': phone.trim(),
        'password': password,
        'deviceId': deviceId,
      }),
    );

    return _parseAuthResponse(response, requireUserData: false);
  }

  AuthResult _parseAuthResponse(
    http.Response response, {
    bool requireUserData = true,
  }) {
    Map<String, dynamic>? data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>?;
    } catch (_) {
      return AuthResult(
        ok: false,
        message: 'Invalid response from server. Please try again.',
      );
    }

    final statusOk = response.statusCode >= 200 && response.statusCode < 300;
    final success =
        data?['success'] == true ||
        data?['ok'] == true ||
        (statusOk && data?['success'] != false);
    final message =
        data?['message']?.toString() ??
        data?['error']?.toString() ??
        data?['msg']?.toString() ??
        (statusOk ? 'Success' : 'Something went wrong');
    if (!success) {
      return AuthResult(ok: false, message: message);
    }

    final inner = data?['data'];
    if (!requireUserData) {
      final user = inner is Map<String, dynamic>
          ? inner
          : data?['user'] is Map<String, dynamic>
              ? (data!['user'] as Map<String, dynamic>)
              : null;
      return AuthResult(ok: true, message: message, user: user);
    }

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
