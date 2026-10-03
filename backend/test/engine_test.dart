import 'package:kavach_backend/engine.dart';
import 'package:test/test.dart';

void main() {
  test('OTP line scores sensitive points', () {
    final seen = <String>{};
    final groups = matchGroups('Share the OTP 3274 I sent', seen);
    expect(groups.map((g) => g.$1), contains('sensitive'));
    expect(groups.fold<int>(0, (a, g) => a + g.$2), 35);
  });

  test('risk bands match app thresholds', () {
    expect(riskLevelFor(0), 'safe');
    expect(riskLevelFor(30), 'safe');
    expect(riskLevelFor(31), 'caution');
    expect(riskLevelFor(60), 'caution');
    expect(riskLevelFor(61), 'danger');
    expect(riskLevelFor(100), 'danger');
  });

  test('authority plus OTP hard-triggers', () {
    final seen = {'authority', 'sensitive'};
    expect(hardTriggered(seen), isTrue);
    expect(scamTypeFor(seen, isScam: true), 'Fake police / Digital arrest');
    expect(reasonsTeluguFor(seen), isNotEmpty);
  });

  test('clean chat stays safe', () {
    final seen = <String>{};
    expect(matchGroups('Namaste, parcel vachindi', seen), isEmpty);
    expect(scamTypeFor(seen, isScam: false), '-');
  });
}
