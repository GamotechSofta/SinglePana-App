import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../pages/login_page.dart';
import 'auth_service.dart';

/// Heartbeat, suspend/403 handling, and global logout navigation — [frontend/src/hooks/useHeartbeat.js]
/// + [clearUserSession] behavior from [frontend/src/config/api.js].
class SessionCoordinator {
  SessionCoordinator._();
  static final SessionCoordinator instance = SessionCoordinator._();

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static const _heartbeatInterval = Duration(minutes: 1);

  Timer? _heartbeatTimer;
  bool _logoutInFlight = false;

  /// Shown once on [LoginPage] after [forceLogoutToLogin] with a message.
  String? _pendingLoginMessage;

  String? consumePendingLoginMessage() {
    final m = _pendingLoginMessage;
    _pendingLoginMessage = null;
    return m;
  }

  void startHeartbeatIfLoggedIn() {
    unawaited(_syncTimer());
  }

  Future<void> _syncTimer() async {
    final ok = await AuthService.instance.hasValidSession();
    if (!ok) {
      stopHeartbeat();
      return;
    }
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) => unawaited(sendHeartbeat()));
    await sendHeartbeat();
  }

  void stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// POST `/users/heartbeat` — same contract as [useHeartbeat.js].
  Future<void> sendHeartbeat() async {
    final u = await AuthService.instance.getStoredUser();
    final token = u?['token']?.toString();
    final id = u?['id'] ?? u?['_id'];
    if (token == null || token.isEmpty || id == null) return;

    try {
      final res = await http.post(
        Uri.parse('$kApiBaseUrl/users/heartbeat'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: '{}',
      );

      if (res.statusCode == 401) {
        await forceLogoutToLogin();
        return;
      }
      if (res.statusCode == 403) {
        await forceLogoutToLogin();
        return;
      }

      Map<String, dynamic>? data;
      try {
        data = jsonDecode(res.body) as Map<String, dynamic>?;
      } catch (_) {}

      if (data != null &&
          data['success'] != true &&
          data['code']?.toString() == 'ACCOUNT_SUSPENDED') {
        await forceLogoutToLogin(message: 'Your account has been suspended.');
        return;
      }
    } catch (_) {
      // Network errors — same as web: ignore
    }
  }

  /// Clears session, stops heartbeat, and navigates to login (stack cleared).
  Future<void> forceLogoutToLogin({String? message}) async {
    if (_logoutInFlight) return;
    _logoutInFlight = true;
    try {
      stopHeartbeat();
      await AuthService.instance.clearUser();
      if (message != null && message.isNotEmpty) {
        _pendingLoginMessage = message;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final nav = navigatorKey.currentState;
        if (nav == null) return;
        nav.pushNamedAndRemoveUntil(LoginPage.routeName, (_) => false);
      });
    } finally {
      _logoutInFlight = false;
    }
  }

}
