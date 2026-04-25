import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/pages/login_page.dart';

void main() {
  testWidgets('Login page builds', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));
    expect(find.text('Welcome Back'), findsOneWidget);
  });
}
