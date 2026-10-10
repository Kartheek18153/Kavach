/// Provider abstraction: keeps CAMARA HTTP details out of business logic.
///
/// A provider failure NEVER maps to a negative result — the service layer
/// turns every [ProviderError] into `unknown` / `check_unavailable`.
library;

/// Base class for all provider failures. Never maps to `false`.
class ProviderError implements Exception {
  ProviderError(this.message);
  final String message;
  @override
  String toString() => message;
}

class ProviderNotConfigured extends ProviderError {
  ProviderNotConfigured(super.message);
}

class ProviderAuthError extends ProviderError {
  ProviderAuthError(super.message);
}

class ProviderTimeout extends ProviderError {
  ProviderTimeout(super.message);
}

class ProviderRateLimited extends ProviderError {
  ProviderRateLimited([super.message = 'Rate limited by provider']);
}

class ProviderUnavailable extends ProviderError {
  ProviderUnavailable(super.message);
}

class ProviderBadResponse extends ProviderError {
  ProviderBadResponse(super.message);
}

class UnsupportedCapability extends ProviderError {
  UnsupportedCapability(super.message);
}

/// Outcome of POST /check.
class CheckOutcome {
  CheckOutcome({
    required this.swapped,
    required this.maxAgeHours,
    this.correlator,
    this.httpStatus,
  });
  final bool swapped;
  final int maxAgeHours;
  final String? correlator;
  final int? httpStatus;
}

/// Outcome of POST /retrieve-date.
class RetrieveDateOutcome {
  RetrieveDateOutcome({
    required this.latestSimChange,
    this.monitoredPeriodDays,
    this.correlator,
    this.httpStatus,
  });
  final DateTime? latestSimChange;
  final int? monitoredPeriodDays;
  final String? correlator;
  final int? httpStatus;
}

/// Interface every provider (live, mock, simulation) must implement.
abstract class SimSwapProvider {
  String get name;
  bool get supportsCheck => true;
  bool get supportsRetrieveDate => true;

  Future<CheckOutcome> check({
    required String? phoneNumber,
    required int maxAgeHours,
  });

  Future<RetrieveDateOutcome> retrieveDate({required String? phoneNumber});
}
