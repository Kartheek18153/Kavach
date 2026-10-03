import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Guardian contact kept in memory for this session.
/// TODO: persist with shared_preferences when the backend goes live.
class GuardianStore {
  static String name = '';
  static String phone = '';
  static String chatId = '';
}

/// Thin client for the Kavach backend (`backend/`).
///
/// Pass `--dart-define=KAVACH_API=http://<host>:8080` at build time to
/// point elsewhere (Android emulator: `http://10.0.2.2:8080`).
/// Every call fails soft so the app keeps working offline with the
/// built-in local rule engine.
class KavachApi {
  static const baseUrl = String.fromEnvironment(
    'KAVACH_API',
    defaultValue: 'http://localhost:8080',
  );

  /// Scores one transcript line server-side.
  /// Returns `{points, groups}` or null when unreachable.
  static Future<Map<String, dynamic>?> scoreLine(String text) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/score'),
            headers: {'content-type': 'application/json'},
            body: jsonEncode({'text': text}),
          )
          .timeout(const Duration(seconds: 3));
      if (res.statusCode != 200) return null;
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Sends a family alert through the backend (Telegram when a bot
  /// token is configured, otherwise the demo log).
  static Future<Map<String, dynamic>> sendAlert({
    required String chatId,
    required String message,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/alert'),
            headers: {'content-type': 'application/json'},
            body: jsonEncode({'chatId': chatId, 'message': message}),
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) {
        return {'sent': false, 'via': 'off'};
      }
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return {'sent': false, 'via': 'off'};
    }
  }

  /// True when the backend answers /health.
  static Future<bool> ping() async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 3));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
