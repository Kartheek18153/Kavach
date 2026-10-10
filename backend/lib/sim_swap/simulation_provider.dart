/// Stateful simulation with temporary in-memory data.
///
/// A functioning simulation, not a fixed script: a volatile subscriber
/// registry (phone -> activation + swap history) mutated through the
/// simulator management endpoints. Restart reseeds the demo numbers.
/// Never mixed with live mode — the factory only selects this provider
/// for `OG_AUTH_FLOW=simulation`.
library;

import 'provider.dart';
import 'validation.dart';

class SubscriberRecord {
  SubscriberRecord({
    required this.phoneNumber,
    required this.activatedAt,
    List<DateTime>? swaps,
  }) : swaps = swaps ?? [];

  final String phoneNumber;
  final DateTime activatedAt;
  final List<DateTime> swaps;
}

/// Thread-safe-by-construction (single-threaded event loop) temp registry.
/// All data is fake and disposable. Responses carry masked phones only.
class SimulationStore {
  final Map<String, SubscriberRecord> _subscribers = {};

  void reset({bool seed = true}) {
    _subscribers.clear();
    if (seed) seedDemoData();
  }

  void seedDemoData() {
    final now = DateTime.now().toUtc();
    _subscribers['+346661113334'] = SubscriberRecord(
      phoneNumber: '+346661113334',
      activatedAt: now.subtract(const Duration(days: 90)),
    );
    _subscribers['+3412340000'] = SubscriberRecord(
      phoneNumber: '+3412340000',
      activatedAt: now.subtract(const Duration(days: 90)),
      swaps: [now.subtract(const Duration(hours: 5))],
    );
  }

  SubscriberRecord addSubscriber(String phoneNumber) {
    return _subscribers.putIfAbsent(
      phoneNumber,
      () => SubscriberRecord(
          phoneNumber: phoneNumber, activatedAt: DateTime.now().toUtc()),
    );
  }

  DateTime recordSwap(String phoneNumber, [DateTime? at]) {
    final moment = (at ?? DateTime.now().toUtc()).toUtc();
    final record = _subscribers.putIfAbsent(
      phoneNumber,
      () => SubscriberRecord(phoneNumber: phoneNumber, activatedAt: moment),
    );
    record.swaps.add(moment);
    return moment;
  }

  SubscriberRecord? get(String phoneNumber) => _subscribers[phoneNumber];

  /// Masked overview for the management endpoint. Never full numbers.
  List<Map<String, Object?>> snapshot() {
    final entries = _subscribers.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return [
      for (final e in entries)
        {
          'maskedPhone': maskPhone(e.key),
          'swapCount': e.value.swaps.length,
          'lastEventAt': e.value.swaps.isEmpty
              ? null
              : e.value.swaps
                  .reduce((a, b) => a.isAfter(b) ? a : b)
                  .toIso8601String(),
        },
    ];
  }
}

/// Process-wide shared registry (seeded once). The factory uses this by
/// default so simulator mutations persist across requests; tests inject
/// fresh stores for isolation.
final SimulationStore sharedSimulationStore =
    SimulationStore()..seedDemoData();

/// v1-shaped provider backed by the temporary simulation store.
class SimulatedSimSwapProvider extends SimSwapProvider {
  SimulatedSimSwapProvider({String? name, SimulationStore? store})
      : _name = name ?? 'simulation',
        _store = store ?? sharedSimulationStore;

  final String _name;
  final SimulationStore _store;

  SimulationStore get store => _store;

  @override
  String get name => _name;

  @override
  Future<CheckOutcome> check({
    required String? phoneNumber,
    required int maxAgeHours,
  }) async {
    final record = _store.get(phoneNumber ?? '');
    if (record == null) {
      throw ProviderUnavailable('Simulated registry has no such subscriber.');
    }
    final now = DateTime.now().toUtc();
    final swapped = record.swaps.any(
        (e) => now.difference(e).inSeconds / 3600 <= maxAgeHours);
    return CheckOutcome(swapped: swapped, maxAgeHours: maxAgeHours);
  }

  @override
  Future<RetrieveDateOutcome> retrieveDate({
    required String? phoneNumber,
  }) async {
    final record = _store.get(phoneNumber ?? '');
    if (record == null) {
      throw ProviderUnavailable('Simulated registry has no such subscriber.');
    }
    if (record.swaps.isNotEmpty) {
      return RetrieveDateOutcome(
          latestSimChange:
              record.swaps.reduce((a, b) => a.isAfter(b) ? a : b));
    }
    // v1 default: activation date when no swap was ever performed.
    return RetrieveDateOutcome(latestSimChange: record.activatedAt);
  }
}
