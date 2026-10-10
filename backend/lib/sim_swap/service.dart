/// Business logic: normalize provider outcomes into risk signals.
///
/// Three outcomes only:
///   completed + detected -> riskSignal=recent_sim_change
///   completed + no swap  -> riskSignal=no_recent_change
///   unknown/unsupported  -> riskSignal=check_unavailable/unsupported_operation
///
/// A provider failure NEVER becomes simSwapDetected=false.
library;

import 'config.dart';
import 'provider.dart';
import 'validation.dart';

String _nowIso() => DateTime.now().toUtc().toIso8601String();

class SimSwapService {
  SimSwapService({required this.provider, required this.settings});

  final SimSwapProvider provider;
  final SimSwapSettings settings;

  Map<String, dynamic> _base({
    required String status,
    required String? phoneNumber,
    required int? lookbackHours,
    String? detail,
  }) =>
      {
        'status': status,
        'provider': provider.name,
        'lookbackHours': lookbackHours,
        'checkedAt': _nowIso(),
        'maskedPhone': maskPhone(phoneNumber),
        'detail': detail,
        'evidence': <Map<String, dynamic>>[],
      };

  Map<String, dynamic> _unsupported(
      String? phoneNumber, int? lookbackHours, String detail) {
    final base = _base(
      status: 'unsupported',
      phoneNumber: phoneNumber,
      lookbackHours: lookbackHours,
      detail: detail,
    );
    return {
      ...base,
      'simSwapDetected': null,
      'lastSwapAt': null,
      'riskSignal': 'unsupported_operation',
    };
  }

  Map<String, dynamic> _unknown(
      String? phoneNumber, int? lookbackHours, String detail,
      [String? errorType]) {
    final base = _base(
      status: 'unknown',
      phoneNumber: phoneNumber,
      lookbackHours: lookbackHours,
      detail: detail,
    );
    if (errorType != null) {
      (base['evidence'] as List).add({
        'type': 'provider_error',
        'error': errorType,
      });
    }
    return {
      ...base,
      'simSwapDetected': null,
      'lastSwapAt': null,
      'riskSignal': 'check_unavailable',
    };
  }

  /// CAMARA POST /check. `lookbackHours` maps to CAMARA maxAge (1..2400).
  Future<Map<String, dynamic>> check({
    required String? phoneNumber,
    required int lookbackHours,
  }) async {
    if (!provider.supportsCheck) {
      return _unsupported(phoneNumber, lookbackHours,
          'Provider does not support SIM Swap check.');
    }
    late final CheckOutcome outcome;
    try {
      outcome = await provider.check(
          phoneNumber: phoneNumber, maxAgeHours: lookbackHours);
    } on UnsupportedCapability catch (e) {
      return _unsupported(phoneNumber, lookbackHours, '$e');
    } on ProviderError catch (e) {
      return _unknown(phoneNumber, lookbackHours,
          '${e.runtimeType}: $e', e.runtimeType.toString());
    }
    final base = _base(
      status: 'completed',
      phoneNumber: phoneNumber,
      lookbackHours: lookbackHours,
    );
    final evidence = <String, dynamic>{
      'type': 'sim_swap_check',
      'swapped': outcome.swapped,
      'maxAgeHours': outcome.maxAgeHours,
      'httpStatus': outcome.httpStatus,
    };
    if (outcome.correlator != null) {
      evidence['xCorrelator'] = outcome.correlator;
    }
    (base['evidence'] as List).add(evidence);
    // Calibrated verdicts, encoded in the payload so downstream consumers
    // cannot mistake a signal for proof (or absence for safety).
    final detail = outcome.swapped
        ? 'SIM swap reported within the last $lookbackHours h. '
            'Treat as a risk signal, not proof of fraud.'
        : 'No SIM swap reported within the last $lookbackHours h. '
            'This does not mean the number is safe.';
    return {
      ...base,
      'detail': detail,
      'simSwapDetected': outcome.swapped,
      'lastSwapAt': null,
      'riskSignal':
          outcome.swapped ? 'recent_sim_change' : 'no_recent_change',
    };
  }

  /// CAMARA POST /retrieve-date. Returns latestSimChange when supported.
  Future<Map<String, dynamic>> retrieveDate({
    required String? phoneNumber,
  }) async {
    if (!provider.supportsRetrieveDate) {
      return _unsupported(
          phoneNumber, null, 'Provider does not support retrieve-date.');
    }
    late final RetrieveDateOutcome outcome;
    try {
      outcome = await provider.retrieveDate(phoneNumber: phoneNumber);
    } on UnsupportedCapability catch (e) {
      return _unsupported(phoneNumber, null, '$e');
    } on ProviderError catch (e) {
      return _unknown(phoneNumber, null, '${e.runtimeType}: $e',
          e.runtimeType.toString());
    }
    // A null date WITHOUT monitoredPeriod (always the case for v1, which
    // has no monitoredPeriod) means operator retention is unknown — it must
    // NOT become a negative result. Map to unknown.
    if (outcome.latestSimChange == null &&
        outcome.monitoredPeriodDays == null) {
      final base = _base(
        status: 'unknown',
        phoneNumber: phoneNumber,
        lookbackHours: null,
        detail: 'Provider returned null latestSimChange without '
            'monitoredPeriod; operator retention is unknown, so no recency '
            'verdict is possible. This is not evidence of safety.',
      );
      final evidence = <String, dynamic>{
        'type': 'sim_swap_retrieve_date',
        'latestSimChange': null,
        'monitoredPeriodDays': null,
        'httpStatus': outcome.httpStatus,
      };
      if (outcome.correlator != null) {
        evidence['xCorrelator'] = outcome.correlator;
      }
      (base['evidence'] as List).add(evidence);
      return {
        ...base,
        'simSwapDetected': null,
        'lastSwapAt': null,
        'riskSignal': 'check_unavailable',
      };
    }
    final base = _base(
      status: 'completed',
      phoneNumber: phoneNumber,
      lookbackHours: null,
    );
    final evidence = <String, dynamic>{
      'type': 'sim_swap_retrieve_date',
      'latestSimChange': outcome.latestSimChange?.toIso8601String(),
      'monitoredPeriodDays': outcome.monitoredPeriodDays,
      'httpStatus': outcome.httpStatus,
    };
    if (outcome.correlator != null) {
      evidence['xCorrelator'] = outcome.correlator;
    }
    (base['evidence'] as List).add(evidence);
    bool? detected;
    var signal = 'no_recent_change';
    if (outcome.latestSimChange != null) {
      final ageHours = DateTime.now()
          .toUtc()
          .difference(outcome.latestSimChange!)
          .inSeconds /
          3600;
      detected = ageHours <= settings.defaultLookbackHours;
      signal = detected ? 'recent_sim_change' : 'no_recent_change';
    } else {
      // Only reachable for null WITH monitoredPeriod: no swap events in
      // the monitored window.
      detected = false;
    }
    return {
      ...base,
      'simSwapDetected': detected,
      'lastSwapAt': outcome.latestSimChange?.toIso8601String(),
      'monitoredPeriodDays': outcome.monitoredPeriodDays,
      'riskSignal': signal,
    };
  }
}
