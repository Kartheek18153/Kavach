/// Deterministic mock for dev/tests. No network.
library;

import 'provider.dart';

/// Numbers ending in `0000` simulate a recent swap; everything else = no swap.
/// Retrieve-date agrees: swap 24h ago, or (null, monitoredPeriod 120).
class MockSimSwapProvider extends SimSwapProvider {
  MockSimSwapProvider({String? name}) : _name = name ?? 'mock';
  final String _name;

  @override
  String get name => _name;

  @override
  Future<CheckOutcome> check({
    required String? phoneNumber,
    required int maxAgeHours,
  }) async {
    final swapped = (phoneNumber ?? '').endsWith('0000');
    return CheckOutcome(swapped: swapped, maxAgeHours: maxAgeHours);
  }

  @override
  Future<RetrieveDateOutcome> retrieveDate({
    required String? phoneNumber,
  }) async {
    if ((phoneNumber ?? '').endsWith('0000')) {
      return RetrieveDateOutcome(
        latestSimChange:
            DateTime.now().toUtc().subtract(const Duration(hours: 24)),
      );
    }
    return RetrieveDateOutcome(
        latestSimChange: null, monitoredPeriodDays: 120);
  }
}
