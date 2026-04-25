import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../config/api_config.dart';
import '../services/auth_service.dart';
import '../theme/casino_ui.dart';

class GamesPage extends StatefulWidget {
  const GamesPage({super.key});

  @override
  State<GamesPage> createState() => _GamesPageState();
}

class _GamesPageState extends State<GamesPage> {
  static const _cardThemes = <({Color start, Color end})>[
    (start: Color(0xFF0284C7), end: Color(0xFF4338CA)),
    (start: Color(0xFF7C3AED), end: Color(0xFF6D28D9)),
    (start: Color(0xFFE11D48), end: Color(0xFFDC2626)),
    (start: Color(0xFF059669), end: Color(0xFF0F766E)),
    (start: Color(0xFFF59E0B), end: Color(0xFFEA580C)),
  ];

  bool _loading = true;
  String _error = '';
  String _launchingCode = '';
  List<_GameItem> _games = const [];

  @override
  void initState() {
    super.initState();
    _loadGames();
  }

  Future<Map<String, String>> _getAuthHeaders() async {
    final user = await AuthService.instance.getStoredUser();
    final token = user?['token']?.toString().trim() ?? '';
    if (token.isEmpty) return const {};
    return {'Authorization': 'Bearer $token'};
  }

  String _resolvePlayerId(Map<String, dynamic>? user) {
    final id =
        user?['_id']?.toString().trim() ??
        user?['id']?.toString().trim() ??
        user?['userId']?.toString().trim() ??
        '';
    return id;
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
    if (value is Map) {
      return value.map((k, v) => MapEntry('$k', v));
    }
    return null;
  }

  Future<List<_GameItem>> _getAllGames() async {
    final headers = await _getAuthHeaders();
    final response = await http.get(
      Uri.parse('$kApiBaseUrl/games'),
      headers: {
        'Content-Type': 'application/json',
        ...headers,
      },
    );

    final data = _decodeMap(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data?['message']?.toString() ?? 'Failed to load games');
    }

    final rawList = data?['data'];
    if (rawList is! List) return const [];

