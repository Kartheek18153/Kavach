import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'demo/simulator.dart';
import 'lang.dart';
import 'screens/dashboard_screen.dart';
import 'screens/family_screen.dart';
import 'screens/live_screen.dart';
import 'screens/report_screen.dart';
import 'services/api.dart';
import 'services/scan_history.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GuardianStore.load();
  await HistoryStore.load();
  await ScanHistoryStore.load();
  runApp(const KavachApp());
}

/// Kavach — Telugu-first scam-call shield (hackathon UI build).
class KavachApp extends StatefulWidget {
  const KavachApp({super.key});

  @override
  State<KavachApp> createState() => _KavachAppState();
}

class _KavachAppState extends State<KavachApp> {
  int _tab = 0;
  late final DemoSession _session;
  bool _familySet = false;
  Map<String, dynamic>? _lastSummary;
  AppLang _lang = AppLang.english;

  @override
  void initState() {
    super.initState();
    _session = DemoSession();
    _familySet = GuardianStore.isConnected;
    _lastSummary = _restoreLatest();
  }

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  Future<void> _protect() async {
    setState(() => _tab = 1);
    // Runtime mic permission for future live audio; demo runs regardless.
    try {
      final st = await Permission.microphone.request();
      if (!st.isGranted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Mic denied - running demo mode. Enable mic for live detection.')),
        );
      }
    } catch (_) {
      // Permission plugin unavailable on desktop/web - continue demo.
    }
    _session.startReal();
  }

  void _practice() {
    setState(() => _tab = 1);
    _session.startScam();
  }

  void _finish(Map<String, dynamic> summary) {
    final level = summary['level'] as RiskLevel;
    setState(() {
      _lastSummary = summary;
      _tab = 3;
    });
    summary['label'] = '${summary['scamType']} | ${riskLabel(level, _lang)}';
    HistoryStore.add(summary);
  }

  Map<String, dynamic>? _restoreLatest() {
    if (HistoryStore.entries.isEmpty) return null;
    final e = HistoryStore.entries.first;
    return {
      'risk': e['risk'] ?? 0,
      'level': _levelFrom(e['level']),
      'scamType': e['scamType'] ?? '-',
      'reasons': List.from(e['reasons'] ?? const []),
      'reasonsTelugu': e['reasonsTelugu'] ?? '',
      'alerted': e['alerted'] ?? false,
      'elapsedSec': e['elapsedSec'] ?? 0,
      'lines': e['lines'] ?? 0,
      'isDemo': e['demo'] ?? false,
      'smsSent': e['smsSent'] ?? false,
    };
  }

  RiskLevel _levelFrom(Object? v) {
    if (v == 'danger') return RiskLevel.danger;
    if (v == 'caution') return RiskLevel.caution;
    return RiskLevel.safe;
  }

  String? get _lastResult {
    final s = _lastSummary;
    if (s == null) return null;
    return '${s['scamType']} | ${(s['level'] as RiskLevel).label}';
  }

  @override
  Widget build(BuildContext context) {
    // LangScope sits ABOVE MaterialApp so pushed pages (settings, tools,
    // threats, history, safety) inherit the language too.
    return LangScope(
      lang: _lang,
      onLang: (l) => setState(() => _lang = l),
      child: MaterialApp(
        title: 'Kavach',
        debugShowCheckedModeBanner: false,
        theme: kavachTheme(),
      home: Builder(
        builder: (context) => Scaffold(
          body: IndexedStack(
            index: _tab,
            children: [
              DashboardScreen(
                onProtect: _protect,
                onPractice: _practice,
                onSetupFamily: () => setState(() => _tab = 2),
                onViewReport: () => setState(() => _tab = 3),
                familySet: _familySet,
                lastResult: _lastResult,
              ),
              LiveScreen(session: _session, onFinish: _finish),
              FamilyScreen(
                  onSaved: () => setState(
                      () => _familySet = GuardianStore.isConnected)),
              ReportScreen(
                summary: _lastSummary,
                onNewScan: () => setState(() => _tab = 1),
                onHistoryCleared: () => setState(() => _lastSummary = null),
              ),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.shield_outlined),
                selectedIcon: const Icon(Icons.shield_rounded),
                label: context.tr('tabHome'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.phone_in_talk_outlined),
                selectedIcon:
                    const Icon(Icons.phone_in_talk_rounded),
                label: context.tr('tabLive'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.family_restroom_outlined),
                selectedIcon:
                    const Icon(Icons.family_restroom_rounded),
                label: context.tr('tabFamily'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.summarize_outlined),
                selectedIcon:
                    const Icon(Icons.summarize_rounded),
                label: context.tr('tabReport'),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}
