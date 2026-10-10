// Tests for the CAMARA SIM-swap port: validation, mock/simulation
// providers, service honesty rules, live error mapping (mocked HTTP),
// v1/v2 factory selection, and the HTTP routes.
import 'dart:convert';

import 'package:cybersafe_backend/server.dart';
import 'package:cybersafe_backend/sim_swap/config.dart';
import 'package:cybersafe_backend/sim_swap/live_provider.dart';
import 'package:cybersafe_backend/sim_swap/mock_provider.dart';
import 'package:cybersafe_backend/sim_swap/provider.dart';
import 'package:cybersafe_backend/sim_swap/service.dart';
import 'package:cybersafe_backend/sim_swap/simulation_provider.dart';
import 'package:cybersafe_backend/sim_swap/validation.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:test/test.dart';

SimSwapSettings _mockSettings() => SimSwapSettings(
      authFlow: 'mock',
      provider: 'mock',
    );

SimSwapService _mockService() {
  final settings = _mockSettings();
  return SimSwapService(
      provider: buildSimSwapProvider(settings), settings: settings);
}

Future<Map<String, dynamic>> _post(
    Router router, String path, Map<String, dynamic> body) async {
  final req = Request('POST', Uri.parse('http://localhost$path'),
      body: jsonEncode(body), headers: {'content-type': 'application/json'});
  final res = await router(req);
  final text = await res.read().transform(utf8.decoder).join();
  return {
    'status': res.statusCode,
    'body': jsonDecode(text) as Map<String, dynamic>,
  };
}

