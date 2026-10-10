import 'dart:convert';
import 'dart:math';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'engine.dart';
import 'sim_swap/config.dart';
import 'sim_swap/live_provider.dart';
import 'sim_swap/service.dart';
import 'sim_swap/simulation_provider.dart';
import 'sim_swap/validation.dart';
import 'tactic_engine.dart' as te;

/// In-memory scoring session: Tier-1 tactic engine over the transcript.
class ScoringSession {
  ScoringSession({required this.id, required this.isScam});

  final String id;
  final bool isScam;
  final te.TacticSession tactics = te.TacticSession();
  final Set<String> seen = {};
  int risk = 0;
  bool alerted = false;
  int lines = 0;
  final DateTime startedAt = DateTime.now();

  int _nowMs() => DateTime.now().difference(startedAt).inMilliseconds;

  Map<String, Object> state() {
    final level = riskLevelFor(risk);
    final snap = tactics.scoreAt(_nowMs());
    return {
      'sessionId': id,
      'risk': risk,
      'level': level,
      'band': level,
      'scamType': scamTypeFor(seen, isScam: isScam),
      'reasons': reasonsFor(seen),
      'reasonsTelugu': reasonsTeluguFor(seen),
      'alerted': alerted,
      'lines': lines,
      // Explainable breakdown: which signals caused the score.
      'families': snap.families.toList(growable: false),
      'evidence': snap.evidence.map((k, v) => MapEntry(k, List.of(v))),
      'capped': snap.cappedByFamily.map((k, v) => MapEntry(k, v)),
      'bonus': snap.diversityBonus,
      'guardDelta': snap.guardDelta,
    };
  }
}

String _newId() {
  final r = Random.secure();
  final bytes = List<int>.generate(16, (_) => r.nextInt(256));
  return base64UrlEncode(bytes).replaceAll('=', '');
}

/// Removes sessions older than [maxAge] and caps the map at [maxSessions]
/// by evicting oldest first. Returns number removed.
int pruneSessions(
  Map<String, ScoringSession> sessions, {
  Duration maxAge = const Duration(minutes: 30),
  int maxSessions = 500,
}) {
  final now = DateTime.now();
  final expired = sessions.entries
      .where((e) => now.difference(e.value.startedAt) >= maxAge)
      .map((e) => e.key)
      .toList();
  for (final k in expired) {
    sessions.remove(k);
  }
  var removed = expired.length;
  if (sessions.length > maxSessions) {
    final sorted = sessions.entries.toList()
      ..sort((a, b) => a.value.startedAt.compareTo(b.value.startedAt));
    final overflow = sessions.length - maxSessions;
    for (var i = 0; i < overflow; i++) {
      sessions.remove(sorted[i].key);
      removed++;
    }
  }
  return removed;
}

Response _json(Object body, {int status = 200}) => Response(
      status,
      body: jsonEncode(body),
      headers: {'content-type': 'application/json'},
    );

Future<Map<String, dynamic>> _readJson(Request req) async {
  try {
    return jsonDecode(await req.readAsString()) as Map<String, dynamic>;
  } catch (_) {
    return {};
  }
}

