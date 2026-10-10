import 'package:cybersafe/lang.dart';
import 'package:cybersafe/screens/tools/sms_analyzer_screen.dart';
import 'package:cybersafe/services/agnes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('explain prompt is grounded in signals + language', () {
    final p = buildExplainPrompt(
      families: {'CREDENTIAL_EXTRACTION', 'AUTHORITY_IMPERSONATION'},
      evidence: {
        'CREDENTIAL_EXTRACTION': ['otp batao'],
        'AUTHORITY_IMPERSONATION': ['cbi']
      },
      risk: 75,
      band: 'danger',
      scamType: 'Bank / OTP fraud',
      lang: 'te',
    );
    expect(p['system']!, contains('Telugu'));
    expect(p['system']!, contains('ONLY'));
    expect(p['user']!, contains('otp batao'));
    expect(p['user']!, contains('cbi'));
    expect(p['user']!, contains('75/100'));
  });

  test('advice prompt caps steps + always includes 1930', () {
    final p = buildAdvicePrompt(
      families: {'REMOTE_ACCESS_AND_TRANSFER'},
      risk: 80,
      band: 'danger',
      lang: 'hi',
    );
    expect(p['system']!, contains('Hindi'));
    expect(p['system']!, contains('1930'));
    expect(p['user']!, contains('REMOTE_ACCESS_AND_TRANSFER'));
  });

  test('sms prompt forces a FRAUD/SCAM/SAFE verdict', () {
    final p = buildSmsPrompt(
      message: 'Your account blocked. Share OTP at http://x.tk now',
      risk: 70,
      band: 'danger',
      signals: const ['Asks for an OTP / PIN outright.'],
      lang: 'hi',
    );
    expect(p['system']!, contains('FRAUD'));
    expect(p['system']!, contains('SCAM'));
    expect(p['system']!, contains('SAFE'));
    expect(p['system']!, contains('Hindi'));
    expect(p['user']!, contains('70/100'));
    expect(p['user']!, contains('http://x.tk'));
  });

  test('sms prompt truncates very long messages', () {
    final long = List.filled(2000, 'x').join();
    final p = buildSmsPrompt(
      message: long,
      risk: 10,
      band: 'safe',
      signals: const [],
      lang: 'en',
    );
    expect(p['user']!.length, lessThan(long.length));
  });

  test('analyzeSms returns null without key (fail-soft)', () async {
    expect(AgnesConfig.isConfigured, isFalse);
    expect(
      await AgnesClient.analyzeSms(
        message: 'hello',
        risk: 0,
        band: 'safe',
        signals: const [],
        lang: 'en',
      ),
      isNull,
    );
  });

  testWidgets('sms screen renders with AI verdict slot', (t) async {
    await t.pumpWidget(LangScope(
      lang: AppLang.english,
      onLang: (_) {},
      child: const MaterialApp(home: SmsAnalyzerScreen()),
    ));
    await t.pump();
    expect(find.text('Check now'), findsOneWidget);
  });

  test('parseChatText extracts content, null-safe on bad shapes', () {
    expect(
      parseChatText({
        'choices': [
          {
            'message': {'content': '  hello  '}
          }
        ]
      }),
      'hello',
    );
    expect(parseChatText({'choices': []}), isNull);
    expect(parseChatText({}), isNull);
    expect(
      parseChatText({
        'choices': [
          {
            'message': {'content': '   '}
          }
        ]
      }),
      isNull,
    );
    expect(parseChatText({'choices': 'x'}), isNull);
  });

  test('client returns null without key (fail-soft, no network)', () async {
    // Tests run without --dart-define, so no key is configured.
    expect(AgnesConfig.isConfigured, isFalse);
    expect(
      await AgnesClient.explain(
        families: {'CREDENTIAL_EXTRACTION'},
        evidence: {
          'CREDENTIAL_EXTRACTION': ['otp']
        },
        risk: 70,
        band: 'danger',
        scamType: 'Bank / OTP fraud',
        lang: 'en',
      ),
      isNull,
    );
    expect(
      await AgnesClient.advise(
        families: {},
        risk: 0,
        band: 'safe',
        lang: 'en',
      ),
      isNull,
    );
  });

  test('consent defaults off and persists', () async {
    SharedPreferences.setMockInitialValues({});
    await AgnesConsent.load();
    expect(AgnesConsent.isOn, isFalse);
    await AgnesConsent.set(true);
    expect(AgnesConsent.isOn, isTrue);
    await AgnesConsent.set(false);
    expect(AgnesConsent.isOn, isFalse);
  });
}
