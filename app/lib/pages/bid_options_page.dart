import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/casino_ui.dart';
import '../utils/nav_main_route.dart';
import '../widgets/remote_image_or_svg.dart';
import '../utils/market_timing.dart';
import 'game_bid_page.dart';

class _BidOpt {
  const _BidOpt({required this.id, required this.title, required this.iconUrl});

  final double id;
  final String title;
  final String iconUrl;
}

const _singleIcon =
    'https://res.cloudinary.com/dzd47mpdo/image/upload/v1769756244/Untitled_90_x_160_px_1080_x_1080_px_1_yinraf.svg';
const _jodiIcon =
    'https://res.cloudinary.com/dzd47mpdo/image/upload/v1769714108/Untitled_1080_x_1080_px_1080_x_1080_px_7_rpzykt.svg';
const _spIcon =
    'https://res.cloudinary.com/dzd47mpdo/image/upload/v1769714254/Untitled_1080_x_1080_px_1080_x_1080_px_8_jdbxyd.svg';
const _dpIcon =
    'https://res.cloudinary.com/dzd47mpdo/image/upload/v1769713943/Untitled_1080_x_1080_px_1080_x_1080_px_6_uccv7o.svg';
const _tpIcon =
    'https://res.cloudinary.com/dzd47mpdo/image/upload/v1769714392/Untitled_1080_x_1080_px_1080_x_1080_px_9_ugcdef.svg';
const _fullSangamIcon =
    'https://res.cloudinary.com/dzd47mpdo/image/upload/v1770033671/Untitled_design_2_kr1imj.svg';
const _halfSangamIcon =
    'https://res.cloudinary.com/dzd47mpdo/image/upload/v1770033165/Untitled_design_c5hag8.svg';

final _allOptions = <_BidOpt>[
  const _BidOpt(id: 1, title: 'Single Digit', iconUrl: _singleIcon),
  const _BidOpt(id: 2, title: 'Single Digit Bulk', iconUrl: _singleIcon),
  const _BidOpt(id: 3, title: 'Jodi', iconUrl: _jodiIcon),
  const _BidOpt(id: 4, title: 'Jodi Bulk', iconUrl: _jodiIcon),
  const _BidOpt(id: 5, title: 'Single Pana', iconUrl: _spIcon),
  const _BidOpt(id: 6, title: 'Single Pana Bulk', iconUrl: _spIcon),
  const _BidOpt(id: 7, title: 'Double Pana', iconUrl: _dpIcon),
  const _BidOpt(id: 8, title: 'Double Pana Bulk', iconUrl: _dpIcon),
  const _BidOpt(id: 9, title: 'Triple Pana', iconUrl: _tpIcon),
  const _BidOpt(id: 10, title: 'Half Sangam', iconUrl: _halfSangamIcon),
  const _BidOpt(id: 11, title: 'Full Sangam', iconUrl: _fullSangamIcon),
  const _BidOpt(id: 12, title: 'SP Common', iconUrl: _spIcon),
  const _BidOpt(id: 13, title: 'DP Common', iconUrl: _dpIcon),
  const _BidOpt(id: 14, title: 'CP', iconUrl: _spIcon),
  const _BidOpt(id: 15, title: 'SP Motor', iconUrl: _spIcon),
  const _BidOpt(id: 16, title: 'DP Motor', iconUrl: _dpIcon),
  const _BidOpt(id: 17, title: 'SP DP Motor', iconUrl: _spIcon),
  const _BidOpt(id: 18, title: 'SP DP T Motor', iconUrl: _spIcon),
  const _BidOpt(id: 19, title: 'Odd Even', iconUrl: _singleIcon),
  const _BidOpt(id: 20, title: 'Chart Game', iconUrl: _spIcon),
];

bool _inferStarline(Map<String, dynamic>? market) {
  if (market == null) return false;
  final t = (market['marketType'] ?? '').toString().trim().toLowerCase();
  if (t == 'starline' || t == 'startline') return true;
  final name = (market['marketName'] ?? market['gameName'] ?? '')
      .toString()
      .toLowerCase();
  return name.contains('starline') ||
      name.contains('startline') ||
      name.contains('star line');
}

class BidOptionsPage extends StatefulWidget {
  const BidOptionsPage({super.key});

  @override
  State<BidOptionsPage> createState() => _BidOptionsPageState();
}

class _BidOptionsPageState extends State<BidOptionsPage> {
  Map<String, dynamic>? _market;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      _market = Map<String, dynamic>.from(args);
    }
  }

  @override
  Widget build(BuildContext context) {
    final market = _market;
    if (market == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) navigateMainRoute(context, '/');
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    final isStarline = _inferStarline(market);
    final timing = isBettingAllowed(market);
    final isCloseOnlyWindow = timing.allowed && timing.closeOnly;
    final isRunning =
        market['status']?.toString() == 'running' || isCloseOnlyWindow;

    final starlineAllowed = {
      'Single Digit',
      'Single Digit Bulk',
      'Odd Even',
      'SP Common',
      'CP',
      'Single Pana',
      'Single Pana Bulk',
      'Double Pana',
      'Double Pana Bulk',
      'Triple Pana',
      'Half Sangam',
      'SP Motor',
      'DP Motor',
      'DP Common',
      'SP DP Motor',
      'SP DP T Motor',
      'Chart Game',
    };

    var visible = isStarline
        ? _allOptions.where((o) => starlineAllowed.contains(o.title)).toList()
        : _allOptions;

    if (!isStarline && isRunning) {
      const hideWhenRunning = {
        'jodi',
        'jodi bulk',
        'full sangam',
        'half sangam',
      };
      visible = visible
          .where((o) => !hideWhenRunning.contains(o.title.toLowerCase().trim()))
          .toList();
    }

    final gameName =
        (market['gameName'] ?? market['marketName'] ?? 'SELECT MARKET')
            .toString();
    final screenW = MediaQuery.sizeOf(context).width;
    final crossAxisCount = screenW >= 520 ? 4 : (screenW >= 340 ? 3 : 2);
    final childAspectRatio = crossAxisCount >= 4
        ? 1.22
        : crossAxisCount >= 3
        ? 1.16
        : 1.1;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          CasinoUi.backdropBlur(
            borderRadius: BorderRadius.zero,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            fill: AppColors.surfaceCard.withValues(alpha: 0.48),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withValues(alpha: 0.14),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                  color: CasinoUi.mutedGold(0.95),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        gameName.toUpperCase(),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          letterSpacing: 0.5,
                          color: CasinoUi.lightGold,
                        ),
                      ),
                      if (isStarline)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'STARLINE MARKET',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                              color: AppColors.neonGreen,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 92),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: childAspectRatio,
              ),
              itemCount: visible.length,
              itemBuilder: (context, i) {
                final o = visible[i];
                final bulk = o.title.toLowerCase().contains('bulk');
                return Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).pushNamed(
                        GameBidPage.routeName,
                        arguments: GameBidArgs(
                          market: market,
                          betType: o.title,
                          gameMode: bulk ? 'bulk' : 'easy',
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    splashColor: Colors.white.withValues(alpha: 0.06),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: AppColors.cardBackgroundGradient,
                      ),
                      padding: const EdgeInsets.fromLTRB(4, 5, 4, 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 1),
                              child: RemoteImageOrSvg(
                                url: o.iconUrl,
                                fit: BoxFit.contain,
                                errorWidget: Icon(
                                  Icons.casino,
                                  size: 22,
                                  color: AppColors.textSecondary.withValues(alpha: 0.85),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            o.title.toUpperCase(),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.35,
                              height: 1.1,
                              color: CasinoUi.lightGold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
