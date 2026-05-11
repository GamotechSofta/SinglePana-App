import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Mirrors [offlineGame2/frontend/src/pages/Login.jsx] `getBrowserDeviceName` for the `deviceName` login field.
String getLoginDeviceName() {
  if (kIsWeb) {
    return 'Flutter Web';
  }
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'Android (Flutter)',
    TargetPlatform.iOS => 'iOS (Flutter)',
    TargetPlatform.macOS => 'macOS (Flutter)',
    TargetPlatform.windows => 'Windows (Flutter)',
    TargetPlatform.linux => 'Linux (Flutter)',
    TargetPlatform.fuchsia => 'Flutter App',
  };
}
