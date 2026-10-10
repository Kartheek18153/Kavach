import 'dart:convert';

import 'package:cybersafe_backend/engine.dart';
import 'package:cybersafe_backend/server.dart';
import 'package:cybersafe_backend/tactic_engine.dart';
import 'package:cybersafe_backend/tactic_lexicon_data.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  test('OTP line fires the credential family', () {
    final snap = TacticSession.scoreTextOnce('Share the OTP 3274 I sent');
    expect(snap.families, contains('CREDENTIAL_EXTRACTION'));
    expect(snap.score, greaterThan(0));
  });

  test('risk bands match app thresholds', () {
    expect(riskLevelFor(0), 'safe');
    expect(riskLevelFor(30), 'safe');
    expect(riskLevelFor(31), 'caution');
    expect(riskLevelFor(60), 'caution');
    expect(riskLevelFor(61), 'danger');
    expect(riskLevelFor(100), 'danger');
  });

  test('authority plus OTP is a digital-arrest headline', () {
    final seen = {'AUTHORITY_IMPERSONATION', 'CREDENTIAL_EXTRACTION'};
    expect(scamTypeFor(seen, isScam: true), 'Fake police / Digital arrest');
    expect(reasonsTeluguFor(seen), isNotEmpty);
  });

  test('clean chat stays safe', () {
    final snap = TacticSession.scoreTextOnce('Namaste, parcel vachindi');
    expect(snap.score, 0);
    expect(TacticSession.scoreTextOnce('Namaste, parcel vachindi').band, 'safe');
  });

  test('safe word gives -20 discount', () {
    expect(safeWordBonus('KAVACHAM amma', 'kavacham'), 20);
    expect(safeWordBonus('hello police otp', 'kavacham'), 0);
    expect(safeWordBonus('anything', ''), 0);
  });

  test('lexicon loads 5 families, 180 markers, 40 guards', () {
    expect(tacticFamilies.map((f) => f.id), [
      'AUTHORITY_IMPERSONATION',
      'ISOLATION_AND_SECRECY',
      'URGENCY_AND_THREAT',
      'CREDENTIAL_EXTRACTION',
      'REMOTE_ACCESS_AND_TRANSFER'
    ]);
    expect(tacticFamilies.fold<int>(0, (a, f) => a + f.markers.length), 180);
    expect(negativeGuards, hasLength(40));
  });

  test('pruneSessions evicts old + caps size', () {
    final sessions = <String, ScoringSession>{
      'old': ScoringSession(id: 'old', isScam: true),
      'fresh': ScoringSession(id: 'fresh', isScam: true),
    };
    // prune with maxAge zero removes everything older than now.
    final removed = pruneSessions(sessions, maxAge: Duration.zero);
    expect(removed, 2);
    expect(sessions, isEmpty);
  });

  test('word boundaries stop false alarms', () {
    expect(
        TacticSession.scoreTextOnce('my spinning wheel is fine').score, 0);
    expect(
        TacticSession.scoreTextOnce('found an old suitcase').score, 0);
    expect(
        TacticSession.scoreTextOnce('share your UPI PIN here').families,
        contains('CREDENTIAL_EXTRACTION'));
  });

  test('single loud family caps below danger (diversity rule)', () {
    final session = TacticSession();
    for (var i = 0; i < 10; i++) {
      session.addWindow('please tell me your otp now, the otp code', i * 6000);
    }
    final snap = session.scoreAt(10 * 6000);
    expect(snap.families, ['CREDENTIAL_EXTRACTION']);
    expect(snap.band, isNot('danger'));
  });

  test('session scores a scam exchange to danger', () async {
    final sessions = <String, ScoringSession>{};
    final router = buildRouter(sessions);
    Future<Map<String, dynamic>> call(
        String path, Map<String, Object?> body) async {
      final res = await router.call(Request(
        'POST',
        Uri.parse('http://localhost$path'),
        body: jsonEncode(body),
        headers: {'content-type': 'application/json'},
      ));
      return jsonDecode(await res.readAsString()) as Map<String, dynamic>;
    }

    final started = await call('/api/session/start', {'mode': 'scam'});
    final sid = started['sessionId'] as String;
    await call('/api/score', {
      'sessionId': sid,
      'text': 'I am calling from the CBI, your Aadhaar is linked to a parcel'
    });
    await call('/api/score', {
      'sessionId': sid,
      'text': 'do not tell anyone, stay on the call, arrest warrant issued'
    });
    final last = await call('/api/score', {
      'sessionId': sid,
      'text': 'share your OTP now to verify and transfer the amount'
    });
    expect(last['level'], 'danger');
    expect(last['alerted'], isTrue);
  });
}
