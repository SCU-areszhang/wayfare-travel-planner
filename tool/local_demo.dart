import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'local_smoke.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.contains('--help') || arguments.contains('-h')) {
    stdout.write(_usage);
    return;
  }

  final config = _LocalDemoConfig.fromArgs(arguments);
  final processes = <Process>[];
  HttpServer? webServer;

  Future<void> closeStartedServices() async {
    await webServer?.close(force: true);
    for (final process in processes) {
      process.kill();
    }
  }

  ProcessSignal.sigint.watch().listen((_) async {
    await closeStartedServices();
    exit(0);
  });

  try {
    final backendAlreadyRunning = await _backendReady(config.apiBase);
    if (backendAlreadyRunning) {
      stdout.writeln('Backend already running: ${config.apiBase}');
    } else {
      stdout.writeln('Starting backend: ${config.apiBase}');
      processes.add(await _startBackend(config));
      await _waitForBackend(config.apiBase, config.timeout);
    }

    final webAlreadyRunning = await _webReady(config.webBase);
    if (webAlreadyRunning) {
      stdout.writeln('Web server already running: ${config.webBase}');
    } else {
      webServer = await _startWebServer(config);
      stdout.writeln('Web server started: ${config.webBase}');
    }

    final report = await runLocalSmoke(
      apiBase: config.apiBase,
      webBase: config.webBase,
      identifier: config.identifier,
      query: config.query,
      timeout: config.timeout,
    );
    stdout.write(report.render());
    if (!report.passed) {
      exitCode = 1;
      await closeStartedServices();
      return;
    }

    stdout
      ..writeln('Wayfare local demo is ready.')
      ..writeln('Frontend: ${config.webBase}')
      ..writeln('Backend: ${config.apiBase}')
      ..writeln('Press Ctrl+C to stop services started by this command.');

    await Completer<void>().future;
  } catch (error) {
    stderr.writeln('Wayfare local demo failed: $error');
    exitCode = 1;
    await closeStartedServices();
  }
}

Future<bool> _backendReady(Uri apiBase) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
  try {
    final health = apiBase.replace(path: '/health');
    final request = await client.getUrl(health);
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    final json = jsonDecode(body);
    return response.statusCode == HttpStatus.ok &&
        json is Map<String, Object?> &&
        json['status'] == 'ok';
  } catch (_) {
    return false;
  } finally {
    client.close(force: true);
  }
}

Future<bool> _webReady(Uri webBase) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
  try {
    final request = await client.getUrl(webBase);
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    return response.statusCode == HttpStatus.ok && body.contains('Wayfare');
  } catch (_) {
    return false;
  } finally {
    client.close(force: true);
  }
}

Future<Process> _startBackend(_LocalDemoConfig config) async {
  final backendDir = Directory('backend');
  if (!backendDir.existsSync()) {
    throw StateError('Missing backend directory.');
  }
  final process = await Process.start(
    Platform.resolvedExecutable,
    ['run', 'bin/server.dart'],
    workingDirectory: backendDir.path,
    environment: {
      'PORT': config.backendPort.toString(),
      'WAYFARE_AUTH_SECRET': config.authSecret,
      'WAYFARE_OPS_TOKEN': config.opsToken,
      'WAYFARE_ALLOWED_ORIGINS':
          '${config.webBase},http://localhost:${config.webPort}',
      'WAYFARE_DB_PATH': 'data/wayfare.sqlite',
    },
  );
  process.stdout.transform(utf8.decoder).listen(stdout.write);
  process.stderr.transform(utf8.decoder).listen(stderr.write);
  return process;
}

Future<void> _waitForBackend(Uri apiBase, Duration timeout) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (await _backendReady(apiBase)) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  throw TimeoutException('Backend did not become ready at $apiBase', timeout);
}

Future<HttpServer> _startWebServer(_LocalDemoConfig config) async {
  if (!config.webDirectory.existsSync()) {
    throw StateError(
      'Missing ${config.webDirectory.path}. Run '
      '`flutter build web --release --pwa-strategy=none` first.',
    );
  }
  final server =
      await HttpServer.bind(InternetAddress.loopbackIPv4, config.webPort);
  server.listen((request) => _serveWeb(request, config.webDirectory));
  return server;
}

