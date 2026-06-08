import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/local_smoke.dart';

void main() {
  test('local smoke passes against a basic backend and web shell', () async {
    final state = _SmokeState();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final subscription =
        server.listen((request) => _handleSmokeRequest(request, state));
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
          'itinerary-create',
          'itinerary-add-day',
          'itinerary-add-item',
          'itinerary-list',
          'itinerary-cleanup',
          'saved-create',
          'saved-list',
          'saved-cleanup',
          'feedback-validation',
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

class _SmokeState {
  final itineraries = <String, Map<String, Object?>>{};
  final savedItems = <String, Map<String, Object?>>{};
}

Future<void> _handleSmokeRequest(
  HttpRequest request,
  _SmokeState state,
) async {
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

  if (request.method == 'GET' && request.uri.path == '/search') {
    _writeJson(request, {
      'items': [
        {'id': 'spot-orange', 'name': 'Orange Isle'},
      ],
    });
    return;
  }

  if (!_hasFakeToken(request)) {
    request.response.statusCode = HttpStatus.unauthorized;
    _writeJson(request, {'error': 'Unauthorized'});
    return;
  }

  if (request.method == 'GET' && request.uri.path == '/me') {
    _writeJson(request, {
      'user': {'identifier': 'demo@wayfare.local'},
    });
    return;
  }

  final path = request.uri.pathSegments;

  if (request.method == 'POST' && request.uri.path == '/itineraries') {
    final body = await _readJson(request);
    final id = body['id']?.toString() ?? 'trip-fake';
    final item = {
      ...body,
      'id': id,
      'days': <Map<String, Object?>>[],
    };
    state.itineraries[id] = item;
    request.response.statusCode = HttpStatus.created;
    _writeJson(request, {'item': item});
    return;
  }

  if (request.method == 'GET' && request.uri.path == '/itineraries') {
    _writeJson(request, {'items': state.itineraries.values.toList()});
    return;
  }

  if (request.method == 'DELETE' &&
      path.length == 2 &&
      path.first == 'itineraries') {
    state.itineraries.remove(path[1]);
    _writeJson(request, {'deleted': path[1]});
    return;
  }

  if (request.method == 'POST' &&
      path.length == 3 &&
      path.first == 'itineraries' &&
      path[2] == 'days') {
    final body = await _readJson(request);
    final trip = state.itineraries[path[1]];
    final day = {
      ...body,
      'id': 'day-fake',
      'items': <Map<String, Object?>>[],
    };
    (trip?['days'] as List<Map<String, Object?>>?)?.add(day);
    request.response.statusCode = HttpStatus.created;
    _writeJson(request, {'item': day});
    return;
  }

  if (request.method == 'POST' &&
      path.length == 5 &&
      path.first == 'itineraries' &&
      path[2] == 'days' &&
      path[4] == 'items') {
    final body = await _readJson(request);
    final item = {
      ...body,
      'id': 'item-fake',
    };
    request.response.statusCode = HttpStatus.created;
    _writeJson(request, {'item': item});
    return;
  }

  if (request.method == 'POST' && request.uri.path == '/saved') {
    final body = await _readJson(request);
    const id = 'saved-fake';
    final item = {
      ...body,
      'id': id,
    };
    state.savedItems[id] = item;
    request.response.statusCode = HttpStatus.created;
    _writeJson(request, {'item': item});
    return;
  }

  if (request.method == 'GET' && request.uri.path == '/saved') {
    _writeJson(request, {'items': state.savedItems.values.toList()});
    return;
  }

  if (request.method == 'DELETE' && path.length == 2 && path.first == 'saved') {
    state.savedItems.remove(path[1]);
    _writeJson(request, {'deleted': path[1]});
    return;
  }

  if (request.method == 'POST' && request.uri.path == '/feedback') {
    final body = await _readJson(request);
    if ((body['description']?.toString().trim() ?? '').isEmpty) {
      request.response.statusCode = HttpStatus.badRequest;
      _writeJson(request, {'error': 'description is required'});
      return;
    }
    request.response.statusCode = HttpStatus.created;
    _writeJson(request, {
      'item': {'id': 'feedback-fake'}
    });
    return;
  }

  request.response.statusCode = HttpStatus.notFound;
  _writeJson(request, {'error': 'Not found'});
}

bool _hasFakeToken(HttpRequest request) {
  return request.headers.value(HttpHeaders.authorizationHeader) ==
      'Bearer fake-token';
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
