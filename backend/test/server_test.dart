import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  late _ServerHarness server;

  setUp(() async {
    server = await _ServerHarness.start();
  });

  tearDown(() async {
    await server.close();
  });

  test('send-code validates identifier input', () async {
    final missing = await server.post('/auth/send-code', <String, Object?>{});

    expect(missing.statusCode, HttpStatus.badRequest);
    expect(missing.json['error'], contains('identifier'));

    final invalidEmail = await server.post('/auth/send-code', {
      'identifier': 'demo@invalid',
    });

    expect(invalidEmail.statusCode, HttpStatus.badRequest);
    expect(invalidEmail.json['error'], contains('email format'));

    final validEmail = await server.post('/auth/send-code', {
      'identifier': 'DEMO@WAYFARE.LOCAL',
    });

    expect(validEmail.statusCode, HttpStatus.ok);
    expect(validEmail.json['identifier'], 'demo@wayfare.local');
  });

  test('search validates non-numeric limits and clamps oversized limits',
      () async {
    final invalid = await server.get('/search?q=west&limit=many');

    expect(invalid.statusCode, HttpStatus.badRequest);
    expect(invalid.json['error'], 'limit must be an integer');

    final oversized = await server.get('/search?q=west&limit=100');

    expect(oversized.statusCode, HttpStatus.ok);
    expect(oversized.json['items'], isA<List<Object?>>());
    expect((oversized.json['items'] as List<Object?>).length,
        lessThanOrEqualTo(50));
  });

  test('user scoped endpoints require bearer tokens', () async {
    final me = await server.get('/me');
    expect(me.statusCode, HttpStatus.unauthorized);
    expect(me.json['error'], contains('Bearer token'));

    final itineraries = await server.get('/itineraries');
    expect(itineraries.statusCode, HttpStatus.unauthorized);

    final tampered = await server.get('/me', token: 'not-a-real-token');
    expect(tampered.statusCode, HttpStatus.unauthorized);
  });

  test('login issues a bearer token that authorizes /me', () async {
    final token = await server.login();

    expect(token, isNotEmpty);

    final me = await server.get('/me', token: token);

    expect(me.statusCode, HttpStatus.ok);
    final user = me.json['user'] as Map<String, Object?>;
    expect(user['identifier'], 'demo@wayfare.local');
  });

  test('logout revokes the bearer token', () async {
    final token = await server.login();

    final logout = await server.post(
      '/auth/logout',
      <String, Object?>{},
      token: token,
    );
    expect(logout.statusCode, HttpStatus.ok);
    expect(logout.json['revoked'], true);

    final me = await server.get('/me', token: token);
    expect(me.statusCode, HttpStatus.unauthorized);
    expect(me.json['error'], 'Bearer token is invalid');
  });

  test('session tokens are opaque and stored server-side', () async {
    final token = await server.login();

    expect(token, isNot(contains('.')));
    expect(token.length, greaterThanOrEqualTo(32));
  });

  test('ops metrics require token and expose aggregate counters', () async {
    final missing = await server.get('/ops/metrics');
    expect(missing.statusCode, HttpStatus.unauthorized);
    expect(missing.json['error'], 'Ops bearer token is required');

    final health = await server.get('/health');
    expect(health.statusCode, HttpStatus.ok);

    final invalid = await server.get('/ops/metrics', token: 'wrong-ops-token');
    expect(invalid.statusCode, HttpStatus.unauthorized);
    expect(invalid.json['error'], 'Ops bearer token is invalid');

    final metrics = await server.get(
      '/ops/metrics',
      token: 'test-ops-token-for-metrics',
    );
    expect(metrics.statusCode, HttpStatus.ok);
    expect(metrics.json['status'], 'ok');
    expect(metrics.json['totalRequests'], greaterThanOrEqualTo(3));
    final routes = metrics.json['routes'] as Map<String, Object?>;
    final statuses = metrics.json['statuses'] as Map<String, Object?>;
    expect(routes['GET /health'], greaterThanOrEqualTo(1));
    expect(routes['GET /ops/metrics'], greaterThanOrEqualTo(2));
    expect(statuses['200'], greaterThanOrEqualTo(1));
    expect(statuses['401'], greaterThanOrEqualTo(2));
  });

  test('auth endpoints return 429 after configured rate limit', () async {
    await server.close();
    server = await _ServerHarness.start(environmentOverrides: {
      'WAYFARE_RATE_LIMIT_AUTH_PER_WINDOW': '2',
      'WAYFARE_RATE_LIMIT_WINDOW_SECONDS': '60',
    });

    for (var index = 0; index < 2; index++) {
      final allowed = await server.post('/auth/send-code', {
        'identifier': 'demo@wayfare.local',
      });
      expect(allowed.statusCode, HttpStatus.ok);
    }

    final limited = await server.post('/auth/send-code', {
      'identifier': 'demo@wayfare.local',
    });

    expect(limited.statusCode, HttpStatus.tooManyRequests);
    expect(limited.json['error'], 'Too many requests');
    expect(limited.json['rule'], 'auth');
    expect(limited.json['limit'], 2);
    expect(limited.retryAfter, isNotNull);
    expect(limited.rateLimitRemaining, '0');
  });

  test('feedback requires descriptions and defaults blank category', () async {
    final token = await server.login();

    final missing = await server.post(
        '/feedback',
        {
          'category': '',
          'description': '   ',
        },
        token: token);

    expect(missing.statusCode, HttpStatus.badRequest);
    expect(missing.json['error'], 'description is required');

    final created = await server.post(
        '/feedback',
        {
          'category': '',
          'description': '  The saved trips filter is useful.  ',
        },
        token: token);

    expect(created.statusCode, HttpStatus.created);
    final item = created.json['item'] as Map<String, Object?>;
    expect(item['category'], 'general');
    expect(item['description'], 'The saved trips filter is useful.');
  });

  test('itinerary and saved mutations validate request schemas', () async {
    final token = await server.login();

    final missingDestination = await server.post(
      '/itineraries',
      {
        'title': 'Schema Trip',
        'startDate': '2026-06-08',
        'endDate': '2026-06-09',
      },
      token: token,
    );
    expect(missingDestination.statusCode, HttpStatus.badRequest);
    expect(missingDestination.json['error'], 'destination is required.');

    final invalidDate = await server.post(
      '/itineraries',
      {
        'title': 'Schema Trip',
        'destination': 'Hangzhou',
        'startDate': '2026-99-08',
        'endDate': '2026-06-09',
      },
      token: token,
    );
    expect(invalidDate.statusCode, HttpStatus.badRequest);
    expect(
        invalidDate.json['error'], 'startDate must be a real calendar date.');

    final trip = await server.post(
      '/itineraries',
      {
        'title': 'Schema Trip',
        'destination': 'Hangzhou',
        'startDate': '2026-06-08',
        'endDate': '2026-06-09',
      },
      token: token,
    );
    expect(trip.statusCode, HttpStatus.created);
    final tripId =
        ((trip.json['item'] as Map<String, Object?>)['id'] as String);

    final invalidDay = await server.post(
      '/itineraries/$tripId/days',
      {
        'title': 'Day 1',
        'date': 'tomorrow',
        'city': 'Hangzhou',
      },
      token: token,
    );
    expect(invalidDay.statusCode, HttpStatus.badRequest);
    expect(invalidDay.json['error'], 'date must use YYYY-MM-DD format.');

    final day = await server.post(
      '/itineraries/$tripId/days',
      {
        'title': 'Day 1',
        'date': '2026-06-08',
        'city': 'Hangzhou',
      },
      token: token,
    );
    expect(day.statusCode, HttpStatus.created);
    final dayId = ((day.json['item'] as Map<String, Object?>)['id'] as String);

    final invalidPoint = await server.post(
      '/itineraries/$tripId/days/$dayId/items',
      {
        'time': '09:00',
        'placeName': 'West Lake',
        'activity': 'Walk',
        'lat': 30.2431,
      },
      token: token,
    );
    expect(invalidPoint.statusCode, HttpStatus.badRequest);
    expect(
        invalidPoint.json['error'], 'lat and lng must be provided together.');

    final invalidReorder = await server.post(
      '/itineraries/$tripId/days/$dayId/items/reorder',
      {
        'itemIds': ['item-a', 'item-a']
      },
      token: token,
      method: 'PATCH',
    );
    expect(invalidReorder.statusCode, HttpStatus.badRequest);
    expect(
        invalidReorder.json['error'], 'itemIds must not contain duplicates.');

    final invalidSaved = await server.post(
      '/saved',
      {
        'type': 'ticket',
        'refId': 'dest-hangzhou',
      },
      token: token,
    );
    expect(invalidSaved.statusCode, HttpStatus.badRequest);
    expect(
      invalidSaved.json['error'],
      'type must be destination, itinerary, or place.',
    );
  });

  test('missing itinerary day or item returns 404', () async {
    final token = await server.login();
    final trip = await server.post(
        '/itineraries',
        {
          'title': 'Integration Trip',
          'destination': 'Hangzhou',
          'startDate': '2026-06-08',
          'endDate': '2026-06-09',
        },
        token: token);
    final tripId =
        ((trip.json['item'] as Map<String, Object?>)['id'] as String);

    final missingDay = await server.post(
      '/itineraries/$tripId/days/missing-day/items',
      {
        'time': '09:00',
        'place': 'West Lake',
        'activity': 'Walk',
      },
      token: token,
    );

    expect(missingDay.statusCode, HttpStatus.notFound);
    expect(missingDay.json['error'], 'Itinerary day not found');

    final day = await server.post(
        '/itineraries/$tripId/days',
        {
          'title': 'Day 1',
          'date': '2026-06-08',
          'city': 'Hangzhou',
        },
        token: token);
    final dayId = ((day.json['item'] as Map<String, Object?>)['id'] as String);

    final missingItem = await server.delete(
      '/itineraries/$tripId/days/$dayId/items/missing-item',
      token: token,
    );

    expect(missingItem.statusCode, HttpStatus.notFound);
    expect(missingItem.json['error'], 'Itinerary item not found');
  });
}

