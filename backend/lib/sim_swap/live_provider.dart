/// Live CAMARA SimSwap HTTP integration (GSMA Open Gateway).
///
/// Port of the reference adapter: separate classes for v2.1.0 (strict)
/// and v1.0.0 (lenient) — never mixed. `OG_API_BASE_URL` must already
/// include the versioned path (`/sim-swap/v1` or `/sim-swap/v2`).
///
/// Auth flows: `bearer` (portal token, verbatim) and `client_credentials`
/// (OAuth2 2-legged, HTTP Basic — confirm with the portal before live use;
/// CAMARA mandates `private_key_jwt`). `ciba` performs the single immediate
/// poll from the reference implementation, which is NOT verified against a
/// live sandbox. `auth_code`/`jwt_bearer` stay unconfigured with guidance.
///
/// No credentials, tokens, auth headers, or full phone numbers are logged.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'config.dart';
import 'mock_provider.dart';
import 'provider.dart';
import 'simulation_provider.dart';
import 'validation.dart';

const _threeLeggedFlows = {'ciba', 'auth_code', 'jwt_bearer', 'bearer'};
const _tokenBoundFlows = {'auth_code', 'jwt_bearer', 'bearer'};

String _newCorrelator() {
  final r = Random.secure();
  final bytes = List<int>.generate(16, (_) => r.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

String _basicAuth(String id, String secret) =>
    'Basic ${base64Encode(utf8.encode('$id:$secret'))}';

/// Live CAMARA SimSwap v2.1.0 HTTP integration.
class GsmaSandboxProvider extends SimSwapProvider {
  GsmaSandboxProvider(this.settings, {http.Client? client})
      : _client = client,
        _ownsClient = client == null;

  final SimSwapSettings settings;
  http.Client? _client;
  final bool _ownsClient;
  String? _cachedToken;
  double _tokenExpiresAt = 0;

  String get _providerName =>
      settings.provider.isNotEmpty ? settings.provider : 'gsma-sandbox';

  @override
  String get name => _providerName;

  http.Client get _http => _client ??= http.Client();

  void close() {
    if (_ownsClient) _client?.close();
  }

  void _requireLive({required bool needsPhone, String? phoneNumber}) {
    if (settings.authFlow == 'mock' || settings.authFlow == 'simulation') {
      throw ProviderNotConfigured(
          'Live integration is unconfigured (OG_AUTH_FLOW=${settings.authFlow}).');
    }
    final missing = settings.missingConfig;
    if (missing.isNotEmpty) {
      throw ProviderNotConfigured(
          'Missing live configuration: ${missing.join(', ')}');
    }
    if (needsPhone && (phoneNumber == null || phoneNumber.isEmpty)) {
      throw ProviderBadResponse(
          'phone_number is required for 2-legged (client_credentials) flow '
          '(CAMARA v2 422 MISSING_IDENTIFIER).');
    }
    if (_tokenBoundFlows.contains(settings.authFlow) &&
        phoneNumber != null &&
        phoneNumber.isNotEmpty) {
      throw ProviderBadResponse(
          'phone_number MUST NOT be provided for token-bound 3-legged flows '
          '(CAMARA v2 422 UNNECESSARY_IDENTIFIER).');
    }
  }

  bool get _isThreeLegged => _threeLeggedFlows.contains(settings.authFlow);

  static void validateMaxAge(dynamic maxAgeHours) {
    try {
      parseMaxAge(maxAgeHours);
    } on FormatException catch (e) {
      throw ProviderBadResponse('$e');
    }
  }

  Future<String> _accessToken(String? phoneNumber) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch / 1000;
    if (_cachedToken != null && now < _tokenExpiresAt - 30) {
      return _cachedToken!;
    }
    final flow = settings.authFlow;
    if (flow != 'bearer' && settings.simSwapScope.isEmpty) {
      throw ProviderNotConfigured(
          'OG_SIM_SWAP_SCOPE is empty. Copy the exact scope(s) from the '
          'sandbox portal for SIM Swap (do not guess).');
    }
    final previousExpiry = _tokenExpiresAt;
    late final String token;
    if (flow == 'bearer') {
      // Portal-issued token, read fresh every call (never cached): a
      // rotated/revoked token takes effect without restarting the process.
      if (settings.bearerToken.isEmpty) {
        throw ProviderNotConfigured(
            'OG_SIM_SWAP_BEARER_TOKEN is empty. Export the portal-issued '
            'bearer token locally; it is never hardcoded or logged.');
      }
      return settings.bearerToken;
    } else if (flow == 'client_credentials') {
      token = await _tokenClientCredentials();
    } else if (flow == 'ciba') {
      token = await _tokenCiba(phoneNumber);
    } else {
      throw ProviderNotConfigured(
          "Auth flow '$flow' requires an externally acquired 3-legged "
          'access token which is not configured in this MVP. Use '
          'OG_AUTH_FLOW=bearer, ciba, or client_credentials.');
    }
    _cachedToken = token;
    if (_tokenExpiresAt == previousExpiry) {
      _tokenExpiresAt = now + 300;
    }
    return token;
  }

  Future<Map<String, dynamic>> _formPost(
    String url,
    Map<String, String> headers,
    Map<String, String> fields,
  ) async {
    try {
      final res = await _http
          .post(Uri.parse(url), headers: headers, body: fields)
          .timeout(_timeout);
      return {'status': res.statusCode, 'body': res.body};
    } on TimeoutException catch (e) {
      throw ProviderTimeout('Token request timed out: $e');
    } on http.ClientException catch (e) {
      throw ProviderUnavailable('Token request failed: $e');
    }
  }

  Duration get _timeout => Duration(
      milliseconds: (settings.timeoutSeconds * 1000).round());

  static Map<String, dynamic> _decodeJson(String body, String what) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      throw ProviderBadResponse('$what returned invalid JSON.');
    } on FormatException {
      throw ProviderBadResponse('$what returned invalid JSON.');
    }
  }

  Future<String> _tokenClientCredentials() async {
    final out = await _formPost(
      settings.tokenUrl,
      {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Authorization':
            _basicAuth(settings.clientId, settings.clientSecret),
      },
      {
        'grant_type': 'client_credentials',
        'scope': settings.simSwapScope,
      },
    );
    final status = out['status'] as int;
    if (status == 401 || status == 403) {
      throw ProviderAuthError('Token endpoint rejected client credentials.');
    }
    if (status == 429) throw ProviderRateLimited();
    if (status >= 500) {
      throw ProviderUnavailable('Token endpoint error HTTP $status.');
    }
    if (status != 200) {
      throw ProviderAuthError('Token endpoint returned HTTP $status.');
    }
    final payload = _decodeJson(out['body'] as String, 'Token endpoint');
    final token = payload['access_token'];
    if (token is! String || token.isEmpty) {
      throw ProviderBadResponse('Token response missing access_token.');
    }
    final expiresIn = payload['expires_in'];
    if (expiresIn is num) {
      _tokenExpiresAt =
          DateTime.now().toUtc().millisecondsSinceEpoch / 1000 +
              expiresIn.toDouble();
    }
    return token;
  }

  Future<String> _tokenCiba(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      throw ProviderBadResponse(
          'phone_number is required to start CIBA (used as login_hint).');
    }
    if (settings.bcAuthorizeUrl.isEmpty) {
      throw ProviderNotConfigured(
          'OG_BC_AUTHORIZE_URL is required for CIBA flow.');
    }
    final auth =
        _basicAuth(settings.clientId, settings.clientSecret);
    final bc = await _formPost(
      settings.bcAuthorizeUrl,
      {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Authorization': auth,
      },
      {
        'login_hint': 'tel:$phoneNumber',
        'scope': settings.simSwapScope,
      },
    );
    final bcStatus = bc['status'] as int;
    if (bcStatus == 401 || bcStatus == 403) {
      throw ProviderAuthError('CIBA authorize rejected client credentials.');
    }
    if (bcStatus == 429) throw ProviderRateLimited();
    if (bcStatus >= 400) {
      throw ProviderAuthError('CIBA authorize returned HTTP $bcStatus.');
    }
    final bcPayload =
        _decodeJson(bc['body'] as String, 'CIBA authorize');
    final authReqId = bcPayload['auth_req_id'];
    if (authReqId is! String || authReqId.isEmpty) {
      throw ProviderBadResponse('CIBA authorize missing auth_req_id.');
    }
    // Single immediate poll (reference behavior) — NOT verified against a
    // live sandbox. Confirm polling interval/retries with the portal.
    final tok = await _formPost(
      settings.tokenUrl,
      {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Authorization': auth,
      },
      {
        'grant_type': 'urn:openid:params:grant-type:ciba',
        'auth_req_id': authReqId,
      },
    );
    final tokStatus = tok['status'] as int;
    if (tokStatus == 400 || tokStatus == 401 || tokStatus == 403) {
      throw ProviderAuthError(
          'CIBA token poll not authorized (user may not have approved, '
          'HTTP $tokStatus).');
    }
    if (tokStatus == 429) throw ProviderRateLimited();
    if (tokStatus >= 500) {
      throw ProviderUnavailable(
          'CIBA token endpoint error HTTP $tokStatus.');
    }
    final tokPayload =
        _decodeJson(tok['body'] as String, 'CIBA token');
    final token = tokPayload['access_token'];
    if (token is! String || token.isEmpty) {
      throw ProviderBadResponse('CIBA token response missing access_token.');
    }
    return token;
  }

  Future<Map<String, dynamic>> _postApi(
    String path,
    String token,
    Map<String, dynamic> body,
    String correlator,
  ) async {
    final url = '${settings.apiBaseUrl}$path';
    try {
      final res = await _http
          .post(
            Uri.parse(url),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
              'x-correlator': correlator,
            },
            body: jsonEncode(body),
          )
          .timeout(_timeout);
      return {'status': res.statusCode, 'body': res.body};
    } on TimeoutException catch (e) {
      throw ProviderTimeout('SIM Swap API timed out: $e');
    } on http.ClientException catch (e) {
      throw ProviderUnavailable('SIM Swap API request failed: $e');
    }
  }

  static (String, String) _codeAndMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return (
          '${decoded['code'] ?? ''}',
          '${decoded['message'] ?? ''}'
        );
      }
    } catch (_) {}
    return ('', '');
  }

  void _raiseForApiStatus(int code, String body) {
    if (code == 429) {
      throw ProviderRateLimited('SIM Swap API rate limit exceeded.');
    }
    if (code == 401 || code == 403) {
      final (apiCode, message) = _codeAndMessage(body);
      throw ProviderAuthError(
          'SIM Swap API rejected access token. $apiCode $message'.trim());
    }
    if (code == 404) {
      final (apiCode, message) = _codeAndMessage(body);
      throw ProviderUnavailable(
          'SIM Swap API: subscription not found. $apiCode $message'.trim());
    }
    if (code == 400) {
      final (apiCode, message) = _codeAndMessage(body);
      throw ProviderBadResponse(
          'SIM Swap API rejected request. $apiCode $message'.trim());
    }
    if (code == 422) {
      final (apiCode, message) = _codeAndMessage(body);
      throw ProviderBadResponse(
          'SIM Swap identifier error. $apiCode $message'.trim());
    }
    if (code >= 500) {
      final (apiCode, message) = _codeAndMessage(body);
      throw ProviderUnavailable(
          'SIM Swap API error HTTP $code. $apiCode $message'.trim());
    }
    if (code != 200) {
      throw ProviderBadResponse('SIM Swap API returned HTTP $code.');
    }
  }

  Map<String, dynamic> _buildCheckBody({
    required String? phoneNumber,
    required int maxAgeHours,
  }) {
    validateMaxAge(maxAgeHours);
    final body = <String, dynamic>{'maxAge': maxAgeHours};
    if (phoneNumber != null &&
        phoneNumber.isNotEmpty &&
        !_isThreeLegged) {
      body['phoneNumber'] = phoneNumber;
    }
    return body;
  }

  Map<String, dynamic> _buildRetrieveBody({required String? phoneNumber}) {
    final body = <String, dynamic>{};
    if (phoneNumber != null &&
        phoneNumber.isNotEmpty &&
        !_isThreeLegged) {
      body['phoneNumber'] = phoneNumber;
    }
    return body;
  }

  @override
  Future<CheckOutcome> check({
    required String? phoneNumber,
    required int maxAgeHours,
  }) async {
    validateMaxAge(maxAgeHours);
    final threeLegged = _isThreeLegged;
    _requireLive(needsPhone: !threeLegged, phoneNumber: phoneNumber);
    final token = await _accessToken(phoneNumber);
    final body = _buildCheckBody(
        phoneNumber: phoneNumber, maxAgeHours: maxAgeHours);
    final correlator = _newCorrelator();
    final out = await _postApi('/check', token, body, correlator);
    _raiseForApiStatus(out['status'] as int, out['body'] as String);
    final payload =
        _decodeJson(out['body'] as String, 'SIM Swap /check');
    final swapped = payload['swapped'];
    if (swapped is! bool) {
      throw ProviderBadResponse("SIM Swap /check missing boolean 'swapped'.");
    }
    return CheckOutcome(
      swapped: swapped,
      maxAgeHours: maxAgeHours,
      correlator: correlator,
      httpStatus: out['status'] as int,
    );
  }

  @override
  Future<RetrieveDateOutcome> retrieveDate({
    required String? phoneNumber,
  }) async {
    final threeLegged = _isThreeLegged;
    _requireLive(needsPhone: !threeLegged, phoneNumber: phoneNumber);
    final token = await _accessToken(phoneNumber);
    final body = _buildRetrieveBody(phoneNumber: phoneNumber);
    final correlator = _newCorrelator();
    final out = await _postApi('/retrieve-date', token, body, correlator);
    _raiseForApiStatus(out['status'] as int, out['body'] as String);
    final payload =
        _decodeJson(out['body'] as String, 'SIM Swap /retrieve-date');
    if (!payload.containsKey('latestSimChange')) {
      throw ProviderBadResponse(
          "SIM Swap /retrieve-date missing 'latestSimChange'.");
    }
    final latest = parseCamaraDateTime(payload['latestSimChange']);
    final monitored = payload['monitoredPeriod'];
    if (monitored != null && monitored is! int) {
      throw ProviderBadResponse(
          'monitoredPeriod must be an integer or absent.');
    }
    return RetrieveDateOutcome(
      latestSimChange: latest,
      monitoredPeriodDays: monitored as int?,
      correlator: correlator,
      httpStatus: out['status'] as int,
    );
  }
}

