import 'package:cybersafe/services/scanners.dart';
import 'package:flutter_test/flutter_test.dart';

/// Real-world smishing shapes (India 2024-26 campaigns: KYC, power,
/// parcel, prize, job, friend-emergency, APK, TRAI) vs legitimate mail.
/// Bands: Safe 0-30 / Caution 31-60 / Danger 61+.
void main() {
  group('smishing corpus: caught', () {
    test('KYC deactivation + link is danger', () {
      final f = scoreSms(
          'Dear Customer, Your SBI YONO account will be deactivated today due to KYC expiry. Update KYC now to continue: http://sbi-yono-kyc.example/update');
      expect(f.risk, greaterThanOrEqualTo(61));
    });

    test('electricity disconnect + link is caution+', () {
      final f = scoreSms(
          'Dear Consumer, electricity will be disconnected tonight 9:30 PM due to unpaid bill. Pay now to avoid: http://bses-update.example/pay');
      expect(f.risk, greaterThanOrEqualTo(31));
    });

    test('parcel customs fee + link is caution+', () {
      final f = scoreSms(
          'India Post: your parcel is held due to customs duty Rs 850. Pay within 24 hrs to avoid return: http://indiapost-customs.example/release');
      expect(f.risk, greaterThanOrEqualTo(31));
    });

    test('prize fee lure is caution+', () {
      final f = scoreSms(
          'Congratulations! You won Rs 25,00,000 lottery. Pay registration fee to claim: http://prize-claim.example/win');
      expect(f.risk, greaterThanOrEqualTo(31));
    });

    test('job task deposit lure (no link) is caution+', () {
      final f = scoreSms(
          'Part time work from home! Earn Rs 5000 daily liking videos. Join our Telegram group, pay a small deposit to unlock bigger tasks.');
      expect(f.risk, greaterThanOrEqualTo(31));
    });

    test('friend emergency money plea (no link) is caution+', () {
      final f = scoreSms(
          'Accident! I am in hospital, please urgently send Rs 20000 to this number, will return tomorrow.');
      expect(f.risk, greaterThanOrEqualTo(31));
    });

    test('KYC APK download is danger', () {
      final f = scoreSms(
          'Download our bank KYC update app now: http://bank-support.example/app.apk');
      expect(f.risk, greaterThanOrEqualTo(61));
    });

    test('TRAI disconnect threat + link is caution+', () {
      final f = scoreSms(
          'TRAI alert: your mobile number will be disconnected in 2 hours due to verification failure. Call now: http://trai-verify.example');
      expect(f.risk, greaterThanOrEqualTo(31));
    });
  });

  group('legit corpus: stays safe', () {
    test('bank debit alert is safe', () {
      final f = scoreSms(
          'Rs 5000 debited from A/C XX1234 on 10-Oct. Avl bal Rs 20000. - HDFC Bank');
      expect(f.risk, lessThanOrEqualTo(30));
    });

    test('clean delivery update with official link is safe', () {
      final f = scoreSms(
          'Your parcel from Amazon arrives today. Track it here: https://www.amazon.in/track/package');
      expect(f.risk, lessThanOrEqualTo(30));
    });

    test('family message is safe', () {
      final f = scoreSms(
          'Amma, I reached home safely. Will call in the evening.');
      expect(f.risk, lessThanOrEqualTo(30));
    });

    test('plain OTP reminder is safe', () {
      final f = scoreSms('Your OTP is 482913. Do not share with anyone.');
      expect(f.risk, lessThanOrEqualTo(30));
    });

    test('official bill SMS is caution at most, never danger', () {
      final f = scoreSms(
          'BSES: electricity bill of Rs 2840 due on 15-Oct. Pay securely at https://www.bsesdelhi.com/pay_bill');
      expect(f.risk, lessThan(61));
    });
  });
}
