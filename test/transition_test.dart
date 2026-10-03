import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kavach/main.dart';

void main() {
  testWidgets('tab transitions during a live session do not throw',
      (WidgetTester tester) async {
    await tester.pumpWidget(const KavachApp());

    // Start the scam demo from Home.
    await tester.tap(find.text('Protect this call'));
    await tester.pump();

    // Let the script play through several lines.
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(seconds: 1));
    }

    // Hop between tabs while the session is live/finished.
    await tester.tap(find.byIcon(Icons.family_restroom_outlined));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.summarize_outlined));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.phone_in_talk_outlined));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.shield_outlined));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
