import 'dart:async';

import 'package:flutter/material.dart';

import '../constants/remote_assets.dart';
import '../game_bid/market_for_bid.dart';
import '../services/markets_service.dart';
import '../theme/app_colors.dart';
import '../utils/nav_main_route.dart';
import '../utils/market_timing.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  Timer? _every30s;
  Timer? _every60s;
  String _lastIstDate = getTodayIst();

  List<Map<String, dynamic>> _rawMarkets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchMarkets();
    _every30s = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _fetchMarkets(),
    );
    _every60s = Timer.periodic(const Duration(seconds: 60), (_) {
      final today = getTodayIst();
      if (_lastIstDate != today) {
        _lastIstDate = today;
        _fetchMarkets();
      } else if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _every30s?.cancel();
    _every60s?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _lastIstDate = getTodayIst();
      _fetchMarkets();
    }
  }

  Future<void> _fetchMarkets() async {
    try {
      final all = await MarketsService.instance.fetchMarkets();
      final mainOnly = all
          .where((m) => m['marketType']?.toString() != 'startline')
          .toList();
      if (mounted) {
        setState(() {
          _rawMarkets = mainOnly;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatTime12(String? time24) {
    if (time24 == null || time24.isEmpty) return '';
    final parts = time24.split(':');
    final hour = int.tryParse(parts.isNotEmpty ? parts[0] : '0') ?? 0;
    final minutes = parts.length > 1 ? parts[1].padLeft(2, '0') : '00';
    final ampm = hour >= 12 ? 'PM' : 'AM';
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    return '$h12:$minutes $ampm';
  }

  bool _isThreeDigits(dynamic v) {
    if (v == null) return false;
    return RegExp(r'^\d{3}$').hasMatch(v.toString().trim());
  }

  Widget _marketCard(BuildContext context, Map<String, dynamic> m) {
    final status = _statusFor(m);
    final displayResult = m['displayResult']?.toString() ?? '***-**-***';
    final name = m['marketName']?.toString() ?? 'Market';
    final openT = _formatTime12(m['startingTime']?.toString());
    final closeT = _formatTime12(m['closingTime']?.toString());
    final clickable = status == 'open' || status == 'running';
    final statusText = status == 'closed'
        ? 'Closed for today'
        : status == 'running'
        ? 'Close is Running'
        : 'Market is Open';

    return _MarketCard(
      gameName: name,
      result: displayResult,
      statusText: statusText,
      statusClosed: status == 'closed',
      openTime: openT,
      closeTime: closeT,
      clickable: clickable,
      onTap: () {
        if (!clickable) return;
        navigateMainRoute(
          context,
          '/bidoptions',
          arguments: normalizeMarketForBid(m),
        );
      },
    );
  }

  String _statusFor(Map<String, dynamic> market) {
    if (isPastClosingTime(market)) return 'closed';
    if (_isThreeDigits(market['openingNumber']) &&
        _isThreeDigits(market['closingNumber'])) {
      return 'closed';
    }
    if (_isThreeDigits(market['openingNumber']) &&
        !_isThreeDigits(market['closingNumber'])) {
      return 'running';
    }
    return 'open';
  }

  Future<void> _confirmBeforeOpeningLottery() async {
    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rotate Screen'),
          content: const Text(
            'Lottery works best in landscape mode.\n\nDo you want to continue to Lottery now?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
    if (!mounted || shouldOpen != true) return;
    navigateMainRoute(context, '/lottery');
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 768;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _HeroSection(wide: wide)),
        SliverToBoxAdapter(
          child: _TopWinnersBanner(
            onTap: () => navigateMainRoute(context, '/top-winners'),
          ),
        ),
        SliverToBoxAdapter(
          child: _HomeQuickActionButtons(
            onLotteryTap: _confirmBeforeOpeningLottery,
            onGamesTap: () => navigateMainRoute(context, '/games'),
          ),
        ),
        SliverToBoxAdapter(child: _MarketsHeader(wide: wide)),
        if (_loading)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Center(
                child: Text(
                  'Loading markets...',
                  style: TextStyle(
                    color: AppColors.goldMuted.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          )
        else if (_rawMarkets.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Center(
                child: Text(
                  'No markets available',
                  style: TextStyle(
                    color: AppColors.goldMuted.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          )
        else if (wide)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.12,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _marketCard(context, _rawMarkets[index]),
                childCount: _rawMarkets.length,
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _marketCard(context, _rawMarkets[index]),
                ),
                childCount: _rawMarkets.length,
              ),
            ),
          ),
      ],
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    if (wide) {
      return AspectRatio(
        aspectRatio: 1920 / 500,
        child: Image.network(
          RemoteAssets.heroDesktop,
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (_, _, _) => Container(color: Colors.grey.shade800),
        ),
      );
    }
    return Image.network(
      RemoteAssets.heroMobile,
      width: double.infinity,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => const SizedBox(height: 10),
    );
  }
}

class _TopWinnersBanner extends StatelessWidget {
  const _TopWinnersBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      child: Container(
        padding: const EdgeInsets.all(1.6),
        decoration: BoxDecoration(
          gradient: AppColors.neonGlowGradient,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Material(
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashColor: Colors.white.withValues(alpha: 0.06),
            child: Container(
              decoration: BoxDecoration(
                gradient: AppColors.cardBackgroundGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.emoji_events_rounded,
                    color: AppColors.neonGreen,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Top Winners',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Text(
                    'View leaderboard',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.neonGreen.withValues(alpha: 0.65),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: AppColors.neonGreen.withValues(alpha: 0.65),
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

class _MarketsHeader extends StatelessWidget {
  const _MarketsHeader({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    final lineDim = AppColors.gold.withValues(alpha: 0.35);
    final lineBright = AppColors.gold.withValues(alpha: 0.85);
    if (wide) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [lineDim, lineBright, lineBright],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Icon(Icons.star, size: 10, color: AppColors.gold),
            const SizedBox(width: 6),
            Text(
              'MARKETS',
              style: TextStyle(
                color: AppColors.goldMuted,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                fontSize: 16,
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.star, size: 10, color: AppColors.gold),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [lineBright, lineBright, lineDim],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: lineDim)),
          const SizedBox(width: 8),
          Text(
            '+',
            style: TextStyle(
              color: AppColors.gold,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'MARKETS',
            style: TextStyle(
              color: AppColors.goldMuted,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              fontSize: 15,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '+',
            style: TextStyle(
              color: AppColors.gold,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 1, color: lineDim)),
        ],
      ),
    );
  }
}

class _HomeQuickActionButtons extends StatelessWidget {
  const _HomeQuickActionButtons({
    required this.onLotteryTap,
    required this.onGamesTap,
  });

  final VoidCallback onLotteryTap;
  final VoidCallback onGamesTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: _HomeActionButton(
              label: 'Lottery',
              icon: Icons.confirmation_number_rounded,
              onTap: onLotteryTap,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _HomeActionButton(
              label: 'Games',
              icon: Icons.sports_esports_rounded,
              onTap: onGamesTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeActionButton extends StatelessWidget {
  const _HomeActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(1.6),
      decoration: BoxDecoration(
        gradient: AppColors.neonGlowGradient,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: Colors.white.withValues(alpha: 0.07),
          child: Container(
            decoration: const BoxDecoration(gradient: AppColors.cardBackgroundGradient),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: AppColors.neonGreen, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
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

class _MarketCard extends StatelessWidget {
  const _MarketCard({
    required this.gameName,
    required this.result,
    required this.statusText,
    required this.statusClosed,
    required this.openTime,
    required this.closeTime,
    required this.clickable,
    required this.onTap,
  });

  final String gameName;
  final String result;
  final String statusText;
  final bool statusClosed;
  final String openTime;
  final String closeTime;
  final bool clickable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(13),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: clickable ? onTap : null,
          splashColor: Colors.white.withValues(alpha: 0.05),
          child: Container(
            decoration: const BoxDecoration(gradient: AppColors.cardBackgroundGradient),
            padding: const EdgeInsets.all(9),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      gameName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    statusText,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: statusClosed
                          ? AppColors.statusSoftError
                          : AppColors.accentEmerald,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      result,
                      style: TextStyle(
                        color: AppColors.accentEmerald,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  if (statusClosed)
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.accentRose,
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 18,
                      ),
                    )
                  else
                    Material(
                      color: AppColors.accentEmerald,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: onTap,
                        splashColor: Colors.white.withValues(alpha: 0.2),
                        child: const Padding(
                          padding: EdgeInsets.all(10),
                          child: Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Open Bids',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.neonGreen.withValues(alpha: 0.52),
                          ),
                        ),
                        Text(
                          openTime.isEmpty ? '-' : openTime,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.92),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Close Bids',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.neonGreen.withValues(alpha: 0.52),
                          ),
                        ),
                        Text(
                          closeTime.isEmpty ? '-' : closeTime,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.92),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }
}