class _ServerHarness {
  _ServerHarness._({
    required this.port,
    required this.process,
    required this.tempDir,
    required this.stdoutLines,
    required this.stderrLines,
    required this.stdoutSubscription,
    required this.stderrSubscription,
  });

  final int port;
  final Process process;
  final Directory tempDir;
  final List<String> stdoutLines;
  final List<String> stderrLines;
  final StreamSubscription<String> stdoutSubscription;
  final StreamSubscription<String> stderrSubscription;

  static Future<_ServerHarness> start({
    Map<String, String> environmentOverrides = const <String, String>{},
  }) async {
    final port = await _freePort();
    final tempDir = await Directory.systemTemp.createTemp('wayfare_backend_');
    final process = await Process.start(
      Platform.resolvedExecutable,
      ['run', 'bin/server.dart', '$port'],
      workingDirectory: Directory.current.path,
      environment: {
        'WAYFARE_DB_PATH': '${tempDir.path}/wayfare.sqlite',
        'WAYFARE_AUTH_SECRET': 'test-secret-for-signed-session-tokens',
        'WAYFARE_OPS_TOKEN': 'test-ops-token-for-metrics',
        ...environmentOverrides,
      },
    );

    final stdoutLines = <String>[];
    final stderrLines = <String>[];
    final stdoutSubscription = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(stdoutLines.add);
    final stderrSubscription = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(stderrLines.add);

    final harness = _ServerHarness._(
      port: port,
      process: process,
      tempDir: tempDir,
      stdoutLines: stdoutLines,
      stderrLines: stderrLines,
      stdoutSubscription: stdoutSubscription,
      stderrSubscription: stderrSubscription,
    );
    await harness._waitUntilReady();
    return harness;
  }

