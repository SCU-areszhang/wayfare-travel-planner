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
    if (config.rebuildWeb) {
      await _buildWeb(config);
    }

    final backendAlreadyRunning = await _backendReady(config.apiBase);
    if (backendAlreadyRunning) {
      stdout.writeln('Backend already running: ${config.apiBase}');
    } else {
      stdout.writeln('Starting backend: ${config.apiBase}');
      processes.add(await _startBackend(config));
      await _waitForBackend(config.apiBase, config.timeout);
    }
    await _verifyAmapBackendIfConfigured(config, backendAlreadyRunning);

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

Future<void> _verifyAmapBackendIfConfigured(
  _LocalDemoConfig config,
  bool backendAlreadyRunning,
) async {
  if (config.amapKeys.webServiceKey == null ||
      config.amapKeys.webServiceKey!.isEmpty) {
    return;
  }

  final verified = await verifyAmapBackendSearch(
    apiBase: config.apiBase,
    timeout: config.timeout,
  );
  if (verified) {
    stdout.writeln('Backend AMap Web Service search verified.');
    return;
  }

  if (backendAlreadyRunning) {
    throw StateError(
      'Backend is already running at ${config.apiBase}, but it did not return '
      'live AMap POI results. Stop that backend or choose another '
      '--backend-port so local_demo can start it with Wayfare_WebSvc.',
    );
  }
  throw StateError(
    'Backend started at ${config.apiBase}, but AMap Web Service search did not '
    'return live POI results.',
  );
}

Future<bool> verifyAmapBackendSearch({
  required Uri apiBase,
  String query = '西湖',
  Duration timeout = const Duration(seconds: 10),
}) async {
  final client = HttpClient()..connectionTimeout = timeout;
  try {
    final uri = _joinUri(apiBase, '/search', {
      'q': query,
      'limit': '3',
    });
    final request = await client.getUrl(uri).timeout(timeout);
    final response = await request.close().timeout(timeout);
    final body = await response.transform(utf8.decoder).join().timeout(timeout);
    if (response.statusCode != HttpStatus.ok) {
      return false;
    }
    final json = jsonDecode(body);
    if (json is! Map<String, Object?>) {
      return false;
    }
    final items = json['items'];
    return items is List &&
        items.any((item) => item is Map && item['type'] == 'amap_poi');
  } catch (_) {
    return false;
  } finally {
    client.close(force: true);
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
      if (config.amapKeys.webServiceKey case final key?) ...{
        'AMAP_WEB_SERVICE_KEY': key,
      },
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

  request.response.headers
    ..contentType = _contentType(file.path)
    ..set(HttpHeaders.cacheControlHeader, 'no-store, max-age=0')
    ..set(HttpHeaders.pragmaHeader, 'no-cache')
    ..set(HttpHeaders.expiresHeader, '0');
  await file.openRead().pipe(request.response);
}

Future<void> _buildWeb(_LocalDemoConfig config) async {
  final jsKey = config.amapKeys.webJsKey;
  if (jsKey == null || jsKey.isEmpty) {
    throw StateError(
      'Missing Wayfare_WebJS key. Provide --amap-key-file or --amap-web-js-key.',
    );
  }

  stdout.writeln('Building Flutter Web with local AMap configuration.');
  final defineDir = Directory.systemTemp.createTempSync('wayfare_defines_');
  try {
    final defineFile = File('${defineDir.path}/amap.env');
    await defineFile.writeAsString(_dartDefineFile(config));
    final args = [
      'build',
      'web',
      '--release',
      '--no-pub',
      '--pwa-strategy=none',
      '--dart-define-from-file=${defineFile.path}',
    ];
    final process = await Process.start(
      'flutter',
      args,
      mode: ProcessStartMode.normal,
    );
    process.stdout.transform(utf8.decoder).listen(stdout.write);
    process.stderr.transform(utf8.decoder).listen(stderr.write);
    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      throw StateError('Flutter Web build failed with exit code $exitCode.');
    }
    // --pwa-strategy=none writes an empty service worker; ship the
    // self-destructing one from web/ so browsers that cached an earlier
    // PWA build clear it and load the fresh shell.
    final cleanupWorker = File('web/flutter_service_worker.js');
    if (cleanupWorker.existsSync()) {
      cleanupWorker.copySync('build/web/flutter_service_worker.js');
    }
  } finally {
    defineDir.deleteSync(recursive: true);
  }
}

