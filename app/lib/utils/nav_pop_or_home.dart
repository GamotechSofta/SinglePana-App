import 'package:flutter/material.dart';

/// Pops if possible; otherwise returns to the root route (home) without wiping history.
void popOrGoHome(BuildContext context) {
  final nav = Navigator.of(context);
  if (nav.canPop()) {
    nav.pop();
  } else {
    nav.popUntil((route) => route.isFirst);
  }
}
