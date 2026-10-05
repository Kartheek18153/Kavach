import 'dart:async';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';

import 'package:kavach_backend/server.dart';

/// `dart run bin/server.dart` — serves the Kavach API.
///
/// Env:
///   PORT (default 8080)
Future<void> main() async {
  final sessions = <String, ScoringSession>{};
  // Prevent unbounded growth from abandoned demo sessions.
  Timer.periodic(const Duration(minutes: 5), (_) => pruneSessions(sessions));
  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsHeaders())
      .addHandler(buildRouter(sessions).call);

  final port =
      int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  final server = await shelf_io.serve(handler, '0.0.0.0', port);
  // ignore: avoid_print
  print('Kavach backend on http://${server.address.host}:${server.port}');
}
