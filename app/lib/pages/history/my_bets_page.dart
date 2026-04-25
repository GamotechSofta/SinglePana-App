import 'package:flutter/material.dart';

import '../../constants/remote_assets.dart';
import '../../theme/app_colors.dart';
import '../../utils/nav_main_route.dart';
import '../../theme/casino_ui.dart';
import '../../utils/nav_pop_or_home.dart';
import 'bet_history_screen.dart';
import 'market_results_screen.dart';

/// Hub for bet history + market results — [frontend/src/pages/Bids.jsx].
class MyBetsPage extends StatefulWidget {
  const MyBetsPage({super.key});

  @override
  State<MyBetsPage> createState() => _MyBetsPageState();
}

class _MyBetsPageState extends State<MyBetsPage> {
  static const _kGameResultsTab = 'game-results';
  static const _kBetHistoryTab = 'bet-history';
  static const _kGameBetHistoryTab = 'game-bet-history';

  String _desktopPanel = _kBetHistoryTab;
  bool _argsRead = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsRead) return;
    _argsRead = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['tab']?.toString() == _kGameResultsTab) {
      _desktopPanel = _kGameResultsTab;
    }
  }

  void _onBack(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 768;
    if (wide) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      popOrGoHome(context);
    }
  }

  void _openMobileBetHistory(BuildContext context) {
    navigateMainRoute(context, '/bet-history');
  }

  void _openMobileResults(BuildContext context) {
    navigateMainRoute(context, '/market-result-history');
  }

  void _openMobileGameBetHistory(BuildContext context) {
    navigateMainRoute(context, '/game-bet-history');
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final rightTitle = _desktopPanel == _kGameResultsTab
        ? 'Market Result History'
        : _desktopPanel == _kGameBetHistoryTab
        ? 'Game Bet History'
        : 'Bet History';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
          child: Row(
            children: [
              IconButton(
                onPressed: () => _onBack(context),
                icon: const Icon(Icons.arrow_back),
                color: AppColors.goldMuted,
              ),
              Expanded(
                child: Text(
                  'MY BETS',
                  style: TextStyle(
                    fontSize: wide ? 22 : 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: AppColors.gold,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: wide
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 280,
                        child: ListView(
                          children: [
                            _HubTile(
                              title: 'Bet History',
                              subtitle: 'You can view your market bet history',
                              onTap: () => setState(
                                () => _desktopPanel = _kBetHistoryTab,
                              ),
                              selected: _desktopPanel == _kBetHistoryTab,
                            ),
                            const SizedBox(height: 12),
                            _HubTile(
                              title: 'Game Bet History',
                              subtitle: 'You can view only game related bets',
                              onTap: () => setState(
                                () => _desktopPanel = _kGameBetHistoryTab,
                              ),
                              selected: _desktopPanel == _kGameBetHistoryTab,
                            ),
                            const SizedBox(height: 12),
                            _HubTile(
                              title: 'Game Results',
                              subtitle:
                                  'You can view your market result history',
                              iconUrl: RemoteAssets.gameResultsHub,
                              onTap: () => setState(
                                () => _desktopPanel = _kGameResultsTab,
                              ),
                              selected: _desktopPanel == _kGameResultsTab,
                            ),
                          ],
                        ),
                      ),
                      VerticalDivider(
                        width: 1,
                        color: AppColors.gold.withValues(alpha: 0.28),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  rightTitle,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.gold,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: _desktopPanel == _kGameResultsTab
                                    ? const MarketResultsView()
                                    : _desktopPanel == _kGameBetHistoryTab
                                    ? const GameBetHistoryView()
                                    : const BetHistoryView(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  children: [
                    _HubTile(
                      title: 'Bet History',
                      subtitle: 'You can view your market bet history',
                      onTap: () => _openMobileBetHistory(context),
                      selected: false,
                      chevron: true,
                    ),
                    const SizedBox(height: 12),
                    _HubTile(
                      title: 'Game Bet History',
                      subtitle: 'You can view only game related bets',
                      onTap: () => _openMobileGameBetHistory(context),
                      selected: false,
                      chevron: true,
                    ),
                    const SizedBox(height: 12),
                    _HubTile(
                      title: 'Game Results',
                      subtitle: 'You can view your market result history',
                      iconUrl: RemoteAssets.gameResultsHub,
                      onTap: () => _openMobileResults(context),
                      selected: false,
                      chevron: true,
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _HubTile extends StatelessWidget {
  const _HubTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.selected,
    this.iconUrl,
    this.chevron = false,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool selected;
  final String? iconUrl;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: Colors.white.withValues(alpha: 0.08),
        highlightColor: Colors.white.withValues(alpha: 0.04),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.gold.withValues(alpha: selected ? 0.42 : 0.24),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: selected ? 0.22 : 0.14),
                blurRadius: selected ? 12 : 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              if (iconUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    iconUrl!,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Icon(
                      Icons.emoji_events,
                      size: 40,
                      color: AppColors.goldMuted.withValues(alpha: 0.9),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: CasinoUi.lightGold,
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: CasinoUi.mutedGold(0.72),
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              if (chevron)
                Icon(
                  Icons.chevron_right,
                  color: AppColors.goldMuted.withValues(alpha: 0.88),
                  size: 28,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
