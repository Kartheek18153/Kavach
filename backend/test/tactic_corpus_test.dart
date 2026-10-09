import 'dart:io';

import 'package:kavach_backend/tactic_engine.dart';
import 'package:test/test.dart';

/// Backend mirror of the app corpus test: vendored KAVACH_IQOO fixtures
/// replayed line-by-line (6 s per line). Positives must reach DANGER with
/// >= 3 families; negatives must never reach DANGER.
List<String> _windows(File f) {
  return f.readAsLinesSync().where((l) {
    final t = l.trim();
    return t.isNotEmpty && !t.startsWith('#');
  }).map((l) {
    final t = l.trim().replaceFirst(RegExp(r'^[A-Z_ ]+:\s*'), '');
    return t;
  }).where((t) => t.isNotEmpty).toList();
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
      final name = f.uri.pathSegments.last;
      expect(peak, greaterThanOrEqualTo(61), reason: '$name peak $peak');
      expect(peakFamilies.length, greaterThanOrEqualTo(3),
          reason: '$name families $peakFamilies');
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
    for (final f in files) {
      final session = TacticSession();
      final lines = _windows(f);
      for (var i = 0; i < lines.length; i++) {
        session.addWindow(lines[i], i * 6000);
        final snap = session.scoreAt(i * 6000);
        expect(snap.band, isNot('danger'),
            reason: '${f.uri.pathSegments.last} line $i hit danger');
      }
    }
  });
}
