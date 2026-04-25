import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_service.dart';
import 'session_coordinator.dart';

/// Help desk API — [frontend/src/pages/Support/SupportNew.jsx], [SupportStatus.jsx].
class HelpDeskService {
  HelpDeskService._();
  static final HelpDeskService instance = HelpDeskService._();

  Future<SubmitTicketResult> submitTicket({
    required String subject,
    required String description,
    List<String> imagePaths = const [],
  }) async {
    final user = await AuthService.instance.getStoredUser();
    final token = user?['token']?.toString();
    if (token == null || token.isEmpty) {
      return const SubmitTicketResult(success: false, message: 'Please log in to submit a support request.');
    }

    final uri = Uri.parse('$kApiBaseUrl/help-desk/tickets');
    final req = http.MultipartRequest('POST', uri);
    req.headers['Authorization'] = 'Bearer $token';
    req.fields['subject'] = subject.trim().isEmpty ? 'Support Request' : subject.trim();
    req.fields['description'] = description.trim();

    for (final path in imagePaths.take(5)) {
      req.files.add(await http.MultipartFile.fromPath('screenshots', path));
    }

    http.StreamedResponse streamed;
    try {
      streamed = await req.send();
    } catch (_) {
      return const SubmitTicketResult(success: false, message: 'Network error. Please try again.');
    }

    final res = await http.Response.fromStream(streamed);
    if (res.statusCode == 401) {
      await SessionCoordinator.instance.forceLogoutToLogin();
      return const SubmitTicketResult(success: false, message: 'Session expired. Please log in again.', unauthorized: true);
    }

    Map<String, dynamic>? data;
    try {
      data = jsonDecode(res.body) as Map<String, dynamic>?;
    } catch (_) {
      return const SubmitTicketResult(success: false, message: 'Invalid response from server');
    }

    if (data?['success'] == true) {
      return SubmitTicketResult(success: true, message: data?['message']?.toString());
    }
    return SubmitTicketResult(
      success: false,
      message: data?['message']?.toString() ?? 'Failed to submit. Please try again.',
    );
  }

  Future<MyTicketsResult> fetchMyTickets() async {
    final user = await AuthService.instance.getStoredUser();
    final token = user?['token']?.toString();
    if (token == null || token.isEmpty) {
      return const MyTicketsResult(success: false, message: 'Please log in', tickets: []);
    }

    final uri = Uri.parse('$kApiBaseUrl/help-desk/my-tickets');
    http.Response res;
    try {
      res = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
    } catch (_) {
      return const MyTicketsResult(success: false, tickets: []);
    }

    if (res.statusCode == 401) {
      await SessionCoordinator.instance.forceLogoutToLogin();
      return const MyTicketsResult(success: false, message: 'Session expired', tickets: [], unauthorized: true);
    }

    try {
      final data = jsonDecode(res.body) as Map<String, dynamic>?;
      if (data?['success'] == true && data?['data'] is List) {
        final list = (data!['data'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        return MyTicketsResult(success: true, tickets: list);
      }
    } catch (_) {}
    return const MyTicketsResult(success: false, tickets: []);
  }
}

class SubmitTicketResult {
  const SubmitTicketResult({
    required this.success,
    this.message,
    this.unauthorized = false,
  });

  final bool success;
  final String? message;
  final bool unauthorized;
}

class MyTicketsResult {
  const MyTicketsResult({
    required this.success,
    this.message,
    this.tickets = const [],
    this.unauthorized = false,
  });

  final bool success;
  final String? message;
  final List<Map<String, dynamic>> tickets;
  final bool unauthorized;
}
