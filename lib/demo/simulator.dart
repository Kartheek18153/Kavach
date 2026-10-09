import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../services/api.dart';
import '../services/tactic_engine.dart';
import '../theme.dart';

/// One line of call transcript.
/// [points] is kept for fixture readability only - live scoring always runs
/// the Tier-1 tactic engine over [text].
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
  final bool isDemo;

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
    this.isDemo = true,
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
    bool? isDemo,
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
      isDemo: isDemo ?? this.isDemo,
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
  late TacticSession _tactics;
  final Set<String> _seenFamilies = {};
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

  /// Local scoring runs the Tier-1 tactic engine (tactic_engine.dart) -
  /// same lexicon, decay and diversity rule as the backend.
  void startScam() => _start(scamScript, isScam: true);

  void startNormal() => _start(normalScript, isScam: false);

  /// Real protection mode: empty transcript waiting for live words
  /// (typed now, mic later). Never auto-finishes — ends on stop/reset.
  void startReal() => _start(const [], isScam: true, demo: false);

  void _start(List<ScriptLine> script,
      {required bool isScam, bool demo = true}) {
    _timer?.cancel();
    _endSessionFireForget();
    _script = script;
    _cursor = 0;
    _tick = 0;
    _tactics = TacticSession();
    _seenFamilies.clear();
    _demoScam = isScam;
    _sessionId = null;
    _seenFamilies.clear();
    _state = DemoState(running: true, isDemo: demo);
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
    final nowMs = elapsed * 1000;

    // New transcript chunk roughly every 2 seconds (3-4 sec audio windows).
    if (_tick.isEven && _cursor < _script.length) {
      final s = _script[_cursor];
      _cursor++;
      // Prefer stateful backend session; then stateless; then local engine.
      final sid = _sessionId;
      if (sid != null) {
        final st = await KavachApi.scoreInSession(sessionId: sid, text: s.text);
        if (st != null) {
          final r = (st['risk'] as num?)?.toInt() ?? _state.risk;
          final synced = (st['reasons'] as List? ?? const []).map((e) => '$e').toList();
          // Keep the local engine fed so offline fallback stays continuous.
          _tactics.addWindow(s.text, nowMs);
          _seenFamilies
              .addAll(_tactics.scoreAt(nowMs).families);
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
      int newSignals;
      if (remote != null) {
        newSignals = (remote['points'] as num?)?.toInt() ?? 0;
        for (final g in (remote['groups'] as List? ?? const [])) {
          _seenFamilies.add(g as String);
        }
        _tactics.addWindow(s.text, nowMs);
      } else {
        newSignals = _tactics.addWindow(s.text, nowMs);
      }
      lines = [...lines, TranscriptLine(s.text, flagged: newSignals > 0)];
      final snap = _tactics.scoreAt(nowMs);
      _seenFamilies.addAll(snap.families);
      risk = snap.score;
      if (_safeWordHit(s.text)) risk = (risk - 20).clamp(0, 100);
    }

    final level = riskLevelFor(risk);
    final alerted = _state.alerted || level == RiskLevel.danger;
    // Real mode stays live until the user ends it; demos finish the script.
    final done = _state.isDemo && _cursor >= _script.length;
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

  String _scamType() =>
      scamTypeForFamilies(_seenFamilies, isScam: _demoScam);

  List<String> _reasons() => reasonsForFamilies(_seenFamilies);

  String _reasonsTelugu() => reasonsTeluguForFamilies(_seenFamilies);

  /// Scores a manually typed line (fallback box when mic/audio fails).
  Future<void> analyzeText(String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    final sid = _sessionId;
    final nowMs = _state.elapsedSec * 1000;
    if (sid != null) {
      final st = await KavachApi.scoreInSession(sessionId: sid, text: t);
      if (st != null) {
        _tactics.addWindow(t, nowMs);
        _seenFamilies.addAll(_tactics.scoreAt(nowMs).families);
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
    int newSignals;
    if (remote != null) {
      newSignals = (remote['points'] as num?)?.toInt() ?? 0;
      for (final g in (remote['groups'] as List? ?? const [])) {
        _seenFamilies.add(g as String);
      }
      _tactics.addWindow(t, nowMs);
    } else {
      newSignals = _tactics.addWindow(t, nowMs);
    }
    final snap = _tactics.scoreAt(nowMs);
    _seenFamilies.addAll(snap.families);
    var risk = snap.score;
    if (_safeWordHit(t)) risk = (risk - 20).clamp(0, 100);
    final level = riskLevelFor(risk);
    _state = _state.copyWith(
      lines: [..._state.lines, TranscriptLine(t, flagged: newSignals > 0)],
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
    _tactics = TacticSession();
    _seenFamilies.clear();
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