    return rawList
        .map(_asMap)
        .whereType<Map<String, dynamic>>()
        .map(_GameItem.fromJson)
        .toList();
  }

  Future<void> _loadGames() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final list = await _getAllGames();
      if (!mounted) return;
      setState(() {
        _games = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _games = const [];
        _error = e.toString().replaceFirst('Exception: ', '').trim();
        _loading = false;
      });
    }
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

  Future<void> _launchGame(_GameItem game) async {
    final gameCode = game.gameCode.trim().toUpperCase();
    if (gameCode.isEmpty) {
      setState(() => _error = 'Missing gameCode');
      return;
    }

    final user = await AuthService.instance.getStoredUser();
    final externalPlayerId = _resolvePlayerId(user);
    final authHeaders = await _getAuthHeaders();

    if (externalPlayerId.isEmpty) {
      if (!mounted) return;
      setState(() => _error = 'Player not found. Please login again.');
      return;
    }
    if (authHeaders['Authorization'] == null || authHeaders['Authorization']!.isEmpty) {
      if (!mounted) return;
      setState(() => _error = 'Session expired. Please login again.');
      return;
    }

    setState(() {
      _error = '';
      _launchingCode = gameCode;
    });

    try {
      final payload = jsonEncode({
        'gameCode': gameCode,
        'externalPlayerId': externalPlayerId,
        'currency': 'INR',
        'locale': 'en',
        'returnUrl': '',
      });

      final response = await http.post(
        Uri.parse('$kApiBaseUrl/games/launch/${Uri.encodeComponent(gameCode)}'),
        headers: {
          'Content-Type': 'application/json',
          ...authHeaders,
        },
        body: payload,
      );

      final data = _decodeMap(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(data?['message']?.toString() ?? 'Failed to launch game');
      }

      final launchLink = _extractLaunchUrl(data);
      if (launchLink.isEmpty) {
        throw Exception('Failed to launch game');
      }

      final uri = Uri.tryParse(launchLink);
      if (uri == null) {
        throw Exception('Invalid game URL');
      }

      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        throw Exception('Unable to open game URL');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '').trim();
      });
    } finally {
      if (!mounted) return;
      setState(() => _launchingCode = '');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 760;
    final horizontalPadding = isWide ? 18.0 : 12.0;
    final columns = isWide ? 2 : 1;
    final cardWidth = (MediaQuery.sizeOf(context).width - (horizontalPadding * 2) - 12) / columns;

    return RefreshIndicator(
      onRefresh: _loadGames,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(horizontalPadding, 14, horizontalPadding, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Games',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: CasinoUi.lightGold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose a game and start playing.',
              style: TextStyle(
                fontSize: 13,
                color: CasinoUi.mutedGold(0.78),
              ),
            ),
            const SizedBox(height: 14),
            if (_loading) _buildSkeletonGrid(isWide: isWide, cardWidth: cardWidth),
            if (!_loading && _error.isNotEmpty)
              _StatusBanner(
                message: _error,
                background: const Color(0xFFFEF2F2),
                border: const Color(0xFFFECACA),
                text: const Color(0xFFB91C1C),
              ),
            if (!_loading && _error.isEmpty && _games.isEmpty)
              const _StatusBanner(
                message: 'No games found. Add games from Postman and refresh.',
                background: Colors.white,
                border: Color(0xFFD1D5DB),
                text: Color(0xFF4B5563),
              ),
            if (!_loading && _error.isEmpty && _games.isNotEmpty)
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _games.asMap().entries.map((entry) {
                  final index = entry.key;
                  final game = entry.value;
                  final theme = _cardThemes[index % _cardThemes.length];
                  final loading = _launchingCode == game.gameCode.trim().toUpperCase();
                  return SizedBox(
                    width: cardWidth,
                    child: _GameCard(
                      game: game,
                      theme: theme,
                      loading: loading,
                      onTap: loading ? null : () => _launchGame(game),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonGrid({required bool isWide, required double cardWidth}) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: List.generate(
        6,
        (index) => SizedBox(
          width: cardWidth,
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFD1D5DB)),
              color: Colors.white,
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Container(
                  height: 108,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: const Color(0xFFE5E7EB),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 12,
                  width: 110,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: const Color(0xFFE5E7EB),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 10,
                  width: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: const Color(0xFFE5E7EB),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.message,
    required this.background,
    required this.border,
    required this.text,
  });

  final String message;
  final Color background;
  final Color border;
  final Color text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: background,
        border: Border.all(color: border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          color: text,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({
    required this.game,
    required this.theme,
    required this.loading,
    required this.onTap,
  });

  final _GameItem game;
  final ({Color start, Color end}) theme;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final title = game.name.isNotEmpty ? game.name : 'Unnamed Game';
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [theme.start, theme.end],
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Opacity(
            opacity: loading ? 0.72 : 1,
            child: SizedBox(
              height: 180,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (game.image.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        game.image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _FallbackInitials(title: title),
                      ),
                    )
                  else
                    _FallbackInitials(title: title),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.15),
                          Colors.black.withValues(alpha: 0.82),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Text(
                      loading ? 'Launching...' : title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FallbackInitials extends StatelessWidget {
  const _FallbackInitials({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        _getInitials(title),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 34,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

String _prettifyText(String value) {
  var output = value.trim();
  output = output.replaceAll(RegExp(r'[_-]+'), ' ');
  output = output.replaceAll(RegExp(r'\s+'), ' ');
  if (output.isEmpty) return '';
  return output
      .split(' ')
      .map((word) {
        if (word.isEmpty) return '';
        return '${word[0].toUpperCase()}${word.substring(1)}';
      })
      .join(' ');
}

String _getInitials(String value) {
  final parts = _prettifyText(value).split(' ').where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) return 'GM';
  if (parts.length == 1) {
    final first = parts.first;
    return first.substring(0, first.length >= 2 ? 2 : 1).toUpperCase();
  }
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}

class _GameItem {
  const _GameItem({
    required this.id,
    required this.gameCode,
    required this.name,
    required this.image,
  });

  final String id;
  final String gameCode;
  final String name;
  final String image;

  factory _GameItem.fromJson(Map<String, dynamic> json) {
    return _GameItem(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      gameCode: (json['gameCode'] ?? '').toString(),
      name: (json['name'] ?? 'Unnamed Game').toString(),
      image: (json['image'] ?? '').toString(),
    );
  }
}
