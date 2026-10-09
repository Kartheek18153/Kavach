/// Live domain-reputation lookup for the Link scanner.
///
/// Ports the reputation half of student-arch/hackthon (phishing_check.py):
/// WHOIS age, DNSBL blacklists and a recomputed A-F health grade from the
/// free dnsxray.com API (no key). Adapted for a phone: 6 s per-section
/// timeouts, everything fetched in parallel, 5-minute in-memory cache, and
/// total fail-soft — offline or API down means heuristics-only, never an
/// error screen.
///
/// Privacy: only the bare domain name is sent (never the full URL), only
/// when the user scans a link, and the UI always says whether the online
/// check ran.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'scanners.dart' show UrlFinding;

const _api = 'https://dnsxray.com/v1.php';
const _sections = [
  'domain',
  'blacklist',
  'web',
  'mail',
  'emailsec',
  'security',
  'dns',
  'dnssec',
  'ipv6',
];
const _requestTimeout = Duration(seconds: 8);
const _cacheTtl = Duration(minutes: 5);

/// Domain facts shown under the verdict.
class DomainFacts {
  final String? registered;
  final int? ageDays;
  final String? registrar;
  final String? expiry;
  final int? expiryDays;
  final String? statuses;
  final String? nameservers;
  final String? dnssec;
  final String? grade;
  final int? healthScore;
  final int healthPass;
  final int healthWarn;
  final int healthFail;
  final int? blacklistFail;
  final List<String> blacklistDetails;
  final bool? httpsOk;
  final double fetchSecs;
  final bool cached;
  final List<String> sectionsFailed;
  final String? error;

  const DomainFacts({
    this.registered,
    this.ageDays,
    this.registrar,
    this.expiry,
    this.expiryDays,
    this.statuses,
    this.nameservers,
    this.dnssec,
    this.grade,
    this.healthScore,
    this.healthPass = 0,
    this.healthWarn = 0,
    this.healthFail = 0,
    this.blacklistFail,
    this.blacklistDetails = const [],
    this.httpsOk,
    this.fetchSecs = 0,
    this.cached = false,
    this.sectionsFailed = const [],
    this.error,
  });

  /// True when at least one live section answered.
  bool get online => grade != null || ageDays != null || blacklistFail != null;
}

class ReputationResult {
  final List<UrlFinding> findings;
  final DomainFacts facts;
  const ReputationResult(this.findings, this.facts);
}

final Map<String, (DateTime, ReputationResult)> _cache = {};

Future<({Map<String, dynamic> section, String? error})> _fetchSection(
  http.Client client,
  String host,
  String kind,
) async {
  try {
    final uri = kind == 'whois'
        ? Uri.parse('$_api?action=whois&target=$host')
        : Uri.parse('$_api?domain=$host&section=$kind');
    final res = await client
        .get(uri, headers: {'User-Agent': 'kavach-link-check/1.0'})
        .timeout(_requestTimeout);
    if (res.statusCode != 200) {
      return (section: <String, dynamic>{}, error: 'http ${res.statusCode}');
    }
    final payload = jsonDecode(res.body);
    if (payload is! Map<String, dynamic>) {
      return (section: <String, dynamic>{}, error: 'bad response');
    }
    if (kind == 'whois') return (section: payload, error: null);
    final sections = payload['sections'];
    final sec = sections is Map ? sections[kind] : null;
    if (sec is Map<String, dynamic>) return (section: sec, error: null);
    return (section: <String, dynamic>{}, error: 'no section');
  } on TimeoutException {
    return (section: <String, dynamic>{}, error: 'timed out');
  } catch (e) {
    return (section: <String, dynamic>{}, error: '$e');
  }
}

List<Map<String, dynamic>> _rows(Map<String, dynamic>? section) {
  final rows = section?['rows'];
  if (rows is! List) return const [];
  return rows.whereType<Map<String, dynamic>>().toList();
}

String? _detail(List<Map<String, dynamic>> rows, List<String> names) {
  final want = names.map((n) => n.toLowerCase()).toSet();
  for (final r in rows) {
    if (want.contains('${r['title'] ?? ''}'.toLowerCase())) {
      return '${r['detail'] ?? ''}';
    }
  }
  return null;
}

DateTime? _parseDate(String s) {
  try {
    var dt = DateTime.parse(s.replaceAll('Z', ''));
    return dt.isUtc ? dt : dt.toUtc();
  } catch (_) {
    return null;
  }
}

/// Progressive snapshot: partial findings/facts plus completion counts.
/// The UI renders each snapshot, so fast sections show in ~2 s while slow
/// ones (blacklists) stream in later instead of blocking everything.
class RepProgress {
  final ReputationResult result;
  final int done;
  final int total;
  final bool finished;
  const RepProgress(this.result, this.done, this.total, this.finished);
}

