import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/game_launch_result.dart';
import '../models/game_model.dart';
import 'auth_service.dart';

class GameLaunchService {
  GameLaunchService._();
  static final GameLaunchService instance = GameLaunchService._();

  Future<List<GameModel>> fetchGames() async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$kApiBaseUrl/games'),
      headers: {
        'Content-Type': 'application/json',
        ...headers,
      },
    );

    final body = _decodeMap(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(body?['message']?.toString() ?? 'Failed to load games');
    }

    final rawList = body?['data'];
    if (rawList is! List) return const [];

    return rawList
        .map(_asMap)
        .whereType<Map<String, dynamic>>()
        .map(GameModel.fromJson)
        .toList();
  }

  Future<GameLaunchResult> launchGame({
    required String gameCode,
  }) async {
    final normalizedCode = gameCode.trim().toUpperCase();
    if (normalizedCode.isEmpty) {
      throw Exception('Missing gameCode');
    }

    final user = await AuthService.instance.getStoredUser();
    final externalPlayerId = _resolvePlayerId(user);
    if (externalPlayerId.isEmpty) {
      throw Exception('Player not found. Please login again.');
    }

    final authHeaders = await _authHeaders();
    if (authHeaders['Authorization'] == null ||
        authHeaders['Authorization']!.isEmpty) {
      throw Exception('Session expired. Please login again.');
    }

    final payload = jsonEncode({
      'gameCode': normalizedCode,
      'externalPlayerId': externalPlayerId,
      'currency': 'INR',
      'locale': 'en',
      'returnUrl': '',
    });

    final response = await http.post(
      Uri.parse('$kApiBaseUrl/games/launch/${Uri.encodeComponent(normalizedCode)}'),
      headers: {
        'Content-Type': 'application/json',
        ...authHeaders,
      },
      body: payload,
    );

    final body = _decodeMap(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(body?['message']?.toString() ?? 'Failed to launch game');
    }

    final launchUrl = _extractLaunchUrl(body);
    if (launchUrl.isEmpty) {
      throw Exception('Failed to launch game');
    }

    final uri = Uri.tryParse(launchUrl);
    if (uri == null || (!uri.hasScheme)) {
      throw Exception('Invalid game URL');
    }

    return GameLaunchResult(
      launchUrl: launchUrl,
      gameCode: normalizedCode,
    );
  }

  Future<Map<String, String>> _authHeaders() async {
    final user = await AuthService.instance.getStoredUser();
    final token = user?['token']?.toString().trim() ?? '';
    if (token.isEmpty) return const {};
    return {'Authorization': 'Bearer $token'};
  }

  String _resolvePlayerId(Map<String, dynamic>? user) {
    return user?['_id']?.toString().trim() ??
        user?['id']?.toString().trim() ??
        user?['userId']?.toString().trim() ??
        '';
  }

  Map<String, dynamic>? _decodeMap(String body) {
    if (body.isEmpty) return null;
    try {
      final parsed = jsonDecode(body);
      if (parsed is Map<String, dynamic>) return parsed;
      if (parsed is Map) return parsed.map((k, v) => MapEntry('$k', v));
    } catch (_) {}
    return null;
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.map((k, v) => MapEntry('$k', v));
    return null;
  }

  String _extractLaunchUrl(Map<String, dynamic>? body) {
    final data = _asMap(body?['data']);
    final nested = _asMap(data?['data']);
    final options = [
      body?['launchUrl'],
      data?['launchUrl'],
      nested?['launchUrl'],
      data?['url'],
      data?['gameUrl'],
      data?['sessionUrl'],
      data?['redirectUrl'],
    ];
    for (final value in options) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return '';
  }
}
