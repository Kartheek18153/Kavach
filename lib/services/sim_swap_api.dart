/// Telco SIM-swap check client (CAMARA SimSwap via our backend).
///
/// The questionnaire in `scanners.dart` stays fully offline; this client
/// adds the network signal (recent SIM change from the operator) on top.
/// Every call fails soft to null so the tab keeps working offline.
///
/// Backend routes (our API, camelCase): POST /api/sim-swap/check
/// {phoneNumber?, lookbackHours?}, POST /api/sim-swap/retrieve-date
/// {phoneNumber?}. Upstream they map to CAMARA {phoneNumber, maxAge}.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api.dart';

final _e164 = RegExp(r'^\+[1-9][0-9]{4,14}$');

/// Client-side E.164 check (server re-validates).
bool isValidE164Phone(String v) => _e164.hasMatch(v.trim());

/// Normalized telco verdict. `detected == null` means unknown/unsupported —
/// never read it as "safe".
class TelcoSimSwapResult {
  const TelcoSimSwapResult({
    required this.status,
    required this.provider,
    required this.lookbackHours,
    required this.detected,
    required this.lastSwapAt,
    required this.monitoredPeriodDays,
    required this.riskSignal,
    required this.maskedPhone,
    required this.detail,
  });

  final String status; // completed | unknown | unsupported
  final String provider;
  final int? lookbackHours;
  final bool? detected;
  final String? lastSwapAt;
  final int? monitoredPeriodDays;
  final String riskSignal; // recent_sim_change | no_recent_change |
  // check_unavailable | unsupported_operation
  final String maskedPhone;
  final String detail;

  factory TelcoSimSwapResult.fromJson(Map<String, dynamic> m) =>
      TelcoSimSwapResult(
        status: '${m['status'] ?? 'unknown'}',
        provider: '${m['provider'] ?? '?'}',
        lookbackHours: (m['lookbackHours'] as num?)?.toInt(),
        detected: m['simSwapDetected'] as bool?,
        lastSwapAt: m['lastSwapAt']?.toString(),
        monitoredPeriodDays: (m['monitoredPeriodDays'] as num?)?.toInt(),
        riskSignal: '${m['riskSignal'] ?? 'check_unavailable'}',
        maskedPhone: '${m['maskedPhone'] ?? '?'}',
        detail: '${m['detail'] ?? ''}',
      );
}

/// Thin client for the SIM-swap backend routes. Never throws.
class SimSwapApi {
  SimSwapApi._();

  static Future<TelcoSimSwapResult?> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await http
          .post(
            Uri.parse('${CyberSafeApi.baseUrl}$path'),
            headers: {'content-type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;
      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) return null;
      return TelcoSimSwapResult.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  /// CAMARA check: was there a swap within [lookbackHours]?
  static Future<TelcoSimSwapResult?> check({
    required String phoneNumber,
    required int lookbackHours,
  }) =>
      _post('/api/sim-swap/check', {
        'phoneNumber': phoneNumber.trim(),
        'lookbackHours': lookbackHours,
      });

  /// CAMARA retrieve-date: when was the last change, if knowable?
  static Future<TelcoSimSwapResult?> retrieveDate({
    required String phoneNumber,
  }) =>
      _post('/api/sim-swap/retrieve-date', {
        'phoneNumber': phoneNumber.trim(),
      });
}
