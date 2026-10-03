import 'dart:convert';
import 'dart:math';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'alerts.dart';
import 'engine.dart';

/// In-memory scoring session: accumulates seen groups and risk.
class ScoringSession {
  ScoringSession({required this.id, required this.isScam});

  final String id;
  final bool isScam;
  final Set<String> seen = {};
  int risk = 0;
  bool alerted = false;
  int lines = 0;
  final DateTime startedAt = DateTime.now();

  Map<String, Object> state() {
    final level = riskLevelFor(risk);
    return {
      'sessionId': id,
      'risk': risk,
      'level': level,
      'scamType': scamTypeFor(seen, isScam: isScam),
      'reasons': reasonsFor(seen),
      'reasonsTelugu': reasonsTeluguFor(seen),
      'alerted': alerted,
      'lines': lines,
    };
  }
}

String _newId() {
  final r = Random.secure();
  final bytes = List<int>.generate(16, (_) => r.nextInt(256));
  return base64UrlEncode(bytes).replaceAll('=', '');
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
  AlertDispatcher alerts,
) {
  final router = Router();

  router.get('/health', (Request req) {
    return _json({
      'ok': true,
      'service': 'kavach-backend',
      'sessions': sessions.length,
      'telegram': alerts.configured,
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
  // {"sessionId": "...", "text": "..."} — omit sessionId for stateless.
  router.post('/api/score', (Request req) async {
    final body = await _readJson(req);
    final text = (body['text'] as String? ?? '').trim();
    if (text.isEmpty) {
      return _json({'error': 'text is required'}, status: 400);
    }
    final sessionId = body['sessionId'] as String?;
    final session =
        sessionId == null ? null : sessions[sessionId];
    if (sessionId != null && session == null) {
      return _json({'error': 'unknown sessionId'}, status: 404);
    }
    final seen = session?.seen ?? <String>{};
    var gained = 0;
    for (final (name, points) in matchGroups(text, seen)) {
      seen.add(name);
      gained += points;
    }
    if (session == null) {
      return _json({
        'points': gained,
        'groups': matchGroups(text, <String>{})
            .map((g) => g.$1)
            .toList(growable: false),
      });
    }
    var risk = (session.risk + gained).clamp(0, 100);
    if (hardTriggered(seen) && risk < 85) risk = 85;
    session.risk = risk;
    session.lines += 1;
    if (riskLevelFor(risk) == 'danger') session.alerted = true;
    return _json({
      'points': gained,
      'flagged': gained > 0,
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

  // Family alert: {"chatId": "...", "message": "..."}.
  router.post('/api/alert', (Request req) async {
    final body = await _readJson(req);
    final result = await alerts.sendAlert(
      chatId: (body['chatId'] as String? ?? '').trim(),
      message: (body['message'] as String? ?? '').trim(),
    );
    return _json(result);
  });

  return router;
}
