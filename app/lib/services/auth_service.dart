import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import 'device_id_service.dart';
import 'login_device_name.dart';

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

  /// Ends **this** device's session on the server, then clears local user and stored device id.
  ///
  /// Always clears locally even if the network call fails, so the user is logged out on this phone.
  /// Uses `POST /users/logout` with the session token (same family as [login] / [heartbeat]).
  Future<void> logoutThisDevice() async {
    final u = await getStoredUser();
    final token = u?['token']?.toString();
    final deviceId = await DeviceIdService.instance.getOrCreate();
    final phone =
        u?['phone']?.toString().trim() ?? u?['username']?.toString().trim() ?? '';

    if (token != null && token.isNotEmpty) {
      try {
        await http.post(
          Uri.parse('$kApiBaseUrl/users/logout'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'deviceId': deviceId,
            'deviceID': deviceId,
            if (phone.isNotEmpty) 'phone': phone,
            if (phone.isNotEmpty) 'username': phone,
          }),
        );
      } catch (_) {
        // Offline or unknown route — still clear locally below.
      }
    }

    await clearUser();
    await DeviceIdService.instance.clearStoredId();
  }

  /// Updates [balance] / [walletBalance] in stored user (same keys as React [updateUserBalance]).
  Future<void> updateStoredBalance(num balance) async {
    final u = await getStoredUser();
    if (u == null) return;
    u['balance'] = balance;
    u['walletBalance'] = balance;
    await saveUser(u);
  }

  /// `POST /users/logout-device` — body: [phone], [password], [deviceId] (all required by API).
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

  /// `POST /users/login` — same body as React [Login.jsx]: [phone], [password], [deviceId], [deviceName].
  ///
  /// On `DEVICE_LIMIT_REACHED`, returns [AuthResult.code] and [AuthResult.activeDevices] for the UI
  /// (per-device `logout-device` then retry login — see [LoginPage]).
  Future<AuthResult> login({
    required String phone,
    required String password,
  }) async {
    final phoneTrim = phone.trim();
    final deviceIdForLogin = await DeviceIdService.instance.getOrCreate();
    final deviceName = getLoginDeviceName();

    Future<AuthResult> postLogin(String id) async {
      final uri = Uri.parse('$kApiBaseUrl/users/login');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': phoneTrim,
          'password': password,
          'deviceId': id,
          'deviceName': deviceName,
        }),
      );
      return _parseAuthResponse(response);
    }

    var result = await postLogin(deviceIdForLogin);
    if (!result.ok && _isInactiveDeviceMessage(result.message)) {
      final freshId = await DeviceIdService.instance.regenerate();
      result = await postLogin(freshId);
    }
    return result;
  }

  static bool _isInactiveDeviceMessage(String message) {
    final s = message.toLowerCase();
    return (s.contains('device') && s.contains('not active')) ||
        s.contains('device is not active');
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
        'deviceName': getLoginDeviceName(),
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
      final code = data?['code']?.toString();
      List<Map<String, dynamic>>? activeDevices;
      if (code != null && code.toUpperCase() == 'DEVICE_LIMIT_REACHED') {
        activeDevices = _parseActiveDevices(data?['data']);
      }
      return AuthResult(
        ok: false,
        message: message,
        code: code,
        activeDevices: activeDevices,
      );
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

  static List<Map<String, dynamic>>? _parseActiveDevices(Object? rawData) {
    if (rawData is! Map) return null;
    final container = Map<String, dynamic>.from(rawData);
    final raw = container['activeDevices'];
    if (raw is! List) return null;
    final out = <Map<String, dynamic>>[];
    for (final e in raw) {
      if (e is Map<String, dynamic>) {
        out.add(e);
      } else if (e is Map) {
        out.add(Map<String, dynamic>.from(e));
      }
    }
    return out.isEmpty ? null : out;
  }
}

class AuthResult {
  const AuthResult({
    required this.ok,
    required this.message,
    this.user,
    this.code,
    this.activeDevices,
  });

  final bool ok;
  final String message;
  final Map<String, dynamic>? user;
  /// e.g. `DEVICE_LIMIT_REACHED` from [Login.jsx].
  final String? code;
  final List<Map<String, dynamic>>? activeDevices;
}
