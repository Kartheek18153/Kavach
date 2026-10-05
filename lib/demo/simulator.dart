import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../services/api.dart';
import '../theme.dart';

/// One line of call transcript with a pre-scored danger weight.
class ScriptLine {
  final String text;
  final int points;
  const ScriptLine(this.text, this.points);
}

/// A line shown in the live transcript.
class TranscriptLine {
  final String text;
  final bool flagged;
  const TranscriptLine(this.text, {this.flagged = false});
}

/// Immutable snapshot of the demo session, pushed via [DemoSession.state].
class DemoState {
  final List<TranscriptLine> lines;
  final int risk;
  final RiskLevel level;
  final String scamType;
  final List<String> reasons;
  final String reasonsTelugu;
  final bool alerted;
  final bool running;
  final bool finished;
  final int elapsedSec;

  const DemoState({
    this.lines = const [],
    this.risk = 0,
    this.level = RiskLevel.safe,
    this.scamType = '-',
    this.reasons = const [],
    this.reasonsTelugu = '',
    this.alerted = false,
    this.running = false,
    this.finished = false,
    this.elapsedSec = 0,
  });

  DemoState copyWith({
    List<TranscriptLine>? lines,
    int? risk,
    RiskLevel? level,
    String? scamType,
    List<String>? reasons,
    String? reasonsTelugu,
    bool? alerted,
    bool? running,
    bool? finished,
    int? elapsedSec,
  }) {
    return DemoState(
      lines: lines ?? this.lines,
      risk: risk ?? this.risk,
      level: level ?? this.level,
      scamType: scamType ?? this.scamType,
      reasons: reasons ?? this.reasons,
      reasonsTelugu: reasonsTelugu ?? this.reasonsTelugu,
      alerted: alerted ?? this.alerted,
      running: running ?? this.running,
      finished: finished ?? this.finished,
      elapsedSec: elapsedSec ?? this.elapsedSec,
    );
  }
}

/// Drives the hackathon demo without a real backend: feeds scripted
/// transcript lines on a timer and scores them like the rule engine.
class DemoSession extends ChangeNotifier implements ValueListenable<DemoState> {
  DemoState _state = const DemoState();
  DemoState get state => _state;
  @override
  DemoState get value => _state;
  ValueListenable<DemoState> get listenable => this;

  Timer? _timer;
  List<ScriptLine> _script = const [];
  int _cursor = 0;
  int _tick = 0;
  final Set<String> _seen = {};
  bool _demoScam = true;
  String? _sessionId;