String _dartDefineFile(_LocalDemoConfig config) {
  final buffer = StringBuffer()
    ..writeln('WAYFARE_API_BASE=${config.apiBase}')
    ..writeln('AMAP_JS_KEY=${config.amapKeys.webJsKey}');
  if (config.amapKeys.webJsSecurityCode case final code?) {
    buffer.writeln('AMAP_JS_SECURITY_CODE=$code');
  }
  return buffer.toString();
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
    required this.amapKeys,
    required this.rebuildWeb,
  });

  factory _LocalDemoConfig.fromArgs(List<String> arguments) {
    final backendPort = int.tryParse(
          _optionValue(arguments, '--backend-port') ?? '',
        ) ??
        8080;
    final webPort =
        int.tryParse(_optionValue(arguments, '--web-port') ?? '') ?? 8092;
    final keyFile = File(
      _optionValue(arguments, '--amap-key-file') ?? '../高德.txt',
    );
    final fileKeys = keyFile.existsSync()
        ? parseAmapLocalKeys(keyFile.readAsStringSync())
        : const AmapLocalKeys();
    final env = Platform.environment;
    final cliKeys = AmapLocalKeys(
      webServiceKey: _optionValue(arguments, '--amap-web-service-key') ??
          env['AMAP_WEB_SERVICE_KEY'],
      webJsKey:
          _optionValue(arguments, '--amap-web-js-key') ?? env['AMAP_JS_KEY'],
      webJsSecurityCode: _optionValue(arguments, '--amap-js-security-code') ??
          env['AMAP_JS_SECURITY_CODE'],
    );
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
      amapKeys: fileKeys.merge(cliKeys),
      rebuildWeb: arguments.contains('--rebuild-web'),
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
  final AmapLocalKeys amapKeys;
  final bool rebuildWeb;

  Uri get apiBase => Uri.parse('http://127.0.0.1:$backendPort');

  Uri get webBase => Uri.parse('http://127.0.0.1:$webPort');
}

class AmapLocalKeys {
  const AmapLocalKeys({
    this.webServiceKey,
    this.webJsKey,
    this.webJsSecurityCode,
  });

  final String? webServiceKey;
  final String? webJsKey;
  final String? webJsSecurityCode;

  AmapLocalKeys merge(AmapLocalKeys overrides) {
    return AmapLocalKeys(
      webServiceKey: overrides.webServiceKey ?? webServiceKey,
      webJsKey: overrides.webJsKey ?? webJsKey,
      webJsSecurityCode: overrides.webJsSecurityCode ?? webJsSecurityCode,
    );
  }
}

AmapLocalKeys parseAmapLocalKeys(String content) {
  String? webServiceKey;
  String? webJsKey;
  String? webJsSecurityCode;

  for (final line in const LineSplitter().convert(content)) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) {
      continue;
    }
    if (trimmed.contains('Wayfare_WebSvc')) {
      webServiceKey = _extractApiKey(trimmed) ?? webServiceKey;
      continue;
    }
    if (trimmed.contains('Wayfare_WebJS')) {
      webJsKey = _extractApiKey(trimmed) ?? webJsKey;
      continue;
    }
    final securityMatch = RegExp(
      r'^(?:Security_code|security_code|AMAP_JS_SECURITY_CODE|securityJsCode)\s*[:=]\s*(\S+)',
    ).firstMatch(trimmed);
    if (securityMatch != null) {
      webJsSecurityCode = securityMatch.group(1);
    }
  }

  return AmapLocalKeys(
    webServiceKey: webServiceKey,
    webJsKey: webJsKey,
    webJsSecurityCode: webJsSecurityCode,
  );
}

String? _extractApiKey(String line) {
  final match = RegExp(r'api_key\s*[:=]\s*(\S+)').firstMatch(line);
  return match?.group(1);
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

Uri _joinUri(Uri base, String path, [Map<String, String>? queryParameters]) {
  final basePath =
      base.path == '/' ? '' : base.path.replaceAll(RegExp(r'/$'), '');
  return base.replace(
    path: '$basePath$path',
    queryParameters: queryParameters,
  );
}

const _usage = '''
Wayfare local demo

Usage:
  dart run tool/local_demo.dart

Options:
  --backend-port <port>       Backend port, default 8080.
  --web-port <port>           Frontend static server port, default 8092.
  --web-dir <path>            Built Flutter Web directory, default build/web.
  --rebuild-web               Rebuild Flutter Web before serving.
  --amap-key-file <path>      Local AMap key file, default ../高德.txt when present.
  --amap-web-service-key <k>  Backend AMap Web Service key override.
  --amap-web-js-key <k>       Web AMap JS key override.
  --amap-js-security-code <c> Web AMap security code override; prefer key file or env for secrets.
  --identifier <value>        Login identifier for the smoke check.
  --query <value>             Search query for the smoke check.
  --timeout-seconds <number>  Startup and smoke timeout.

Build Web first if build/web is missing:
  flutter build web --release --pwa-strategy=none
''';
