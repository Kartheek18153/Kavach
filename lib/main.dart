import 'package:flutter/material.dart';

import 'demo/simulator.dart';
import 'lang.dart';
import 'screens/family_screen.dart';
import 'screens/home_screen.dart';
import 'screens/live_screen.dart';
import 'screens/report_screen.dart';
import 'theme.dart';

void main() {
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
  }

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  void _protect() {
    setState(() => _tab = 1);
    _session.startScam();
  }

  void _finish(Map<String, dynamic> summary) {
    final level = summary['level'] as RiskLevel;
    setState(() {
      _lastSummary = summary;
      _tab = 3;
    });
    summary['label'] = '${summary['scamType']} • ${riskLabel(level, _lang)}';
  }

  String? get _lastResult {
    final s = _lastSummary;
    if (s == null) return null;
    return '${s['scamType']} • ${(s['level'] as RiskLevel).label}';
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kavach',
      debugShowCheckedModeBanner: false,
      theme: kavachTheme(),
      home: LangScope(
        lang: _lang,
        onLang: (l) => setState(() => _lang = l),
        child: Builder(
          builder: (context) => Scaffold(
            body: IndexedStack(
              index: _tab,
              children: [
                HomeScreen(
                  onProtect: _protect,
                  familySet: _familySet,
                  lastResult: _lastResult,
                ),
                LiveScreen(session: _session, onFinish: _finish),
                FamilyScreen(
                    onSaved: () => setState(() => _familySet = true)),
                ReportScreen(
                  summary: _lastSummary,
                  onNewScan: () => setState(() => _tab = 1),
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
                  selectedIcon: const Icon(Icons.summarize_rounded),
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
