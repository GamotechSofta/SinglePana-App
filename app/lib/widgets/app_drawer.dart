import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../pages/login_page.dart';
import '../services/auth_service.dart';
import '../services/session_coordinator.dart';
import '../theme/app_colors.dart';
import '../utils/nav_main_route.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, required this.shellContext});

  final BuildContext shellContext;

  static final _items = <_DrawerItem>[
    _DrawerItem(
      label: 'My Bets',
      path: '/bids',
      icon: Icons.receipt_long_outlined,
    ),
    _DrawerItem(
      label: 'Bank',
      path: '/bank',
      icon: Icons.account_balance_outlined,
    ),
    _DrawerItem(
      label: 'Top Winners',
      path: '/top-winners',
      icon: Icons.emoji_events_outlined,
    ),
    _DrawerItem(
      label: 'Funds',
      path: '/funds',
      icon: Icons.account_balance_wallet_outlined,
    ),
    _DrawerItem(
      label: 'Passbook',
      path: '/passbook',
      icon: Icons.menu_book_outlined,
    ),
    _DrawerItem(
      label: 'Game Rate',
      path: '/game-rate',
      icon: Icons.star_outline_rounded,
    ),
    _DrawerItem(
      label: 'Help Desk',
      path: '/support',
      icon: Icons.support_agent_outlined,
    ),
    _DrawerItem(label: 'Logout', isLogout: true, icon: Icons.logout_rounded),
  ];

  void _closeDrawer() {
    final nav = Navigator.of(shellContext);
    if (nav.canPop()) nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.surface,
      width: (MediaQuery.sizeOf(context).width * 0.86).clamp(0.0, 320.0),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DrawerProfileHeader(
              shellContext: shellContext,
              onCloseDrawer: _closeDrawer,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                children: [
                  for (final item in _items)
                    _DrawerTile(
                        item: item,
                        onTap: () async {
                          if (item.isLogout) {
                            _closeDrawer();
                            SessionCoordinator.instance.stopHeartbeat();
                            await AuthService.instance.clearUser();
                            if (shellContext.mounted) {
                              Navigator.of(
                                shellContext,
                              ).pushNamedAndRemoveUntil(
                                LoginPage.routeName,
                                (_) => false,
                              );
                            }
                            return;
                          }
                          if (item.path != null) {
                            _closeDrawer();
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (shellContext.mounted) {
                                navigateMainRoute(shellContext, item.path!);
                              }
                            });
                          }
                        },
                      ),
                  const SizedBox(height: 16),
                  Text(
                    'Version: 1.0.0',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem {
  const _DrawerItem({
    required this.label,
    this.path,
    required this.icon,
    this.isLogout = false,
  });

  final String label;
  final String? path;
  final IconData icon;
  final bool isLogout;
}

class _DrawerProfileHeader extends StatefulWidget {
  const _DrawerProfileHeader({
    required this.shellContext,
    required this.onCloseDrawer,
  });

  final BuildContext shellContext;
  final VoidCallback onCloseDrawer;

  @override
  State<_DrawerProfileHeader> createState() => _DrawerProfileHeaderState();
}

class _DrawerProfileHeaderState extends State<_DrawerProfileHeader> {
  Map<String, dynamic>? _user;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final u = await AuthService.instance.getStoredUser();
    if (mounted) setState(() => _user = u);
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final displayName = user?['username']?.toString() ?? 'Sign In';
    final displayPhone =
        user?['phone']?.toString() ??
        user?['mobile']?.toString() ??
        user?['email']?.toString() ??
        '-';
    final sinceRaw =
        user?['createdAt'] ?? user?['created_at'] ?? user?['createdOn'];
    DateTime? since;
    if (sinceRaw != null) {
      since = DateTime.tryParse(sinceRaw.toString());
    }
    final sinceText = since != null
        ? 'Since ${DateFormat('dd/MM/yyyy').format(since)}'
        : 'Since -';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 20),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: InkWell(
              onTap: () {
                widget.onCloseDrawer();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!widget.shellContext.mounted) return;
                  final hasToken = user != null && user['token'] != null;
                  if (hasToken) {
                    navigateMainRoute(widget.shellContext, '/profile');
                  } else {
                    Navigator.of(
                      widget.shellContext,
                    ).pushNamed(LoginPage.routeName);
                  }
                });
              },
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.surfaceCard,
                          border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.35),
                            width: 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          initial,
                          style: TextStyle(
                            color: AppColors.gold,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (user != null)
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: Colors.green.shade500,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          displayPhone,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          sinceText,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: widget.onCloseDrawer,
            style: IconButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
            icon: const Icon(Icons.close_rounded, size: 22),
          ),
        ],
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({required this.item, required this.onTap});

  final _DrawerItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isLogout = item.isLogout;
    final iconFg = isLogout ? AppColors.accentRose : AppColors.gold;
    final titleColor = isLogout ? AppColors.accentRose : AppColors.textPrimary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: AppColors.gold.withValues(alpha: 0.06),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: [
              Icon(item.icon, color: iconFg, size: 22),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.1,
                    color: titleColor,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.textSecondary.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
