import 'package:flutter_test/flutter_test.dart';

import 'package:kavach/main.dart';

void main() {
  testWidgets('Kavach home smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const KavachApp());

    expect(find.text('KAVACH'), findsOneWidget);
    expect(find.text('Protect this call'), findsOneWidget);
  });
}
