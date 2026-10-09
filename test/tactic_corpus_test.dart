import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kavach/services/tactic_engine.dart';

/// Corpus regression test: the vendored KAVACH_IQOO fixture set
/// (test/fixtures/calls) replayed line-by-line (6 s per line) through the
/// Tier-1 tactic engine. Positive calls must reach DANGER (>= 61 with >= 3
/// families); negative calls must never reach DANGER.
List<String> _windows(File f) {
  return f.readAsLinesSync().where((l) {
    final t = l.trim();
    return t.isNotEmpty && !t.startsWith('#');
  }).map((l) {
    final t = l.trim().replaceFirst(RegExp(r'^[A-Z_ ]+:\s*'), '');
    return t;
  }).where((t) => t.isNotEmpty).toList();
}

({int peak, Set<String> families, String name}) _replay(File f) {
  final session = TacticSession();
  var peak = 0;
  var peakFamilies = <String>{};
  final lines = _windows(f);
  for (var i = 0; i < lines.length; i++) {
    session.addWindow(lines[i], i * 6000);
    final snap = session.scoreAt(i * 6000);
    if (snap.score > peak) {
      peak = snap.score;
      peakFamilies = snap.families;
    }
  }
  return (peak: peak, families: peakFamilies, name: f.uri.pathSegments.last);
}

void main() {
  test('positive corpus: 10/10 reach DANGER with >= 3 families', () {
    final dir = Directory('test/fixtures/calls/positive');
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.txt'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    expect(files, hasLength(10));
    for (final f in files) {
      final r = _replay(f);
      expect(r.peak, greaterThanOrEqualTo(61),
          reason: '${r.name} peak ${r.peak} < 61');
      expect(r.families.length, greaterThanOrEqualTo(3),
          reason: '${r.name} families ${r.families}');
    }
  });

  test('negative corpus: 0/8 reach DANGER', () {
    final dir = Directory('test/fixtures/calls/negative');
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.txt'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    expect(files, hasLength(8));
    var worst = 0;
    var worstName = '';
    for (final f in files) {
      final session = TacticSession();
      final lines = _windows(f);
      for (var i = 0; i < lines.length; i++) {
        session.addWindow(lines[i], i * 6000);
        final snap = session.scoreAt(i * 6000);
        expect(snap.band, isNot('danger'),
            reason: '${f.uri.pathSegments.last} line $i hit danger');
        if (snap.score > worst) {
          worst = snap.score;
          worstName = f.uri.pathSegments.last;
        }
      }
    }
    // Informational: how close the hardest legitimate call gets.
    // ignore: avoid_print
    print('hardest negative: $worstName peak $worst');
  });
}
