import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../lang.dart';
import '../services/api.dart';
import '../services/live_audio.dart';
import '../services/scan_history.dart';
import '../theme.dart';
import '../widgets/cards.dart';

/// Settings & privacy: language, voice check, privacy promise,
/// data controls, about.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _voice = LiveAudioListener();
  bool _testingVoice = false;
  String? _heard;

  @override
  void dispose() {
    _voice.stop();
    super.dispose();
  }

  Future<void> _testVoice() async {
    if (_testingVoice) {
      await _voice.stop();
      if (mounted) setState(() => _testingVoice = false);
      return;
    }
    final lang = context.appLang;
    setState(() {
      _testingVoice = true;
      _heard = null;
    });
    bool granted = false;
    try {
      granted = (await Permission.microphone.request()).isGranted;
    } catch (_) {}
    if (!mounted) return;
    if (!granted) {
      setState(() {
        _testingVoice = false;
        _heard = context.tr('liveMicDenied');
      });
      return;
    }
    final heard = StringBuffer();
    _voice.onPartial = (_) {};
    _voice.onFinal = (t) {
      heard.write('${heard.isEmpty ? '' : ' '}$t');
      if (mounted) setState(() => _heard = heard.toString());
    };
    _voice.onError = (_) {
      if (mounted && _heard == null) {
        setState(() => _heard = context.tr('liveNoStt'));
      }
    };
    final ok = await _voice.init();
    String localeTag = '';
    if (ok && mounted) {
      await _voice.start(localeChain: sttLocaleFallbacks(lang));
      localeTag = _voice.activeLocale;
      await Future.delayed(const Duration(seconds: 8));
    }
    await _voice.stop();
    if (!mounted) return;
    setState(() {
      _testingVoice = false;
      final text = heard.isEmpty
          ? context.tr('voiceNothing')
          : heard.toString();
      _heard = localeTag.isEmpty ? text : '[$localeTag] $text';
    });
  }
  Future<void> _confirmClearScans() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('clearHistTitle')),
        content: Text(context.tr('clearHistBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('cancelBtn')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('deleteBtn')),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ScanHistoryStore.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('scansCleared'))),
        );
        setState(() {});
      }
    }
  }

  Future<void> _confirmClearCalls() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('clearHistTitle')),
        content: Text(context.tr('clearHistBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('cancelBtn')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('deleteBtn')),
          ),
        ],
      ),
    );
    if (ok == true) {
      await HistoryStore.clearHistory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('historyCleared'))),
        );
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = LangScope.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('settingsTitle'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        children: [
          SectionTitle(context.tr('langSection')),
          GlassCard(
            child: Row(
              children: AppLang.values.map((l) {
                final selected = scope.lang == l;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: SizedBox(
                        height: 22,
                        child: Center(
                          child: Text(l.nativeName,
                              style: TextStyle(
                                color: selected
                                    ? KavachColors.teal
                                    : KavachColors.sub,
                                fontWeight: FontWeight.w700,
                              )),
                        ),
                      ),
                      selected: selected,
                      selectedColor: KavachColors.washTeal,
                      onSelected: (_) => scope.onLang(l),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),
          SectionTitle(context.tr('voiceSection')),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.tr('voiceBody'),
                    style: const TextStyle(
                        color: KavachColors.sub,
                        fontSize: 13.5,
                        height: 1.5)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _testVoice,
                    icon: Icon(_testingVoice
                        ? Icons.stop_rounded
                        : Icons.mic_rounded),
                    label: Text(context.tr(_testingVoice
                        ? 'voiceStopBtn'
                        : 'voiceTestBtn')),
                  ),
                ),
                if (_heard != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: KavachColors.surface2,
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: KavachColors.line),
                    ),
                    child: Text(
                      '${context.tr('liveHeard')}: $_heard',
                      style: const TextStyle(
                          fontSize: 14, height: 1.45),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          SectionTitle(context.tr('privacySection')),
          GlassCard(
            borderColor:
                KavachColors.teal.withValues(alpha: 0.4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: KavachColors.washTeal,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.lock_rounded,
                      color: KavachColors.teal, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.tr('privacyTitle'),
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text(context.tr('privacyBody'),
                          style: const TextStyle(
                              color: KavachColors.sub,
                              fontSize: 13.5,
                              height: 1.55)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SectionTitle(context.tr('dataSection')),
          GlassCard(
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.qr_code_scanner_rounded,
                      color: KavachColors.teal),
                  title: Text(context.tr('clearScanData'),
                      style:
                          const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                      '${ScanHistoryStore.entries.length}',
                      style: const TextStyle(
                          color: KavachColors.sub, fontSize: 13)),
                  trailing: TextButton(
                    onPressed: _confirmClearScans,
                    child: Text(context.tr('deleteBtn')),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.phone_in_talk_rounded,
                      color: KavachColors.teal),
                  title: Text(context.tr('clearHistory'),
                      style:
                          const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${HistoryStore.entries.length}',
                      style: const TextStyle(
                          color: KavachColors.sub, fontSize: 13)),
                  trailing: TextButton(
                    onPressed: _confirmClearCalls,
                    child: Text(context.tr('deleteBtn')),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SectionTitle(context.tr('aboutSection')),
          GlassCard(
            child: Text(context.tr('aboutBody'),
                style: const TextStyle(
                    color: KavachColors.sub,
                    fontSize: 13.5,
                    height: 1.55)),
          ),
        ],
      ),
    );
  }
}
