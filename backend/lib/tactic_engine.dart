/// KAVACH Tier-1 tactic engine: deterministic on-device scam scoring.
///
/// Port of the Tier-1 engine from KAVACH_IQOO (Atul Chahar & Anant Sharma,
/// Apache-2.0): 5 tactic families, ~180 trilingual markers (EN / romanised
/// Hinglish / Devanagari), 40 negative guards, per-family caps, exponential
/// time decay (120 s half-life) and the family-diversity rule.
///
/// Two deliberate adaptations to this project (documented, not hidden):
/// - Bands stay the app's Safe 0-30 / Caution 31-60 / Danger 61+.
/// - DANGER additionally requires >= 3 distinct families (their HIGH_RISK
///   rule); a loud single family caps at 60, exactly like their 69-cap
///   under HIGH_RISK.
///
/// Pure Dart, no Flutter imports. This file is IDENTICAL in
/// lib/services/tactic_engine.dart and backend/lib/tactic_engine.dart -
/// KEEP IN SYNC. Data comes from the generated tactic_lexicon_data.dart.
library;

import 'dart:math' as math;

import 'tactic_lexicon_data.dart';

/// Scoring constants (mirror data/tactic_lexicon.json `scoring`).
const int tacticDecayHalfLifeMs = 120 * 1000;
const int tacticPruneHorizonMs = 8 * tacticDecayHalfLifeMs;
const int tacticDiversityBonus = 15;
const int tacticMinFamiliesForDanger = 3;
const int tacticDangerFloor = 61;
const int tacticCautionFloor = 31;
const int tacticSingleFamilyCap = 60;

/// Guard signals are filed under this pseudo-family (never counts as a
/// detection family, never earns the diversity bonus).
const String guardFamilyId = 'NEGATIVE_GUARD';

