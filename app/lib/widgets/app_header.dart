import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../pages/login_page.dart';
import '../services/auth_service.dart';
import '../services/wallet_service.dart';
import '../theme/app_colors.dart';
import '../utils/nav_main_route.dart';
import 'app_nav_metrics.dart';

class AppHeader extends StatefulWidget implements PreferredSizeWidget {
  const AppHeader({
    super.key,
    required this.onOpenMenu,
    required this.shellContext,
    this.casinoHomeStyle = false,
  });

  final VoidCallback onOpenMenu;
  final BuildContext shellContext;

  /// Minimal bar on [HomeCasinoBackdrop].
  final bool casinoHomeStyle;

  @override
  Size get preferredSize =>
      const Size.fromHeight(AppNavMetrics.headerBodyHeight);

  @override
  State<AppHeader> createState() => _AppHeaderState();
}

class _AppHeaderState extends State<AppHeader> with WidgetsBindingObserver {
  double _balance = 0;
  Map<String, dynamic>? _user;
  Timer? _balanceTicker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadFromStorage();
    WalletService.instance.refreshBalanceInStorage().then((_) {
      if (mounted) _loadFromStorage();
    });
    _balanceTicker = Timer.periodic(const Duration(seconds: 30), (_) {
      WalletService.instance.refreshBalanceInStorage().then((_) {
        if (mounted) _loadFromStorage();
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _balanceTicker?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadFromStorage();
      WalletService.instance.refreshBalanceInStorage().then((_) {
        if (mounted) _loadFromStorage();
      });
    }
  }

  Future<void> _loadFromStorage() async {
    final u = await AuthService.instance.getStoredUser();
    if (!mounted) return;
    final b = u?['balance'] ?? u?['walletBalance'] ?? u?['wallet'] ?? 0;
    setState(() {
      _user = u;
      _balance = (b is num) ? b.toDouble() : double.tryParse(b.toString()) ?? 0;
    });
  }

  String get _formattedBalance {
    final fmt = NumberFormat('#,##0', 'en_IN');
    return fmt.format(_balance.round());
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final hasUser = user != null && user['token'] != null;
    final scheme = Theme.of(context).colorScheme;
    final lux = widget.casinoHomeStyle;
    final onBar = lux ? AppColors.textPrimary : scheme.onSurface;
    final muted = lux ? AppColors.textSecondary : scheme.onSurfaceVariant;
    final hairline = lux
        ? Colors.white.withValues(alpha: 0.08)
        : scheme.outlineVariant.withValues(alpha: 0.6);

    return Material(
      color: lux ? Colors.transparent : scheme.surfaceContainer,
      elevation: 0,
      child: SafeArea(
        bottom: false,
        child: Container(
          decoration: BoxDecoration(
            color: lux ? Colors.transparent : scheme.surfaceContainer,
            border: Border(bottom: BorderSide(color: hairline, width: 1)),
          ),
          padding: const EdgeInsets.fromLTRB(
            AppNavMetrics.horizontalPadding,
            AppNavMetrics.headerVerticalPadding,
            AppNavMetrics.horizontalPadding,
            AppNavMetrics.headerVerticalPadding,
          ),
          child: SizedBox(
            height: AppNavMetrics.headerInnerHeight,
            child: Row(
              children: [
                IconButton(
                  onPressed: widget.onOpenMenu,
                  style: IconButton.styleFrom(
                    foregroundColor: onBar,
                    minimumSize: const Size(36, 36),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: Icon(
                    Icons.menu_rounded,
                    size: 24,
                    color: onBar,
                  ),
                ),
                const Spacer(),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      navigateMainRoute(
                        widget.shellContext,
                        '/funds',
                        arguments: {'tab': 'add-fund'},
                      );
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.account_balance_wallet_outlined,
                            size: 20,
                            color: lux ? AppColors.gold : scheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '₹$_formattedBalance',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                              color: lux ? AppColors.goldMuted : scheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () {
                    if (hasUser) {
                      navigateMainRoute(widget.shellContext, '/profile');
                    } else {
                      Navigator.of(widget.shellContext).pushNamed(LoginPage.routeName);
                    }
                  },
                  style: IconButton.styleFrom(
                    foregroundColor: hasUser ? onBar : muted,
                    minimumSize: const Size(36, 36),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: Icon(
                    Icons.person_outline_rounded,
                    size: 24,
                    color: hasUser ? onBar : muted,
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
