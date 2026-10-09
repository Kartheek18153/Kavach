import 'package:flutter_test/flutter_test.dart';

import 'package:kavach/services/scanners.dart';

void main() {
  group('URL scanner', () {
    test('clean https link stays safe', () {
      final f = scoreUrl('https://www.rbi.org.in/commonman/english/');
      expect(f.risk, lessThanOrEqualTo(30));
    });

    test('http + login lure raises risk', () {
      final f = scoreUrl('http://secure-login-verify.tk/account/login');
      expect(f.risk, greaterThanOrEqualTo(31));
      expect(f.reasons, isNotEmpty);
    });

    test('apk download is danger', () {
      final f = scoreUrl('https://free-prize-xyz.top/app.apk');
      expect(f.risk, greaterThanOrEqualTo(61));
    });

    test('shortened link flagged', () {
      final f = scoreUrl('https://bit.ly/3xKycVerify');
      expect(f.reasons.any((r) => r.contains('Shortened')), isTrue);
    });

    test('garbage input scores mid, not crash', () {
      final f = scoreUrl('not a link at all!!!');
      expect(f.risk, greaterThanOrEqualTo(31));
    });
  });

  group('SMS analyzer', () {
    test('kyc block sms is flagged', () {
      final f = scoreSms(
          'Dear Customer your SBI KYC is blocked, verify immediately at http://sbi-kyc-update.tk/login or account suspended');
      expect(f.risk, greaterThanOrEqualTo(31));
    });

    test('otp ask plus link sms is danger', () {
      final f = scoreSms(
          'Your SBI account will be blocked today. Share your OTP now at http://sbi-kyc.tk/verify to unblock');
      expect(f.risk, greaterThanOrEqualTo(61));
    });

    test('family message stays safe', () {
      final f = scoreSms('Amma, I reached home safely. Will call in the evening.');
      expect(f.risk, lessThanOrEqualTo(30));
    });

    test('embedded bad link raises score', () {
      final clean = scoreSms('Your OTP is 482913. Do not share.');
      final withLink = scoreSms(
          'Your OTP is 482913. Verify at http://otp-verify-login.tk now');
      expect(withLink.risk, greaterThan(clean.risk));
    });
  });

  group('QR+UPI unified routing', () {
    test('upi intent detected as upi', () {
      expect(detectQrUpiKind('upi://pay?pa=x@okhdfc&am=100'), 'upi');
      final r = scoreQrUpi('upi://pay?pa=x@okhdfc&am=100');
      expect(r.kind, 'upi');
      expect(r.finding.risk, greaterThanOrEqualTo(0));
    });

    test('bare vpa detected as upi', () {
      expect(detectQrUpiKind('ravi.kumar@okhdfcbank'), 'upi');
      final r = scoreQrUpi('ravi.kumar@okhdfcbank');
      expect(r.kind, 'upi');
      expect(r.finding.risk, lessThanOrEqualTo(30));
    });

    test('link and wifi detected as qr', () {
      expect(detectQrUpiKind('https://example.com/pay'), 'qr');
      expect(detectQrUpiKind('WIFI:T:WPA;S:Home;P:x;;'), 'qr');
    });
  });

  group('QR scanner', () {
    test('upi intent routed to upi checks', () {
      final f = scoreQrContent('upi://pay?pa=scammer@okhdfc&pn=X&am=5000&cu=INR');
      expect(f.risk, greaterThanOrEqualTo(31));
    });

    test('apk qr is danger', () {
      final f = scoreQrContent('https://evil.top/payload.apk');
      expect(f.risk, greaterThanOrEqualTo(61));
    });

    test('wifi qr is low risk', () {
      final f = scoreQrContent('WIFI:T:WPA;S:HomeNet;P:secret;;');
      expect(f.risk, lessThanOrEqualTo(30));
    });
  });

  group('UPI checker', () {
    test('valid vpa is safe', () {
      final f = scoreUpi('ravi.kumar@okhdfcbank');
      expect(f.risk, lessThanOrEqualTo(30));
    });

    test('malformed vpa flagged', () {
      final f = scoreUpi('not-a-upi');
      expect(f.risk, greaterThanOrEqualTo(31));
    });

    test('collect request with amount is caution+', () {
      final f = scoreUpi('upi://pay?pa=9876543210@okaxis&pn=&am=25000&cu=INR');
      expect(f.risk, greaterThanOrEqualTo(31));
    });

    test('bait handle flagged', () {
      final f = scoreUpi('rbi-cashback-offer@okpay');
      expect(f.risk, greaterThanOrEqualTo(31));
    });
  });

  group('SIM-swap checklist', () {
    test('all clear is safe', () {
      final f = scoreSimSwap([false, false, false, false, false]);
      expect(f.risk, 0);
    });

    test('three signs is danger', () {
      final f = scoreSimSwap([true, true, true, false, false]);
      expect(f.risk, greaterThanOrEqualTo(61));
    });
  });
}
