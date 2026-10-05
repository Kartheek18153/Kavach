import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../demo/simulator.dart';
import '../lang.dart';
import '../services/api.dart';
import '../theme.dart';
import '../widgets/cards.dart';
import '../widgets/danger_meter.dart';
import '../widgets/transcript_list.dart';
import '../widgets/waveform.dart';

/// Live protection: meter, waveform, transcript, reasons, typed fallback.
/// Shows a full-screen red overlay + vibration on danger.
class LiveScreen extends StatefulWidget {
  final DemoSession session;
  final void Function(Map<String, dynamic> summary) onFinish;

  const LiveScreen({super.key, required this.session, required this.onFinish});

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  RiskLevel _prevLevel = RiskLevel.safe;
  bool _prevRunning = false;
  bool _snackedAlert = false;
  bool _smsOpened = false;
  bool _overlayDismissed = false;
  String? _dismissedSig;
  final _typed = TextEditingController();
  final _alarm = AudioPlayer();
  bool _alarmPlaying = false;

  @override
  void dispose() {
    _typed.dispose();
    _alarm.dispose();
    super.dispose();
  }

  static String _sig(DemoState s) => '${s.risk}|${s.reasons.join(';')}';

  void _watchLevel(DemoState s) {
    if (s.level == RiskLevel.danger && _prevLevel != RiskLevel.danger) {
      HapticFeedback.vibrate();
      _overlayDismissed = false;
      _dismissedSig = null;
    }
    // New tricks while dismissed re-raise the overlay + alarm.
    if (s.level == RiskLevel.danger &&
        s.running &&
        _overlayDismissed &&
        _dismissedSig != _sig(s)) {
      HapticFeedback.vibrate();
      _overlayDismissed = false;
      _dismissedSig = null;
    }
    if (s.alerted && !_snackedAlert) {
      _snackedAlert = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: KavachColors.danger,
            content: Text(context.tr('dangerNow'),
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        );
      });
    }
    _prevLevel = s.level;
    if (s.running && !_prevRunning) _smsOpened = false;
    _prevRunning = s.running;
  }

  /// Loops the alarm beep while the red overlay is up, stops otherwise.
  void _driveAlarm(bool show) {
    if (show && !_alarmPlaying) {
      _alarmPlaying = true;
      _alarm.setReleaseMode(ReleaseMode.loop).then((_) {
        if (_alarmPlaying) _alarm.play(AssetSource('alert_beep.wav'));
      }).catchError((_) {
        _alarmPlaying = false;
      });
    } else if (!show && _alarmPlaying) {
      _alarmPlaying = false;
      _alarm.stop();
    }
  }

  void _dismissOverlay(DemoState s) {
    setState(() {
      _overlayDismissed = true;
      _dismissedSig = _sig(s);
    });
  }

  Future<void> _smsFamily(DemoState s) async {
    final phone = GuardianStore.phone.trim();
    if (phone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('smsNoContact'))),
      );
      return;
    }
    final body = Uri.encodeComponent(
        context.trP('smsDangerBody', {'type': s.scamType, 'risk': '${s.risk}'}));
    final uri = Uri.parse('sms:$phone?body=$body');
    try {
      if (await launchUrl(uri)) {
        _smsOpened = true;
        return;
      }
    } catch (_) {}
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr('smsNoContact'))),
    );
  }

  Future<void> _submitTyped() async {
    final t = _typed.text.trim();
    if (t.isEmpty) return;
    _typed.clear();
    await widget.session.analyzeText(t);
  }

  Map<String, dynamic> _summary(DemoState s) => {
        'risk': s.risk,
        'level': s.level,
        'scamType': s.scamType,
        'reasons': s.reasons,
        'reasonsTelugu': s.reasonsTelugu,
        'alerted': s.alerted,
        'elapsedSec': s.elapsedSec,
        'lines': s.lines.length,
        'isDemo': s.isDemo,
        'smsSent': _smsOpened,
      };

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DemoState>(
      valueListenable: widget.session,
      builder: (context, s, _) {
        _watchLevel(s);
        final showOverlay =
            s.level == RiskLevel.danger && s.running && !_overlayDismissed;
        _driveAlarm(showOverlay);
        return Scaffold(
          body: SafeArea(
            child: Stack(
              children: [
                ListView(
                  padding:
                      const EdgeInsets.fromLTRB(18, 6, 18, 110),
                  children: [
                    _topRow(s),
                    _statusCard(s),
                  const SizedBox(height: 14),
                  GlassCard(
                    borderColor: KavachColors.forLevel(s.level)
                        .withValues(alpha: 0.45),
                    child: Column(
                      children: [
                        DangerMeter(risk: s.risk, level: s.level),
                        const SizedBox(height: 12),
                        Waveform(level: s.level, active: s.running),
                        const SizedBox(height: 6),
                        Text(
                          s.running
                              ? context.tr('listening')
                              : s.finished
                                  ? context.tr('callComplete')
                                  : context.tr('pressDemo'),
                          style: const TextStyle(
                              color: KavachColors.sub, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (s.reasonsTelugu.isNotEmpty || s.reasons.isNotEmpty)
                    _verdictCard(s),
                  SectionTitle(context.tr('liveTranscript')),
                  GlassCard(child: TranscriptList(lines: s.lines)),
                  const SizedBox(height: 14),
                  SectionTitle(context.tr('demoControls')),
                  _demoControls(s),
                ],
              ),
              if (showOverlay) _dangerOverlay(s),
            ],
          ),
        ),
      );
      },
    );
  }

  Widget _topRow(DemoState s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 6, 2, 12),
      child: Row(
        children: [
          _liveDot(s.running),
          const SizedBox(width: 10),
          Text(
            context.tr('liveTitle'),
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 8),
          if (s.running || s.finished) _modeChip(s.isDemo),
          const Spacer(),
          Text(
            _fmtTime(s.elapsedSec),
            style: const TextStyle(
                color: KavachColors.sub,
                fontSize: 14,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          const LangButton(),
        ],
      ),
    );
  }

  /// Honest mode label: green LIVE for real sessions, amber DEMO for scripts.
  Widget _modeChip(bool isDemo) {
    final bg = isDemo ? KavachColors.washCaution : KavachColors.washSafe;
    final fg = isDemo ? KavachColors.caution : KavachColors.safe;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fg.withValues(alpha: 0.5)),
      ),
      child: Text(
        isDemo ? 'DEMO' : 'LIVE',
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w900, color: fg),
      ),
    );
  }

  Widget _liveDot(bool running) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: running ? KavachColors.danger : KavachColors.sub,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _statusCard(DemoState s) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Detected pattern',
                    style:
                        TextStyle(color: KavachColors.sub, fontSize: 12)),
                const SizedBox(height: 2),
                Text(s.scamType,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 16)),
              ],
            ),
          ),
          StatusChip(s.level),
        ],
      ),
    );
  }

  Widget _verdictCard(DemoState s) {
    final color = KavachColors.forLevel(s.level);
    final bigVerdict = context.appLang == AppLang.telugu || s.reasons.isEmpty
        ? s.reasonsTelugu
        : s.reasons.join(' | ');
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KavachColors.tintForLevel(s.level),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x260D47A1),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
          BoxShadow(
            color: Color(0x1F0D47A1),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.record_voice_over_rounded, color: color),
              const SizedBox(width: 8),
              Text(context.tr('verdictTitle'),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 8),
          Text(bigVerdict,
              style: const TextStyle(fontSize: 16, height: 1.5)),
          if (s.reasons.isNotEmpty) const SizedBox(height: 8),
          for (final r in s.reasons)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('-  ',
                      style: TextStyle(
                          color: color, fontWeight: FontWeight.w900)),
                  Expanded(
                    child: Text(r,
                        style: const TextStyle(
                            color: KavachColors.sub, fontSize: 13.5)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _demoControls(DemoState s) {
    return GlassCard(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    _snackedAlert = false;
                    widget.session.startScam();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        KavachColors.danger.withValues(alpha: 0.85),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.warning_amber_rounded),
                  label: Text(context.tr('playScam')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    _snackedAlert = false;
                    widget.session.startNormal();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        KavachColors.safe.withValues(alpha: 0.85),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.mark_chat_read_rounded),
                  label: Text(context.tr('playNormal')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _typed,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _submitTyped(),
                  decoration: InputDecoration(
                    hintText: context.tr('typeWhatYouHear'),
                    prefixIcon: const Icon(Icons.keyboard_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filled(
                onPressed: _submitTyped,
                icon: const Icon(Icons.send_rounded),
                tooltip: 'Analyze',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (!s.running && s.finished) || s.lines.isNotEmpty
                      ? () {
                          final sum = _summary(s);
                          widget.session.reset();
                          _snackedAlert = false;
                          _prevLevel = RiskLevel.safe;
                          widget.onFinish(sum);
                        }
                      : null,
                  icon: const Icon(Icons.summarize_rounded),
                  label: Text(context.tr('endReport')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextButton.icon(
                  onPressed: s.lines.isEmpty && !s.running
                      ? null
                      : () {
                          widget.session.reset();
                          _snackedAlert = false;
                          _prevLevel = RiskLevel.safe;
                        },
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(context.tr('reset')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmtTime(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Widget _dangerOverlay(DemoState s) {
    final overlayVerdict =
        context.appLang == AppLang.telugu || s.reasons.isEmpty
            ? s.reasonsTelugu
            : s.reasons.join(' | ');
    return Positioned.fill(
      child: Container(
        color: KavachColors.washDanger,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: KavachColors.surface,
                    border: Border.all(
                        color: KavachColors.danger, width: 3),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x400D47A1),
                        blurRadius: 28,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                      Icons.do_not_disturb_on_rounded,
                      size: 64,
                      color: KavachColors.danger),
                ),
                const SizedBox(height: 18),
                Text(context.tr('hangup'),
                    style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                        color: KavachColors.danger)),
                const SizedBox(height: 6),
                Text(context.tr('hangupSub'),
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: KavachColors.danger)),
                const SizedBox(height: 14),
                Text(
                  overlayVerdict,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      color: KavachColors.danger),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: KavachColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: KavachColors.danger
                            .withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.touch_app_rounded,
                          color: KavachColors.danger),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(context.tr('cutFirst'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: KavachColors.danger,
                                fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _smsFamily(s),
                    icon: const Icon(Icons.sms_rounded),
                    label: Text(context.tr('smsAlert')),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final sum = _summary(s);
                      _alarmPlaying = false;
                      _alarm.stop();
                      widget.session.stop();
                      setState(() => _overlayDismissed = true);
                      widget.onFinish(sum);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: KavachColors.danger,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(context.tr('hungUp')),
                  ),
                ),
                TextButton(
                  onPressed: () => _dismissOverlay(s),
                  child: Text(context.tr('keepListening'),
                      style:
                          const TextStyle(color: KavachColors.sub)),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }
}