/// Live CAMARA SimSwap v1.0.0 adapter.
///
/// Lenient phone rule exactly like the portal Swagger: phoneNumber optional
/// with 3-legged tokens, passed through for server-side validation.
/// Documented errors: 400 INVALID_ARGUMENT, 401 UNAUTHENTICATED,
/// 403 PERMISSION_DENIED (+ INVALID_TOKEN_CONTEXT tolerated),
/// 404 NOT_FOUND, 422 NOT_SUPPORTED (+ UNIDENTIFIABLE_PHONE_NUMBER
/// tolerated), 500 INTERNAL, 503 UNAVAILABLE, 504 TIMEOUT. No
/// `monitoredPeriod` in v1 responses (absent -> null).
class SimSwapV1Provider extends GsmaSandboxProvider {
  SimSwapV1Provider(super.settings, {super.client});

  @override
  String get name {
    final base = settings.provider.isNotEmpty ? settings.provider : 'mock';
    return base == 'mock' ? 'gsma-sandbox-v1' : base;
  }

  @override
  void _requireLive({required bool needsPhone, String? phoneNumber}) {
    if (settings.authFlow == 'mock' || settings.authFlow == 'simulation') {
      throw ProviderNotConfigured(
          'Live integration is unconfigured (OG_AUTH_FLOW=${settings.authFlow}).');
    }
    final missing = settings.missingConfig;
    if (missing.isNotEmpty) {
      throw ProviderNotConfigured(
          'Missing live configuration: ${missing.join(', ')}');
    }
    if (needsPhone && (phoneNumber == null || phoneNumber.isEmpty)) {
      throw ProviderBadResponse(
          'phone_number is required for 2-legged (client_credentials) flow '
          '(CAMARA v1: phoneNumber MUST be provided).');
    }
    // v1 lenient: never reject phoneNumber for 3-legged flows here.
  }