/// Builds the API router. [sessions] is shared mutable state.
Router buildRouter(
  Map<String, ScoringSession> sessions,
) {
  final router = Router();

  router.get('/health', (Request req) {
    return _json({
      'ok': true,
      'service': 'cybersafe-backend',
      'sessions': sessions.length,
      'simSwap': SimSwapSettings().describe(),
    });
  });

  SimSwapService makeSimService() {
    final settings = SimSwapSettings();
    return SimSwapService(
      provider: buildSimSwapProvider(settings),
      settings: settings,
    );
  }

  void closeSimProvider(SimSwapService service) {
    final p = service.provider;
    if (p is GsmaSandboxProvider) p.close();
  }

  /// Optional E.164 phoneNumber from a decoded body. Returns a 400 response
  /// record instead of a phone when invalid: `(null, response)`.
  (String?, Response?) phoneOr400(Map<String, dynamic> body) {
    final raw = body['phoneNumber'];
    if (raw == null) return (null, null);
    final phone = '$raw'.trim();
    if (phone.isEmpty) return (null, null);
    if (!isValidE164(phone)) {
      return (
        null,
        _json(
          {'error': 'phoneNumber must be E.164 format, e.g. +919876543210'},
          status: 400,
        )
      );
    }
    return (phone, null);
  }

  // SIM-swap telco check (CAMARA): {phoneNumber?, lookbackHours?}.
  router.post('/api/sim-swap/check', (Request req) async {
    final body = await _readJson(req);
    final (phone, bad) = phoneOr400(body);
    if (bad != null) return bad;
    final settings = SimSwapSettings();
    var lookback = settings.defaultLookbackHours;
    if (body.containsKey('lookbackHours') && body['lookbackHours'] != null) {
      final v = body['lookbackHours'];
      if (v is! int) {
        return _json(
          {'error': 'lookbackHours must be an integer 1..2400'},
          status: 400,
        );
      }
      lookback = v;
    }
    try {
      parseMaxAge(lookback);
    } on FormatException catch (e) {
      return _json({'error': '$e'}, status: 400);
    }
    final service = makeSimService();
    try {
      return _json(await service.check(
          phoneNumber: phone, lookbackHours: lookback));
    } finally {
      closeSimProvider(service);
    }
  });

  // SIM-swap last-change date (CAMARA): {phoneNumber?}.
  router.post('/api/sim-swap/retrieve-date', (Request req) async {
    final body = await _readJson(req);
    final (phone, bad) = phoneOr400(body);
    if (bad != null) return bad;
    final service = makeSimService();
    try {
      return _json(await service.retrieveDate(phoneNumber: phone));
    } finally {
      closeSimProvider(service);
    }
  });

  // --- Temporary simulation registry (volatile, demo only) ---

  router.get('/api/simulator/subscribers', (Request req) {
    return _json({
      'subscribers': sharedSimulationStore.snapshot(),
      'temporary': true,
    });
  });

  router.post('/api/simulator/subscribers', (Request req) async {
    final body = await _readJson(req);
    final (phone, bad) = phoneOr400(body);
    if (bad != null) return bad;
    if (phone == null) {
      return _json({'error': 'phoneNumber is required'}, status: 400);
    }
    final record = sharedSimulationStore.addSubscriber(phone);
    return _json({
      'maskedPhone': maskPhone(record.phoneNumber),
      'activatedAt': record.activatedAt.toIso8601String(),
      'swapCount': record.swaps.length,
      'temporary': true,
    });
  });

  router.post('/api/simulator/swaps', (Request req) async {
    final body = await _readJson(req);
    final (phone, bad) = phoneOr400(body);
    if (bad != null) return bad;
    if (phone == null) {
      return _json({'error': 'phoneNumber is required'}, status: 400);
    }
    DateTime? at;
    if (body.containsKey('at') && body['at'] != null) {
      try {
        at = DateTime.parse('${body['at']}').toUtc();
      } on FormatException {
        return _json(
            {'error': 'at must be an RFC3339 datetime'}, status: 400);
      }
    }
    final moment = sharedSimulationStore.recordSwap(phone, at);
    return _json({
      'maskedPhone': maskPhone(phone),
      'recordedAt': moment.toIso8601String(),
      'temporary': true,
    });
  });

  router.post('/api/simulator/reset', (Request req) async {
    sharedSimulationStore.reset(seed: true);
    return _json({
      'reset': true,
      'subscribers': sharedSimulationStore.snapshot(),
      'temporary': true,
    });
  });

  // Start a scoring session: {"mode": "scam" | "normal"}.
  router.post('/api/session/start', (Request req) async {
    final body = await _readJson(req);
    final mode = (body['mode'] as String? ?? 'scam').toLowerCase();
    final session =
        ScoringSession(id: _newId(), isScam: mode != 'normal');
    sessions[session.id] = session;
    return _json({'sessionId': session.id, ...session.state()});
  });

  // Score one transcript line inside a session.
  // {"sessionId": "...", "text": "...", "safeWord": "..."} — omit sessionId for stateless.
  router.post('/api/score', (Request req) async {
    final body = await _readJson(req);
    final text = (body['text'] as String? ?? '').trim();
    if (text.isEmpty) {
      return _json({'error': 'text is required'}, status: 400);
    }
    final safeWord = (body['safeWord'] as String? ?? '').trim();
    final discount = safeWordBonus(text, safeWord);
    final sessionId = body['sessionId'] as String?;
    final session =
        sessionId == null ? null : sessions[sessionId];
    if (sessionId != null && session == null) {
      return _json({'error': 'unknown sessionId'}, status: 404);
    }
    if (session == null) {
      final tmp = te.TacticSession();
      final n = tmp.addWindow(text, 0);
      final snap = tmp.scoreAt(0);
      final net = (snap.score - discount).clamp(0, 100);
      return _json({
        'points': n > 0 ? net : 0,
        'groups': snap.families.toList(growable: false),
        'families': snap.families.toList(growable: false),
        'evidence': snap.evidence,
        'capped': snap.cappedByFamily,
        'bonus': snap.diversityBonus,
        'guardDelta': snap.guardDelta,
      });
    }
    final newSignals = session.tactics.addWindow(text, session._nowMs());
    final snap = session.tactics.scoreAt(session._nowMs());
    session.seen.addAll(snap.families);
    final risk = (snap.score - discount).clamp(0, 100);
    session.risk = risk;
    session.lines += 1;
    if (riskLevelFor(risk) == 'danger') session.alerted = true;
    return _json({
      'points': newSignals,
      'flagged': newSignals > 0,
      ...session.state(),
    });
  });

  // End a session and get the summary.
  router.post('/api/session/end', (Request req) async {
    final body = await _readJson(req);
    final sessionId = body['sessionId'] as String?;
    final session =
        sessionId == null ? null : sessions.remove(sessionId);
    if (session == null) {
      return _json({'error': 'unknown sessionId'}, status: 404);
    }
    return _json({
      ...session.state(),
      'elapsedSec': DateTime.now()
          .difference(session.startedAt)
          .inSeconds,
    });
  });

  return router;
}
