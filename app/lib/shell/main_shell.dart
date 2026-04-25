import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_header.dart';
import '../widgets/home_casino_backdrop.dart';

/// Routes that share the home-style casino backdrop + light status bar.
bool shellUsesCasinoStyle(String path) {
  return path == '/' ||
      path == '/bids' ||
      path == '/bet-history' ||
      path == '/game-bet-history' ||
      path == '/market-result-history' ||
      path == '/games' ||
      path == '/bank' ||
      path == '/funds' ||
      path == '/passbook' ||
      path == '/game-rate' ||
      path == '/support' ||
      path == '/support/new' ||
      path == '/support/status' ||
      path == '/profile' ||
      path == '/top-winners' ||
      path == '/bidoptions';
}

/// Bottom bar only on primary tabs (not sub-pages like profile or support/new).
bool shellShowsMobileBottomNav(String path) {
  return path == '/' ||
      path == '/bids' ||
      path == '/bet-history' ||
      path == '/game-bet-history' ||
      path == '/market-result-history' ||
      path == '/games' ||
      path == '/funds' ||
      path == '/support';
}

/// App chrome matching [AppHeader] + [BottomNavbar] from the React app.
class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.path, required this.child});

  final String path;
  final Widget child;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  DateTime? _lastBackToExit;

  void _onRootBackAttempt(BuildContext context) {
    final now = DateTime.now();
    if (_lastBackToExit == null ||
        now.difference(_lastBackToExit!) > const Duration(seconds: 2)) {
      _lastBackToExit = now;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Press back again to exit'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final showTopNav = widget.path == '/';
    final fullScreenContent =
        widget.path == '/lottery' ||
        widget.path == '/lottery/quiz' ||
        widget.path == '/lottery/3d' ||
        widget.path.startsWith('/lottery/3d/');
    final casinoShell = shellUsesCasinoStyle(widget.path);
    final showBottomNav = width < 768 && shellShowsMobileBottomNav(widget.path);
    final canPopNavigator = Navigator.of(context).canPop();

    return PopScope(
      canPop: canPopNavigator,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        if (context.mounted) _onRootBackAttempt(context);
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: casinoShell
            ? AppColors.surface
            : Theme.of(context).colorScheme.surface,
        drawer: showTopNav ? AppDrawer(shellContext: context) : null,
        body: _HomeBody(
          shellContext: context,
          useCasinoBackdrop: casinoShell,
          showTopNav: showTopNav,
          fullScreenContent: fullScreenContent,
          scaffoldKey: _scaffoldKey,
          child: widget.child,
        ),
        bottomNavigationBar: showBottomNav
            ? AppBottomNav(
                shellContext: context,
                currentPath: widget.path,
                casinoHomeStyle: casinoShell,
              )
            : null,
      ),
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody({
    required this.shellContext,
    required this.useCasinoBackdrop,
    required this.showTopNav,
    required this.fullScreenContent,
    required this.scaffoldKey,
    required this.child,
  });

  final BuildContext shellContext;
  final bool useCasinoBackdrop;
  final bool showTopNav;
  final bool fullScreenContent;
  final GlobalKey<ScaffoldState> scaffoldKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final content = SafeArea(
      top: !fullScreenContent,
      bottom: false,
      child: Column(
        children: [
          if (showTopNav)
            AppHeader(
              shellContext: shellContext,
              casinoHomeStyle: useCasinoBackdrop,
              onOpenMenu: () => scaffoldKey.currentState?.openDrawer(),
            ),
          Expanded(child: child),
        ],
      ),
    );

    if (!useCasinoBackdrop) return content;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.surface,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [const HomeCasinoBackdrop(), content],
      ),
    );
  }
}