void main() {
  group('validation', () {
    test('E.164 accept/reject', () {
      expect(isValidE164('+919876543210'), isTrue);
      expect(isValidE164('+346661113334'), isTrue);
      expect(isValidE164('9876543210'), isFalse);
      expect(isValidE164('+91 98765 43210'), isFalse);
      expect(isValidE164('+0123'), isFalse);
      expect(isValidE164('+1'), isFalse);
    });

    test('maskPhone hides full numbers', () {
      expect(maskPhone('+346661113334'), '+34******3334');
      expect(maskPhone('+919876543210'), '+91******3210');
      expect(maskPhone(null), isNull);
      expect(maskPhone(''), isNull);
      expect(maskPhone('123'), '***');
    });

    test('parseMaxAge enforces int 1..2400', () {
      expect(parseMaxAge(72), 72);
      expect(parseMaxAge(1), 1);
      expect(parseMaxAge(2400), 2400);
      expect(() => parseMaxAge(0), throwsFormatException);
      expect(() => parseMaxAge(2401), throwsFormatException);
      expect(() => parseMaxAge('72'), throwsFormatException);
      expect(() => parseMaxAge(7.5), throwsFormatException);
      expect(() => parseMaxAge(null), throwsFormatException);
    });

    test('parseCamaraDateTime handles RFC3339', () {
      expect(parseCamaraDateTime(null), isNull);
      expect(
          parseCamaraDateTime('2026-10-01T10:00:00Z'),
          DateTime.utc(2026, 10, 1, 10));
      expect(
          parseCamaraDateTime('2026-10-01T12:00:00+02:00'),
          DateTime.utc(2026, 10, 1, 10));
      expect(() => parseCamaraDateTime('yesterday'), throwsFormatException);
      expect(() => parseCamaraDateTime(42), throwsFormatException);
    });
  });

  group('mock provider + service', () {
    test('numbers ending 0000 simulate a swap', () async {
      final service = _mockService();
      final hit = await service.check(
          phoneNumber: '+3412340000', lookbackHours: 72);
      expect(hit['status'], 'completed');
      expect(hit['simSwapDetected'], isTrue);
      expect(hit['riskSignal'], 'recent_sim_change');
      expect(hit['maskedPhone'], '+34******0000');
      expect((hit['evidence'] as List).single['swapped'], isTrue);

      final miss = await service.check(
          phoneNumber: '+346661113334', lookbackHours: 72);
      expect(miss['simSwapDetected'], isFalse);
      expect(miss['riskSignal'], 'no_recent_change');
      expect(miss['detail'], contains('does not mean the number is safe'));
    });

    test('mock retrieve-date agrees with check', () async {
      final service = _mockService();
      final hit = await service.retrieveDate(phoneNumber: '+3412340000');
      expect(hit['status'], 'completed');
      expect(hit['simSwapDetected'], isTrue);
      expect(hit['lastSwapAt'], isNotNull);

      final miss =
          await service.retrieveDate(phoneNumber: '+346661113334');
      // null date WITH monitoredPeriod -> completed, no swap in window.
      expect(miss['status'], 'completed');
      expect(miss['simSwapDetected'], isFalse);
      expect(miss['monitoredPeriodDays'], 120);
    });

    test('provider failure is unknown, never false', () async {
      final settings = _mockSettings();
      final service = SimSwapService(
          provider: _FailingProvider(), settings: settings);
      final out = await service.check(
          phoneNumber: '+919876543210', lookbackHours: 72);
      expect(out['status'], 'unknown');
      expect(out['simSwapDetected'], isNull);
      expect(out['riskSignal'], 'check_unavailable');
    });
  });

  group('simulation provider', () {
    test('seeded demo numbers behave', () async {
      final store = SimulationStore()..seedDemoData();
      final service = SimSwapService(
          provider: SimulatedSimSwapProvider(store: store),
          settings: _mockSettings());
      final hit = await service.check(
          phoneNumber: '+3412340000', lookbackHours: 72);
      expect(hit['simSwapDetected'], isTrue);
      final miss = await service.check(
          phoneNumber: '+346661113334', lookbackHours: 72);
      expect(miss['simSwapDetected'], isFalse);
      final unknownNum = await service.check(
          phoneNumber: '+919876543210', lookbackHours: 72);
      expect(unknownNum['status'], 'unknown');
    });

    test('recorded swaps react + reset restores', () async {
      final store = SimulationStore()..seedDemoData();
      final service = SimSwapService(
          provider: SimulatedSimSwapProvider(store: store),
          settings: _mockSettings());
      store.addSubscriber('+919876543210');
      var out = await service.check(
          phoneNumber: '+919876543210', lookbackHours: 72);
      expect(out['simSwapDetected'], isFalse);
      store.recordSwap('+919876543210');
      out = await service.check(
          phoneNumber: '+919876543210', lookbackHours: 72);
      expect(out['simSwapDetected'], isTrue);
      final date =
          await service.retrieveDate(phoneNumber: '+919876543210');
      expect(date['lastSwapAt'], isNotNull);
      store.reset(seed: true);
      expect(store.snapshot(), hasLength(2));
    });
  });

  group('live provider error mapping (mocked HTTP)', () {
    SimSwapSettings bearerSettings() => SimSwapSettings(
          authFlow: 'bearer',
          bearerToken: 'tok',
          apiBaseUrl: 'https://example.com/sim-swap/v2',
          provider: 'test-live',
        );

    test('200 swapped=true with correlator', () async {
      String? correlator;
      String? auth;
      final client = MockClient((req) async {
        correlator = req.headers['x-correlator'];
        auth = req.headers['authorization'];
        expect(req.url.path, endsWith('/check'));
        expect(jsonDecode(req.body)['maxAge'], 72);
        return http.Response(jsonEncode({'swapped': true}), 200);
      });
      final p = GsmaSandboxProvider(bearerSettings(), client: client);
      final out =
          await p.check(phoneNumber: null, maxAgeHours: 72);
      expect(out.swapped, isTrue);
      expect(auth, 'Bearer tok');
      expect(correlator, isNotNull);
      expect(correlator!.length, 32);
      expect(out.httpStatus, 200);
    });

    test('401/400/429/500 map to unknown via service', () async {
      for (final entry in {
        401: ProviderAuthError,
        400: ProviderBadResponse,
        429: ProviderRateLimited,
        500: ProviderUnavailable,
      }.entries) {
        final client = MockClient((_) async => http.Response(
            jsonEncode(
                {'code': 'ERR', 'message': 'm'}),
            entry.key));
        final p = GsmaSandboxProvider(bearerSettings(), client: client);
        final service = SimSwapService(
            provider: p, settings: _mockSettings());
        final out = await service.check(
            phoneNumber: null, lookbackHours: 72);
        expect(out['status'], 'unknown', reason: 'HTTP ${entry.key}');
        expect(out['simSwapDetected'], isNull);
      }
    });

    test('malformed payload is a bad response', () async {
      final client = MockClient(
          (_) async => http.Response(jsonEncode({'nope': 1}), 200));
      final p = GsmaSandboxProvider(bearerSettings(), client: client);
      expect(() => p.check(phoneNumber: null, maxAgeHours: 72),
          throwsA(isA<ProviderBadResponse>()));
    });

    test('maxAge validated before any HTTP call', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response(jsonEncode({'swapped': false}), 200);
      });
      final p = GsmaSandboxProvider(bearerSettings(), client: client);
      expect(() => p.check(phoneNumber: null, maxAgeHours: 0),
          throwsA(isA<ProviderBadResponse>()));
      expect(calls, 0);
    });

    test('v2 bearer forbids phoneNumber; v1 passes it through', () async {
      Map<String, dynamic>? v2body;
      final v2client = MockClient((req) async {
        v2body = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response(jsonEncode({'swapped': false}), 200);
      });
      final v2 = GsmaSandboxProvider(bearerSettings(), client: v2client);
      expect(
          () => v2.check(
              phoneNumber: '+919876543210', maxAgeHours: 72),
          throwsA(isA<ProviderBadResponse>()));
      expect(v2body, isNull);

      Map<String, dynamic>? v1body;
      final v1client = MockClient((req) async {
        v1body = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response(jsonEncode({'swapped': false}), 200);
      });
      final v1settings = SimSwapSettings(
        authFlow: 'bearer',
        bearerToken: 'tok',
        apiBaseUrl: 'https://example.com/sim-swap/v1',
        simSwapApiVersion: 'v1',
      );
      final v1 = SimSwapV1Provider(v1settings, client: v1client);
      final out = await v1.check(
          phoneNumber: '+919876543210', maxAgeHours: 72);
      expect(out.swapped, isFalse);
      expect(v1body!['phoneNumber'], '+919876543210');
    });

    test('client_credentials token flow then check', () async {
      final seen = <String>[];
      final client = MockClient((req) async {
        seen.add(req.url.path);
        if (req.url.path.endsWith('/token')) {
          expect(req.headers['authorization'], startsWith('Basic '));
          return http.Response(
              jsonEncode({'access_token': 'abc', 'expires_in': 3600}),
              200);
        }
        expect(req.headers['authorization'], 'Bearer abc');
        return http.Response(jsonEncode({'swapped': false}), 200);
      });
      final settings = SimSwapSettings(
        authFlow: 'client_credentials',
        clientId: 'id',
        clientSecret: 'secret',
        apiBaseUrl: 'https://example.com/sim-swap/v2',
        tokenUrl: 'https://example.com/token',
        simSwapScope: 'sim-swap:check',
      );
      final p = GsmaSandboxProvider(settings, client: client);
      final out = await p.check(
          phoneNumber: '+919876543210', maxAgeHours: 72);
      expect(out.swapped, isFalse);
      expect(seen, ['/token', '/sim-swap/v2/check']);
    });
  });

  group('factory', () {
    test('mock default, simulation flow, v1/v2 live selection', () {
      expect(
          buildSimSwapProvider(SimSwapSettings(authFlow: 'mock')),
          isA<MockSimSwapProvider>());
      // Live values but mock flow -> still mock.
      expect(
          buildSimSwapProvider(SimSwapSettings(
            authFlow: 'mock',
            bearerToken: 'tok',
            apiBaseUrl: 'https://example.com/sim-swap/v2',
          )),
          isA<MockSimSwapProvider>());
      expect(
          buildSimSwapProvider(SimSwapSettings(authFlow: 'simulation')),
          isA<SimulatedSimSwapProvider>());
      final v2 = buildSimSwapProvider(SimSwapSettings(
        authFlow: 'bearer',
        bearerToken: 'tok',
        apiBaseUrl: 'https://example.com/sim-swap/v2',
      ));
      expect(v2, isA<GsmaSandboxProvider>());
      final v1 = buildSimSwapProvider(SimSwapSettings(
        authFlow: 'bearer',
        bearerToken: 'tok',
        apiBaseUrl: 'https://example.com/sim-swap/v1',
        simSwapApiVersion: 'v1',
      ));
      expect(v1, isA<SimSwapV1Provider>());
    });
  });

  group('routes', () {
    test('check + retrieve-date over HTTP (mock)', () async {
      final router = buildRouter({});
      var out = await _post(router, '/api/sim-swap/check',
          {'phoneNumber': '+3412340000', 'lookbackHours': 72});
      expect(out['status'], 200);
      expect(out['body']['riskSignal'], 'recent_sim_change');

      out = await _post(router, '/api/sim-swap/check',
          {'phoneNumber': '+346661113334'});
      expect(out['body']['riskSignal'], 'no_recent_change');

      out = await _post(
          router, '/api/sim-swap/check', {'phoneNumber': 'oops'});
      expect(out['status'], 400);

      out = await _post(router, '/api/sim-swap/check',
          {'phoneNumber': '+3412340000', 'lookbackHours': '72'});
      expect(out['status'], 400);

      out = await _post(router, '/api/sim-swap/retrieve-date',
          {'phoneNumber': '+3412340000'});
      expect(out['status'], 200);
      expect(out['body']['lastSwapAt'], isNotNull);
    });

    test('simulator registry round-trip', () async {
      final router = buildRouter({});
      await _post(router, '/api/simulator/reset', {});
      var out = await _post(router, '/api/simulator/subscribers',
          {'phoneNumber': '+919876543210'});
      expect(out['status'], 200);
      expect(out['body']['maskedPhone'], '+91******3210');
      out = await _post(router, '/api/simulator/swaps',
          {'phoneNumber': '+919876543210'});
      expect(out['status'], 200);
      out = await _post(router, '/api/sim-swap/check',
          {'phoneNumber': '+919876543210', 'lookbackHours': 72});
      // Default flow is mock (env unset): mock answers from the number shape,
      // not the registry — +…3210 does not end in 0000 -> no swap.
      expect(out['body']['riskSignal'], 'no_recent_change');
    });
  });
}

class _FailingProvider extends SimSwapProvider {
  @override
  String get name => 'failing';

  @override
  Future<CheckOutcome> check(
          {required String? phoneNumber, required int maxAgeHours}) =>
      throw ProviderUnavailable('boom');

  @override
  Future<RetrieveDateOutcome> retrieveDate(
          {required String? phoneNumber}) =>
      throw ProviderUnavailable('boom');
}
