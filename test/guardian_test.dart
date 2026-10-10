import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cybersafe/lang.dart';
import 'package:cybersafe/screens/dashboard_screen.dart';
import 'package:cybersafe/services/api.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('phone normalization', () {
    test('strips spaces and dashes', () {
      expect(GuardianStore.normalizePhone('98765 43210'), '9876543210');
      expect(GuardianStore.normalizePhone('98-765-43210'), '9876543210');
    });

    test('drops +91, 91 and leading 0', () {
      expect(GuardianStore.normalizePhone('+91-9876543210'), '9876543210');
      expect(GuardianStore.normalizePhone('919876543210'), '9876543210');
      expect(GuardianStore.normalizePhone('09876543210'), '9876543210');
    });

    test('leaves short input untouched', () {
      expect(GuardianStore.normalizePhone('123'), '123');
      expect(GuardianStore.normalizePhone(''), '');
    });
  });

  group('validation', () {
    test('indian mobiles only', () {
      expect(GuardianStore.isValidPhone('9876543210'), isTrue);
      expect(GuardianStore.isValidPhone('+91 98765 43210'), isTrue);
      expect(GuardianStore.isValidPhone('12345'), isFalse);
      expect(GuardianStore.isValidPhone('5876543210'), isFalse);
      expect(GuardianStore.isValidPhone(''), isFalse);
    });

    test('names need 2+ letters', () {
      expect(GuardianStore.isValidName('Am'), isTrue);
      expect(GuardianStore.isValidName('A'), isFalse);
      expect(GuardianStore.isValidName('   '), isFalse);
    });

    test('safe word is one word, 4+ letters', () {
      expect(GuardianStore.isValidSafeWord('KAVACHAM'), isTrue);
      expect(GuardianStore.isValidSafeWord('abc'), isFalse);
      expect(GuardianStore.isValidSafeWord('my word'), isFalse);
    });

    test('display format', () {
      expect(
          GuardianStore.displayPhone('9876543210'), '+91 98765 43210');
      expect(GuardianStore.displayPhone('123'), '123');
    });
  });

  group('persistence', () {
    setUp(() {
      GuardianStore.name = '';
      GuardianStore.phone = '';
      GuardianStore.safeWord = '';
    });

    test('save normalizes, load restores, connected holds', () async {
      SharedPreferences.setMockInitialValues({});
      GuardianStore.name = 'Amma';
      GuardianStore.phone = '+91 98765 43210';
      GuardianStore.safeWord = 'kavacham';
      await GuardianStore.save();

      expect(GuardianStore.phone, '9876543210');
      expect(GuardianStore.safeWord, 'KAVACHAM');

      GuardianStore.name = '';
      GuardianStore.phone = '';
      GuardianStore.safeWord = '';
      expect(GuardianStore.isConnected, isFalse);

      await GuardianStore.load();
      expect(GuardianStore.name, 'Amma');
      expect(GuardianStore.phone, '9876543210');
      expect(GuardianStore.safeWord, 'KAVACHAM');
      expect(GuardianStore.isConnected, isTrue);
    });

    test('clear wipes disk and memory', () async {
      SharedPreferences.setMockInitialValues({});
      GuardianStore.name = 'Amma';
      GuardianStore.phone = '9876543210';
      await GuardianStore.save();
      await GuardianStore.clear();

      expect(GuardianStore.isConnected, isFalse);
      await GuardianStore.load();
      expect(GuardianStore.name, '');
      expect(GuardianStore.phone, '');
    });
  });

  group('history', () {
    test('keeps latest 20 with newest first', () async {
      SharedPreferences.setMockInitialValues({});
      HistoryStore.entries = [];
      for (var i = 0; i < 22; i++) {
        await HistoryStore.add({
          'scamType': 'Type $i',
          'risk': i,
          'level': 'safe',
          'reasons': <String>[],
          'reasonsTelugu': '',
          'alerted': false,
          'elapsedSec': i,
          'lines': 1,
          'isDemo': true,
          'smsSent': false,
        });
      }
      expect(HistoryStore.entries, hasLength(20));
      expect(HistoryStore.entries.first['scamType'], 'Type 21');
      expect(HistoryStore.entries.first['demo'], isTrue);

      await HistoryStore.load();
      expect(HistoryStore.entries, hasLength(20));
      expect(HistoryStore.entries.first['scamType'], 'Type 21');
    });
  });

  group('memory', () {
    test('scoreboard counts live dangers this month only', () {
      final m = DateTime.now().toIso8601String().substring(0, 7);
      HistoryStore.entries = <Map<String, dynamic>>[
        {'ts': '$m-10T10:00:00', 'level': 'danger', 'risk': 92},
        {
          'ts': '$m-11T10:00:00',
          'level': 'danger',
          'risk': 70,
          'demo': true
        },
        {'ts': '$m-12T10:00:00', 'level': 'caution', 'risk': 40},
        {
          'ts': '2000-01-01T00:00:00',
          'level': 'danger',
          'risk': 100,
        },
      ];
      expect(HistoryStore.monthDangers, 1);
      expect(HistoryStore.monthWorst, 92);
      HistoryStore.entries = [];
      expect(HistoryStore.monthDangers, 0);
      expect(HistoryStore.monthWorst, 0);
    });

    testWidgets('dashboard shows shield and protect when empty', (t) async {
      HistoryStore.entries = [];
      await t.pumpWidget(LangScope(
        lang: AppLang.english,
        onLang: (_) {},
        child: MaterialApp(
          home: DashboardScreen(
            onProtect: () {},
            onPractice: () {},
            onSetupFamily: () {},
            onViewReport: () {},
            familySet: false,
          ),
        ),
      ));
      expect(find.text('Security shield'), findsOneWidget);
      expect(find.text('Protect this call'), findsOneWidget);
      await t.dragUntilVisible(
        find.text('Safety tools'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      expect(find.text('Safety tools'), findsOneWidget);
    });

    testWidgets('dashboard shows connected family badge', (t) async {
      HistoryStore.entries = [];
      await t.pumpWidget(LangScope(
        lang: AppLang.english,
        onLang: (_) {},
        child: MaterialApp(
          home: DashboardScreen(
            onProtect: () {},
            onPractice: () {},
            onSetupFamily: () {},
            onViewReport: () {},
            familySet: true,
          ),
        ),
      ));
      expect(find.text('Security shield'), findsOneWidget);
      await t.dragUntilVisible(
        find.text('Connected '),
        find.byType(ListView),
        const Offset(0, -200),
      );
      expect(find.text('Connected '), findsOneWidget);
      await t.dragUntilVisible(
        find.text('Recent activity'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      expect(find.text('Recent activity'), findsOneWidget);
    });
  });
}
