import 'package:flutter/material.dart';

/// Pushes a main [MainShell] route while keeping [Navigator] history so the
/// system back gesture returns to the previous screen instead of exiting.
///
/// The first route (typically `/`) stays at the bottom of the stack; tab
/// switches pop back to it then push the new shell route.
void navigateMainRoute(
  BuildContext context,
  String routeName, {
  Object? arguments,
}) {
  final nav = Navigator.of(context);

  if (routeName == '/') {
    nav.popUntil((route) => route.isFirst);
    return;
  }

  nav.pushNamedAndRemoveUntil(
    routeName,
    (route) => route.isFirst,
    arguments: arguments,
  );
}
