import 'package:flutter/material.dart';

import '../utils/market_timing.dart' show BettingWindowResult, isBettingAllowed;

/// Same data as React [BettingWindowContext].
class BettingWindowScope extends InheritedWidget {
  const BettingWindowScope({
    super.key,
    required this.market,
    required super.child,
  });

  final Map<String, dynamic> market;

  static BettingWindowResult of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<BettingWindowScope>();
    final m = scope?.market;
    if (m == null) {
      return const BettingWindowResult(allowed: true, closeOnly: false, message: null);
    }
    final st = (m['startingTime'] ?? '').toString().trim();
    final ct = (m['closingTime'] ?? '').toString().trim();
    if (st.isEmpty || ct.isEmpty) {
      return const BettingWindowResult(allowed: true, closeOnly: false, message: null);
    }
    return isBettingAllowed(m);
  }

  @override
  bool updateShouldNotify(BettingWindowScope oldWidget) =>
      oldWidget.market != market;
}
