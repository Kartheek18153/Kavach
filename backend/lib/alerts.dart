import 'dart:io';

import 'package:http/http.dart' as http;

/// Sends a family alert through Telegram Bot API when a bot token is
/// configured, otherwise logs it. Returns how the alert was handled.
class AlertDispatcher {
  AlertDispatcher({String botToken = ''}) : _overrideToken = botToken;

  final String _overrideToken;

  String get _token {
    if (_overrideToken.isNotEmpty) return _overrideToken;
    return Platform.environment['TELEGRAM_BOT_TOKEN'] ?? '';
  }

  bool get configured => _token.isNotEmpty;

  /// Sends [message] to Telegram [chatId]. Falls back to logging.
  Future<Map<String, Object>> sendAlert({
    required String chatId,
    required String message,
  }) async {
    final token = _token;
    if (token.isEmpty || chatId.isEmpty) {
      // No credentials — log so demos still visibly "alert".
      // ignore: avoid_print
      print('[alert:logged] chat=$chatId message=$message');
      return {
        'sent': false,
        'via': 'log',
        'reason': token.isEmpty
            ? 'TELEGRAM_BOT_TOKEN not configured'
            : 'empty chat id',
      };
    }
    final uri = Uri.parse('https://api.telegram.org/bot$token/sendMessage');
    try {
      final res = await http.post(uri, body: {
        'chat_id': chatId,
        'text': message,
      }).timeout(const Duration(seconds: 10));
      final ok = res.statusCode == 200;
      if (!ok) {
        // ignore: avoid_print
        print('[alert:telegram-failed] ${res.statusCode} ${res.body}');
      }
      return {
        'sent': ok,
        'via': 'telegram',
        if (!ok) 'reason': 'telegram api ${res.statusCode}',
      };
    } catch (e) {
      // ignore: avoid_print
      print('[alert:error] $e');
      return {'sent': false, 'via': 'telegram', 'reason': '$e'};
    }
  }
}
