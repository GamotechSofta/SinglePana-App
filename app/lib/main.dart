import 'dart:async';

import 'package:flutter/material.dart';

import 'pages/bid_options_page.dart';
import 'pages/game_bid_page.dart';
import 'pages/games_page.dart';
import 'pages/game_rate_page.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'pages/history/bet_history_screen.dart';
import 'pages/history/market_results_screen.dart';
import 'pages/history/my_bets_page.dart';
import 'pages/lottery_page.dart';
import 'pages/lottery_3d_page.dart';
import 'pages/lottery_3d_account_page.dart';
import 'pages/lottery_3d_subpages.dart';
import 'pages/lottery_old_results_page.dart';
import 'pages/lottery_quiz_page.dart';
import 'pages/my_bets_2d_lottery_page.dart';
import 'pages/support/support_landing_page.dart';
import 'pages/support/support_new_page.dart';
import 'pages/support/support_status_page.dart';
import 'pages/profile_page.dart';
import 'pages/top_winners_page.dart';
import 'pages/signup_page.dart';
import 'pages/wallet/bank_transactions_page.dart';
import 'pages/wallet/funds_page.dart';
import 'pages/wallet/passbook_page.dart';
import 'services/auth_service.dart';
import 'services/session_coordinator.dart';
import 'services/wallet_service.dart';
import 'shell/main_shell.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SinglePanaApp());
}

class SinglePanaApp extends StatefulWidget {
  const SinglePanaApp({super.key});

  @override
  State<SinglePanaApp> createState() => _SinglePanaAppState();
}

class _SinglePanaAppState extends State<SinglePanaApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_onAppResumed());
    }
  }

  Future<void> _onAppResumed() async {
    if (!await AuthService.instance.hasValidSession()) return;
    await SessionCoordinator.instance.sendHeartbeat();
    await WalletService.instance.refreshBalanceInStorage();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: SessionCoordinator.instance.navigatorKey,
      title: 'Shri Balaji',
      theme: buildAppTheme(),
      // Cannot set [home] and also register `/` in [routes] — use initialRoute for splash.
      initialRoute: '/splash',
      routes: {
        '/splash': (_) => const _SplashScreen(),
        '/': (_) => const MainShell(
              path: '/',
              child: HomePage(),
            ),
        '/bids': (_) => const MainShell(
              path: '/bids',
              child: MyBetsPage(),
            ),
        '/bet-history': (_) => const MainShell(
              path: '/bet-history',
              child: BetHistoryScreen(),
            ),
        '/game-bet-history': (_) => const MainShell(
              path: '/game-bet-history',
              child: GameBetHistoryScreen(),
            ),
        '/market-result-history': (_) => const MainShell(
              path: '/market-result-history',
              child: MarketResultHistoryScreen(),
            ),
        '/games': (_) => const MainShell(
              path: '/games',
              child: GamesPage(),
            ),
        '/lottery': (_) => const MainShell(
              path: '/lottery',
              child: LotteryPage(),
            ),
        '/lottery/quiz': (_) => const MainShell(
              path: '/lottery/quiz',
              child: LotteryQuizPage(),
            ),
        '/lottery/3d': (_) => const MainShell(
              path: '/lottery/3d',
              child: Lottery3DPage(),
            ),
        '/lottery/3d/result': (_) => const MainShell(
              path: '/lottery/3d/result',
              child: Lottery3DResultPage(),
            ),
        '/lottery/3d/account': (_) => MainShell(
              path: '/lottery/3d/account',
              child: const Lottery3DAccountPage(),
            ),
        '/lottery/3d/quiz': (_) => const MainShell(
              path: '/lottery/3d/quiz',
              child: Lottery3DQuizPage(),
            ),
        '/lottery/3d/ticket-list': (_) => const MainShell(
              path: '/lottery/3d/ticket-list',
              child: Lottery3DTicketListPage(),
            ),
        '/lottery/3d/history': (_) => const MainShell(
              path: '/lottery/3d/history',
              child: Lottery3DHistoryPage(),
            ),
        '/lottery/my-bets-2d': (_) => const MainShell(
              path: '/lottery/my-bets-2d',
              child: MyBets2DLotteryPage(),
            ),
        '/lottery/old-results': (_) => const LotteryOldResultsPage(),
        '/bank': (_) => const MainShell(
              path: '/bank',
              child: BankTransactionsPage(),
            ),
        '/funds': (_) => const MainShell(
              path: '/funds',
              child: FundsPage(),
            ),
        '/passbook': (_) => const MainShell(
              path: '/passbook',
              child: PassbookPage(),
            ),
        '/game-rate': (_) => const MainShell(
              path: '/game-rate',
              child: GameRatePage(),
            ),
        '/support': (_) => const MainShell(
              path: '/support',
              child: SupportLandingPage(),
            ),
        '/support/new': (_) => const MainShell(
              path: '/support/new',
              child: SupportNewPage(),
            ),
        '/support/status': (_) => const MainShell(
              path: '/support/status',
              child: SupportStatusPage(),
            ),
        '/profile': (_) => const MainShell(
              path: '/profile',
              child: ProfilePage(),
            ),
        '/top-winners': (_) => const MainShell(
              path: '/top-winners',
              child: TopWinnersPage(),
            ),
        '/bidoptions': (_) => const MainShell(
              path: '/bidoptions',
              child: BidOptionsPage(),
            ),
        GameBidPage.routeName: (_) => const MainShell(
              path: '/bidoptions',
              child: GameBidPage(),
            ),
        LoginPage.routeName: (_) => const LoginPage(),
        SignupPage.routeName: (_) => const SignupPage(),
      },
    );
  }
}

class _SplashScreen extends StatefulWidget {
  const _SplashScreen();

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    final ok = await AuthService.instance.hasValidSession();
    if (!mounted) return;
    final next = ok ? '/' : LoginPage.routeName;
    await Navigator.of(context).pushReplacementNamed(next);
    if (ok) {
      SessionCoordinator.instance.startHeartbeatIfLoggedIn();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: Center(
        child: CircularProgressIndicator(color: scheme.primary),
      ),
    );
  }
}
