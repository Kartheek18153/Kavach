import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Guardian contact kept in memory for this session.
/// Persisted across app restarts via SharedPreferences.
class GuardianStore {
  static String name = '';
  static String phone = '';
  static String safeWord = '';

  /// Key used for persistent storage.
  static const String _keyName = 'kavach_guardian_name';
  static const String _keyPhone = 'kavach_guardian_phone';
  static const String _keySafeWord = 'kavach_guardian_safe_word';

  /// Loads persisted guardian data. Call once at app startup (main.dart).
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    name = prefs.getString(_keyName) ?? '';
    phone = prefs.getString(_keyPhone) ?? '';
    safeWord = prefs.getString(_keySafeWord) ?? '';
  }

  /// Saves all guardian fields to disk (phone stored normalized).
  static Future<void> save() async {
    phone = normalizePhone(phone);
    safeWord = safeWord.trim().toUpperCase();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyName, name);
    await prefs.setString(_keyPhone, phone);
    await prefs.setString(_keySafeWord, safeWord);
  }

  /// True when a usable family contact exists (survives restarts).
  static bool get isConnected =>
      isValidName(name) && isValidPhone(phone);

  /// Strips spaces/dashes, drops leading +91/91/0. Returns 10 digits or ''.
  static String normalizePhone(String raw) {
    var d = raw.replaceAll(RegExp(r'\D'), '');
    if (d.length == 12 && d.startsWith('91')) d = d.substring(2);
    if (d.length == 11 && d.startsWith('0')) d = d.substring(1);
    return d;
  }

  /// Valid Indian mobile: 10 digits starting 6-9.
  static bool isValidPhone(String raw) {
    final d = normalizePhone(raw);
    return d.length == 10 && RegExp(r'^[6-9]').hasMatch(d);
  }

  /// Pretty display: '+91 98765 43210' for stored 10-digit numbers.
  static String displayPhone(String stored) {
    final d = normalizePhone(stored);
    if (d.length != 10) return stored;
    return '+91 ${d.substring(0, 5)} ${d.substring(5)}';
  }

  static bool isValidName(String v) => v.trim().length >= 2;

  /// One word, 4+ letters — easy to say on a call, hard to guess.
  static bool isValidSafeWord(String v) {
    final t = v.trim();
    return t.length >= 4 && !t.contains(RegExp(r'\s'));
  }

  /// Clears all persisted data.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyName);
    await prefs.remove(_keyPhone);
    await prefs.remove(_keySafeWord);
    name = phone = safeWord = '';
  }
}