  @override
  Map<String, dynamic> _buildCheckBody({
    required String? phoneNumber,
    required int maxAgeHours,
  }) {
    GsmaSandboxProvider.validateMaxAge(maxAgeHours);
    final body = <String, dynamic>{'maxAge': maxAgeHours};
    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      body['phoneNumber'] = phoneNumber;
    }
    return body;
  }

  @override
  Map<String, dynamic> _buildRetrieveBody({required String? phoneNumber}) {
    final body = <String, dynamic>{};
    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      body['phoneNumber'] = phoneNumber;
    }
    return body;
  }
}

/// Factory: mock unless live credentials + non-mock flow are configured.
/// Selects the separate v1/v2 adapter by OG_SIM_SWAP_API_VERSION.
/// `simulation` returns the stateful temporary-data provider (offline).
SimSwapProvider buildSimSwapProvider(
  SimSwapSettings settings, {
  SimulationStore? simulationStore,
}) {
  if (settings.authFlow == 'simulation') {
    return SimulatedSimSwapProvider(
      name: settings.provider,
      store: simulationStore,
    );
  }
  if (settings.authFlow == 'mock' || !settings.isLiveConfigured) {
    return MockSimSwapProvider(name: settings.provider);
  }
  if (settings.isV1) return SimSwapV1Provider(settings);
  return GsmaSandboxProvider(settings);
}