/// Normalises text exactly like the reference TranscriptNormalizer:
/// lowercase, Devanagari digits to ASCII, drop [.''], the rest of the
/// punctuation set to spaces, collapse whitespace.
String normalizeTranscript(String raw) {
  final lower = raw.toLowerCase();
  final buf = StringBuffer();
  for (final rune in lower.runes) {
    if (rune >= 0x0966 && rune <= 0x096F) {
      buf.writeCharCode(0x30 + (rune - 0x0966));
    } else if (rune == 0x27 || rune == 0x2E || rune == 0x2019) {
      // ' . ' - deleted outright (O.T.P. -> otp).
    } else if (rune == 0x2C || // ,
        rune == 0x21 || // !
        rune == 0x3F || // ?
        rune == 0x3B || // ;
        rune == 0x3A || // :
        rune == 0x22 || // "
        rune == 0x28 || // (
        rune == 0x29 || // )
        rune == 0x2026 || // …
        rune == 0x2014 || // —
        rune == 0x2013 || // –
        rune == 0x2212 || // −
        rune == 0x0964 || // । danda
        rune == 0x2D) {
      // -
      buf.write(' ');
    } else {
      buf.writeCharCode(rune);
    }
  }
  return buf.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

final _letterOrDigit = RegExp(r'[\p{L}\p{N}]', unicode: true);

bool _isWordChar(String ch) => _letterOrDigit.hasMatch(ch);

/// One compiled marker: normalised text, weight, family (or guard id).
class _CompiledMarker {
  final String text;
  final int weight;
  final String family;
  const _CompiledMarker(this.text, this.weight, this.family);
}

List<_CompiledMarker>? _compiled;

/// Longest-first compiled marker list (detection + guards together).
List<_CompiledMarker> _markers() {
  final cached = _compiled;
  if (cached != null) return cached;
  final out = <_CompiledMarker>[];
  for (final f in tacticFamilies) {
    for (final m in f.markers) {
      final t = normalizeTranscript(m.t);
      if (t.isNotEmpty) out.add(_CompiledMarker(t, m.w, f.id));
    }
  }
  for (final g in negativeGuards) {
    final t = normalizeTranscript(g.t);
    if (t.isNotEmpty) out.add(_CompiledMarker(t, g.w, guardFamilyId));
  }
  out.sort((a, b) => b.text.length.compareTo(a.text.length));
  _compiled = out;
  return out;
}

/// A single matched occurrence.
class TacticSignal {
  final String family;
  final int weight;
  final String span;
  final int tsMs;
  const TacticSignal(this.family, this.weight, this.span, this.tsMs);
}

/// Snapshot of the session at one moment.
class TacticScore {
  final int score;
  final Set<String> families;
  final Map<String, List<String>> evidence;
  final String band; // 'safe' | 'caution' | 'danger' (app thresholds)

  const TacticScore(this.score, this.families, this.evidence, this.band);
}

/// Stateful session: feed transcript windows, read decayed scores.
class TacticSession {
  final List<TacticSignal> _signals = [];
  final Map<String, int> _seenKeys = {};

  /// Matches [text] and records new (family|span) signals at [nowMs].
  /// Returns the number of newly recorded signals.
  int addWindow(String text, int nowMs) {
    final norm = normalizeTranscript(text);
    if (norm.isEmpty) return 0;
    final claimed = List<bool>.filled(norm.length, false);
    var added = 0;
    for (final m in _markers()) {
      var from = 0;
      while (true) {
        final idx = norm.indexOf(m.text, from);
        if (idx < 0) break;
        from = idx + 1;
        final end = idx + m.text.length;
        var overlapped = false;
        for (var i = idx; i < end; i++) {
          if (claimed[i]) {
            overlapped = true;
            break;
          }
        }
        if (overlapped) continue;
        if (idx > 0 && _isWordChar(norm[idx - 1])) continue;
        if (end < norm.length && _isWordChar(norm[end])) continue;
        for (var i = idx; i < end; i++) {
          claimed[i] = true;
        }
        final key = '${m.family}|${m.text}';
        if (!_seenKeys.containsKey(key)) {
          _seenKeys[key] = nowMs;
          _signals.add(TacticSignal(m.family, m.weight, m.text, nowMs));
          added++;
        }
      }
    }
    return added;
  }

  /// Scores all live signals at [nowMs] with decay, caps, guards and the
  /// diversity rule. Prunes anything older than the horizon.
  TacticScore scoreAt(int nowMs) {
    _signals.removeWhere((s) => nowMs - s.tsMs > tacticPruneHorizonMs);
    _seenKeys.removeWhere((_, ts) => nowMs - ts > tacticPruneHorizonMs);

    final familySum = <String, double>{};
    final evidence = <String, List<String>>{};
    var guards = 0.0;
    for (final s in _signals) {
      final ageMs = math.max(0, nowMs - s.tsMs);
      final decayed = s.weight * math.pow(0.5, ageMs / tacticDecayHalfLifeMs);
      if (s.family == guardFamilyId) {
        guards += decayed;
        continue;
      }
      familySum[s.family] = (familySum[s.family] ?? 0) + decayed;
      (evidence[s.family] ??= []).add(s.span);
    }
    var total = 0.0;
    var distinct = 0;
    for (final f in tacticFamilies) {
      final sum = familySum[f.id] ?? 0;
      if (sum > 0) distinct++;
      total += math.min(f.cap.toDouble(), sum);
    }
    total += tacticDiversityBonus * math.max(0, distinct - 2);
    total += guards;
    var score = total.clamp(0, 100).toInt();
    if (score >= tacticDangerFloor &&
        distinct < tacticMinFamiliesForDanger) {
      score = tacticSingleFamilyCap;
    }
    final band = score >= tacticDangerFloor
        ? 'danger'
        : score >= tacticCautionFloor
            ? 'caution'
            : 'safe';
    return TacticScore(score, familySum.keys.toSet(), evidence, band);
  }

  /// Stateless one-shot score (SMS path): whole text as a single window.
  static TacticScore scoreTextOnce(String text) {
    final session = TacticSession();
    session.addWindow(text, 0);
    return session.scoreAt(0);
  }
}

/// English label for a tactic family id.
String familyDisplayEn(String id) {
  for (final f in tacticFamilies) {
    if (f.id == id) return f.displayEn;
  }
  return id;
}

/// Scam-type headline from matched families (drives report + history).
String scamTypeForFamilies(Set<String> families, {required bool isScam}) {
  if (families.contains('AUTHORITY_IMPERSONATION')) {
    return 'Fake police / Digital arrest';
  }
  if (families.contains('REMOTE_ACCESS_AND_TRANSFER')) return 'Screen-share fraud';
  if (families.contains('CREDENTIAL_EXTRACTION')) {
    return isScam ? 'Bank / OTP fraud' : 'Checking...';
  }
  if (families.isEmpty) return '-';
  return 'Suspicious pattern';
}

/// One verdict reason per matched family.
List<String> reasonsForFamilies(Set<String> families) =>
    families.map(familyDisplayEn).toList(growable: false);

/// Telugu verdict summary keyed on families (same voice as the old engine).
String reasonsTeluguForFamilies(Set<String> families) {
  if (families.isEmpty) return '';
  if (families.contains('AUTHORITY_IMPERSONATION') &&
      families.contains('CREDENTIAL_EXTRACTION')) {
    return 'Ee caller police ani cheppi OTP adugutunnadu. Idi scam - phone cut cheyyandi.';
  }
  if (families.contains('AUTHORITY_IMPERSONATION')) {
    return 'Ee caller police / CBI ani cheptunnadu. Nijamaina police phone lo threat cheyyaru.';
  }
  if (families.contains('CREDENTIAL_EXTRACTION') ||
      families.contains('REMOTE_ACCESS_AND_TRANSFER')) {
    return 'OTP / PIN / dabbulu adige call scam ayyundavachu. Evariki cheppakandi ani ante inka danger.';
  }
  return 'Konchem anumananga undi - jagratta ga undandi.';
}
