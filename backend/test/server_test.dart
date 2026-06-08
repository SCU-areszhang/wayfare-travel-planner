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

  test('feedback requires descriptions and defaults blank category', () async {
    final missing = await server.post('/feedback', {
      'userId': 'user-dev-1',
      'category': '',
      'description': '   ',
    });

    expect(missing.statusCode, HttpStatus.badRequest);
    expect(missing.json['error'], 'description is required');

    final created = await server.post('/feedback', {
      'userId': 'user-dev-1',
      'category': '',
      'description': '  The saved trips filter is useful.  ',
    });

    expect(created.statusCode, HttpStatus.created);
    final item = created.json['item'] as Map<String, Object?>;
    expect(item['category'], 'general');
    expect(item['description'], 'The saved trips filter is useful.');
  });

  test('missing itinerary day or item returns 404', () async {
    final trip = await server.post('/itineraries', {
      'title': 'Integration Trip',
      'destination': 'Hangzhou',
    });
    final tripId =
        ((trip.json['item'] as Map<String, Object?>)['id'] as String);

    final missingDay = await server.post(
      '/itineraries/$tripId/days/missing-day/items',
      {
        'time': '09:00',
        'place': 'West Lake',
        'activity': 'Walk',
      },
    );

    expect(missingDay.statusCode, HttpStatus.notFound);
    expect(missingDay.json['error'], 'Itinerary day not found');

    final day = await server.post('/itineraries/$tripId/days', {
      'title': 'Day 1',
      'date': '2026-06-08',
      'city': 'Hangzhou',
    });
    final dayId = ((day.json['item'] as Map<String, Object?>)['id'] as String);

    final missingItem = await server.delete(
      '/itineraries/$tripId/days/$dayId/items/missing-item',
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

  static Future<_ServerHarness> start() async {
    final port = await _freePort();
    final tempDir = await Directory.systemTemp.createTemp('wayfare_backend_');
    final process = await Process.start(
      Platform.resolvedExecutable,
      ['run', 'bin/server.dart', '$port'],
      workingDirectory: Directory.current.path,
      environment: {
        'WAYFARE_DB_PATH': '${tempDir.path}/wayfare.sqlite',
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

  Future<_JsonResponse> get(String path) {
    return _request('GET', path);
  }

  Future<_JsonResponse> post(String path, Map<String, Object?> body) {
    return _request('POST', path, body: body);
  }

  Future<_JsonResponse> delete(String path) {
    return _request('DELETE', path);
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
  }) async {
    final client = HttpClient();
    try {
      final request = await client.openUrl(
        method,
        Uri.parse('http://127.0.0.1:$port$path'),
      );
      request.headers.contentType = ContentType.json;
      if (body != null) {
        request.write(jsonEncode(body));
      }
      final response = await request.close();
      final text = await utf8.decoder.bind(response).join();
      return _JsonResponse(
        statusCode: response.statusCode,
        json: jsonDecode(text) as Map<String, Object?>,
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
  });

  final int statusCode;
  final Map<String, Object?> json;
}

Future<int> _freePort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}
