import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/nav_main_route.dart';
import 'app_nav_metrics.dart';

/// Bottom bar — minimal icon + label, no heavy chrome.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.shellContext,
    required this.currentPath,
    this.casinoHomeStyle = false,
  });

  final BuildContext shellContext;
  final String currentPath;

  final bool casinoHomeStyle;

  bool _isActive(String path) {
    if (path == '/') {
      return currentPath == '/';
    }
    if (path == '/bids') {
      return currentPath == '/bids' ||
          currentPath == '/bet-history' ||
          currentPath == '/game-bet-history' ||
          currentPath == '/market-result-history';
    }
    return currentPath == path || currentPath.startsWith('$path/');
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final scheme = Theme.of(context).colorScheme;
    final lux = casinoHomeStyle;
    final barColor = lux ? AppColors.surface : scheme.surfaceContainer;
    final hairline = lux
        ? Colors.white.withValues(alpha: 0.08)
        : scheme.outlineVariant.withValues(alpha: 0.5);

    return Material(
      color: barColor,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: barColor,
          border: Border(top: BorderSide(color: hairline, width: 1)),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            4,
            6,
            4,
            bottomInset + 6,
          ),
          child: SizedBox(
            height: AppNavMetrics.innerHeight - 8,
            width: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _NavItem(
                  label: 'My Bets',
                  path: '/bids',
                  icon: Icons.emoji_events_outlined,
                  activeIcon: Icons.emoji_events_rounded,
                  active: _isActive('/bids'),
                  shellContext: shellContext,
                  casinoStyle: lux,
                ),
                _NavItem(
                  label: 'Games',
                  path: '/games',
                  icon: Icons.sports_esports_outlined,
                  activeIcon: Icons.sports_esports_rounded,
                  active: _isActive('/games'),
                  shellContext: shellContext,
                  casinoStyle: lux,
                ),
                _NavItem(
                  label: 'Home',
                  path: '/',
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  active: _isActive('/'),
                  shellContext: shellContext,
                  prominent: true,
                  casinoStyle: lux,
                ),
                _NavItem(
                  label: 'Funds',
                  path: '/funds',
                  icon: Icons.savings_outlined,
                  activeIcon: Icons.savings_rounded,
                  active: _isActive('/funds'),
                  shellContext: shellContext,
                  casinoStyle: lux,
                ),
                _NavItem(
                  label: 'Support',
                  path: '/support',
                  icon: Icons.headset_mic_outlined,
                  activeIcon: Icons.headset_mic_rounded,
                  active: _isActive('/support'),
                  shellContext: shellContext,
                  casinoStyle: lux,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.path,
    required this.icon,
    required this.activeIcon,
    required this.active,
    required this.shellContext,
    this.prominent = false,
    this.casinoStyle = false,
  });

  final String label;
  final String path;
  final IconData icon;
  final IconData activeIcon;
  final bool active;
  final BuildContext shellContext;
  final bool prominent;
  final bool casinoStyle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final inactiveColor = casinoStyle
        ? Colors.white.withValues(alpha: 0.45)
        : scheme.onSurface.withValues(alpha: 0.55);
    final activeColor =
        casinoStyle ? AppColors.gold : scheme.primary;
    final fg = active ? activeColor : inactiveColor;
    final iconSize = prominent ? (active ? 28.0 : 26.0) : (active ? 24.0 : 22.0);

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => navigateMainRoute(shellContext, path),
          borderRadius: BorderRadius.circular(12),
          splashColor: (casinoStyle ? AppColors.gold : scheme.primary)
              .withValues(alpha: 0.08),
          highlightColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  active ? activeIcon : icon,
                  size: iconSize,
                  color: fg,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: prominent ? 11 : 10,
                    height: 1.05,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    letterSpacing: -0.1,
                    color: fg,
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