  Future<String> login() async {
    final response = await post('/auth/login', {
      'identifier': 'demo@wayfare.local',
    });
    expect(response.statusCode, HttpStatus.ok);
    return response.json['token'] as String;
  }

  Future<_JsonResponse> get(String path, {String? token}) {
    return _request('GET', path, token: token);
  }

  Future<_JsonResponse> post(
    String path,
    Map<String, Object?> body, {
    String? token,
    String method = 'POST',
  }) {
    return _request(method, path, body: body, token: token);
  }

  Future<_JsonResponse> delete(String path, {String? token}) {
    return _request('DELETE', path, token: token);
  }

  Future<void> close() async {
    process.kill();
    try {
      await process.exitCode.timeout(const Duration(seconds: 3));
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
      await process.exitCode.timeout(const Duration(seconds: 3));
    }
    await stdoutSubscription.cancel();
    await stderrSubscription.cancel();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  }

  Future<void> _waitUntilReady() async {
    final exitCode = process.exitCode.then<int?>((code) => code);
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (DateTime.now().isBefore(deadline)) {
      final exited = await Future.any<int?>([
        exitCode,
        Future<int?>.delayed(const Duration(milliseconds: 100), () => null),
      ]);
      if (exited != null) {
        fail('Backend exited before startup with code $exited.\n'
            'stdout: ${stdoutLines.join('\n')}\n'
            'stderr: ${stderrLines.join('\n')}');
      }
      try {
        final response =
            await get('/health').timeout(const Duration(seconds: 1));
        if (response.statusCode == HttpStatus.ok) {
          return;
        }
      } catch (_) {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
    }

    fail('Backend did not become ready.\n'
        'stdout: ${stdoutLines.join('\n')}\n'
        'stderr: ${stderrLines.join('\n')}');
  }

  Future<_JsonResponse> _request(
    String method,
    String path, {
    Map<String, Object?>? body,
    String? token,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.openUrl(
        method,
        Uri.parse('http://127.0.0.1:$port$path'),
      );
      request.headers.contentType = ContentType.json;
      if (token != null) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      if (body != null) {
        request.write(jsonEncode(body));
      }
      final response = await request.close();
      final text = await utf8.decoder.bind(response).join();
      return _JsonResponse(
        statusCode: response.statusCode,
        json: jsonDecode(text) as Map<String, Object?>,
        retryAfter: response.headers.value('retry-after'),
        rateLimitRemaining: response.headers.value('x-ratelimit-remaining'),
      );
    } finally {
      client.close(force: true);
    }
  }
}

class _JsonResponse {
  const _JsonResponse({
    required this.statusCode,
    required this.json,
    required this.retryAfter,
    required this.rateLimitRemaining,
  });

  final int statusCode;
  final Map<String, Object?> json;
  final String? retryAfter;
  final String? rateLimitRemaining;
}

Future<int> _freePort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}
