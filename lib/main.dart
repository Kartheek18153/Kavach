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
    summary['label'] = '${summary['scamType']} | ${riskLabel(level, _lang)}';
  }

  String? get _lastResult {
    final s = _lastSummary;
    if (s == null) return null;
    return '${s['scamType']} | ${(s['level'] as RiskLevel).label}';
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
            bottomNavigationBar: null,
            floatingActionButton: _FloatingNav(
              index: _tab,
              onSelect: (i) => setState(() => _tab = i),
            ),
            floatingActionButtonLocation:
                FloatingActionButtonLocation.centerFloat,
          ),
        ),
      ),
    );
  }
}

/// Floating pill navigator with all four routes.
class _FloatingNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelect;

  const _FloatingNav({required this.index, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.shield_outlined, Icons.shield_rounded, 'tabHome'),
      (
        Icons.phone_in_talk_outlined,
        Icons.phone_in_talk_rounded,
        'tabLive'
      ),
      (
        Icons.family_restroom_outlined,
        Icons.family_restroom_rounded,
        'tabFamily'
      ),
      (Icons.summarize_outlined, Icons.summarize_rounded, 'tabReport'),
    ];
    // No outer shell — the buttons float directly over the content.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: _pillItem(context, i, items[i]),
          ),
      ],
    );
  }

  Widget _pillItem(
    BuildContext context,
    int i,
    (IconData, IconData, String) item,
  ) {
    final selected = i == index;
    if (selected) {
      return InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => onSelect(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: KavachColors.blue,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: KavachColors.blue.withValues(alpha: 0.45),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.$2, color: Colors.white, size: 22),
              const SizedBox(width: 6),
              Text(
                context.tr(item.$3),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => onSelect(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          color: Color(0xFFE9EEF5),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0x260D47A1),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          item.$1,
          color: KavachColors.sub,
          size: 22,
        ),
      ),
    );
  }
}
