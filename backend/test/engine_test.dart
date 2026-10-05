import 'package:kavach_backend/engine.dart';
import 'package:kavach_backend/server.dart';
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

  test('safe word gives -20 discount', () {
    expect(safeWordBonus('KAVACHAM amma', 'kavacham'), 20);
    expect(safeWordBonus('hello police otp', 'kavacham'), 0);
    expect(safeWordBonus('anything', ''), 0);
  });

  test('keyword groups stay in sync with app (7 groups)', () {
    expect(keywordGroups.map((g) => g.$1),
        ['authority', 'threat', 'secrecy', 'urgency', 'sensitive', 'remote', 'money']);
    expect(keywordGroups.fold<int>(0, (a, g) => a + g.$2), 20 + 25 + 25 + 10 + 35 + 35 + 30);
  });

  test('pruneSessions evicts old + caps size', () {
    final sessions = <String, ScoringSession>{
      'old': ScoringSession(id: 'old', isScam: true),
      'fresh': ScoringSession(id: 'fresh', isScam: true),
    };
    // Age one session beyond TTL by mutating startedAt via removal test:
    // prune with maxAge zero removes everything older than now.
    final removed = pruneSessions(sessions, maxAge: Duration.zero);
    expect(removed, 2);
    expect(sessions, isEmpty);
  });
}