/// Call history: last 20 reports persisted as JSON.
class HistoryStore {
  static const _key = 'kavach_history_v1';
  static List<Map<String, dynamic>> entries = [];

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) {
      entries = [];
      return;
    }
    try {
      final list = jsonDecode(raw) as List;
      entries = list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      entries = [];
    }
  }

  static Future<void> add(Map<String, dynamic> summary) async {
    Map<String, dynamic> strMap(Object? v) {
      if (v is Map) {
        return v.map((k, e) => MapEntry('$k', e));
      }
      return {};
    }

    final entry = <String, dynamic>{
      'ts': DateTime.now().toIso8601String(),
      'scamType': '${summary['scamType'] ?? '-'}',
      'risk': (summary['risk'] as num? ?? 0).toInt(),
      'level': _levelName(summary['level']),
      'band': '${summary['band'] ?? _levelName(summary['level'])}',
      'reasons': ((summary['reasons'] as List?) ?? const []).take(5).toList(),
      'reasonsTelugu': '${summary['reasonsTelugu'] ?? ''}',
      'alerted': summary['alerted'] == true,
      'elapsedSec': (summary['elapsedSec'] as num? ?? 0).toInt(),
      'lines': (summary['lines'] as num? ?? 0).toInt(),
      'demo': summary['isDemo'] == true,
      'smsSent': summary['smsSent'] == true,
      'families': ((summary['families'] as List?) ?? const [])
          .map((e) => '$e')
          .toList(),
      'evidence': strMap(summary['evidence']).map(
          (k, v) => MapEntry(k, ((v as List?) ?? const []).map((e) => '$e').toList())),
      'capped': strMap(summary['capped']).map(
          (k, v) => MapEntry(k, (v as num? ?? 0).toDouble())),
      'bonus': (summary['bonus'] as num? ?? 0).toInt(),
      'guardDelta': (summary['guardDelta'] as num? ?? 0).toDouble(),
    };
    entries = [entry, ...entries].take(20).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(entries));
  }

  static String _levelName(Object? level) {
    final s = '$level';
    if (s.contains('danger')) return 'danger';
    if (s.contains('caution')) return 'caution';
    return 'safe';
  }

  /// Wipes the stored call history (device only).
  static Future<void> clearHistory() async {
    entries = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static String get _month => DateTime.now().toIso8601String().substring(0, 7);

  static Iterable<Map<String, dynamic>> get _live =>
      entries.where((e) => e['demo'] != true);

  static bool _thisMonth(Map<String, dynamic> e) =>
      '${e['ts'] ?? ''}'.startsWith(_month);

  /// Live danger hits this month — the scoreboard number.
  static int get monthDangers =>
      _live.where((e) => e['level'] == 'danger' && _thisMonth(e)).length;

  /// Worst live risk this month (0 when none).
  static int get monthWorst {
    var w = 0;
    for (final e in _live) {
      if (_thisMonth(e)) {
        final r = (e['risk'] as num? ?? 0).toInt();
        if (r > w) w = r;
      }
    }
    return w;
  }
}

/// Thin client for the CyberSafe backend (`backend/`).
///
/// Point at your backend at build time:
///   Android emulator: `--dart-define=CYBERSAFE_API=http://10.0.2.2:8080`
///   Real device:      `--dart-define=CYBERSAFE_API=http://<PC-LAN-IP>:8080`
/// Every call fails soft so the app keeps working offline with the
/// built-in local rule engine.
class CyberSafeApi {
  static const baseUrl = String.fromEnvironment(
    'CYBERSAFE_API',
    defaultValue: 'http://localhost:8080',
  );

  /// Scores one transcript line server-side.
  /// Returns `{points, groups}` or null when unreachable.
  static Future<Map<String, dynamic>?> scoreLine(String text) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/score'),
            headers: {'content-type': 'application/json'},
            body: jsonEncode({
              'text': text,
              if (GuardianStore.safeWord.trim().isNotEmpty)
                'safeWord': GuardianStore.safeWord.trim(),
            }),
          )
          .timeout(const Duration(seconds: 3));
      if (res.statusCode != 200) return null;
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Starts a stateful scoring session. Returns sessionId or null offline.
  static Future<String?> startSession({required bool isScam}) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/session/start'),
            headers: {'content-type': 'application/json'},
            body: jsonEncode({'mode': isScam ? 'scam' : 'normal'}),
          )
          .timeout(const Duration(seconds: 3));
      if (res.statusCode != 200) return null;
      final m = jsonDecode(res.body) as Map<String, dynamic>;
      return m['sessionId'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Scores inside a session. Returns full server state or null offline.
  static Future<Map<String, dynamic>?> scoreInSession({
    required String sessionId,
    required String text,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/score'),
            headers: {'content-type': 'application/json'},
            body: jsonEncode({
              'sessionId': sessionId,
              'text': text,
              if (GuardianStore.safeWord.trim().isNotEmpty)
                'safeWord': GuardianStore.safeWord.trim(),
            }),
          )
          .timeout(const Duration(seconds: 3));
      if (res.statusCode != 200) return null;
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Ends a session. Returns summary or null offline.
  static Future<Map<String, dynamic>?> endSession(String sessionId) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/session/end'),
            headers: {'content-type': 'application/json'},
            body: jsonEncode({'sessionId': sessionId}),
          )
          .timeout(const Duration(seconds: 3));
      if (res.statusCode != 200) return null;
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// True when the backend answers /health.
  static Future<bool> ping() async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 3));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
