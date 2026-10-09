import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// One saved Scan-tool result (URL / QR / UPI / SIM / SMS).
class ScanRecord {
  final String kind; // 'url' | 'qr' | 'upi' | 'sim' | 'sms'
  final String input;
  final int risk;
  final String level; // 'safe' | 'caution' | 'danger'
  final List<String> reasons;
  final String ts; // ISO-8601

  const ScanRecord({
    required this.kind,
    required this.input,
    required this.risk,
    required this.level,
    required this.reasons,
    required this.ts,
  });

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'input': input,
        'risk': risk,
        'level': level,
        'reasons': reasons,
        'ts': ts,
      };

  static ScanRecord fromJson(Map<String, dynamic> m) => ScanRecord(
        kind: '${m['kind'] ?? '?'}',
        input: '${m['input'] ?? ''}',
        risk: (m['risk'] as num? ?? 0).toInt(),
        level: '${m['level'] ?? 'safe'}',
        reasons: ((m['reasons'] as List?) ?? const [])
            .map((e) => '$e')
            .toList(),
        ts: '${m['ts'] ?? ''}',
      );
}

/// Persisted scan history (newest first, capped at 50).
class ScanHistoryStore {
  static const _key = 'kavach_scan_history_v1';
  static List<ScanRecord> entries = [];

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) {
      entries = [];
      return;
    }
    try {
      final list = jsonDecode(raw) as List;
      entries = list
          .whereType<Map>()
          .map((e) => ScanRecord.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      entries = [];
    }
  }

  static Future<void> add(ScanRecord r) async {
    entries = [r, ...entries].take(50).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(entries.map((e) => e.toJson()).toList()));
  }

  static Future<void> clear() async {
    entries = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static String get _month => DateTime.now().toIso8601String().substring(0, 7);

  static bool _thisMonth(ScanRecord e) => e.ts.startsWith(_month);

  static int get monthScans => entries.where(_thisMonth).length;

  static int get monthDangers =>
      entries.where((e) => e.level == 'danger' && _thisMonth(e)).length;

  static int get monthWorst {
    var w = 0;
    for (final e in entries) {
      if (_thisMonth(e) && e.risk > w) w = e.risk;
    }
    return w;
  }
}