Future<void> _serveWeb(HttpRequest request, Directory webDirectory) async {
  final segments = request.uri.pathSegments;
  if (segments.any((segment) => segment == '..')) {
    request.response.statusCode = HttpStatus.badRequest;
    await request.response.close();
    return;
  }

  final relativePath = segments.isEmpty ? 'index.html' : segments.join('/');
  var file = File('${webDirectory.path}/$relativePath');
  if (!file.existsSync()) {
    file = File('${webDirectory.path}/index.html');
  }

  if (!file.existsSync()) {
    request.response.statusCode = HttpStatus.notFound;
    await request.response.close();
    return;
  }

  request.response.headers.contentType = _contentType(file.path);
  await file.openRead().pipe(request.response);
}

ContentType _contentType(String path) {
  if (path.endsWith('.html')) {
    return ContentType.html;
  }
  if (path.endsWith('.js')) {
    return ContentType('application', 'javascript');
  }
  if (path.endsWith('.json')) {
    return ContentType.json;
  }
  if (path.endsWith('.css')) {
    return ContentType('text', 'css');
  }
  if (path.endsWith('.png')) {
    return ContentType('image', 'png');
  }
  if (path.endsWith('.wasm')) {
    return ContentType('application', 'wasm');
  }
  return ContentType.binary;
}

class _LocalDemoConfig {
  _LocalDemoConfig({
    required this.backendPort,
    required this.webPort,
    required this.webDirectory,
    required this.identifier,
    required this.query,
    required this.timeout,
    required this.authSecret,
    required this.opsToken,
  });

  factory _LocalDemoConfig.fromArgs(List<String> arguments) {
    final backendPort = int.tryParse(
          _optionValue(arguments, '--backend-port') ?? '',
        ) ??
        8080;
    final webPort =
        int.tryParse(_optionValue(arguments, '--web-port') ?? '') ?? 8092;
    return _LocalDemoConfig(
      backendPort: backendPort,
      webPort: webPort,
      webDirectory:
          Directory(_optionValue(arguments, '--web-dir') ?? 'build/web'),
      identifier:
          _optionValue(arguments, '--identifier') ?? 'demo@wayfare.local',
      query: _optionValue(arguments, '--query') ?? 'orange',
      timeout: Duration(
        seconds: int.tryParse(
              _optionValue(arguments, '--timeout-seconds') ?? '',
            ) ??
            20,
      ),
      authSecret: _optionValue(arguments, '--auth-secret') ??
          'local-demo-auth-secret-with-at-least-32-chars',
      opsToken: _optionValue(arguments, '--ops-token') ??
          'local-demo-ops-token-with-at-least-32-chars',
    );
  }

  final int backendPort;
  final int webPort;
  final Directory webDirectory;
  final String identifier;
  final String query;
  final Duration timeout;
  final String authSecret;
  final String opsToken;

  Uri get apiBase => Uri.parse('http://127.0.0.1:$backendPort');

  Uri get webBase => Uri.parse('http://127.0.0.1:$webPort');
}

String? _optionValue(List<String> arguments, String name) {
  for (var index = 0; index < arguments.length; index++) {
    final value = arguments[index];
    if (value == name && index + 1 < arguments.length) {
      return arguments[index + 1];
    }
    if (value.startsWith('$name=')) {
      return value.substring(name.length + 1);
    }
  }
  return null;
}

const _usage = '''
Wayfare local demo

Usage:
  dart run tool/local_demo.dart

Options:
  --backend-port <port>       Backend port, default 8080.
  --web-port <port>           Frontend static server port, default 8092.
  --web-dir <path>            Built Flutter Web directory, default build/web.
  --identifier <value>        Login identifier for the smoke check.
  --query <value>             Search query for the smoke check.
  --timeout-seconds <number>  Startup and smoke timeout.

Build Web first if build/web is missing:
  flutter build web --release --pwa-strategy=none
''';
