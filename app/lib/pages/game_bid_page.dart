import 'package:flutter/material.dart';

import '../game_bid/betting_window_scope.dart';
import '../game_bid/screens/chart_game_bid_screen.dart';
import '../game_bid/screens/cp_common_bid_screen.dart';
import '../game_bid/screens/dp_motor_bid_screen.dart';
import '../game_bid/screens/dp_common_bid_screen.dart';
import '../game_bid/screens/double_pana_bid_screen.dart';
import '../game_bid/screens/double_pana_bulk_bid_screen.dart';
import '../game_bid/screens/full_sangam_bid_screen.dart';
import '../game_bid/screens/half_sangam_bid_screen.dart';
import '../game_bid/screens/jodi_bulk_bid_screen.dart';
import '../game_bid/screens/list_bid_screen.dart';
import '../game_bid/screens/odd_even_bid_screen.dart';
import '../game_bid/screens/single_digit_bid_screen.dart';
import '../game_bid/screens/single_digit_bulk_bid_screen.dart';
import '../game_bid/screens/single_pana_bid_screen.dart';
import '../game_bid/screens/single_pana_bulk_bid_screen.dart';
import '../game_bid/screens/sp_common_bid_screen.dart';
import '../game_bid/screens/sp_dp_motor_stub_screen.dart';
import '../game_bid/screens/sp_motor_bid_screen.dart';
import '../game_bid/screens/stub_bid_screen.dart';
import '../game_bid/screens/triple_pana_bid_screen.dart';
import '../theme/casino_ui.dart';

class GameBidArgs {
  const GameBidArgs({
    required this.market,
    required this.betType,
    required this.gameMode,
  });

  final Map<String, dynamic> market;
  final String betType;
  final String gameMode;
}

class GameBidPage extends StatelessWidget {
  const GameBidPage({super.key});

  static const routeName = '/game-bid';

  /// Normalizes labels from the grid / API so routing matches [switch] cases.
  static String normalizeBetTypeKey(String raw) {
    var s = raw.replaceAll('\u00a0', ' ').trim().toLowerCase();
    s = s.replaceAll(RegExp(r'[-_]+'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ');
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final raw = ModalRoute.of(context)?.settings.arguments;
    Map<String, dynamic>? market;
    String betType = '';
    String gameMode = 'easy';
    if (raw is GameBidArgs) {
      market = raw.market;
      betType = raw.betType;
      gameMode = raw.gameMode;
    } else if (raw is Map) {
      market = Map<String, dynamic>.from(raw);
      betType = (market['betType'] ?? '').toString();
    }

    if (market == null || betType.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).pushReplacementNamed('/');
      });
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Could not open this bet (missing market or type).\nReturning home…',
            textAlign: TextAlign.center,
            style: TextStyle(color: CasinoUi.mutedGold(0.88), fontSize: 14, height: 1.35),
          ),
        ),
      );
    }

    final key = normalizeBetTypeKey(betType);
    final child = _widgetFor(key, market, betType, gameMode);

    return BettingWindowScope(
      market: market,
      child: child,
    );
  }
}

Widget _widgetFor(
  String key,
  Map<String, dynamic> market,
  String title,
  String gameMode,
) {
  switch (key) {
    case 'single digit':
      return SingleDigitBidScreen(market: market, title: title);
    case 'single digit bulk':
      return SingleDigitBulkBidScreen(market: market, title: title);
    case 'odd even':
      return OddEvenBidScreen(market: market, title: title);
    case 'jodi':
      return ListBidScreen(
        market: market,
        title: title,
        apiBetType: 'jodi',
        maxLength: 2,
        validate: (s) => RegExp(r'^\d{2}$').hasMatch(s),
        specialKeys: List.generate(100, (i) => i.toString().padLeft(2, '0')),
        lockSessionOpen: true,
        useBulkSpecialUi: false,
        easyQuickPoints: true,
      );
    case 'single pana':
      return SinglePanaBidScreen(market: market, title: title);
    case 'double pana':
      return DoublePanaBidScreen(market: market, title: title);
    case 'triple pana':
      return TriplePanaBidScreen(market: market, title: title);
    case 'full sangam':
      return FullSangamBidScreen(market: market, title: title);
    case 'half sangam':
      return HalfSangamBidScreen(market: market, title: title);
    case 'sp motor':
      return SpMotorBidScreen(market: market, title: title);
    case 'dp motor':
      return DpMotorBidScreen(market: market, title: title);
    case 'sp dp motor':
      return SpDpMotorStubScreen(market: market, title: title);
    case 'sp dp t motor':
      return SpDpMotorStubScreen(
        market: market,
        title: title,
        includeTripleCombinations: true,
      );
    case 'sp common':
      return SpCommonBidScreen(market: market, title: title);
    case 'cp':
    case 'cp (common pana)':
      return CpCommonBidScreen(market: market, title: title);
    case 'dp common':
      return DpCommonBidScreen(market: market, title: title);
    case 'chart':
    case 'chart game':
      return ChartGameBidScreen(market: market, title: title);
    case 'jodi bulk':
      return JodiBulkBidScreen(market: market, title: title);
    case 'single pana bulk':
      return SinglePanaBulkBidScreen(market: market, title: title);
    case 'double pana bulk':
      return DoublePanaBulkBidScreen(market: market, title: title);
    default:
      return StubBidScreen(market: market, title: title, message: 'This bet type is not available yet.');
  }
}
