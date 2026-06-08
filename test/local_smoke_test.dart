import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/local_smoke.dart';

void main() {
  test('local smoke passes against a basic backend and web shell', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = server.listen(_handleSmokeRequest);
    final base = Uri.parse('http://${server.address.address}:${server.port}');

    try {
      final report = await runLocalSmoke(
        apiBase: base,
        webBase: base,
        identifier: 'demo@wayfare.local',
        query: 'orange',
        timeout: const Duration(seconds: 5),
      );

      expect(report.passed, isTrue, reason: report.render());
      expect(
        report.checks.map((check) => check.name),
        containsAll([
          'backend-health',
          'auth-login',
          'auth-me',
          'search',
          'web-index',
        ]),
      );
    } finally {
      await subscription.cancel();
      await server.close(force: true);
    }
  });
}

Future<void> _handleSmokeRequest(HttpRequest request) async {
  if (request.method == 'GET' && request.uri.path == '/') {
    _writeText(request, '<title>Wayfare Travel Planner</title>');
    return;
  }

  if (request.method == 'GET' && request.uri.path == '/health') {
    _writeJson(request, {
      'status': 'ok',
      'storage': 'SQLite',
      'schemaVersion': 1,
    });
    return;
  }

  if (request.method == 'POST' && request.uri.path == '/auth/login') {
    final body = await _readJson(request);
    _writeJson(request, {
      'token': 'fake-token',
      'identifier': body['identifier'],
    });
    return;
  }

  if (request.method == 'GET' && request.uri.path == '/me') {
    if (request.headers.value(HttpHeaders.authorizationHeader) !=
        'Bearer fake-token') {
      request.response.statusCode = HttpStatus.unauthorized;
      _writeJson(request, {'error': 'Unauthorized'});
      return;
    }
    _writeJson(request, {
      'user': {'identifier': 'demo@wayfare.local'},
    });
    return;
  }

  if (request.method == 'GET' && request.uri.path == '/search') {
    _writeJson(request, {
      'items': [
        {'id': 'spot-orange', 'name': 'Orange Isle'},
      ],
    });
    return;
  }

  request.response.statusCode = HttpStatus.notFound;
  _writeJson(request, {'error': 'Not found'});
}

Future<Map<String, Object?>> _readJson(HttpRequest request) async {
  final text = await utf8.decoder.bind(request).join();
  final decoded = jsonDecode(text);
  if (decoded is Map<String, Object?>) {
    return decoded;
  }
  return const {};
}

void _writeJson(HttpRequest request, Map<String, Object?> body) {
  request.response
    ..headers.contentType = ContentType.json
    ..write(jsonEncode(body))
    ..close();
}

void _writeText(HttpRequest request, String body) {
  request.response
    ..headers.contentType = ContentType.html
    ..write(body)
    ..close();
}
