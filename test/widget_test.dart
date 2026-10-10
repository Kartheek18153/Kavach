import 'package:flutter_test/flutter_test.dart';

import 'package:cybersafe/main.dart';

void main() {
  testWidgets('CyberSafe home smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const CyberSafeApp());

    expect(find.text('CYBERSAFE'), findsOneWidget);
    expect(find.text('Protect this call'), findsOneWidget);
  });
}
