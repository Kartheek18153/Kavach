import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../lang.dart';

/// Preferred speech-recognition locale per app language.
String preferredSttLocale(AppLang lang) =>
    sttLocaleFallbacks(lang).first;

/// Ordered locale fallback chain per app language. Telugu tries te-IN
/// first, then bare te, then Hindi, then English - so voice typing
/// degrades gracefully instead of landing on whatever locale the
/// recognizer happens to list first.
List<String> sttLocaleFallbacks(AppLang lang) {
  switch (lang) {
    case AppLang.english:
      return const ['en-IN', 'en'];
    case AppLang.telugu:
      return const ['te-IN', 'te', 'hi-IN', 'hi', 'en-IN', 'en'];
    case AppLang.hindi:
      return const ['hi-IN', 'hi', 'en-IN', 'en'];
  }
}

/// Picks the best available STT locale from an ordered [chain]:
/// first exact match, then same-language prefix in chain order,
/// then whatever the device offers first.
/// Pure function so it stays unit-testable without a microphone.
String pickSttLocaleChain(List<String> chain, List<String> available) {
  for (final want in chain) {
    if (available.contains(want)) return want;
  }
  for (final want in chain) {
    final lang = want.split(RegExp(r'[-_]')).first.toLowerCase();
    for (final id in available) {
      if (id.toLowerCase().startsWith(lang)) return id;
    }
  }
  if (available.isNotEmpty) return available.first;
  return chain.isNotEmpty ? chain.first : '';
}

/// Single-preference shorthand over [pickSttLocaleChain].
String pickSttLocale(String preferred, List<String> available) =>
    pickSttLocaleChain([preferred], available);

/// Live microphone listener: streams the room (call on speaker) through the
/// phone's speech recognizer and hands finished phrases to the tactic
/// engine. Android mutes call audio for third-party apps, so speakerphone +
/// mic is the only universal capture path - the UI must keep reminding that.
///
/// The recognizer auto-stops after pauses, so [onStatus] restarts listening
/// while [_wantListening] is set. Duplicate finals are filtered.
class LiveAudioListener {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _wantListening = false;
  bool _starting = false;
  String _lastFinal = '';
  String _localeId = '';

  /// Partial (in-progress) phrase, for the "hearing..." line.
  void Function(String partial)? onPartial;

  /// Finished phrase - feed it to the scoring engine.
  void Function(String text)? onFinal;

  /// Raw recognizer status ('listening', 'notListening', 'done', ...).
  void Function(String status)? onState;

  /// Error message for the UI when the recognizer fails.
  void Function(String error)? onError;

  bool get isListening => _speech.isListening;

  Future<bool> init() async {
    try {
      return await _speech.initialize(
        onError: (e) => onError?.call(e.errorMsg),
        onStatus: _handleStatus,
      );
    } catch (e) {
      onError?.call(e.toString());
      return false;
    }
  }

  void _handleStatus(String status) {
    onState?.call(status);
    if (!_wantListening) return;
    if ((status == 'done' || status == 'notListening') && !_starting) {
      _restart();
    }
  }

  Future<void> _restart() async {
    if (!_wantListening || _speech.isListening) return;
    _starting = true;
    try {
      await _speech.listen(
        onResult: _handleResult,
        listenOptions: stt.SpeechListenOptions(
          localeId: _localeId.isEmpty ? null : _localeId,
          partialResults: true,
          listenMode: stt.ListenMode.dictation,
          cancelOnError: true,
        ),
      );
    } catch (e) {
      onError?.call(e.toString());
    }
    _starting = false;
  }

  void _handleResult(SpeechRecognitionResult result) {
    final words = result.recognizedWords.trim();
    if (words.isEmpty) return;
    if (result.finalResult) {
      if (words == _lastFinal) return;
      _lastFinal = words;
      onPartial?.call('');
      onFinal?.call(words);
    } else {
      onPartial?.call(words);
    }
  }

  /// Starts the listen-restart loop, picking the closest device locale
  /// from [localeChain] (see [sttLocaleFallbacks]).
  Future<bool> start({required List<String> localeChain}) async {
    _wantListening = true;
    _lastFinal = '';
    try {
      final locales = await _speech.locales();
      _localeId = pickSttLocaleChain(
        localeChain,
        locales.map((l) => l.localeId).toList(),
      );
    } catch (_) {
      _localeId = localeChain.isNotEmpty ? localeChain.first : '';
    }
    await stopListeningOnly();
    await _restart();
    return _speech.isListening;
  }

  /// The device locale actually in use ('' until started).
  String get activeLocale => _localeId;

  Future<void> stopListeningOnly() async {
    try {
      if (_speech.isListening) await _speech.stop();
    } catch (_) {}
  }

  /// Stops everything; safe to call from dispose (fire-and-forget).
  Future<void> stop() async {
    _wantListening = false;
    onPartial = null;
    onFinal = null;
    await stopListeningOnly();
  }
}
