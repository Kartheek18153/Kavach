import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cybersafe/lang.dart';
import 'package:cybersafe/screens/history_screen.dart';
import 'package:cybersafe/screens/safety_screen.dart';
import 'package:cybersafe/screens/settings_screen.dart';
import 'package:cybersafe/screens/threats_screen.dart';
import 'package:cybersafe/screens/tools/url_scanner_screen.dart';

/// Regression test: every pushed page must render inside the app's
/// language scope. Pushed routes live above the home tree, so a scope
/// placed under MaterialApp leaves them with no strings (blank pages).
Future<void> _pumpPage(WidgetTester t, Widget page) async {
  await t.pumpWidget(LangScope(
    lang: AppLang.english,
    onLang: (_) {},
    child: MaterialApp(home: page),
  ));
  await t.pump();
}

void main() {
  testWidgets('settings page renders all sections', (t) async {
    await _pumpPage(t, const SettingsScreen());
    expect(find.text('Settings & privacy'), findsOneWidget);
    expect(find.text('VOICE CHECK'), findsOneWidget);
    expect(find.text('YOUR PRIVACY'), findsOneWidget);
    expect(find.text('YOUR DATA'), findsOneWidget);
    await t.dragUntilVisible(
      find.text('ABOUT CYBERSAFE'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    expect(find.text('ABOUT CYBERSAFE'), findsOneWidget);
  });

  testWidgets('tool screen renders', (t) async {
    await _pumpPage(t, const UrlScannerScreen());
    expect(find.text('Link scanner'), findsWidgets);
    expect(find.text('Check now'), findsOneWidget);
  });

  testWidgets('threats, history and safety render', (t) async {
    await _pumpPage(t, const ThreatsScreen());
    expect(find.text('Threats'), findsOneWidget);
    await _pumpPage(t, const HistoryScreen());
    expect(find.text('History'), findsOneWidget);
    await _pumpPage(t, SafetyScreen(onSetupFamily: () {}));
    expect(find.text('Safety guide'), findsOneWidget);
  });
}