/// Looks up [host] reputation, emitting a snapshot every time a section
/// lands. All sections fire at once (parallel); slow ones get one
/// background retry while the UI already shows partial data.
/// Never throws: failures become findings-free facts.
Stream<RepProgress> watchReputation(
  String host, {
  http.Client? client,
  bool forceRefresh = false,
}) async* {
  host = host.trim().toLowerCase();
  if (host.isEmpty) {
    yield const RepProgress(
        ReputationResult([], DomainFacts(error: 'empty host')), 0, 0, true);
    return;
  }
  final hit = _cache[host];
  if (!forceRefresh &&
      hit != null &&
      DateTime.now().difference(hit.$1) < _cacheTtl) {
    yield RepProgress(hit.$2, _kinds.length, _kinds.length, true);
    return;
  }
  final owned = client == null;
  final ownedClient = owned ? http.Client() : client;
  final t0 = DateTime.now();
  final sections = <String, Map<String, dynamic>>{};
  final errors = <String, String>{};
  Map<String, dynamic> whois = {};
  final controller = StreamController<RepProgress>();

  int doneCount() =>
      sections.length + (whois.isNotEmpty ? 1 : 0);

  void emit({required bool finished}) {
    if (controller.isClosed) return;
    controller.add(RepProgress(
      _buildResult(host, sections, Map.of(errors), Map.of(whois), t0,
          cache: finished),
      doneCount(),
      _kinds.length,
      finished,
    ));
  }

  Future<void> runKind(String kind) async {
    final r = await _fetchSection(ownedClient, host, kind);
    if (controller.isClosed) return;
    if (r.error != null) {
      errors[kind] = r.error!;
    } else {
      errors.remove(kind);
      if (kind == 'whois') {
        whois = r.section;
      } else {
        sections[kind] = r.section;
      }
    }
    emit(finished: false);
  }

  // Pass 1: everything at once; pass 2: retry whatever missed.
  // ignore: unawaited_futures
  Future.wait(_kinds.map(runKind)).then((_) async {
    final missing = _kinds
        .where((k) => k != 'whois'
            ? !sections.containsKey(k)
            : whois.isEmpty)
        .toList();
    if (missing.isNotEmpty && !controller.isClosed) {
      await Future.wait(missing.map(runKind));
    }
    emit(finished: true);
    await controller.close();
    if (owned) ownedClient.close();
  });
  yield* controller.stream;
}

const _kinds = [..._sections, 'whois'];

