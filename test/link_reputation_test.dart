import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:kavach/services/link_reputation.dart';
import 'package:kavach/services/scanners.dart';

void main() {
  group('merged URL heuristics', () {
    test('brand buried in subdomain is spoofing', () {
      final labels =
          urlFindings('https://sbi.login.verify.tk/').map((f) => f.label);
      expect(labels.any((l) => l.contains('sbi')), isTrue);
    });

    test('hyphen, digit run and long domain flagged', () {
      final labels = urlFindings('https://secure-login123-pay.top/x')
          .map((f) => f.label);
      expect(labels.any((l) => l.contains('Hyphen')), isTrue);
      expect(labels.any((l) => l.contains('digit run')), isTrue);
    });

    test('subdomain tiers scored', () {
      final deep = urlFindings('https://a.b.c.d.example.com/')
          .fold<int>(0, (a, f) => a + f.points);
      final www = urlFindings('https://www.example.com/')
          .fold<int>(0, (a, f) => a + f.points);
      expect(deep, greaterThan(www));
    });

    test('deep path and encoded segments flagged', () {
      final labels =
          urlFindings('https://example.com/a/b/c/d?r=%2f..').map((f) => f.label);
      expect(labels.any((l) => l.contains('nested')), isTrue);
      expect(labels.any((l) => l.contains('Encoded')), isTrue);
    });

    test('invalid link still scores 55', () {
      expect(scoreUrl('not a link at all!!!').risk, 55);
    });

    test('clean site stays safe', () {
      expect(scoreUrl('https://www.rbi.org.in/commonman/english/').risk,
          lessThanOrEqualTo(30));
    });
  });

  group('domain reputation (mocked)', () {
    Map<String, dynamic> wrap(String section, Map<String, dynamic> body) =>
        {'sections': {section: body}};

    MockClient client(int Function() onRequest, {bool failAll = false}) {
      return MockClient((req) async {
        onRequest();
        if (failAll) return http.Response('down', 500);
        final q = req.url.queryParameters;
        if (q['action'] == 'whois') {
          return http.Response(
              jsonEncode({'registrar': 'TestReg', 'registered': '2020-01-01'}),
              200);
        }
        switch (q['section']) {
          case 'domain':
            final recent = DateTime.now()
                .toUtc()
                .subtract(const Duration(days: 12));
            final stamp =
                '${recent.year.toString().padLeft(4, '0')}-${recent.month.toString().padLeft(2, '0')}-${recent.day.toString().padLeft(2, '0')}';
            return http.Response(
                jsonEncode(wrap('domain', {
                  'rows': [
                    {'title': 'Registrar', 'detail': 'TestReg'},
                    {'title': 'Registered', 'detail': stamp},
                    {
                      'title': 'Domain expiry',
                      'detail': '2027-01-01 (20 days remaining).'
                    },
                    {
                      'title': 'Domain status',
                      'detail': 'client transfer prohibited'
                    },
                    {
                      'title': 'Nameservers (WHOIS)',
                      'detail': 'ns1.test.io\nns2.test.io'
                    },
                    {'title': 'DNSSEC', 'detail': 'signed'},
                  ],
                  'counts': {'pass': 5, 'warn': 0, 'fail': 0},
                })),
                200);
          case 'blacklist':
            return http.Response(
                jsonEncode(wrap('blacklist', {
                  'rows': [
                    {
                      'title': 'Spamhaus DBL',
                      'detail': 'listed for phishing',
                      'status': 'fail'
                    }
                  ],
                  'counts': {'pass': 26, 'warn': 0, 'fail': 1},
                })),
                200);
          default:
            return http.Response(
                jsonEncode(wrap('${q['section']}', {
                  'rows': [],
                  'counts': {'pass': 8, 'warn': 0, 'fail': 0},
                })),
                200);
        }
      });
    }

    test('young + blacklisted domain scores findings', () async {
      var calls = 0;
      final rep = await fetchReputation('evil-test.tk',
          client: client(() => calls++));
      expect(
          rep.findings.any((f) => f.label.contains('only 1')), isTrue);
      expect(
          rep.findings.any((f) => f.label.contains('blacklist')), isTrue);
      expect(rep.facts.ageDays, lessThanOrEqualTo(30));
      expect(rep.facts.blacklistFail, 1);
      expect(rep.facts.online, isTrue);
      expect(rep.facts.expiryDays, 20);
      expect(
          rep.findings.any((f) => f.label.contains('expires in')), isTrue);
      expect(rep.facts.dnssec, 'signed');
      expect(rep.facts.nameservers, contains('ns1.test.io'));
      expect(rep.facts.healthPass, greaterThan(0));
      // Cached: second lookup makes no HTTP calls.
      await fetchReputation('evil-test.tk', client: client(() => calls++));
      expect(calls, 10); // 9 sections + whois, once
    });

    test('total failure is fail-soft', () async {
      final rep = await fetchReputation('down-test.tk',
          client: client(() => 0, failAll: true));
      expect(rep.findings, isEmpty);
      expect(rep.facts.online, isFalse);
      expect(rep.facts.error, isNotNull);
    });

    test('forceRefresh bypasses a cached partial result', () async {
      var calls = 0;
      final first = await fetchReputation('refresh-test.tk',
          client: client(() => calls++));
      expect(first.facts.sectionsFailed,
          isNot(contains('blacklist')));
      final cachedCalls = calls;
      // Cached: no new HTTP.
      await fetchReputation('refresh-test.tk', client: client(() => calls++));
      expect(calls, cachedCalls);
      // Forced: refetches everything.
      await fetchReputation('refresh-test.tk',
          client: client(() => calls++), forceRefresh: true);
      expect(calls, greaterThan(cachedCalls));
    });

    test('timed-out sections are retried once', () async {
      var blCalls = 0;
      final retryClient = MockClient((req) async {
        final q = req.url.queryParameters;
        if (q['action'] == 'whois') {
          return http.Response(jsonEncode({}), 200);
        }
        if (q['section'] == 'blacklist') {
          blCalls++;
          if (blCalls == 1) throw TimeoutException('slow blacklist');
          return http.Response(
              jsonEncode(wrap('blacklist', {
                'rows': [],
                'counts': {'pass': 27, 'warn': 0, 'fail': 0},
              })),
              200);
        }
        return http.Response(
            jsonEncode(wrap('${q['section']}', {
              'rows': [],
              'counts': {'pass': 1, 'warn': 0, 'fail': 0},
            })),
            200);
      });
      final rep =
          await fetchReputation('retry-test.tk', client: retryClient);
      expect(blCalls, 2);
      expect(rep.facts.sectionsFailed, isNot(contains('blacklist')));
      expect(rep.facts.blacklistFail, 0);
    });

    test('watch emits progressive snapshots then a finished total', () async {
      var calls = 0;
      final events = await watchReputation('stream-test.tk',
              client: client(() => calls++))
          .toList();
      expect(events.length, greaterThan(2));
      final last = events.last;
      expect(last.finished, isTrue);
      expect(last.done, last.total);
      expect(last.total, 10);
      expect(
          last.result.findings.any((f) => f.label.contains('blacklist')),
          isTrue);
      for (var i = 1; i < events.length; i++) {
        expect(events[i].done, greaterThanOrEqualTo(events[i - 1].done));
      }
    });
  });
}
