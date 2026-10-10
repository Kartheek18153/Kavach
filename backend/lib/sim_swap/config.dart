/// SIM-swap provider configuration from environment variables.
///
/// Port of the reference FastAPI implementation's config (GSMA Open Gateway /
/// CAMARA SimSwap): no secrets are hardcoded; everything comes from the
/// environment. See backend/README.md for where to obtain each value.
library;

import 'dart:io';

String _get(String name, [String defaultValue = '']) =>
    (Platform.environment[name] ?? defaultValue).trim();

int _getInt(String name, int defaultValue) {
  final raw = Platform.environment[name] ?? '';
  if (raw.isEmpty) return defaultValue;
  return int.tryParse(raw) ?? defaultValue;
}

double _getDouble(String name, double defaultValue) {
  final raw = Platform.environment[name] ?? '';
  if (raw.isEmpty) return defaultValue;
  return double.tryParse(raw) ?? defaultValue;
}

/// Runtime settings for the SIM-swap integration.
class SimSwapSettings {
  SimSwapSettings({
    String? provider,
    String? clientId,
    String? clientSecret,
    String? bearerToken,
    String? apiBaseUrl,
    String? tokenUrl,
    String? bcAuthorizeUrl,
    String? simSwapScope,
    String? authFlow,
    double? timeoutSeconds,
    int? defaultLookbackHours,
    int? maxLookbackHours,
    String? simSwapApiVersion,
  })  : provider = provider ?? _get('OG_PROVIDER', 'gsma-sandbox'),
        clientId = clientId ?? _get('OG_CLIENT_ID'),
        clientSecret = clientSecret ?? _get('OG_CLIENT_SECRET'),
        bearerToken = bearerToken ?? _get('OG_SIM_SWAP_BEARER_TOKEN'),
        apiBaseUrl =
            (apiBaseUrl ?? _get('OG_API_BASE_URL')).replaceAll(RegExp(r'/+$'), ''),
        tokenUrl = tokenUrl ?? _get('OG_TOKEN_URL'),
        bcAuthorizeUrl = bcAuthorizeUrl ?? _get('OG_BC_AUTHORIZE_URL'),
        simSwapScope = simSwapScope ?? _get('OG_SIM_SWAP_SCOPE'),
        authFlow = (authFlow ?? _get('OG_AUTH_FLOW', 'mock')).toLowerCase(),
        timeoutSeconds =
            timeoutSeconds ?? _getDouble('OG_TIMEOUT_SECONDS', 10.0),
        defaultLookbackHours =
            defaultLookbackHours ?? _getInt('OG_DEFAULT_LOOKBACK_HOURS', 72),
        maxLookbackHours =
            maxLookbackHours ?? _getInt('OG_MAX_LOOKBACK_HOURS', 2400),
        simSwapApiVersion = (simSwapApiVersion ??
                _get('OG_SIM_SWAP_API_VERSION', 'v2'))
            .toLowerCase()
            .replaceAll(RegExp(r'^[ /]+|[/ ]+$'), '');

  final String provider;
  final String clientId;
  final String clientSecret;
  final String bearerToken;
  final String apiBaseUrl;
  final String tokenUrl;
  final String bcAuthorizeUrl;
  final String simSwapScope;
  final String authFlow;
  final double timeoutSeconds;
  final int defaultLookbackHours;
  final int maxLookbackHours;
  final String simSwapApiVersion;

  bool get isV1 => const {'v1', '1', '1.0', '1.0.0', 'v1.0.0'}
      .contains(simSwapApiVersion);

  /// True only when a real HTTP integration can be attempted.
  bool get isLiveConfigured {
    if (authFlow == 'mock' || authFlow == 'simulation') return false;
    if (authFlow == 'bearer') {
      return bearerToken.isNotEmpty && apiBaseUrl.isNotEmpty;
    }
    if (clientId.isEmpty ||
        clientSecret.isEmpty ||
        apiBaseUrl.isEmpty ||
        tokenUrl.isEmpty) {
      return false;
    }
    if (simSwapScope.isEmpty) return false;
    if (authFlow == 'ciba' && bcAuthorizeUrl.isEmpty) return false;
    return true;
  }

  /// Env names the operator must still supply (never the values).
  List<String> get missingConfig {
    if (authFlow == 'mock' || authFlow == 'simulation') return [];
    if (authFlow == 'bearer') {
      return [
        if (bearerToken.isEmpty) 'OG_SIM_SWAP_BEARER_TOKEN',
        if (apiBaseUrl.isEmpty) 'OG_API_BASE_URL',
      ];
    }
    return [
      if (clientId.isEmpty) 'OG_CLIENT_ID',
      if (clientSecret.isEmpty) 'OG_CLIENT_SECRET',
      if (apiBaseUrl.isEmpty) 'OG_API_BASE_URL',
      if (tokenUrl.isEmpty) 'OG_TOKEN_URL',
      if (simSwapScope.isEmpty) 'OG_SIM_SWAP_SCOPE',
      if (authFlow == 'ciba' && bcAuthorizeUrl.isEmpty)
        'OG_BC_AUTHORIZE_URL',
    ];
  }

  /// Never includes secret values — safe to log/return.
  Map<String, Object> describe() => {
        'provider': provider,
        'authFlow': authFlow,
        'liveConfigured': isLiveConfigured,
        'missingConfig': missingConfig,
      };
}
