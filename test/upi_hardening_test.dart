import 'package:cybersafe/lang.dart';
import 'package:cybersafe/screens/tools/qr_upi_screen.dart';
import 'package:cybersafe/services/scanners.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ported rule coverage from the hackathon2026 QR + UPI engine:
/// blocklist, impersonation, typosquat, random handles, reverse-collect,
/// mandate hijack, tamper guards. Bands stay this app's 31/61.
void main() {
  test('known suspect VPA is danger with 1930 guidance', () {
    final f = scoreUpi('refund-officer@ybl');
    expect(f.risk, greaterThanOrEqualTo(61));
    expect(f.reasons.join(' '), contains('1930'));
  });

  test('known suspect phone digits flagged', () {
    final f = scoreUpi('9123456780@okaxis');
    expect(f.risk, greaterThanOrEqualTo(61));
  });

  test('typosquat brand mimic flagged', () {
    final f = scoreUpi('paytmm-care@okhdfcbank');
    expect(f.risk, greaterThanOrEqualTo(31));
    expect(f.reasons.join(' '), contains('mimics'));
  });

  test('impersonation keyword on personal handle', () {
    final f = scoreUpi('kyc-refund@ybl');
    expect(f.risk, greaterThanOrEqualTo(31));
    expect(f.reasons.join(' '), contains('authority keyword'));
  });

  test('random-looking handle is caution+', () {
    final f = scoreUpi('jsfkjshfk124@oksbi');
    expect(f.risk, greaterThanOrEqualTo(31));
    expect(f.reasons.join(' '), contains('auto-generated'));
  });

  test('reverse-collect only fires when receiving', () {
    const link = 'upi://pay?pa=shop@ybl&am=1000';
    final receiving =
        scoreUpi(link, expectsIncoming: true);
    expect(receiving.risk, greaterThanOrEqualTo(31));
    expect(receiving.reasons.join(' '), contains('RECEIVE'));
    final paying = scoreUpi(link);
    expect(paying.risk, lessThan(receiving.risk));
    expect(paying.reasons.join(' '), isNot(contains('RECEIVE')));
  });

  test('mandate hijack floors to danger', () {
    final f = scoreUpi(
        'upi://mandate?pa=victim99@ybl&pn=Support+Desk&am=5000&cu=INR&recurrence=monthly&validitystart=01012026&validityend=01012027');
    expect(f.risk, greaterThanOrEqualTo(61));
    expect(f.reasons.join(' '), contains('recurring'));
  });

  test('registered recurring mandate is not a hijack', () {
    final f = scoreUpi(
        'upi://mandate?pa=shop@ybl&mc=5411&recurrence=monthly');
    expect(f.risk, lessThan(61));
    expect(f.reasons.join(' '), contains('MCC 5411'));
  });

  test('duplicate critical params flagged', () {
    final f = scoreUpi('upi://pay?pa=a@ybl&pa=b@ybl&am=10');
    expect(f.risk, greaterThanOrEqualTo(31));
    expect(f.reasons.join(' '), contains('repeats critical'));
  });

  test('zero-width poisoned VPA flagged', () {
    final zw = String.fromCharCode(0x200b);
    final f = scoreUpi('upi://pay?pa=abc$zw@ybl&am=10');
    expect(f.risk, greaterThanOrEqualTo(31));
    expect(f.reasons.join(' '), contains('zero-width'));
  });

  test('tampered currency tag flagged', () {
    final f = scoreUpi('upi://pay?pa=shop@ybl&am=10&cu=USDD');
    expect(f.risk, greaterThanOrEqualTo(31));
    expect(f.reasons.join(' '), contains('Currency'));
  });

  test('high-value unverified P2P flagged', () {
    final f = scoreUpi('upi://pay?pa=shop@paytm&am=30000');
    expect(f.risk, greaterThanOrEqualTo(31));
  });

  test('corporate-claim name without MCC flagged', () {
    final f =
        scoreUpi('upi://pay?pa=x@ybl&pn=Electricity Board&am=500');
    expect(f.risk, greaterThanOrEqualTo(31));
  });

  test('prize wording inside PAY link flagged', () {
    final f = scoreUpi(
        'upi://pay?pa=x@ybl&am=4999&tn=cashback+credit+claim');
    expect(f.risk, greaterThanOrEqualTo(31));
  });

  test('clean trusted VPA stays silent', () {
    final f = scoreUpi('friend.123@okhdfcbank');
    expect(f.risk, 0);
  });

  testWidgets('QR tab offers Scan + Gallery without opening camera',
      (WidgetTester t) async {
    await t.pumpWidget(LangScope(
      lang: AppLang.english,
      onLang: (_) {},
      child: const MaterialApp(home: QrUpiScreen()),
    ));
    await t.pump();
    expect(find.text('Scan QR'), findsOneWidget);
    expect(find.text('Gallery'), findsOneWidget);
    expect(find.text('I’m paying'), findsOneWidget);
    expect(find.text('I’m receiving'), findsOneWidget);
  });
}
