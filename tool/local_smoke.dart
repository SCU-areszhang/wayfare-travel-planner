import 'dart:async';
import 'dart:convert';
import 'dart:io';

class LocalSmokeCheck {
  const LocalSmokeCheck({
    required this.name,
    required this.passed,
    required this.detail,
  });

  final String name;
  final bool passed;
  final String detail;
}

class LocalSmokeReport {
  const LocalSmokeReport(this.checks);

  final List<LocalSmokeCheck> checks;

  bool get passed => checks.every((check) => check.passed);

  String render() {
    final buffer = StringBuffer()
      ..writeln('Wayfare local smoke: ${passed ? 'pass' : 'fail'}')
      ..writeln('checks:');
    for (final check in checks) {
      buffer.writeln(
        '- [${check.passed ? 'pass' : 'fail'}] ${check.name}: ${check.detail}',
      );
    }
    return buffer.toString();
  }
}

Future<LocalSmokeReport> runLocalSmoke({
  required Uri apiBase,
  required String identifier,
  required String query,
  Uri? webBase,
  Duration timeout = const Duration(seconds: 10),
}) async {
  final checks = <LocalSmokeCheck>[];
  final client = HttpClient()..connectionTimeout = timeout;

  Future<T?> record<T>(
    String name,
    Future<_StepResult<T>> Function() body,
  ) async {
    try {
      final result = await body().timeout(timeout);
      checks.add(LocalSmokeCheck(
        name: name,
        passed: true,
        detail: result.detail,
      ));
      return result.value;
    } catch (error) {
      checks.add(LocalSmokeCheck(
        name: name,
        passed: false,
        detail: error.toString(),
      ));
      return null;
    }
  }

  try {
    await record('backend-health', () async {
      final payload = await _requestJson(
        client,
        'GET',
        _join(apiBase, '/health'),
        timeout,
      );
      final status = payload.json['status'];
      final storage = payload.json['storage'];
      if (payload.statusCode != HttpStatus.ok ||
          status != 'ok' ||
          storage != 'SQLite') {
        throw StateError('Unexpected health response: ${payload.body}');
      }
      return _StepResult(
        null,
        'status ok, storage SQLite, schema ${payload.json['schemaVersion']}',
      );
    });

    final token = await record<String>('auth-login', () async {
      final payload = await _requestJson(
        client,
        'POST',
        _join(apiBase, '/auth/login'),
        timeout,
        body: {'identifier': identifier},
      );
      final token = payload.json['token']?.toString() ?? '';
      if (payload.statusCode != HttpStatus.ok || token.isEmpty) {
        throw StateError('Login did not return a token: ${payload.body}');
      }
      return _StepResult(token, 'token issued for $identifier');
    });

    if (token == null) {
      checks.add(const LocalSmokeCheck(
        name: 'auth-me',
        passed: false,
        detail: 'Skipped because auth-login failed.',
      ));
    } else {
      await record('auth-me', () async {
        final payload = await _requestJson(
          client,
          'GET',
          _join(apiBase, '/me'),
          timeout,
          bearerToken: token,
        );
        final userIdentifier = _userIdentifier(payload.json);
        if (payload.statusCode != HttpStatus.ok ||
            userIdentifier != identifier) {
          throw StateError('Unexpected /me response: ${payload.body}');
        }
        return _StepResult(null, '/me returned $userIdentifier');
      });
    }

    await record('search', () async {
      final payload = await _requestJson(
        client,
        'GET',
        _join(apiBase, '/search', {'q': query, 'limit': '2'}),
        timeout,
      );
      final items = payload.json['items'];
      if (payload.statusCode != HttpStatus.ok ||
          items is! List ||
          items.isEmpty) {
        throw StateError('Search returned no items: ${payload.body}');
      }
      return _StepResult(null, 'query "$query" returned ${items.length} items');
    });

    if (webBase != null) {
      await record('web-index', () async {
        final payload = await _requestText(
          client,
          'GET',
          webBase,
          timeout,
        );
        if (payload.statusCode != HttpStatus.ok ||
            !payload.body.contains('Wayfare')) {
          throw StateError('Unexpected web index response.');
        }
        return const _StepResult(
          null,
          'web index responded with Wayfare shell',
        );
      });
    }
  } finally {
    client.close(force: true);
  }

  return LocalSmokeReport(List.unmodifiable(checks));
}

Future<void> main(List<String> arguments) async {
  final apiBase = Uri.parse(
    _optionValue(arguments, '--api-base') ?? 'http://127.0.0.1:8080',
  );
  final webBaseValue = _optionValue(arguments, '--web-base');
  final report = await runLocalSmoke(
    apiBase: apiBase,
    webBase: webBaseValue == null ? null : Uri.parse(webBaseValue),
    identifier: _optionValue(arguments, '--identifier') ?? 'demo@wayfare.local',
    query: _optionValue(arguments, '--query') ?? 'orange',
    timeout: Duration(
      seconds: int.tryParse(
            _optionValue(arguments, '--timeout-seconds') ?? '',
          ) ??
          10,
    ),
  );
  stdout.write(report.render());
  if (!report.passed) {
    exitCode = 1;
  }
}

Uri _join(Uri base, String path, [Map<String, String>? queryParameters]) {
  final basePath =
      base.path == '/' ? '' : base.path.replaceAll(RegExp(r'/$'), '');
  return base.replace(
    path: '$basePath$path',
    queryParameters: queryParameters,
  );
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

Future<_JsonPayload> _requestJson(
  HttpClient client,
  String method,
  Uri uri,
  Duration timeout, {
  Object? body,
  String? bearerToken,
}) async {
  final payload = await _requestText(
    client,
    method,
    uri,
    timeout,
    body: body,
    bearerToken: bearerToken,
  );
  final decoded = jsonDecode(payload.body);
  if (decoded is! Map<String, Object?>) {
    throw StateError('Expected JSON object from $uri.');
  }
  return _JsonPayload(payload.statusCode, payload.body, decoded);
}

Future<_TextPayload> _requestText(
  HttpClient client,
  String method,
  Uri uri,
  Duration timeout, {
  Object? body,
  String? bearerToken,
}) async {
  final request = await client.openUrl(method, uri).timeout(timeout);
  request.headers.set(HttpHeaders.acceptHeader, 'application/json');
  if (bearerToken != null) {
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $bearerToken');
  }
  if (body != null) {
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(body));
  }
  final response = await request.close().timeout(timeout);
  final text = await utf8.decoder.bind(response).join().timeout(timeout);
  return _TextPayload(response.statusCode, text);
}

String? _userIdentifier(Map<String, Object?> json) {
  final user = json['user'];
  if (user is Map<String, Object?>) {
    return user['identifier']?.toString();
  }
  return json['identifier']?.toString();
}

class _StepResult<T> {
  const _StepResult(this.value, this.detail);

  final T value;
  final String detail;
}

class _TextPayload {
  const _TextPayload(this.statusCode, this.body);

  final int statusCode;
  final String body;
}

class _JsonPayload extends _TextPayload {
  const _JsonPayload(super.statusCode, super.body, this.json);

  final Map<String, Object?> json;
}
