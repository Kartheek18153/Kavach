import 'package:flutter_test/flutter_test.dart';
import 'package:cybersafe/services/risk_explain.dart';
import 'package:cybersafe/services/tactic_engine.dart';

TacticScore _scoreOf(List<String> lines) {
  final s = TacticSession();
  var t = 0;
  for (final l in lines) {
    s.addWindow(l, t);
    t += 2000;
  }
  return s.scoreAt(t);
}

void main() {
  test('engine exposes per-family breakdown', () {
    final snap = _scoreOf([
      'Hello, nenu Mumbai CBI office nundi matladutunnanu.',
      'Mee bank OTP cheppandi, account verify chestam.',
    ]);
    expect(snap.families.isNotEmpty, isTrue);
    expect(snap.cappedByFamily.isNotEmpty, isTrue);
    expect(snap.rawByFamily.isNotEmpty, isTrue);
    // Capped never exceeds raw.
    for (final k in snap.cappedByFamily.keys) {
      expect(snap.cappedByFamily[k]! <= snap.rawByFamily[k]! + 0.001, isTrue);
    }
    final j = snap.toJson();
    expect(j['cappedByFamily'], isA<Map>());
    expect(j['evidence'], isA<Map>());
    expect(j['diversityBonus'], isA<int>());
  });

  test('breakdown sorted largest-first with shares', () {
    final snap = _scoreOf([
      'CBI office, arrest warrant, money laundering case.',
      'OTP batao, UPI PIN enter karo.',
      'AnyDesk install karke screen share karo.',
      'Phone cut mat karo, kisi ko mat batana.',
      'Immediately, within two hours, account block ho jayega.',
    ]);
    final bd = breakdownFor(snap);
    expect(bd.length, greaterThanOrEqualTo(3));
    for (var i = 1; i < bd.length; i++) {
      expect(bd[i - 1].capped >= bd[i].capped, isTrue);
    }
    for (final c in bd) {
      expect(c.spans.isNotEmpty, isTrue);
      expect(c.sharePct, greaterThan(0));
    }
  });

  test('danger + all families yields all 7 actions, end_call first', () {
    final fams = {
      'AUTHORITY_IMPERSONATION',
      'ISOLATION_AND_SECRECY',
      'URGENCY_AND_THREAT',
      'CREDENTIAL_EXTRACTION',
      'REMOTE_ACCESS_AND_TRANSFER',
    };
    final acts = actionsFor(families: fams, risk: 85, band: 'danger');
    expect(acts.map((a) => a.id).toSet(),
        containsAll(['end_call', 'no_otp', 'no_apk', 'disable_access', 'no_money', 'secure_accounts', 'report_incident']));
    expect(acts.first.id, 'end_call');
    expect(acts.first.priority, 0);
    // Priorities non-decreasing.
    for (var i = 1; i < acts.length; i++) {
      expect(acts[i].priority >= acts[i - 1].priority, isTrue);
    }
    // OTP + APK + access + money are NOW in this shape.
    expect(acts.firstWhere((a) => a.id == 'no_otp').priority, 0);
    expect(acts.firstWhere((a) => a.id == 'no_apk').priority, 0);
    expect(acts.firstWhere((a) => a.id == 'disable_access').priority, 0);
    expect(acts.firstWhere((a) => a.id == 'no_money').priority, 0);
  });

  test('credential-only caution puts no_otp at P0', () {
    final acts = actionsFor(
        families: {'CREDENTIAL_EXTRACTION'}, risk: 45, band: 'caution');
    expect(acts.firstWhere((a) => a.id == 'no_otp').priority, 0);
    expect(acts.first.priority, isNotNull);
  });

  test('safe + silent returns only calm follow-ups', () {
    final acts = actionsFor(families: {}, risk: 0, band: 'safe');
    expect(acts.isNotEmpty, isTrue);
    expect(acts.every((a) => a.priority == 2), isTrue);
  });

  test('every family + action has EN/TE/HI text', () {
    for (final f in familyExplains) {
      for (final lang in ['en', 'te', 'hi']) {
        expect(f.inLang(f.title, lang).isNotEmpty, isTrue,
            reason: '${f.id} title $lang');
        expect(f.inLang(f.behaviour, lang).isNotEmpty, isTrue,
            reason: '${f.id} behaviour $lang');
        expect(f.inLang(f.whyRisky, lang).isNotEmpty, isTrue,
            reason: '${f.id} why $lang');
      }
    }
    final acts = actionsFor(
      families: {
        'AUTHORITY_IMPERSONATION',
        'CREDENTIAL_EXTRACTION',
        'REMOTE_ACCESS_AND_TRANSFER'
      },
      risk: 75,
      band: 'danger',
    );
    for (final a in acts) {
      for (final lang in ['en', 'te', 'hi']) {
        expect(a.t(lang).isNotEmpty, isTrue,
            reason: '${a.id} title $lang');
        expect(a.d(lang).isNotEmpty, isTrue,
            reason: '${a.id} detail $lang');
      }
    }
  });
}
