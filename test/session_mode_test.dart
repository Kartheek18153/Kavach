import 'package:flutter_test/flutter_test.dart';
import 'package:kavach/demo/simulator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('real mode stays live on an empty transcript', () async {
    final s = DemoSession();
    s.startReal();
    expect(s.state.running, isTrue);
    expect(s.state.isDemo, isFalse);

    await Future.delayed(const Duration(seconds: 3));
    expect(s.state.running, isTrue);
    expect(s.state.finished, isFalse);
    expect(s.state.elapsedSec, greaterThanOrEqualTo(2));
    s.dispose();
  });

  test('demo scripts are flagged demo', () {
    final s = DemoSession();
    s.startScam();
    expect(s.state.isDemo, isTrue);
    expect(s.state.running, isTrue);
    s.dispose();
  });

  test('typed words score inside a real session', () async {
    final s = DemoSession();
    s.startReal();
    await s.analyzeText('Share the OTP 3274 I sent');
    expect(s.state.lines, hasLength(1));
    expect(s.state.risk, greaterThan(0));
    s.dispose();
  });

  test('whole words only, repeats escalate', () async {
    final s = DemoSession();
    s.startReal();
    await s.analyzeText('my spinning wheel is fine');
    expect(s.state.risk, 0);
    expect(s.state.lines.single.flagged, isFalse);
    await s.analyzeText('do it immediately');
    expect(s.state.risk, 10);
    await s.analyzeText('hurry, immediately!');
    expect(s.state.risk, 15);
    s.dispose();
  });
}