ReputationResult _buildResult(
  String host,
  Map<String, Map<String, dynamic>> sections,
  Map<String, String> errors,
  Map<String, dynamic> whois,
  DateTime t0, {
  required bool cache,
}) {
    if (sections.isEmpty && whois.isEmpty) {
      final msg = errors.values.toSet().join('; ');
      return ReputationResult(
        [],
        DomainFacts(
          error: msg.isEmpty ? 'all lookups failed' : msg,
          fetchSecs: _secs(t0),
          sectionsFailed: _kinds,
        ),
      );
    }

    final findings = <UrlFinding>[];
    String? registrar;
    String? registered;
    int? ageDays;
    String? expiry;
    int? expiryDays;
    String? statuses;
    String? nameservers;
    String? dnssec;

    // WHOIS / domain age (domain section, parallel whois as fallback).
    final drows = _rows(sections['domain']);
    String? reg = _detail(drows, ['Registered']);
    if (reg != null) {
      final dt = _parseDate(reg.trim().split(' ').first);
      if (dt != null) {
        ageDays = DateTime.now().toUtc().difference(dt).inDays;
        registered =
            reg.length > 10 ? reg.substring(0, 10) : reg;
        registrar = _detail(drows, ['Registrar']);
        if (ageDays < 30) {
          findings.add(UrlFinding(
              30, 'Domain registered only $ageDays days ago.'));
        } else if (ageDays < 180) {
          findings.add(UrlFinding(
              20, 'Domain is young: $ageDays days old.'));
        } else if (ageDays < 365) {
          findings.add(
              UrlFinding(8, 'Domain is $ageDays days old (< 1 year).'));
        }
      }
      expiry = _detail(drows, ['Domain expiry']);
      if (expiry != null) {
        final m =
            RegExp(r'(\d+)\s+days?\s+remaining').firstMatch(expiry);
        expiryDays = m == null ? null : int.tryParse(m.group(1)!);
        if (expiryDays != null && expiryDays < 30) {
          findings.add(UrlFinding(
              10, 'Domain expires in $expiryDays days.'));
        }
      }
      statuses = _detail(drows, ['Domain status']);
      nameservers =
          _detail(drows, ['Nameservers (WHOIS)', 'Nameservers']);
      dnssec = _detail(drows, ['DNSSEC']);
      if (registered == null) {
        // Fall through to the parallel whois payload below.
        reg = null;
      }
    }
    if (reg == null && whois.isNotEmpty) {
      registrar = '${whois['registrar'] ?? ''}';
      final wreg = '${whois['registered'] ?? ''}';
      final dt = wreg.isEmpty ? null : _parseDate(wreg);
      if (dt != null) {
        ageDays = DateTime.now().toUtc().difference(dt).inDays;
        registered = wreg.length > 10 ? wreg.substring(0, 10) : wreg;
        if (ageDays < 30) {
          findings.add(UrlFinding(
              30, 'Domain registered only $ageDays days ago.'));
        } else if (ageDays < 180) {
          findings.add(UrlFinding(
              20, 'Domain is young: $ageDays days old.'));
        }
      } else if (whois['not_found'] == true) {
        findings.add(const UrlFinding(25, 'WHOIS record not found.'));
      }
    }

    // Blacklists.
    int? blacklistFail;
    final blacklistDetails = <String>[];
    if (sections.containsKey('blacklist')) {
      final bad = _rows(sections['blacklist'])
          .where((r) => r['status'] == 'fail')
          .toList();
      blacklistFail = bad.length;
      if (bad.isNotEmpty) {
        findings.add(UrlFinding(40,
            'Listed on ${bad.length} blacklist(s): ${bad.take(3).map((r) => r['title'] ?? '?').join(', ')}.'));
        for (final r in bad.take(3)) {
          blacklistDetails.add('${r['title'] ?? '?'}');
        }
      }
    }

    // Health grade recomputed locally (100 - fails*8 - warns*3).
    String? grade;
    int? healthScore;
    int fails = 0;
    int warns = 0;
    int passes = 0;
    bool? httpsOk;
    if (sections.isNotEmpty) {
      for (final s in sections.values) {
        final counts = s['counts'];
        if (counts is Map) {
          fails += (counts['fail'] as num? ?? 0).toInt();
          warns += (counts['warn'] as num? ?? 0).toInt();
          passes += (counts['pass'] as num? ?? 0).toInt();
        }
      }
      healthScore = (100 - fails * 8 - warns * 3).clamp(0, 100);
      grade = healthScore >= 90
          ? 'A'
          : healthScore >= 80
              ? 'B'
              : healthScore >= 70
                  ? 'C'
                  : healthScore >= 50
                      ? 'D'
                      : 'F';
      if (grade == 'E' || grade == 'F' || fails >= 6) {
        findings.add(UrlFinding(
            15, 'Poor domain health grade $grade ($fails checks failing).'));
      }
      final web = _rows(sections['web']);
      if (web.isNotEmpty) {
        final noHttps = web.any((r) =>
            r['status'] == 'fail' &&
            '${r['title'] ?? ''}'.toLowerCase().contains('https'));
        httpsOk = !noHttps;
        if (noHttps) {
          findings.add(const UrlFinding(15, 'No working HTTPS on this host.'));
        }
      }
      var mailFails = 0;
      for (final k in ['mail', 'emailsec']) {
        final counts = sections[k]?['counts'];
        if (counts is Map) {
          mailFails += (counts['fail'] as num? ?? 0).toInt();
        }
      }
      if (mailFails >= 3) {
        findings.add(UrlFinding(
            10, 'Weak mail authentication ($mailFails SPF/DKIM/DMARC fails).'));
      }
      final secCounts = sections['security']?['counts'];
      final secFails =
          secCounts is Map ? (secCounts['fail'] as num? ?? 0).toInt() : 0;
      if (secFails >= 3) {
        findings.add(UrlFinding(
            8, 'Weak web security posture ($secFails TLS/header fails).'));
      }
    }

    final failed =
        _kinds.where((k) => k != 'whois' && !sections.containsKey(k)).toList();
    if (whois.isEmpty) failed.add('whois');
    final result = ReputationResult(
      findings,
      DomainFacts(
        registered: registered,
        ageDays: ageDays,
        registrar: registrar?.isEmpty == true ? null : registrar,
        expiry: expiry,
        expiryDays: expiryDays,
        statuses: statuses,
        nameservers: nameservers,
        dnssec: dnssec,
        grade: grade,
        healthScore: healthScore,
        healthPass: passes,
        healthWarn: warns,
        healthFail: fails,
        blacklistFail: blacklistFail,
        blacklistDetails: blacklistDetails,
        httpsOk: httpsOk,
        fetchSecs: _secs(t0),
        sectionsFailed: failed,
        error: errors.isEmpty
            ? null
            : errors.entries
                .where((e) => e.key == 'blacklist' || e.key == 'domain')
                .map((e) => '${e.key}: ${e.value}')
                .join('; '),
      ),
    );
    if (cache && (sections.isNotEmpty || whois.isNotEmpty)) {
      _cache[host] = (DateTime.now(), result);
    }
    return result;
}

/// Final-result shorthand over [watchReputation] (tests, one-shot callers).
Future<ReputationResult> fetchReputation(
  String host, {
  http.Client? client,
  bool forceRefresh = false,
}) async {
  var last = const ReputationResult([], DomainFacts(error: 'empty host'));
  await for (final p
      in watchReputation(host, client: client, forceRefresh: forceRefresh)) {
    last = p.result;
  }
  return last;
}

double _secs(DateTime t0) =>
    DateTime.now().difference(t0).inMilliseconds / 1000.0;
