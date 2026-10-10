import 'package:cybersafe/lang.dart';
import 'package:cybersafe/screens/tools/sim_swap_screen.dart';
import 'package:cybersafe/services/scanners.dart';
import 'package:cybersafe/services/sim_swap_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

TelcoSimSwapResult _result(Map<String, dynamic> m) =>
    TelcoSimSwapResult.fromJson(m);

void main() {
  test('client-side E.164 validation', () {
    expect(isValidE164Phone('+919876543210'), isTrue);
    expect(isValidE164Phone('  +346661113334  '), isTrue);
    expect(isValidE164Phone('9876543210'), isFalse);
    expect(isValidE164Phone('+91 98765 43210'), isFalse);
    expect(isValidE164Phone(''), isFalse);
  });

  test('telco result parses all fields', () {
    final r = _result({
      'status': 'completed',
      'provider': 'mock',
      'lookbackHours': 72,
      'simSwapDetected': true,
      'lastSwapAt': null,
      'riskSignal': 'recent_sim_change',
      'maskedPhone': '+34******0000',
      'detail': 'SIM swap reported within the last 72h.',
    });
    expect(r.status, 'completed');
    expect(r.detected, isTrue);
    expect(r.lookbackHours, 72);
    expect(r.maskedPhone, '+34******0000');

    final unknown = _result({'status': 'unknown'});
    expect(unknown.detected, isNull);
    expect(unknown.riskSignal, 'check_unavailable');
    expect(unknown.maskedPhone, '?');
  });

  test('mapper: recent=75, calm=10, unavailable=0 without gauge scare', () {
    final recent = telcoSimSwapFinding(_result({
      'status': 'completed',
      'provider': 'mock',
      'riskSignal': 'recent_sim_change',
      'maskedPhone': '+34******0000',
      'detail': 'SIM swap reported within the last 72h.',
      'lastSwapAt': '2026-10-09T10:00:00Z',
    }));
    expect(recent.risk, 75);
    expect(recent.reasons.any((s) => s.contains('Last change')), isTrue);

    final calm = telcoSimSwapFinding(_result({
      'status': 'completed',
      'provider': 'mock',
      'riskSignal': 'no_recent_change',
      'maskedPhone': '+34******3334',
      'detail': 'No SIM swap reported.',
    }));
    expect(calm.risk, 10);

    final off = telcoSimSwapFinding(_result({'status': 'unknown'}));
    expect(off.risk, 0);
    expect(off.reasons.join(' '), contains('unavailable'));
  });

  testWidgets('SIM tab shows telco card above the checklist',
      (WidgetTester t) async {
    await t.pumpWidget(LangScope(
      lang: AppLang.english,
      onLang: (_) {},
      child: const MaterialApp(home: SimSwapScreen()),
    ));
    await t.pump();
    expect(find.text('Network check (telco)'), findsOneWidget);
    expect(find.text('Check network'), findsOneWidget);
    expect(find.text('Last change?'), findsOneWidget);
    // Questionnaire intact below.
    expect(find.byType(Switch), findsNWidgets(5));
    await t.dragUntilVisible(
      find.text('Check now'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    expect(find.text('Check now'), findsOneWidget);
  });
}
