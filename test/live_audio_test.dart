import 'package:flutter_test/flutter_test.dart';

import 'package:cybersafe/lang.dart';
import 'package:cybersafe/services/live_audio.dart';

void main() {
  test('preferred locale per language', () {
    expect(preferredSttLocale(AppLang.english), 'en-IN');
    expect(preferredSttLocale(AppLang.telugu), 'te-IN');
    expect(preferredSttLocale(AppLang.hindi), 'hi-IN');
  });

  test('picks exact locale first', () {
    expect(
      pickSttLocale('hi-IN', ['en-IN', 'hi-IN', 'te-IN']),
      'hi-IN',
    );
  });

  test('falls back to same-language prefix', () {
    expect(
      pickSttLocale('te-IN', ['en-IN', 'te']),
      'te',
    );
    expect(
      pickSttLocale('hi-IN', ['en-US', 'hi']),
      'hi',
    );
  });

  test('falls back to first available, then preferred', () {
    expect(pickSttLocale('te-IN', ['en-US']), 'en-US');
    expect(pickSttLocale('te-IN', []), 'te-IN');
  });

  test('telugu chain prefers telugu, then hindi, then english', () {
    final chain = sttLocaleFallbacks(AppLang.telugu);
    expect(chain.first, 'te-IN');
    expect(
      pickSttLocaleChain(chain, ['en-IN', 'hi-IN', 'te-IN']),
      'te-IN',
    );
    // No Telugu on device: Hindi wins over English for a Telugu user.
    expect(
      pickSttLocaleChain(chain, ['en-IN', 'hi-IN']),
      'hi-IN',
    );
    expect(
      pickSttLocaleChain(chain, ['en-US']),
      'en-US',
    );
  });
}