  /// Notifies listeners outside the build phase so timer ticks that land
  /// mid-transition (tab switches) never throw "called during build".
  void _safeNotify() {
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      notifyListeners();
    } else {
      SchedulerBinding.instance
          .addPostFrameCallback((_) => notifyListeners());
    }
  }

  static const List<ScriptLine> scamScript = [
    ScriptLine('Hello, nenu Mumbai CBI office nundi matladutunnanu.', 20),
    ScriptLine('Mee Aadhaar number tho oka parcel customs lo dhorikindi.', 15),
    ScriptLine('Mee peru meeda money-laundering case register ayyindi.', 25),
    ScriptLine('Phone cut cheyyakandi, evariki cheppakandi, secret ga unchandi.', 25),
    ScriptLine('One hour lo arrest warrant vastundi, ventane verify cheyyali.', 20),
    ScriptLine('Mee bank OTP cheppandi, account verify chestam.', 35),
    ScriptLine('AnyDesk app install chesi screen share cheyyandi.', 35),
    ScriptLine('Safe account ki ₹50,000 transfer cheyyandi, malli refund vastundi.', 30),
    ScriptLine('Mee UPI PIN enter cheyyandi verification kosam.', 35),
    ScriptLine('Evarikaina cheppithe case peddadi avutundi, jail ki velataru.', 25),
    ScriptLine('Time ledu, ippude cheyyandi, immediately!', 10),
  ];

  static const List<ScriptLine> normalScript = [
    ScriptLine('Namaste sir, nenu delivery boy ni, mee parcel vachindi.', 0),
    ScriptLine('Address confirm cheyyandi, mee gate number enti?', 0),
    ScriptLine('Mee intlo evaru unnaru? Parcel kinda icheda?', 0),
    ScriptLine('Delivery OTP vachinda sir? Door daggara unnanu.', 5),
    ScriptLine('Thank you sir, delivery complete ayyindi.', 0),
  ];

  /// Keyword groups mirroring the backend rule engine, for typed input.
  /// KEEP IN SYNC with backend/lib/engine.dart (same names, points, words,
  /// thresholds 31/61, hard-trigger, safe-word -20).
  static const List<(String, int, List<String>)> keywordGroups = [
    ('authority', 20, ['cbi', 'police', 'customs', 'trai', 'rbi', 'court', 'officer']),
    ('threat', 25, ['arrest', 'warrant', 'case', 'jail', 'legal']),
    ('secrecy', 25, ['secret', 'cheppakandi', 'cut cheyyakandi', 'disconnect']),
    ('urgency', 10, ['immediately', 'ippude', 'one hour', 'tonight', 'ventane']),
    ('sensitive', 35, ['otp', 'pin', 'cvv', 'aadhaar', 'aadhar', 'password', 'card']),
    ('remote', 35, ['anydesk', 'teamviewer', 'screen share', 'screen']),
    ('money', 30, ['safe account', 'transfer', 'refund', 'upi', '₹', 'rs.']),
  ];

  void startScam() => _start(scamScript, isScam: true);

  void startNormal() => _start(normalScript, isScam: false);

  void _start(List<ScriptLine> script, {required bool isScam}) {
    _timer?.cancel();
    _endSessionFireForget();
    _script = script;
    _cursor = 0;
    _tick = 0;
    _seen.clear();
    _demoScam = isScam;
    _sessionId = null;
    _state = const DemoState(running: true);
    _safeNotify();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    // Open a stateful backend session when reachable; ticks fall back
    // to local scoring until the id arrives.
    KavachApi.startSession(isScam: isScam).then((id) {
      if (id != null && _state.running) _sessionId = id;
    });
  }

  void _endSessionFireForget() {
    final id = _sessionId;
    _sessionId = null;
    if (id != null) KavachApi.endSession(id);
  }

  bool _safeWordHit(String text) {
    final w = GuardianStore.safeWord.trim().toLowerCase();
    if (w.isEmpty) return false;
    return text.toLowerCase().contains(w);
  }

  void _onTick() async {
    if (!_state.running) return;
    _tick++;
    final elapsed = _state.elapsedSec + 1;
    List<TranscriptLine> lines = _state.lines;
    int risk = _state.risk;

    // New transcript chunk roughly every 2 seconds (3-4 sec audio windows).
    if (_tick.isEven && _cursor < _script.length) {
      final s = _script[_cursor];
      _cursor++;
      // Prefer stateful backend session; then stateless; then local rules.
      final sid = _sessionId;
      if (sid != null) {
        final st = await KavachApi.scoreInSession(sessionId: sid, text: s.text);
        if (st != null) {
          final r = (st['risk'] as num?)?.toInt() ?? _state.risk;
          final synced = (st['reasons'] as List? ?? const []).map((e) => '$e').toList();
          // Keep local _seen roughly in sync for offline fallback continuity.
          _noteScriptGroups(s.text);
          lines = [...lines, TranscriptLine(s.text, flagged: ((st['points'] as num?)?.toInt() ?? 0) > 0)];
          risk = r;
          final lvl = riskLevelFor(risk);
          final doneEarly = _cursor >= _script.length;
          _state = _state.copyWith(
            lines: lines,
            risk: risk,
            level: lvl,
            scamType: '${st['scamType'] ?? _scamType()}',
            reasons: synced.isNotEmpty ? synced : _reasons(),
            reasonsTelugu: '${st['reasonsTelugu'] ?? _reasonsTelugu()}',
            alerted: (st['alerted'] == true) || _state.alerted || lvl == RiskLevel.danger,
            running: !doneEarly,
            finished: doneEarly,
            elapsedSec: elapsed,
          );
          _safeNotify();
          if (doneEarly) _timer?.cancel();
          return;
        }
      }
      final remote = await KavachApi.scoreLine(s.text);
      int points;
      if (remote != null) {
        points = (remote['points'] as num?)?.toInt() ?? 0;
        for (final g in (remote['groups'] as List? ?? const [])) {
          _seen.add(g as String);
        }
      } else {
        points = s.points;
        _noteScriptGroups(s.text);
      }
      lines = [...lines, TranscriptLine(s.text, flagged: points > 0)];
      risk = (_state.risk + points).clamp(0, 100);
      if (_safeWordHit(s.text)) risk = (risk - 20).clamp(0, 100);
      if (_hardTriggered()) risk = risk < 85 ? 85 : risk;
    }

    final level = riskLevelFor(risk);
    final alerted = _state.alerted || level == RiskLevel.danger;
    final done = _cursor >= _script.length;
    _state = _state.copyWith(
      lines: lines,
      risk: risk,
      level: level,
      scamType: _scamType(),
      reasons: _reasons(),
      reasonsTelugu: _reasonsTelugu(),
      alerted: alerted,
      running: !done,
      finished: done,
      elapsedSec: elapsed,
    );
    _safeNotify();
    if (done) _timer?.cancel();
  }

  void _noteScriptGroups(String text) {
    final t = text.toLowerCase();
    for (final (name, _, words) in keywordGroups) {
      if (words.any(t.contains)) _seen.add(name);
    }
  }

  bool _hardTriggered() {
    final s = _seen;
    return (s.contains('authority') &&
            (s.contains('sensitive') || s.contains('money'))) ||
        (s.contains('secrecy') && s.contains('money'));
  }

  String _scamType() {
    if (_seen.contains('authority')) return 'Fake police / Digital arrest';
    if (_seen.contains('remote')) return 'Screen-share fraud';
    if (_seen.contains('sensitive') || _seen.contains('money')) {
      return _demoScam ? 'Bank / OTP fraud' : 'Checking...';
    }
    if (_seen.isEmpty) return '-';
    return 'Suspicious pattern';
  }

  String _groupReason(String name) {
    switch (name) {
      case 'authority':
        return 'Caller claims to be police / CBI / customs';
      case 'threat':
        return 'Threatens arrest or legal action';
      case 'secrecy':
        return 'Tells you to keep the call secret';
      case 'urgency':
        return 'Creates false urgency ("right now")';
      case 'sensitive':
        return 'Asks for OTP / PIN / Aadhaar';
      case 'remote':
        return 'Asks to install a screen-sharing app';
      case 'money':
        return 'Asks to transfer money / UPI';
      default:
        return name;
    }
  }

  List<String> _reasons() =>
      _seen.map(_groupReason).toList(growable: false);

  String _reasonsTelugu() {
    if (_seen.isEmpty) return '';
    if (_seen.contains('authority') && _seen.contains('sensitive')) {
      return 'Ee caller police ani cheppi OTP adugutunnadu. Idi scam - phone cut cheyyandi.';
    }
    if (_seen.contains('authority')) {
      return 'Ee caller police / CBI ani cheptunnadu. Nijamaina police phone lo threat cheyyaru.';
    }
    if (_seen.contains('sensitive') || _seen.contains('money')) {
      return 'OTP / PIN / dabbulu adige call scam ayyundavachu. Evariki cheppakandi ani ante inka danger.';
    }
    if (_seen.contains('remote')) {
      return 'Screen share app install cheyamante cheppakandi. Idi scam trick.';
    }
    return 'Konchem anumananga undi - jagratta ga undandi.';
  }

  /// Scores a manually typed line (fallback box when mic/audio fails).
  Future<void> analyzeText(String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    final sid = _sessionId;
    if (sid != null) {
      final st = await KavachApi.scoreInSession(sessionId: sid, text: t);
      if (st != null) {
        _noteScriptGroups(t);
        final r = (st['risk'] as num?)?.toInt() ?? _state.risk;
        final lvl = riskLevelFor(r);
        _state = _state.copyWith(
          lines: [..._state.lines,
            TranscriptLine(t, flagged: ((st['points'] as num?)?.toInt() ?? 0) > 0)],
          risk: r,
          level: lvl,
          scamType: '${st['scamType'] ?? _scamType()}',
          reasons: ((st['reasons'] as List?) ?? const []).map((e) => '$e').toList(),
          reasonsTelugu: '${st['reasonsTelugu'] ?? _reasonsTelugu()}',
          alerted: (st['alerted'] == true) || _state.alerted || lvl == RiskLevel.danger,
        );
        _safeNotify();
        return;
      }
    }
    final remote = await KavachApi.scoreLine(t);
    int gained = 0;
    if (remote != null) {
      gained = (remote['points'] as num?)?.toInt() ?? 0;
      for (final g in (remote['groups'] as List? ?? const [])) {
        _seen.add(g as String);
      }
    } else {
      final lower = t.toLowerCase();
      for (final (name, pts, words) in keywordGroups) {
        if (!_seen.contains(name) && words.any(lower.contains)) {
          _seen.add(name);
          gained += pts;
        }
      }
    }
    var risk = (_state.risk + gained).clamp(0, 100);
    if (_safeWordHit(t)) risk = (risk - 20).clamp(0, 100);
    if (_hardTriggered() && risk < 85) risk = 85;
    final level = riskLevelFor(risk);
    _state = _state.copyWith(
      lines: [..._state.lines, TranscriptLine(t, flagged: gained > 0)],
      risk: risk,
      level: level,
      scamType: _scamType(),
      reasons: _reasons(),
      reasonsTelugu: _reasonsTelugu(),
      alerted: _state.alerted || level == RiskLevel.danger,
    );
    _safeNotify();
  }

  void stop() {
    _timer?.cancel();
    _endSessionFireForget();
    // Privacy: drop the live transcript the moment the call ends -
    // Kavach listens, it never records.
    _state = _state.copyWith(
        running: false, finished: true, lines: const []);
    _safeNotify();
  }

  void reset() {
    _timer?.cancel();
    _endSessionFireForget();
    _seen.clear();
    _state = const DemoState();
    _safeNotify();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _endSessionFireForget();
    super.dispose();
  }
}
