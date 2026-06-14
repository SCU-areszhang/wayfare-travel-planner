import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:sqlite3/sqlite3.dart';

final _secureRandom = math.Random.secure();
final _rateLimiter = RateLimiter.fromEnvironment(Platform.environment);
final _telemetry = ServerTelemetry();

void main(List<String> args) async {
  final port = int.tryParse(
        Platform.environment['PORT'] ?? (args.isEmpty ? '' : args.first),
      ) ??
      8080;
  final databasePath =
      Platform.environment['WAYFARE_DB_PATH'] ?? 'data/wayfare.sqlite';
  final amapWebServiceKey = _loadAmapWebServiceKey();
  final store = SqliteStore.open(databasePath, amapWebServiceKey: amapWebServiceKey);
  final bindHost = Platform.environment['WAYFARE_BIND_HOST'] ?? '127.0.0.1';
  final bindAddress =
      InternetAddress.tryParse(bindHost) ?? InternetAddress.loopbackIPv4;
  final server = await HttpServer.bind(bindAddress, port);
  stdout.writeln(
    'Wayfare SQLite backend listening on http://${bindAddress.address}:$port',
  );
  if (amapWebServiceKey != null) {
    stdout.writeln('AMap Web Service key loaded from Amap.csv.');
  } else {
    stdout.writeln(
      'No AMap Web Service key found. Search will use local data only.',
    );
  }

  await for (final request in server) {
    await _handle(request, store);
  }
}

String? _loadAmapWebServiceKey() {
  if (_environmentFlagEnabled(
    Platform.environment,
    'WAYFARE_DISABLE_AMAP_WEB_SERVICE',
  )) {
    return null;
  }
  final envKey = Platform.environment['AMAP_WEB_SERVICE_KEY']?.trim();
  if (envKey != null && envKey.isNotEmpty) {
    return envKey;
  }

  for (final path in const ['../Amap.csv', 'Amap.csv']) {
    final file = File(path);
    if (!file.existsSync()) {
      continue;
    }
    try {
      for (final line in file.readAsLinesSync()) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) {
          continue;
        }
        if (trimmed.contains('Wayfare_WebSvc')) {
          final csv = RegExp(r',\s*([^\s,]+)\s*$').firstMatch(trimmed);
          if (csv != null) {
            return csv.group(1);
          }
        }
      }
    } catch (_) {
      // Ignore parse errors for individual files.
    }
  }
  return null;
}

Future<void> _handle(HttpRequest request, SqliteStore store) async {
  final startedAt = DateTime.now().toUtc();
  final path = request.uri.pathSegments;
  final method = request.method;
  final route = _routeTemplate(method, path);
  _applyCors(request);
  if (request.method == 'OPTIONS') {
    request.response.statusCode = HttpStatus.noContent;
    await request.response.close();
    _telemetry.record(method, route, HttpStatus.noContent, startedAt);
    return;
  }

  try {
    final rateLimit = _rateLimiter.check(request, method, path);
    if (!rateLimit.allowed) {
      return _tooManyRequests(request, rateLimit);
    }

    if (method == 'GET' && path.isEmpty) {
      return _json(request, {
        'name': 'Wayfare backend',
        'storage': 'SQLite',
        'database': _databaseLabel(store.path),
      });
    }

    if (method == 'GET' && _matches(path, ['health'])) {
      return _json(request, {
        'status': 'ok',
        'storage': 'SQLite',
        'database': _databaseLabel(store.path),
        'schemaVersion': store.schemaVersion(),
        'userCount': store.userCount(),
        'auth': _authMode(),
      });
    }

    if (method == 'GET' && _matches(path, ['ops', 'metrics'])) {
      _requireOpsToken(request);
      return _json(request, _telemetry.snapshot());
    }

    if (method == 'GET' && _matches(path, ['ops', 'schema'])) {
      _requireOpsToken(request);
      return _json(request, {
        'schemaVersion': store.schemaVersion(),
        'migrations': store.schemaMigrations(),
      });
    }

    if (method == 'POST' && _matches(path, ['auth', 'login'])) {
      final body = await _body(request);
      final identifier = (body['identifier'] ?? body['phone'] ?? body['email'])
          ?.toString()
          .trim()
          .toLowerCase();
      final identifierError = _identifierValidationError(identifier);
      if (identifierError != null) {
        return _badRequest(request, identifierError);
      }
      final password = body['password']?.toString() ?? '';
      final passwordError = _passwordValidationError(password);
      if (passwordError != null) {
        return _badRequest(request, passwordError);
      }
      final result = store.loginOrRegister(identifier!, password);
      if (result == null) {
        return _json(
          request,
          {
            'error': 'invalid_credentials',
            'message': 'Incorrect password for this account.',
          },
          status: HttpStatus.unauthorized,
        );
      }
      final user = result['user'] as Map<String, Object?>;
      final session = _issueSession(store, user['id'].toString());
      return _json(request, {
        ...result,
        ...session,
      });
    }

    if (method == 'POST' && _matches(path, ['auth', 'logout'])) {
      final session = _requireSession(request, store);
      store.revokeSession(session.tokenHash);
      return _json(request, {'revoked': true});
    }

    if (method == 'POST' && _matches(path, ['auth', 'send-code'])) {
      final body = await _body(request);
      final identifier = (body['identifier'] ?? body['phone'] ?? body['email'])
          ?.toString()
          .trim()
          .toLowerCase();
      final identifierError = _identifierValidationError(identifier);
      if (identifierError != null) {
        return _badRequest(request, identifierError);
      }
      return _json(request, {
        'requestId': _id('code'),
        'identifier': identifier,
        'message': 'SMS/email code is mocked for the course prototype.',
      });
    }

    if (method == 'GET' && _matches(path, ['me'])) {
      final session = _requireSession(request, store);
      final user = store.userById(session.userId);
      if (user == null) {
        return _notFound(request, 'User not found');
      }
      return _json(request, {'user': user});
    }

    if (method == 'PATCH' && _matches(path, ['me'])) {
      final session = _requireSession(request, store);
      final body = await _body(request);
      final displayName = body['displayName']?.toString().trim() ?? '';
      if (displayName.isEmpty || displayName.length > 60) {
        return _badRequest(request, 'Display name must be 1-60 characters.');
      }
      final user = store.updateDisplayName(session.userId, displayName);
      if (user == null) {
        return _notFound(request, 'User not found');
      }
      return _json(request, {'user': user});
    }

    if (method == 'POST' && _matches(path, ['me', 'password'])) {
      final session = _requireSession(request, store);
      final body = await _body(request);
      final currentPassword = body['currentPassword']?.toString() ?? '';
      final newPassword = body['newPassword']?.toString() ?? '';
      final passwordError = _passwordValidationError(newPassword);
      if (passwordError != null) {
        return _badRequest(request, passwordError);
      }
      final updated = store.changePassword(
        session.userId,
        currentPassword,
        newPassword,
      );
      if (!updated) {
        return _json(
          request,
          {
            'error': 'invalid_credentials',
            'message': 'Current password is incorrect.',
          },
          status: HttpStatus.unauthorized,
        );
      }
      return _json(request, {'updated': true});
    }

    if (method == 'GET' && _matches(path, ['destinations'])) {
      return _json(request, {'items': store.destinations()});
    }

    if (method == 'GET' && path.length == 2 && path.first == 'destinations') {
      final item = store.destination(path[1]);
      if (item == null) {
        return _notFound(request, 'Destination not found');
      }
      return _json(request, {'item': item});
    }

    if (method == 'GET' && _matches(path, ['recommendations'])) {
      return _json(request, {
        'items': store.destinations(priorityOnly: true),
        'strategy': 'rule-based-small-team',
      });
    }

    if (method == 'GET' && _matches(path, ['search'])) {
      final query = request.uri.queryParameters['q'] ?? '';
      final limit = _queryLimit(request.uri.queryParameters['limit']);
      return _json(request, {'items': await store.search(query, limit: limit)});
    }

    if (method == 'GET' && _matches(path, ['reverse-geocode'])) {
      final point = _queryPoint(request.uri.queryParameters);
      final fallbackName = request.uri.queryParameters['fallbackName']?.trim();
      return _json(request, {
        'item': await store.reverseGeocode(
          lat: point['lat']!,
          lng: point['lng']!,
          fallbackName: fallbackName,
        ),
      });
    }

    if (method == 'GET' && _matches(path, ['map', 'places'])) {
      return _json(request, {'items': store.mapPlaces()});
    }

    if (method == 'GET' && _matches(path, ['itineraries'])) {
      final session = _requireSession(request, store);
      return _json(request, {'items': store.itineraries(session.userId)});
    }

    if (method == 'POST' && _matches(path, ['itineraries'])) {
      final session = _requireSession(request, store);
      final body = await _body(request);
      body['userId'] = session.userId;
      return _json(
        request,
        {'item': store.createItinerary(_validateCreateItinerary(body))},
        status: HttpStatus.created,
      );
    }

    if (path.length >= 2 && path.first == 'itineraries') {
      final session = _requireSession(request, store);
      return await _handleItinerary(request, path, store, session);
    }

    if (method == 'GET' && _matches(path, ['saved'])) {
      final session = _requireSession(request, store);
      return _json(request, {'items': store.savedTrips(session.userId)});
    }

    if (method == 'POST' && _matches(path, ['saved'])) {
      final session = _requireSession(request, store);
      final body = await _body(request);
      body['userId'] = session.userId;
      return _json(
        request,
        {'item': store.createSavedItem(_validateCreateSavedItem(body))},
        status: HttpStatus.created,
      );
    }

    if (method == 'DELETE' && path.length == 2 && path.first == 'saved') {
      final session = _requireSession(request, store);
      final deleted = store.deleteSavedItem(path[1], session.userId);
      if (!deleted) {
        return _notFound(request, 'Saved item not found');
      }
      return _json(request, {'deleted': path[1]});
    }

    if (method == 'POST' && _matches(path, ['feedback'])) {
      final session = _requireSession(request, store);
      final body = await _body(request);
      final description = body['description']?.toString().trim() ?? '';
      if (description.isEmpty) {
        return _badRequest(request, 'description is required');
      }
      final category = body['category']?.toString().trim();
      body['description'] = description;
      body['category'] =
          category == null || category.isEmpty ? 'general' : category;
      body['userId'] = session.userId;
      return _json(
        request,
        {'item': store.createFeedback(body)},
        status: HttpStatus.created,
      );
    }

    return _notFound(request, 'Route not found');
  } on UnauthorizedException catch (error) {
    return _json(
      request,
      {'error': error.message},
      status: HttpStatus.unauthorized,
    );
  } on NotFoundException catch (error) {
    return _notFound(request, error.message);
  } on FormatException catch (error) {
    return _badRequest(request, error.message);
  } on ArgumentError catch (error) {
    return _badRequest(request, error.message);
  } catch (error, stackTrace) {
    stderr.writeln(error);
    stderr.writeln(stackTrace);
    return _json(
      request,
      {'error': 'Internal server error'},
      status: HttpStatus.internalServerError,
    );
  } finally {
    _telemetry.record(method, route, request.response.statusCode, startedAt);
  }
}

Future<void> _handleItinerary(
  HttpRequest request,
  List<String> path,
  SqliteStore store,
  AuthSession session,
) async {
  final trip = store.itinerary(path[1]);
  if (trip == null || trip['userId'] != session.userId) {
    return _notFound(request, 'Itinerary not found');
  }

  if (request.method == 'GET' && path.length == 2) {
    return _json(request, {'item': trip});
  }

  if (request.method == 'PATCH' && path.length == 2) {
    final body = await _body(request);
    return _json(
      request,
      {'item': store.updateItinerary(path[1], _validateUpdateItinerary(body))},
    );
  }

  if (request.method == 'DELETE' && path.length == 2) {
    store.deleteItinerary(path[1]);
    return _json(request, {'deleted': path[1]});
  }

  if (request.method == 'POST' && path.length == 3 && path[2] == 'days') {
    final body = await _body(request);
    return _json(
      request,
      {'item': store.addDay(path[1], _validateAddDay(body))},
      status: HttpStatus.created,
    );
  }

  if (request.method == 'DELETE' &&
      path.length == 4 &&
      path[2] == 'days') {
    store.deleteDay(path[1], path[3]);
    return _json(request, {'deleted': path[3]});
  }

  if (request.method == 'POST' &&
      path.length == 5 &&
      path[2] == 'days' &&
      path[4] == 'items') {
    final body = await _body(request);
    return _json(
      request,
      {'item': store.addItem(path[1], path[3], _validateAddItem(body))},
      status: HttpStatus.created,
    );
  }

  if (path.length == 6 && path[2] == 'days' && path[4] == 'items') {
    if (request.method == 'PATCH' && path[5] == 'reorder') {
      final body = await _body(request);
      return _json(
        request,
        {'items': store.reorderItems(path[1], path[3], _validateReorder(body))},
      );
    }
    if (request.method == 'PATCH') {
      final body = await _body(request);
      return _json(
        request,
        {
          'item': store.updateItem(
            path[1],
            path[3],
            path[5],
            _validateUpdateItem(body),
          )
        },
      );
    }
    if (request.method == 'DELETE') {
      store.deleteItem(path[1], path[3], path[5]);
      return _json(request, {'deleted': path[5]});
    }
  }

  return _notFound(request, 'Itinerary route not found');
}

class NotFoundException implements Exception {
  const NotFoundException(this.message);

  final String message;
}

class UnauthorizedException implements Exception {
  const UnauthorizedException(this.message);

  final String message;
}

class RateLimitDecision {
  const RateLimitDecision({
    required this.allowed,
    required this.ruleId,
    required this.limit,
    required this.remaining,
    required this.resetAt,
  });

  final bool allowed;
  final String ruleId;
  final int limit;
  final int remaining;
  final DateTime resetAt;

  int get retryAfterSeconds {
    final seconds = resetAt.difference(DateTime.now().toUtc()).inSeconds;
    return math.max(1, seconds);
  }
}

class RateLimitRule {
  const RateLimitRule({
    required this.id,
    required this.limit,
    required this.matches,
  });

  final String id;
  final int limit;
  final bool Function(String method, List<String> path) matches;
}

class RateLimiter {
  RateLimiter({
    required this.enabled,
    required this.window,
    required this.rules,
    required this.trustProxyHeaders,
  });

  factory RateLimiter.fromEnvironment(Map<String, String> environment) {
    final windowSeconds = _environmentInt(
      environment,
      'WAYFARE_RATE_LIMIT_WINDOW_SECONDS',
      fallback: 60,
      min: 1,
      max: 3600,
    );
    final authLimit = _environmentInt(
      environment,
      'WAYFARE_RATE_LIMIT_AUTH_PER_WINDOW',
      fallback: 12,
      min: 1,
      max: 10000,
    );
    final searchLimit = _environmentInt(
      environment,
      'WAYFARE_RATE_LIMIT_SEARCH_PER_WINDOW',
      fallback: 120,
      min: 1,
      max: 10000,
    );
    final writeLimit = _environmentInt(
      environment,
      'WAYFARE_RATE_LIMIT_WRITE_PER_WINDOW',
      fallback: 120,
      min: 1,
      max: 10000,
    );
    return RateLimiter(
      enabled: !_environmentFlagDisabled(
        environment,
        'WAYFARE_RATE_LIMIT_ENABLED',
      ),
      window: Duration(seconds: windowSeconds),
      trustProxyHeaders: _environmentFlagEnabled(
        environment,
        'WAYFARE_TRUST_PROXY',
      ),
      rules: [
        RateLimitRule(
          id: 'auth',
          limit: authLimit,
          matches: (method, path) =>
              method == 'POST' &&
              (_matches(path, ['auth', 'login']) ||
                  _matches(path, ['auth', 'send-code'])),
        ),
        RateLimitRule(
          id: 'search',
          limit: searchLimit,
          matches: (method, path) =>
              method == 'GET' &&
              (_matches(path, ['search']) ||
                  _matches(path, ['reverse-geocode'])),
        ),
        RateLimitRule(
          id: 'write',
          limit: writeLimit,
          matches: (method, path) {
            if (method != 'POST' && method != 'PATCH' && method != 'DELETE') {
              return false;
            }
            return !_matches(path, ['auth', 'login']) &&
                !_matches(path, ['auth', 'send-code']) &&
                !_matches(path, ['auth', 'logout']);
          },
        ),
      ],
    );
  }

  final bool enabled;
  final Duration window;
  final List<RateLimitRule> rules;
  final bool trustProxyHeaders;
  final Map<String, _RateLimitWindow> _windows = {};

  RateLimitDecision check(
    HttpRequest request,
    String method,
    List<String> path,
  ) {
    final rule = _ruleFor(method, path);
    final now = DateTime.now().toUtc();
    if (!enabled || rule == null) {
      return RateLimitDecision(
        allowed: true,
        ruleId: 'none',
        limit: 0,
        remaining: 0,
        resetAt: now,
      );
    }

    _prune(now);
    final key = '${rule.id}:${_clientKey(request)}';
    final current = _windows[key];
    final bucket = current == null || !now.isBefore(current.resetAt)
        ? _RateLimitWindow(count: 0, resetAt: now.add(window))
        : current;
    _windows[key] = bucket;

    if (bucket.count >= rule.limit) {
      return RateLimitDecision(
        allowed: false,
        ruleId: rule.id,
        limit: rule.limit,
        remaining: 0,
        resetAt: bucket.resetAt,
      );
    }

    bucket.count += 1;
    return RateLimitDecision(
      allowed: true,
      ruleId: rule.id,
      limit: rule.limit,
      remaining: math.max(0, rule.limit - bucket.count),
      resetAt: bucket.resetAt,
    );
  }

  RateLimitRule? _ruleFor(String method, List<String> path) {
    for (final rule in rules) {
      if (rule.matches(method, path)) {
        return rule;
      }
    }
    return null;
  }

  String _clientKey(HttpRequest request) {
    if (trustProxyHeaders) {
      final forwardedFor = request.headers.value('x-forwarded-for');
      final firstForwarded = forwardedFor?.split(',').first.trim();
      if (firstForwarded != null && firstForwarded.isNotEmpty) {
        return firstForwarded;
      }
    }
    return request.connectionInfo?.remoteAddress.address ?? 'unknown';
  }

  void _prune(DateTime now) {
    _windows.removeWhere((_, bucket) => !now.isBefore(bucket.resetAt));
  }
}

class _RateLimitWindow {
  _RateLimitWindow({
    required this.count,
    required this.resetAt,
  });

  int count;
  final DateTime resetAt;
}

class ServerTelemetry {
  ServerTelemetry() : startedAt = DateTime.now().toUtc();

  final DateTime startedAt;
  var totalRequests = 0;
  var totalDurationMicros = 0;
  final Map<String, int> routeCounts = {};
  final Map<String, int> statusCounts = {};

  void record(
    String method,
    String route,
    int statusCode,
    DateTime requestStartedAt,
  ) {
    totalRequests += 1;
    final elapsedMicros =
        DateTime.now().toUtc().difference(requestStartedAt).inMicroseconds;
    totalDurationMicros += math.max(0, elapsedMicros);
    routeCounts.update('$method $route', (value) => value + 1,
        ifAbsent: () => 1);
    statusCounts.update(
      statusCode.toString(),
      (value) => value + 1,
      ifAbsent: () => 1,
    );
  }

  Map<String, Object?> snapshot() {
    final uptime = DateTime.now().toUtc().difference(startedAt);
    final averageDurationMillis =
        totalRequests == 0 ? 0.0 : totalDurationMicros / totalRequests / 1000;
    return {
      'status': 'ok',
      'startedAt': startedAt.toIso8601String(),
      'uptimeSeconds': uptime.inSeconds,
      'totalRequests': totalRequests,
      'averageDurationMillis':
          double.parse(averageDurationMillis.toStringAsFixed(3)),
      'routes': Map<String, int>.fromEntries(
        routeCounts.entries.toList()
          ..sort((left, right) => left.key.compareTo(right.key)),
      ),
      'statuses': Map<String, int>.fromEntries(
        statusCounts.entries.toList()
          ..sort((left, right) => left.key.compareTo(right.key)),
      ),
    };
  }
}

class AuthSession {
  const AuthSession({
    required this.tokenHash,
    required this.userId,
    required this.expiresAt,
  });

  final String tokenHash;
  final String userId;
  final DateTime expiresAt;
}

class SqliteStore {
  SqliteStore._(this.path, this._db, {this.amapWebServiceKey});

  final String path;
  final Database _db;
  final String? amapWebServiceKey;

  static SqliteStore open(String path, {String? amapWebServiceKey}) {
    Directory(File(path).parent.path).createSync(recursive: true);
    final db = sqlite3.open(path);
    final store = SqliteStore._(path, db, amapWebServiceKey: amapWebServiceKey);
    store._migrate();
    store._seed();
    store.pruneExpiredSessions();
    return store;
  }

  void _migrate() {
    _db.execute('PRAGMA foreign_keys = ON');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS schema_migrations (
        version INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        checksum TEXT NOT NULL,
        applied_at TEXT NOT NULL
      )
    ''');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        identifier TEXT NOT NULL UNIQUE,
        display_name TEXT NOT NULL,
        created_at TEXT NOT NULL,
        last_login_at TEXT NOT NULL
      )
    ''');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS sessions (
        token_hash TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        expires_at TEXT NOT NULL,
        revoked_at TEXT,
        FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS destinations (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        city TEXT NOT NULL,
        theme TEXT NOT NULL,
        summary TEXT NOT NULL,
        duration TEXT NOT NULL,
        tags_json TEXT NOT NULL,
        priority INTEGER NOT NULL,
        lat REAL NOT NULL,
        lng REAL NOT NULL
      )
    ''');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS map_places (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        description TEXT NOT NULL,
        rating TEXT NOT NULL,
        lat REAL NOT NULL,
        lng REAL NOT NULL
      )
    ''');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS scenic_spots (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        province TEXT NOT NULL,
        city TEXT NOT NULL,
        district TEXT NOT NULL,
        level TEXT NOT NULL,
        kind TEXT NOT NULL,
        intro TEXT NOT NULL,
        aliases_json TEXT NOT NULL,
        image_url TEXT NOT NULL,
        lat REAL NOT NULL,
        lng REAL NOT NULL
      )
    ''');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS itineraries (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        title TEXT NOT NULL,
        destination TEXT NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        status TEXT NOT NULL,
        days_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS saved_trips (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        type TEXT NOT NULL,
        ref_id TEXT NOT NULL,
        label TEXT NOT NULL,
        folder TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    _db.execute('''
      CREATE TABLE IF NOT EXISTS feedback (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        category TEXT NOT NULL,
        description TEXT NOT NULL,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    _ensureColumn('saved_trips', 'label', "TEXT NOT NULL DEFAULT 'Saved item'");
    _ensureColumn('users', 'password_hash', "TEXT NOT NULL DEFAULT ''");
    _ensureColumn('users', 'password_salt', "TEXT NOT NULL DEFAULT ''");
    _recordSchemaMigration();
  }

  void _seed() {
    _deleteLegacyMapPlaceSeeds();
    _deleteUnchangedLegacyItinerarySeed();
    _mergeDuplicateItineraryDays();
    if (_count('users') == 0) {
      final now = DateTime.now().toIso8601String();
      _db.execute(
        'INSERT INTO users '
        '(id, identifier, display_name, password_hash, password_salt, '
        'created_at, last_login_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?)',
        ['user-dev-1', 'demo@wayfare.local', 'Demo Traveler', '', '', now, now],
      );
    }
    if (_count('destinations') == 0) {
      _insertDestination(
        'dest-hangzhou',
        'Hangzhou Lakeside',
        'Hangzhou',
        'Nature + Culture',
        'West Lake, tea fields, evening streets, and easy walks.',
        '2 days',
        ['Nature', 'Culture', 'Weekend'],
        true,
        30.2431,
        120.1508,
      );
      _insertDestination(
        'dest-shanghai',
        'Shanghai City Break',
        'Shanghai',
        'City Break',
        'Museums, skyline viewpoints, food streets, and metro routes.',
        '1-2 days',
        ['City Break', 'Food', 'Culture'],
        true,
        31.2304,
        121.4737,
      );
    }
    _seedScenicSpots();
    if (_count('itineraries') == 0) {
      final today = DateTime.now().toIso8601String().split('T').first;
      createItinerary({
        'id': 'trip-dev-default',
        'userId': 'user-dev-1',
        'title': 'My Travel Plan',
        'destination': 'Current Trip',
        'startDate': today,
        'endDate': today,
        'days': <Map<String, Object?>>[],
      });
    }
  }

  void _deleteLegacyMapPlaceSeeds() {
    _db.execute(
      '''
      DELETE FROM map_places
      WHERE id IN (?, ?, ?)
         OR name IN (?, ?, ?)
      ''',
      [
        'place-west-lake',
        'place-hefang',
        'place-longjing',
        'West Lake',
        'Hefang Street',
        'Longjing Village',
      ],
    );
  }

  void _deleteUnchangedLegacyItinerarySeed() {
    final rows = _db.select(
      'SELECT days_json FROM itineraries WHERE id = ?',
      ['trip-dev-hangzhou'],
    );
    if (rows.isEmpty) {
      return;
    }
    final decoded = jsonDecode(rows.first['days_json'] as String);
    if (decoded is! List || decoded.length != 1) {
      return;
    }
    final day = decoded.first;
    if (day is! Map || day['id'] != 'day-dev-1') {
      return;
    }
    final items = day['items'];
    if (items is! List || items.length != 1) {
      return;
    }
    final item = items.first;
    if (item is! Map || item['id'] != 'item-dev-1') {
      return;
    }
    _db.execute('DELETE FROM itineraries WHERE id = ?', ['trip-dev-hangzhou']);
  }

  void _mergeDuplicateItineraryDays() {
    final rows = _db.select('SELECT * FROM itineraries');
    for (final row in rows) {
      final trip = _decodeItinerary(row);
      final days = _days(trip);
      final merged = <Map<String, Object?>>[];
      final byDate = <String, Map<String, Object?>>{};
      var changed = false;

      for (final day in days) {
        final date = day['date']?.toString();
        final key = date == null || date.isEmpty
            ? day['id']?.toString() ?? _id('day')
            : date;
        final existing = byDate[key];
        if (existing == null) {
          byDate[key] = day;
          merged.add(day);
          continue;
        }
        _items(existing).addAll(_items(day));
        changed = true;
      }

      if (!changed) {
        continue;
      }
      for (var dayIndex = 0; dayIndex < merged.length; dayIndex++) {
        final day = merged[dayIndex];
        day['dayIndex'] = dayIndex + 1;
        final title = day['title']?.toString() ?? '';
        if (RegExp(r'^Day \d+$').hasMatch(title)) {
          day['title'] = 'Day ${dayIndex + 1}';
        }
        final items = _items(day);
        for (var itemIndex = 0; itemIndex < items.length; itemIndex++) {
          items[itemIndex]['order'] = itemIndex;
        }
        day['items'] = items;
      }
      trip['days'] = merged;
      trip['updatedAt'] = DateTime.now().toIso8601String();
      _saveItinerary(trip);
    }
  }

  int userCount() => _count('users');

  int schemaVersion() {
    final result = _db.select('PRAGMA user_version');
    final value = result.isEmpty ? 0 : result.first.values.first;
    return value is int ? value : int.tryParse(value.toString()) ?? 0;
  }

  List<Map<String, Object?>> schemaMigrations() {
    return _db
        .select(
          '''
          SELECT version, name, checksum, applied_at
          FROM schema_migrations
          ORDER BY version
          ''',
        )
        .map(_row)
        .toList(growable: false);
  }

  // Returns null when an existing account's password does not match. New
  // identifiers register with the supplied password; existing accounts without
  // a password yet adopt the one supplied on this login.
  Map<String, Object?>? loginOrRegister(String identifier, String password) {
    final existing = _db.select(
      'SELECT * FROM users WHERE identifier = ?',
      [identifier],
    );
    final now = DateTime.now().toIso8601String();
    if (existing.isNotEmpty) {
      final row = existing.first;
      final storedHash = (row['password_hash'] as String?) ?? '';
      final storedSalt = (row['password_salt'] as String?) ?? '';
      if (storedHash.isEmpty) {
        final salt = _generateSalt();
        _db.execute(
          'UPDATE users SET password_hash = ?, password_salt = ?, '
          'last_login_at = ? WHERE id = ?',
          [_hashPassword(password, salt), salt, now, row['id']],
        );
      } else if (_hashPassword(password, storedSalt) != storedHash) {
        return null;
      } else {
        _db.execute('UPDATE users SET last_login_at = ? WHERE id = ?', [
          now,
          row['id'],
        ]);
      }
      return {
        'registered': false,
        'user': {
          'id': row['id'],
          'identifier': row['identifier'],
          'display_name': row['display_name'],
          'created_at': row['created_at'],
          'last_login_at': now,
        },
      };
    }

    final id = _id('user');
    final displayName = _displayName(identifier);
    final salt = _generateSalt();
    _db.execute(
      'INSERT INTO users '
      '(id, identifier, display_name, password_hash, password_salt, '
      'created_at, last_login_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?)',
      [id, identifier, displayName, _hashPassword(password, salt), salt, now, now],
    );
    return {
      'registered': true,
      'user': {
        'id': id,
        'identifier': identifier,
        'display_name': displayName,
        'created_at': now,
        'last_login_at': now,
      },
    };
  }

  Map<String, Object?> createSession({
    required String userId,
    required String tokenHash,
    required DateTime expiresAt,
  }) {
    final now = DateTime.now().toUtc().toIso8601String();
    final expiresAtIso = expiresAt.toUtc().toIso8601String();
    _db.execute(
      '''
      INSERT INTO sessions
        (token_hash, user_id, created_at, expires_at, revoked_at)
      VALUES (?, ?, ?, ?, NULL)
      ''',
      [tokenHash, userId, now, expiresAtIso],
    );
    return {
      'tokenHash': tokenHash,
      'userId': userId,
      'createdAt': now,
      'expiresAt': expiresAtIso,
      'revokedAt': null,
    };
  }

  Map<String, Object?>? sessionByTokenHash(String tokenHash) => _first(
        '''
        SELECT token_hash, user_id, created_at, expires_at, revoked_at
        FROM sessions
        WHERE token_hash = ?
        ''',
        [tokenHash],
      );

  void revokeSession(String tokenHash) {
    _db.execute(
      '''
      UPDATE sessions
      SET revoked_at = ?
      WHERE token_hash = ? AND revoked_at IS NULL
      ''',
      [DateTime.now().toUtc().toIso8601String(), tokenHash],
    );
  }

  void pruneExpiredSessions() {
    _db.execute(
      'DELETE FROM sessions WHERE expires_at <= ?',
      [DateTime.now().toUtc().toIso8601String()],
    );
  }

  Map<String, Object?>? userById(String id) => _first(
        'SELECT id, identifier, display_name, created_at, last_login_at '
        'FROM users WHERE id = ?',
        [id],
      );

  Map<String, Object?>? updateDisplayName(String userId, String displayName) {
    final rows = _db.select('SELECT id FROM users WHERE id = ?', [userId]);
    if (rows.isEmpty) {
      return null;
    }
    _db.execute('UPDATE users SET display_name = ? WHERE id = ?', [
      displayName,
      userId,
    ]);
    return userById(userId);
  }

  // Returns false when the user is missing or the current password does not
  // match. A user with no password yet may set one without a current password.
  bool changePassword(String userId, String currentPassword, String newPassword) {
    final rows = _db.select(
      'SELECT password_hash, password_salt FROM users WHERE id = ?',
      [userId],
    );
    if (rows.isEmpty) {
      return false;
    }
    final storedHash = (rows.first['password_hash'] as String?) ?? '';
    final storedSalt = (rows.first['password_salt'] as String?) ?? '';
    if (storedHash.isNotEmpty &&
        _hashPassword(currentPassword, storedSalt) != storedHash) {
      return false;
    }
    final salt = _generateSalt();
    _db.execute(
      'UPDATE users SET password_hash = ?, password_salt = ? WHERE id = ?',
      [_hashPassword(newPassword, salt), salt, userId],
    );
    return true;
  }

  List<Map<String, Object?>> destinations({bool priorityOnly = false}) {
    final rows = _db.select(
      priorityOnly
          ? 'SELECT * FROM destinations WHERE priority = 1'
          : 'SELECT * FROM destinations',
    );
    return rows.map((row) {
      final item = _row(row);
      item['tags'] = jsonDecode(item.remove('tags_json') as String);
      item['priority'] = item['priority'] == 1;
      return item;
    }).toList();
  }

  Map<String, Object?>? destination(String id) {
    final item = _first('SELECT * FROM destinations WHERE id = ?', [id]);
    if (item == null) {
      return null;
    }
    item['tags'] = jsonDecode(item.remove('tags_json') as String);
    item['priority'] = item['priority'] == 1;
    return item;
  }

  List<Map<String, Object?>> mapPlaces() {
    return _db.select('SELECT * FROM map_places').map(_row).toList();
  }

  Future<List<Map<String, Object?>>> search(String query,
      {int limit = 20}) async {
    final amapItems = await _searchAmap(query, limit: limit);
    if (amapItems.isNotEmpty) {
      return _normalizeSearchItems(amapItems);
    }
    return _normalizeSearchItems(_searchLocal(query, limit: limit));
  }

  Future<Map<String, Object?>> reverseGeocode({
    required double lat,
    required double lng,
    String? fallbackName,
  }) async {
    final fallback = _reverseGeocodeFallback(
      lat: lat,
      lng: lng,
      fallbackName: fallbackName,
    );
    final key = (amapWebServiceKey?.trim().isNotEmpty == true)
        ? amapWebServiceKey!.trim()
        : Platform.environment['AMAP_WEB_SERVICE_KEY']?.trim();
    if (key == null || key.isEmpty) {
      return fallback;
    }

    final uri = Uri.https('restapi.amap.com', '/v3/geocode/regeo', {
      'key': key,
      'location': '${lng.toStringAsFixed(7)},${lat.toStringAsFixed(7)}',
      'radius': '300',
      'extensions': 'all',
      'output': 'json',
    });

    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 8);
      try {
        final request = await client.getUrl(uri);
        final response = await request.close().timeout(
              const Duration(seconds: 10),
            );
        if (response.statusCode != HttpStatus.ok) {
          return fallback;
        }
        final raw = await utf8.decoder.bind(response).join();
        final decoded = jsonDecode(raw);
        if (decoded is! Map || decoded['status']?.toString() != '1') {
          return fallback;
        }
        final regeocode = decoded['regeocode'];
        if (regeocode is! Map) {
          return fallback;
        }
        final pois = regeocode['pois'];
        final aois = regeocode['aois'];
        final nearest = _firstAmapPlace(pois) ?? _firstAmapPlace(aois);
        final formattedAddress = _amapField(
          regeocode['formatted_address'] ?? regeocode['formattedAddress'],
        );
        final component = regeocode['addressComponent'];
        final componentMap = component is Map
            ? component.map((key, value) => MapEntry(key, value))
            : const <Object?, Object?>{};
        final city = _amapField(componentMap['city']).trim().isNotEmpty
            ? _amapField(componentMap['city'])
            : _amapField(componentMap['province']);
        final nearestName = nearest == null ? '' : _amapField(nearest['name']);
        final type = nearest == null ? '' : _amapField(nearest['type']);
        return {
          'name': _firstNonEmpty([
            nearestName,
            formattedAddress,
            fallback['name']?.toString() ?? '',
          ]),
          'address': formattedAddress,
          'city': city,
          'source': 'amap_regeo',
          if (type.isNotEmpty) 'poiType': type,
          'lat': lat,
          'lng': lng,
        };
      } finally {
        client.close(force: true);
      }
    } catch (_) {
      return fallback;
    }
  }

  List<Map<String, Object?>> _searchLocal(String query, {int limit = 20}) {
    final text = query.trim().toLowerCase();
    if (text.isEmpty) {
      return [];
    }
    final like = '%$text%';
    final items = <Map<String, Object?>>[];
    final seen = <String>{};

    final spots = _db.select(
      '''
      SELECT *, 0 AS rank FROM scenic_spots
      WHERE lower(name) = ?
      UNION ALL
      SELECT *, 1 AS rank FROM scenic_spots
      WHERE lower(name) LIKE ? OR lower(city) LIKE ? OR lower(province) LIKE ?
         OR lower(district) LIKE ? OR lower(aliases_json) LIKE ?
      ORDER BY rank, city, name
      LIMIT ?
      ''',
      [text, like, like, like, like, like, limit],
    );
    for (final row in spots) {
      final item = _row(row);
      final id = item['id'].toString();
      if (!seen.add(id)) {
        continue;
      }
      items.add({
        'id': item['id'],
        'type': 'scenic_spot',
        'name': item['name'],
        'subtitle': '${item['city']} · ${item['district']}',
        'city': item['city'],
        'level': item['level'],
        'intro': item['intro'],
        'imageUrl': item['image_url'],
        'lat': item['lat'],
        'lng': item['lng'],
      });
    }

    if (items.length >= limit) {
      return items.take(limit).toList();
    }

    final destinationRows = _db.select(
      '''
      SELECT * FROM destinations
      WHERE lower(name) LIKE ? OR lower(city) LIKE ? OR lower(theme) LIKE ?
      LIMIT ?
      ''',
      [like, like, like, limit - items.length],
    );
    for (final row in destinationRows) {
      final item = _row(row);
      items.add({
        'id': item['id'],
        'type': 'destination',
        'name': item['name'],
        'subtitle': '${item['city']} · ${item['theme']}',
        'city': item['city'],
        'level': item['priority'] == 1 ? 'Recommended' : 'Destination',
        'intro': _shortIntro(item['summary']?.toString() ?? ''),
        'imageUrl': _imageUrl(item['name'].toString(), item['city'].toString()),
        'lat': item['lat'],
        'lng': item['lng'],
      });
    }

    if (items.length >= limit) {
      return items.take(limit).toList();
    }

    final placeRows = _db.select(
      '''
      SELECT * FROM map_places
      WHERE lower(name) LIKE ? OR lower(category) LIKE ?
      LIMIT ?
      ''',
      [like, like, limit - items.length],
    );
    for (final row in placeRows) {
      final item = _row(row);
      items.add({
        'id': item['id'],
        'type': 'map_place',
        'name': item['name'],
        'subtitle': item['category'],
        'city': '',
        'level': item['rating'],
        'intro': _shortIntro(item['description']?.toString() ?? ''),
        'imageUrl': _imageUrl(item['name'].toString(), 'China'),
        'lat': item['lat'],
        'lng': item['lng'],
      });
    }

    return items.take(limit).toList();
  }

  Future<List<Map<String, Object?>>> _searchAmap(String query,
      {int limit = 20}) async {
    final key = (amapWebServiceKey?.trim().isNotEmpty == true)
        ? amapWebServiceKey!.trim()
        : Platform.environment['AMAP_WEB_SERVICE_KEY']?.trim();
    final text = query.trim();
    if (key == null || key.isEmpty || text.isEmpty) {
      return [];
    }

    final uri = Uri.https('restapi.amap.com', '/v3/place/text', {
      'key': key,
      'keywords': text,
      'city': '全国',
      'citylimit': 'false',
      'offset': limit.clamp(1, 25).toString(),
      'page': '1',
      'extensions': 'all',
      'output': 'json',
    });

    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 8);
      try {
        final request = await client.getUrl(uri);
        final response = await request.close().timeout(
              const Duration(seconds: 10),
            );
        if (response.statusCode != HttpStatus.ok) {
          return [];
        }
        final raw = await utf8.decoder.bind(response).join();
        final decoded = jsonDecode(raw);
        if (decoded is! Map || decoded['status']?.toString() != '1') {
          return [];
        }
        final pois = decoded['pois'];
        if (pois is! List) {
          return [];
        }
        final items = <Map<String, Object?>>[];
        final seen = <String>{};
        for (final poi in pois) {
          if (poi is! Map) {
            continue;
          }
          final location = poi['location']?.toString() ?? '';
          final parts = location.split(',');
          if (parts.length != 2) {
            continue;
          }
          final lng = double.tryParse(parts[0]);
          final lat = double.tryParse(parts[1]);
          if (lat == null || lng == null) {
            continue;
          }
          final id = poi['id']?.toString() ??
              'amap-${lat.toStringAsFixed(6)}-${lng.toStringAsFixed(6)}';
          if (!seen.add(id)) {
            continue;
          }
          final name = poi['name']?.toString() ?? text;
          final city = _amapField(poi['cityname']);
          final district = _amapField(poi['adname']);
          final address = _amapField(poi['address']);
          final type = _amapField(poi['type']);
          final imageUrl = _amapPhotoUrl(poi) ??
              _imageUrl(name, city.isEmpty ? 'China' : city);
          items.add({
            'id': id,
            'type': 'amap_poi',
            'name': name,
            'subtitle': [
              if (city.isNotEmpty) city,
              if (district.isNotEmpty) district,
              if (address.isNotEmpty) address,
            ].join(' | '),
            'city': city,
            'level': 'AMap',
            'intro': _shortIntro(type.isEmpty ? address : type),
            'imageUrl': imageUrl,
            'lat': lat,
            'lng': lng,
          });
        }
        return items.take(limit).toList();
      } finally {
        client.close(force: true);
      }
    } catch (_) {
      return [];
    }
  }

  List<Map<String, Object?>> _normalizeSearchItems(
    List<Map<String, Object?>> items,
  ) {
    return items.map((item) {
      final normalized = Map<String, Object?>.from(item);
      final subtitle = normalized['subtitle']?.toString() ?? '';
      normalized['subtitle'] = subtitle
          .replaceAll(' \u8def ', ' ')
          .replaceAll(' 璺?', ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if ((normalized['level']?.toString().toLowerCase() ?? '') == 'amap') {
        normalized['level'] = '';
      }
      final imageUrl = normalized['imageUrl']?.toString() ?? '';
      if (imageUrl.isEmpty) {
        normalized['imageUrl'] = _imageUrl(
          normalized['name']?.toString() ?? 'travel',
          normalized['city']?.toString() ?? 'China',
        );
      }
      return normalized;
    }).toList(growable: false);
  }

  List<Map<String, Object?>> itineraries(String userId) {
    return _db
        .select('SELECT * FROM itineraries WHERE user_id = ?', [userId])
        .map(_decodeItinerary)
        .toList();
  }

  Map<String, Object?>? itinerary(String id) {
    final result = _db.select('SELECT * FROM itineraries WHERE id = ?', [id]);
    if (result.isEmpty) {
      return null;
    }
    return _decodeItinerary(result.first);
  }

  Map<String, Object?> createItinerary(Map<String, Object?> body) {
    final now = DateTime.now().toIso8601String();
    final item = {
      'id': body['id'] ?? _id('trip'),
      'userId': body['userId'] ?? 'user-dev-1',
      'title': body['title'] ?? 'Untitled trip',
      'destination': body['destination'] ?? 'TBD',
      'startDate': body['startDate'] ?? 'TBD',
      'endDate': body['endDate'] ?? 'TBD',
      'status': body['status'] ?? 'draft',
      'days': body['days'] ?? <Map<String, Object?>>[],
      'createdAt': now,
      'updatedAt': now,
    };
    _db.execute(
      'INSERT OR REPLACE INTO itineraries VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        item['id'],
        item['userId'],
        item['title'],
        item['destination'],
        item['startDate'],
        item['endDate'],
        item['status'],
        jsonEncode(item['days']),
        item['createdAt'],
        item['updatedAt'],
      ],
    );
    return item;
  }

  Map<String, Object?> updateItinerary(String id, Map<String, Object?> body) {
    final item = itinerary(id);
    if (item == null) {
      throw StateError('Itinerary not found');
    }
    item.addAll(body);
    item['updatedAt'] = DateTime.now().toIso8601String();
    _saveItinerary(item);
    return item;
  }

  void deleteItinerary(String id) {
    _db.execute('DELETE FROM itineraries WHERE id = ?', [id]);
  }

  Map<String, Object?> addDay(String itineraryId, Map<String, Object?> body) {
    final trip = itinerary(itineraryId);
    if (trip == null) {
      throw StateError('Itinerary not found');
    }
    final days = _days(trip);
    final day = {
      'id': _id('day'),
      'dayIndex': body['dayIndex'] ?? days.length + 1,
      'title': body['title'] ?? body['date'] ?? 'TBD',
      'date': body['date'] ?? 'TBD',
      'city': body['city'] ?? 'TBD',
      'reminder': body['reminder'] ?? '',
      'items': <Map<String, Object?>>[],
    };
    days.add(day);
    trip['days'] = days;
    trip['updatedAt'] = DateTime.now().toIso8601String();
    _saveItinerary(trip);
    return day;
  }

  void deleteDay(String itineraryId, String dayId) {
    final trip = itinerary(itineraryId);
    if (trip == null) {
      throw StateError('Itinerary not found');
    }
    final days = _days(trip);
    _dayById(days, dayId);
    days.removeWhere((entry) => entry['id'] == dayId);
    for (var index = 0; index < days.length; index++) {
      days[index]['dayIndex'] = index + 1;
    }
    trip['days'] = days;
    trip['updatedAt'] = DateTime.now().toIso8601String();
    _saveItinerary(trip);
  }

  Map<String, Object?> addItem(
    String itineraryId,
    String dayId,
    Map<String, Object?> body,
  ) {
    final trip = itinerary(itineraryId);
    if (trip == null) {
      throw StateError('Itinerary not found');
    }
    final days = _days(trip);
    final day = _dayById(days, dayId);
    final items = _items(day);
    final item = {
      'id': _id('item'),
      'time': body['time'] ?? 'Flexible',
      'placeId': body['placeId'],
      'placeName': body['placeName'] ?? body['place'] ?? 'TBD',
      'activity': body['activity'] ?? 'Plan visit',
      'note': body['note'] ?? '',
      'order': body['order'] ?? items.length,
      'status': body['status'] ?? 'draft',
      'lat': body['lat'],
      'lng': body['lng'],
    };
    items.add(item);
    day['items'] = items;
    trip['days'] = days;
    trip['updatedAt'] = DateTime.now().toIso8601String();
    _saveItinerary(trip);
    return item;
  }

  Map<String, Object?> updateItem(
    String itineraryId,
    String dayId,
    String itemId,
    Map<String, Object?> body,
  ) {
    final trip = itinerary(itineraryId);
    if (trip == null) {
      throw StateError('Itinerary not found');
    }
    final days = _days(trip);
    final day = _dayById(days, dayId);
    final items = _items(day);
    final item = _itemById(items, itemId);
    item.addAll(body);
    final targetDayId = body['targetDayId']?.toString();
    if (targetDayId != null && targetDayId.isNotEmpty && targetDayId != dayId) {
      items.removeWhere((entry) => entry['id'] == itemId);
      final targetDay = _dayById(days, targetDayId);
      final targetItems = _items(targetDay);
      item['order'] = targetItems.length;
      targetItems.add(item);
      targetDay['items'] = targetItems;
    }
    item['status'] = body['status'] ?? item['status'] ?? 'draft';
    item.remove('targetDayId');
    for (final indexedDay in days) {
      final indexedItems = _items(indexedDay);
      for (var index = 0; index < indexedItems.length; index++) {
        indexedItems[index]['order'] = index;
      }
      indexedDay['items'] = indexedItems;
    }
    trip['updatedAt'] = DateTime.now().toIso8601String();
    _saveItinerary(trip);
    return item;
  }

  List<Map<String, Object?>> reorderItems(
    String itineraryId,
    String dayId,
    Map<String, Object?> body,
  ) {
    final trip = itinerary(itineraryId);
    if (trip == null) {
      throw StateError('Itinerary not found');
    }
    final ids = (body['itemIds'] as List?)?.map((id) => id.toString()).toList();
    if (ids == null) {
      throw const FormatException('itemIds is required.');
    }
    final days = _days(trip);
    final day = _dayById(days, dayId);
    final items = _items(day);
    final byId = {for (final item in items) item['id'].toString(): item};
    final reordered = <Map<String, Object?>>[];
    for (final id in ids) {
      final item = byId[id];
      if (item != null) {
        reordered.add(item);
      }
    }
    for (final item in items) {
      if (!ids.contains(item['id'].toString())) {
        reordered.add(item);
      }
    }
    for (var index = 0; index < reordered.length; index++) {
      reordered[index]['order'] = index;
    }
    day['items'] = reordered;
    trip['days'] = days;
    trip['updatedAt'] = DateTime.now().toIso8601String();
    _saveItinerary(trip);
    return reordered;
  }

  void deleteItem(String itineraryId, String dayId, String itemId) {
    final trip = itinerary(itineraryId);
    if (trip == null) {
      throw StateError('Itinerary not found');
    }
    final days = _days(trip);
    final day = _dayById(days, dayId);
    final items = _items(day);
    _itemById(items, itemId);
    items.removeWhere((entry) => entry['id'] == itemId);
    day['items'] = items;
    trip['days'] = days;
    trip['updatedAt'] = DateTime.now().toIso8601String();
    _saveItinerary(trip);
  }

  List<Map<String, Object?>> savedTrips(String userId) {
    return _db
        .select('SELECT * FROM saved_trips WHERE user_id = ?', [userId])
        .map(_row)
        .toList();
  }

  Map<String, Object?> createSavedItem(Map<String, Object?> body) {
    final now = DateTime.now().toIso8601String();
    final item = {
      'id': _id('saved'),
      'user_id': body['userId'] ?? 'user-dev-1',
      'type': body['type'] ?? 'destination',
      'ref_id': body['refId'] ?? body['destination'] ?? 'unknown',
      'label':
          body['label'] ?? body['destination'] ?? body['refId'] ?? 'Saved item',
      'folder': body['folder'] ?? 'Weekend',
      'created_at': now,
    };
    _db.execute(
      '''
      INSERT INTO saved_trips
        (id, user_id, type, ref_id, label, folder, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        item['id'],
        item['user_id'],
        item['type'],
        item['ref_id'],
        item['label'],
        item['folder'],
        item['created_at'],
      ],
    );
    return item;
  }

  bool deleteSavedItem(String id, String userId) {
    final result = _db.select(
      'SELECT COUNT(*) AS count FROM saved_trips WHERE id = ? AND user_id = ?',
      [id, userId],
    );
    final exists = (result.first['count'] as int) > 0;
    if (!exists) {
      return false;
    }
    _db.execute(
      'DELETE FROM saved_trips WHERE id = ? AND user_id = ?',
      [id, userId],
    );
    return true;
  }

  Map<String, Object?> createFeedback(Map<String, Object?> body) {
    final now = DateTime.now().toIso8601String();
    final item = {
      'id': _id('feedback'),
      'user_id': body['userId'] ?? 'user-dev-1',
      'category': body['category'] ?? 'general',
      'description': body['description'] ?? '',
      'status': 'open',
      'created_at': now,
    };
    _db.execute(
      'INSERT INTO feedback VALUES (?, ?, ?, ?, ?, ?)',
      [
        item['id'],
        item['user_id'],
        item['category'],
        item['description'],
        item['status'],
        item['created_at'],
      ],
    );
    return item;
  }

  void _saveItinerary(Map<String, Object?> item) {
    _db.execute(
      '''
      UPDATE itineraries
      SET title = ?, destination = ?, start_date = ?, end_date = ?,
          status = ?, days_json = ?, updated_at = ?
      WHERE id = ?
      ''',
      [
        item['title'],
        item['destination'],
        item['startDate'],
        item['endDate'],
        item['status'],
        jsonEncode(item['days']),
        item['updatedAt'],
        item['id'],
      ],
    );
  }

  Map<String, Object?> _decodeItinerary(Row row) {
    final item = _row(row);
    return {
      'id': item['id'],
      'userId': item['user_id'],
      'title': item['title'],
      'destination': item['destination'],
      'startDate': item['start_date'],
      'endDate': item['end_date'],
      'status': item['status'],
      'days': jsonDecode(item['days_json'] as String),
      'createdAt': item['created_at'],
      'updatedAt': item['updated_at'],
    };
  }

  int _count(String table) {
    return _db.select('SELECT COUNT(*) AS value FROM $table').first['value']
        as int;
  }

  Map<String, Object?>? _first(String sql, [List<Object?> params = const []]) {
    final result = _db.select(sql, params);
    return result.isEmpty ? null : _row(result.first);
  }

  void _seedScenicSpots() {
    final spots = [
      [
        'spot-bj-palace',
        '故宫博物院',
        '北京',
        '北京',
        '东城区',
        '5A',
        '博物馆',
        '明清宫城与皇家建筑群',
        'forbidden city,palace museum,故宫',
        39.9163,
        116.3972
      ],
      [
        'spot-bj-summer-palace',
        '颐和园',
        '北京',
        '北京',
        '海淀区',
        '5A',
        '皇家园林',
        '皇家园林与昆明湖山景',
        'summer palace,颐和园景区',
        39.9999,
        116.2755
      ],
      [
        'spot-bj-temple-heaven',
        '天坛公园',
        '北京',
        '北京',
        '东城区',
        '5A',
        '历史文化',
        '祭天建筑与古柏园林',
        'temple of heaven,天坛',
        39.8822,
        116.4066
      ],
      [
        'spot-ah-huangshan',
        '黄山风景区',
        '安徽',
        '黄山',
        '黄山区',
        '5A',
        '山岳景区',
        '奇松怪石、云海温泉与山岳徒步路线',
        'huangshan,yellow mountain,黄山',
        30.1302,
        118.1662
      ],
      [
        'spot-sc-jiuzhaigou',
        '九寨沟景区',
        '四川',
        '阿坝',
        '九寨沟县',
        '5A',
        '自然保护区',
        '高山湖泊、瀑布群和彩林观景路线',
        'jiuzhaigou,九寨沟旅游景区',
        33.2600,
        103.9180
      ],
      [
        'spot-hn-zhangjiajie-wulingyuan',
        '张家界武陵源',
        '湖南',
        '张家界',
        '武陵源区',
        '5A',
        '峰林峡谷',
        '石英砂岩峰林、峡谷索道与高空观景台',
        'wulingyuan,zhangjiajie,张家界国家森林公园',
        29.3450,
        110.4790
      ],
      [
        'spot-xa-terracotta',
        '秦始皇帝陵博物院',
        '陕西',
        '西安',
        '临潼区',
        '5A',
        '遗址博物馆',
        '兵马俑、秦文化与大型遗址博物馆动线',
        'terracotta warriors,兵马俑,秦始皇兵马俑',
        34.3853,
        109.2787
      ],
      [
        'spot-nj-fuzimiao-qinhuai',
        '南京夫子庙秦淮风光带',
        '江苏',
        '南京',
        '秦淮区',
        '5A',
        '历史街区',
        '秦淮夜游、夫子庙街巷与传统商业街区',
        'confucius temple qinhuai,夫子庙,秦淮河',
        32.0206,
        118.7880
      ],
      [
        'spot-tj-ancient-culture-5a',
        '天津古文化街',
        '天津',
        '天津',
        '南开区',
        '5A',
        '民俗街区',
        '津门民俗、传统商铺与老城街景',
        'ancient culture street tianjin,古文化街,天津古文化街旅游区',
        39.1427,
        117.1886
      ],
      [
        'spot-sx-pingyao',
        '平遥古城',
        '山西',
        '晋中',
        '平遥县',
        '5A',
        '古城街巷',
        '古城墙、票号院落与北方街巷肌理',
        'pingyao ancient city,平遥',
        37.2010,
        112.1750
      ],
      [
        'spot-gz-chimelong',
        '广州长隆旅游度假区',
        '广东',
        '广州',
        '番禺区',
        '5A',
        '主题度假区',
        '主题乐园、亲子演艺与高密度度假动线',
        'chimelong guangzhou,广州长隆,长隆旅游度假区',
        23.0050,
        113.3260
      ],
      [
        'spot-zj-wuzhen',
        '乌镇景区',
        '浙江',
        '嘉兴',
        '桐乡市',
        '5A',
        '水乡古镇',
        '江南水乡、夜游街巷与慢节奏商业体验',
        'wuzhen,乌镇古镇,乌镇旅游区',
        30.7460,
        120.4870
      ],
      [
        'spot-yn-lijiang-old-town',
        '丽江古城',
        '云南',
        '丽江',
        '古城区',
        '5A',
        '古城街巷',
        '纳西古城街巷、夜游与小店集群',
        'lijiang old town,丽江古城景区,大研古城',
        26.8768,
        100.2376
      ],
      [
        'spot-bj-798',
        '798艺术区',
        '北京',
        '北京',
        '朝阳区',
        '4A',
        '艺术街区',
        '工业遗存与当代艺术空间',
        '798 art district,北京798',
        39.9842,
        116.4962
      ],
      [
        'spot-sh-oriental-pearl',
        '东方明珠',
        '上海',
        '上海',
        '浦东新区',
        '5A',
        '城市地标',
        '浦江天际线与观景塔',
        'oriental pearl tower,东方明珠广播电视塔',
        31.2397,
        121.4998
      ],
      [
        'spot-sh-yuyuan',
        '豫园',
        '上海',
        '上海',
        '黄浦区',
        '4A',
        '古典园林',
        '江南园林与城隍庙街区',
        'yu garden,豫园商城',
        31.2273,
        121.4920
      ],
      [
        'spot-sh-museum',
        '上海博物馆',
        '上海',
        '上海',
        '黄浦区',
        '4A',
        '博物馆',
        '中国古代艺术与城市文化',
        'shanghai museum,上海博物馆人民广场',
        31.2303,
        121.4708
      ],
      [
        'spot-sh-bund',
        '外滩',
        '上海',
        '上海',
        '黄浦区',
        '城市核心',
        '滨江街区',
        '万国建筑与浦江夜景',
        'the bund shanghai,外滩风景区',
        31.2400,
        121.4908
      ],
      [
        'spot-gz-canton-tower',
        '广州塔',
        '广东',
        '广州',
        '海珠区',
        '4A',
        '城市地标',
        '珠江夜景与高塔观景',
        'canton tower,广州塔小蛮腰',
        23.1067,
        113.3245
      ],
      [
        'spot-gz-yuexiu',
        '越秀公园',
        '广东',
        '广州',
        '越秀区',
        '4A',
        '城市公园',
        '五羊石像与广州城脉',
        'yuexiu park,越秀山',
        23.1396,
        113.2644
      ],
      [
        'spot-gz-chen-clan',
        '陈家祠',
        '广东',
        '广州',
        '荔湾区',
        '4A',
        '岭南建筑',
        '岭南祠堂与民间工艺',
        'chen clan ancestral hall,陈家祠堂',
        23.1292,
        113.2475
      ],
      [
        'spot-gz-shamian',
        '沙面',
        '广东',
        '广州',
        '荔湾区',
        '城市核心',
        '历史街区',
        '欧陆建筑与珠江街景',
        'shamian island,沙面岛',
        23.1092,
        113.2393
      ],
      [
        'spot-sz-window',
        '世界之窗',
        '广东',
        '深圳',
        '南山区',
        '5A',
        '主题公园',
        '世界微缩景观与演艺',
        'window of the world shenzhen,深圳世界之窗',
        22.5343,
        113.9737
      ],
      [
        'spot-sz-splendid-china',
        '锦绣中华民俗村',
        '广东',
        '深圳',
        '南山区',
        '5A',
        '主题公园',
        '中国微缩景观与民俗演艺',
        'splendid china folk village,锦绣中华',
        22.5350,
        113.9810
      ],
      [
        'spot-sz-happy-valley',
        '深圳欢乐谷',
        '广东',
        '深圳',
        '南山区',
        '4A',
        '主题公园',
        '大型游乐设施与演艺',
        'happy valley shenzhen,深圳欢乐谷',
        22.5394,
        113.9865
      ],
      [
        'spot-sz-lianhuashan',
        '莲花山公园',
        '广东',
        '深圳',
        '福田区',
        '城市核心',
        '城市公园',
        '城市中轴与山顶视野',
        'lianhuashan park shenzhen,莲花山',
        22.5550,
        114.0557
      ],
      [
        'spot-hz-west-lake',
        '西湖',
        '浙江',
        '杭州',
        '西湖区',
        '5A',
        '湖泊景区',
        '湖山园林与江南风景',
        'west lake hangzhou,杭州西湖',
        30.2431,
        120.1508
      ],
      [
        'spot-cs-yuelu-orange',
        '岳麓山橘子洲',
        '湖南',
        '长沙',
        '岳麓区',
        '5A',
        '山水景区',
        '湘江洲岛与岳麓山景',
        'yuelu mountain orange isle,橘子洲,岳麓山',
        28.1960,
        112.9552
      ],
      [
        'spot-cd-kuanzhai',
        '宽窄巷子',
        '四川',
        '成都',
        '青羊区',
        '4A',
        '历史街区',
        '清代街巷与川西生活体验',
        'kuanzhai alley,宽窄巷子景区',
        30.6695,
        104.0552
      ],
      [
        'spot-cd-wuhou',
        '武侯祠',
        '四川',
        '成都',
        '武侯区',
        '4A',
        '历史文化',
        '三国文化与园林红墙',
        'wuhou shrine,成都武侯祠',
        30.6455,
        104.0473
      ],
      [
        'spot-cd-dufu',
        '杜甫草堂',
        '四川',
        '成都',
        '青羊区',
        '4A',
        '博物馆',
        '唐诗文化与清幽园林',
        'dufu thatched cottage,杜甫草堂博物馆',
        30.6598,
        104.0289
      ],
      [
        'spot-hz-songcheng',
        '杭州宋城',
        '浙江',
        '杭州',
        '西湖区',
        '4A',
        '主题景区',
        '宋韵演艺与古街体验',
        'songcheng,杭州宋城景区',
        30.1739,
        120.0881
      ],
      [
        'spot-hz-qinghefang',
        '清河坊历史街区',
        '浙江',
        '杭州',
        '上城区',
        '4A',
        '历史街区',
        '老杭州街巷与小吃商铺',
        'hefang street,清河坊,河坊街',
        30.2416,
        120.1784
      ],
      [
        'spot-hz-tea-museum',
        '中国茶叶博物馆',
        '浙江',
        '杭州',
        '西湖区',
        '4A',
        '博物馆',
        '茶文化展示与龙井山景',
        'china national tea museum,茶叶博物馆',
        30.2265,
        120.1001
      ],
      [
        'spot-cq-hongyadong',
        '洪崖洞',
        '重庆',
        '重庆',
        '渝中区',
        '4A',
        '城市夜景',
        '吊脚楼夜景与山城步道',
        'hongyadong,洪崖洞民俗风貌区',
        29.5623,
        106.5792
      ],
      [
        'spot-cq-ciqikou',
        '磁器口古镇',
        '重庆',
        '重庆',
        '沙坪坝区',
        '4A',
        '古镇',
        '巴渝古镇与小吃街巷',
        'ciqikou,磁器口',
        29.5815,
        106.4515
      ],
      [
        'spot-cq-zoo',
        '重庆动物园',
        '重庆',
        '重庆',
        '九龙坡区',
        '4A',
        '公园',
        '城市动物园与亲子游线',
        'chongqing zoo,重庆动物园',
        29.5111,
        106.5110
      ],
      [
        'spot-wh-museum',
        '湖北省博物馆',
        '湖北',
        '武汉',
        '武昌区',
        '4A',
        '博物馆',
        '楚文化文物与编钟展',
        'hubei provincial museum,湖北博物馆',
        30.5619,
        114.3672
      ],
      [
        'spot-wh-jianghan',
        '江汉路步行街',
        '湖北',
        '武汉',
        '江汉区',
        '城市核心',
        '商业街区',
        '近代建筑与城市商业街',
        'jianghan road,江汉路',
        30.5864,
        114.2869
      ],
      [
        'spot-wh-yellow-crane',
        '黄鹤楼',
        '湖北',
        '武汉',
        '武昌区',
        '城市核心',
        '历史地标',
        '江城名楼与长江视野',
        'yellow crane tower,黄鹤楼公园',
        30.5467,
        114.3046
      ],
      [
        'spot-sz-pingjiang',
        '平江路历史街区',
        '江苏',
        '苏州',
        '姑苏区',
        '4A',
        '历史街区',
        '水巷老街与苏式生活',
        'pingjiang road,平江路',
        31.3133,
        120.6319
      ],
      [
        'spot-sz-shantang',
        '山塘街',
        '江苏',
        '苏州',
        '姑苏区',
        '4A',
        '历史街区',
        '古运河街景与夜游',
        'shantang street,七里山塘',
        31.3261,
        120.5988
      ],
      [
        'spot-sz-museum',
        '苏州博物馆',
        '江苏',
        '苏州',
        '姑苏区',
        '城市核心',
        '博物馆',
        '贝聿铭建筑与江南文物',
        'suzhou museum,苏博',
        31.3223,
        120.6272
      ],
      [
        'spot-xa-datang',
        '大唐不夜城',
        '陕西',
        '西安',
        '雁塔区',
        '城市核心',
        '文化街区',
        '唐风夜游与演艺街区',
        'datang everbright city,大唐不夜城',
        34.2118,
        108.9631
      ],
      [
        'spot-xa-shaanxi-museum',
        '陕西历史博物馆',
        '陕西',
        '西安',
        '雁塔区',
        '4A',
        '博物馆',
        '周秦汉唐文物精华',
        'shaanxi history museum,陕历博',
        34.2292,
        108.9570
      ],
      [
        'spot-xa-bell-tower',
        '西安钟鼓楼',
        '陕西',
        '西安',
        '碑林区',
        '城市核心',
        '历史地标',
        '古城中轴与夜景地标',
        'bell tower xian,鼓楼,钟楼',
        34.2610,
        108.9423
      ],
      [
        'spot-nj-presidential',
        '南京总统府',
        '江苏',
        '南京',
        '玄武区',
        '4A',
        '历史文化',
        '近代史建筑与园林院落',
        'presidential palace nanjing,总统府',
        32.0444,
        118.7924
      ],
      [
        'spot-nj-xuanwu',
        '玄武湖',
        '江苏',
        '南京',
        '玄武区',
        '4A',
        '城市公园',
        '城墙湖景与环湖散步',
        'xuanwu lake,玄武湖公园',
        32.0712,
        118.7932
      ],
      [
        'spot-nj-yuejiang',
        '阅江楼',
        '江苏',
        '南京',
        '鼓楼区',
        '4A',
        '历史地标',
        '登楼看江与明城故事',
        'yuejiang tower,阅江楼景区',
        32.0884,
        118.7466
      ],
      [
        'spot-cs-hunan-museum',
        '湖南博物院',
        '湖南',
        '长沙',
        '开福区',
        '4A',
        '博物馆',
        '马王堆文物与湖湘历史',
        'hunan museum,湖南省博物馆',
        28.2135,
        112.9836
      ],
      [
        'spot-cs-taiping',
        '太平街',
        '湖南',
        '长沙',
        '天心区',
        '城市核心',
        '历史街区',
        '老街小吃与长沙夜游',
        'taiping street changsha,太平老街',
        28.1911,
        112.9735
      ],
      [
        'spot-cs-orange',
        '橘子洲',
        '湖南',
        '长沙',
        '岳麓区',
        '5A',
        '洲岛公园',
        '湘江洲岛与城市天际线',
        'orange isle,橘子洲头',
        28.1960,
        112.9552
      ],
      [
        'spot-zz-henan-museum',
        '河南博物院',
        '河南',
        '郑州',
        '金水区',
        '4A',
        '博物馆',
        '中原文明与青铜文物',
        'henan museum,河南博物院',
        34.7928,
        113.6777
      ],
      [
        'spot-zz-erqi',
        '二七纪念塔',
        '河南',
        '郑州',
        '二七区',
        '城市核心',
        '城市地标',
        '郑州老城商业地标',
        'erqi memorial tower,二七塔',
        34.7511,
        113.6655
      ],
      [
        'spot-zz-yellow-river',
        '黄河风景名胜区',
        '河南',
        '郑州',
        '惠济区',
        '4A',
        '自然人文',
        '黄河岸线与炎黄文化',
        'yellow river scenic area zhengzhou,郑州黄河',
        34.9541,
        113.6218
      ],
      [
        'spot-tj-wudadao',
        '五大道',
        '天津',
        '天津',
        '和平区',
        '4A',
        '历史街区',
        '近代洋楼与街区漫步',
        'five great avenues,五大道文化旅游区',
        39.1124,
        117.2026
      ],
      [
        'spot-tj-italian',
        '意式风情区',
        '天津',
        '天津',
        '河北区',
        '4A',
        '历史街区',
        '欧式街景与海河夜游',
        'italian style town tianjin,意风区',
        39.1375,
        117.1992
      ],
      [
        'spot-tj-ancient-culture',
        '古文化街',
        '天津',
        '天津',
        '南开区',
        '城市核心',
        '民俗街区',
        '津门民俗与传统商铺',
        'ancient culture street tianjin,古文化街',
        39.1427,
        117.1886
      ],
      [
        'spot-hf-baogong',
        '包公园',
        '安徽',
        '合肥',
        '包河区',
        '4A',
        '历史公园',
        '包公文化与环城水景',
        'bao park,包公园景区',
        31.8625,
        117.2994
      ],
      [
        'spot-hf-anhui-museum',
        '安徽博物院',
        '安徽',
        '合肥',
        '蜀山区',
        '4A',
        '博物馆',
        '徽文化文物与省级展览',
        'anhui museum,安徽博物院新馆',
        31.8216,
        117.2210
      ],
      [
        'spot-hf-xiaoyaojin',
        '逍遥津公园',
        '安徽',
        '合肥',
        '庐阳区',
        '城市核心',
        '城市公园',
        '三国故事与城市公园',
        'xiaoyaojin park,逍遥津',
        31.8728,
        117.2929
      ],
      [
        'spot-qd-badaguan',
        '八大关',
        '山东',
        '青岛',
        '市南区',
        '4A',
        '历史街区',
        '海滨别墅与花石楼街景',
        'badaguan,八大关风景区',
        36.0518,
        120.3542
      ],
      [
        'spot-qd-zhanqiao',
        '栈桥',
        '山东',
        '青岛',
        '市南区',
        '4A',
        '海滨地标',
        '海湾栈桥与老城风景',
        'zhanqiao pier,青岛栈桥',
        36.0610,
        120.3202
      ],
      [
        'spot-qd-beer',
        '青岛啤酒博物馆',
        '山东',
        '青岛',
        '市北区',
        '4A',
        '博物馆',
        '啤酒工业史与城市味道',
        'tsingtao beer museum,青岛啤酒博物馆',
        36.0839,
        120.3580
      ],
      [
        'spot-dg-keyuan',
        '可园博物馆',
        '广东',
        '东莞',
        '莞城区',
        '4A',
        '岭南园林',
        '岭南园林与莞邑文化',
        'keyuan dongguan,可园',
        23.0440,
        113.7442
      ],
      [
        'spot-dg-songshan',
        '松山湖',
        '广东',
        '东莞',
        '松山湖',
        '4A',
        '城市湖区',
        '湖岸骑行与科技园景',
        'songshan lake dongguan,松山湖景区',
        22.9146,
        113.8891
      ],
      [
        'spot-dg-opium-war',
        '鸦片战争博物馆',
        '广东',
        '东莞',
        '虎门镇',
        '4A',
        '博物馆',
        '近代史展陈与虎门炮台',
        'opium war museum,虎门炮台',
        22.8215,
        113.6730
      ],
      [
        'spot-nb-tianyi',
        '天一阁',
        '浙江',
        '宁波',
        '海曙区',
        '城市核心',
        '藏书楼',
        '古代藏书楼与江南院落',
        'tianyi pavilion,天一阁博物院',
        29.8731,
        121.5407
      ],
      [
        'spot-nb-old-bund',
        '宁波老外滩',
        '浙江',
        '宁波',
        '江北区',
        '城市核心',
        '历史街区',
        '江岸建筑与夜生活街区',
        'ningbo old bund,老外滩',
        29.8805,
        121.5598
      ],
      [
        'spot-nb-nantang',
        '南塘老街',
        '浙江',
        '宁波',
        '海曙区',
        '城市核心',
        '历史街区',
        '甬城小吃与老街商铺',
        'nantang old street,南塘老街',
        29.8524,
        121.5425
      ],
      [
        'spot-fs-ancestral',
        '佛山祖庙',
        '广东',
        '佛山',
        '禅城区',
        '4A',
        '历史文化',
        '岭南建筑与醒狮武术',
        'foshan ancestral temple,祖庙',
        23.0300,
        113.1120
      ],
      [
        'spot-fs-nanfeng',
        '南风古灶',
        '广东',
        '佛山',
        '禅城区',
        '4A',
        '陶艺文化',
        '陶瓷古窑与手作体验',
        'nanfeng ancient kiln,南风古灶',
        23.0127,
        113.0875
      ],
      [
        'spot-fs-lingnan',
        '岭南天地',
        '广东',
        '佛山',
        '禅城区',
        '城市核心',
        '历史街区',
        '岭南骑楼与城市商业',
        'lingnan tiandi,岭南天地',
        23.0270,
        113.1170
      ],
    ];

    for (final spot in spots) {
      _insertScenicSpot(
        spot[0] as String,
        spot[1] as String,
        spot[2] as String,
        spot[3] as String,
        spot[4] as String,
        spot[5] as String,
        spot[6] as String,
        spot[7] as String,
        (spot[8] as String).split(','),
        spot[9] as double,
        spot[10] as double,
      );
    }
  }

  void _insertDestination(
    String id,
    String name,
    String city,
    String theme,
    String summary,
    String duration,
    List<String> tags,
    bool priority,
    double lat,
    double lng,
  ) {
    _db.execute(
      'INSERT INTO destinations VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        id,
        name,
        city,
        theme,
        summary,
        duration,
        jsonEncode(tags),
        priority ? 1 : 0,
        lat,
        lng
      ],
    );
  }

  void _insertScenicSpot(
    String id,
    String name,
    String province,
    String city,
    String district,
    String level,
    String kind,
    String intro,
    List<String> aliases,
    double lat,
    double lng,
  ) {
    _db.execute(
      '''
      INSERT OR REPLACE INTO scenic_spots
        (id, name, province, city, district, level, kind, intro,
         aliases_json, image_url, lat, lng)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        id,
        name,
        province,
        city,
        district,
        level,
        kind,
        _shortIntro(intro),
        jsonEncode(aliases),
        _imageUrl(name, city),
        lat,
        lng,
      ],
    );
  }

  void _ensureColumn(String table, String column, String definition) {
    final columns = _db.select('PRAGMA table_info($table)');
    final exists = columns.any((row) => row['name'] == column);
    if (!exists) {
      _db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  void _recordSchemaMigration() {
    final checksum = _schemaChecksum();
    final existing = _db.select(
      'SELECT checksum FROM schema_migrations WHERE version = ?',
      [_schemaVersion],
    );
    if (existing.isNotEmpty && existing.first['checksum'] != checksum) {
      throw StateError(
        'Schema migration checksum mismatch for version $_schemaVersion',
      );
    }
    _db.execute(
      '''
      INSERT OR IGNORE INTO schema_migrations
        (version, name, checksum, applied_at)
      VALUES (?, ?, ?, ?)
      ''',
      [
        _schemaVersion,
        _schemaMigrationName,
        checksum,
        DateTime.now().toUtc().toIso8601String(),
      ],
    );
    _db.execute('PRAGMA user_version = $_schemaVersion');
  }

  Map<String, Object?> _dayById(
    List<Map<String, Object?>> days,
    String dayId,
  ) {
    for (final day in days) {
      if (day['id'] == dayId) {
        return day;
      }
    }
    throw const NotFoundException('Itinerary day not found');
  }

  Map<String, Object?> _itemById(
    List<Map<String, Object?>> items,
    String itemId,
  ) {
    for (final item in items) {
      if (item['id'] == itemId) {
        return item;
      }
    }
    throw const NotFoundException('Itinerary item not found');
  }
}

String _shortIntro(String value) {
  final text = value.trim();
  if (text.length <= 18) {
    return text;
  }
  return text.substring(0, 18);
}

String _amapField(Object? value) {
  if (value == null) {
    return '';
  }
  if (value is List) {
    return value.whereType<Object>().map((item) => item.toString()).join(' ');
  }
  return value.toString();
}

Map<Object?, Object?>? _firstAmapPlace(Object? value) {
  if (value is! List || value.isEmpty) {
    return null;
  }
  for (final item in value) {
    if (item is Map) {
      return item.map((key, value) => MapEntry(key, value));
    }
  }
  return null;
}

Map<String, Object?> _reverseGeocodeFallback({
  required double lat,
  required double lng,
  String? fallbackName,
}) {
  final name = (fallbackName ?? '').trim();
  return {
    'name': name.isEmpty ? 'Selected map point' : name,
    'address': 'Lat ${lat.toStringAsFixed(6)}, Lng ${lng.toStringAsFixed(6)}',
    'city': '',
    'source': 'coordinate',
    'lat': lat,
    'lng': lng,
  };
}

String _firstNonEmpty(Iterable<String> values) {
  for (final value in values) {
    final text = value.trim();
    if (text.isNotEmpty) {
      return text;
    }
  }
  return '';
}

String? _amapPhotoUrl(Map<Object?, Object?> poi) {
  final photos = poi['photos'];
  if (photos is! List || photos.isEmpty) {
    return null;
  }
  final first = photos.first;
  if (first is! Map) {
    return null;
  }
  final url = first['url']?.toString().trim();
  if (url == null || url.isEmpty) {
    return null;
  }
  return url;
}

String _imageUrl(String name, String city) {
  final seed = Uri.encodeComponent('$city-$name-travel');
  return 'https://picsum.photos/seed/$seed/640/360';
}

List<Map<String, Object?>> _days(Map<String, Object?> trip) {
  return (trip['days'] as List).cast<Map<String, Object?>>();
}

List<Map<String, Object?>> _items(Map<String, Object?> day) {
  return (day['items'] as List).cast<Map<String, Object?>>();
}

Map<String, Object?> _row(Row row) {
  return {
    for (final column in row.keys) column: row[column],
  };
}

Future<Map<String, Object?>> _body(HttpRequest request) async {
  if (request.headers.contentLength > _maxBodyBytes) {
    throw const FormatException('Request body is too large.');
  }
  final bytes = <int>[];
  var totalBytes = 0;
  await for (final chunk in request) {
    totalBytes += chunk.length;
    if (totalBytes > _maxBodyBytes) {
      throw const FormatException('Request body is too large.');
    }
    bytes.addAll(chunk);
  }
  final raw = utf8.decode(bytes);
  if (raw.trim().isEmpty) {
    return {};
  }
  if (request.headers.contentType?.mimeType != ContentType.json.mimeType) {
    throw const FormatException('Content-Type must be application/json.');
  }
  final decoded = jsonDecode(raw);
  if (decoded is Map) {
    return decoded.map<String, Object?>(
      (key, value) => MapEntry(key.toString(), value),
    );
  }
  throw const FormatException('JSON request body must be an object.');
}

Future<void> _json(
  HttpRequest request,
  Object body, {
  int status = HttpStatus.ok,
}) async {
  request.response.statusCode = status;
  request.response.headers.contentType = ContentType.json;
  request.response.write(jsonEncode(body));
  await request.response.close();
}

Future<void> _notFound(HttpRequest request, String message) {
  return _json(request, {'error': message}, status: HttpStatus.notFound);
}

Future<void> _badRequest(HttpRequest request, String message) {
  return _json(request, {'error': message}, status: HttpStatus.badRequest);
}

Future<void> _tooManyRequests(
  HttpRequest request,
  RateLimitDecision decision,
) {
  request.response.headers
    ..set('Retry-After', decision.retryAfterSeconds.toString())
    ..set('X-RateLimit-Limit', decision.limit.toString())
    ..set('X-RateLimit-Remaining', decision.remaining.toString())
    ..set('X-RateLimit-Reset', decision.resetAt.toIso8601String());
  return _json(
    request,
    {
      'error': 'Too many requests',
      'rule': decision.ruleId,
      'limit': decision.limit,
      'retryAfterSeconds': decision.retryAfterSeconds,
    },
    status: HttpStatus.tooManyRequests,
  );
}

void _applyCors(HttpRequest request) {
  final response = request.response;
  final origin = request.headers.value('origin');
  if (origin != null && _isAllowedOrigin(origin)) {
    response.headers
      ..set('Access-Control-Allow-Origin', origin)
      ..set('Vary', 'Origin');
  }
  response.headers
    ..set('Access-Control-Allow-Methods', 'GET,POST,PATCH,DELETE,OPTIONS')
    ..set(
      'Access-Control-Allow-Headers',
      'Content-Type,Authorization',
    )
    ..set('Access-Control-Max-Age', '600');
}

bool _isAllowedOrigin(String origin) {
  final configured = (Platform.environment['WAYFARE_ALLOWED_ORIGINS'] ?? '')
      .split(',')
      .map((entry) => entry.trim())
      .where((entry) => entry.isNotEmpty)
      .toSet();
  if (configured.isNotEmpty) {
    return configured.contains(origin);
  }
  final uri = Uri.tryParse(origin);
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
    return false;
  }
  return uri.host == 'localhost' ||
      uri.host == '127.0.0.1' ||
      uri.host == '::1';
}

bool _matches(List<String> path, List<String> target) {
  if (path.length != target.length) {
    return false;
  }
  for (var index = 0; index < target.length; index++) {
    if (path[index] != target[index]) {
      return false;
    }
  }
  return true;
}

String _routeTemplate(String method, List<String> path) {
  if (path.isEmpty) {
    return '/';
  }
  if (_matches(path, ['health'])) {
    return '/health';
  }
  if (_matches(path, ['ops', 'metrics'])) {
    return '/ops/metrics';
  }
  if (_matches(path, ['ops', 'schema'])) {
    return '/ops/schema';
  }
  if (path.first == 'auth') {
    return '/auth/${path.length > 1 ? path[1] : ':action'}';
  }
  if (path.first == 'destinations') {
    return path.length == 1 ? '/destinations' : '/destinations/:id';
  }
  if (_matches(path, ['recommendations'])) {
    return '/recommendations';
  }
  if (_matches(path, ['search'])) {
    return '/search';
  }
  if (_matches(path, ['reverse-geocode'])) {
    return '/reverse-geocode';
  }
  if (path.length >= 2 && path.first == 'map' && path[1] == 'places') {
    return '/map/places';
  }
  if (path.first == 'itineraries') {
    if (path.length == 1) {
      return '/itineraries';
    }
    if (path.length == 2) {
      return '/itineraries/:id';
    }
    if (path.length == 3 && path[2] == 'days') {
      return '/itineraries/:id/days';
    }
    if (path.length == 5 && path[2] == 'days' && path[4] == 'items') {
      return '/itineraries/:id/days/:dayId/items';
    }
    if (path.length == 6 && path[2] == 'days' && path[4] == 'items') {
      return path[5] == 'reorder'
          ? '/itineraries/:id/days/:dayId/items/reorder'
          : '/itineraries/:id/days/:dayId/items/:itemId';
    }
    return '/itineraries/*';
  }
  if (path.first == 'saved') {
    return path.length == 1 ? '/saved' : '/saved/:id';
  }
  if (_matches(path, ['feedback'])) {
    return '/feedback';
  }
  return '/${path.first}/*';
}

String _id(String prefix) {
  return '$prefix-${_randomUrlSafe(12)}';
}

const _maxBodyBytes = 64 * 1024;
const _localDevelopmentSecret = 'wayfare-local-development-secret-change-me';
const _schemaVersion = 2;
const _schemaMigrationName = 'user_password_20260613';
const _schemaSignature = '''
schema_migrations(version,name,checksum,applied_at);
users(id,identifier,display_name,password_hash,password_salt,created_at,last_login_at);
sessions(token_hash,user_id,created_at,expires_at,revoked_at);
destinations(id,name,city,theme,summary,duration,tags_json,priority,lat,lng);
map_places(id,name,category,description,rating,lat,lng);
scenic_spots(id,name,province,city,district,level,kind,intro,aliases_json,image_url,lat,lng);
itineraries(id,user_id,title,destination,start_date,end_date,status,days_json,created_at,updated_at);
saved_trips(id,user_id,type,ref_id,label,folder,created_at);
feedback(id,user_id,category,description,status,created_at);
''';

String _schemaChecksum() {
  return sha256.convert(utf8.encode(_schemaSignature)).toString();
}

String _generateSalt() => _randomUrlSafe(16);

String _hashPassword(String password, String salt) {
  return sha256.convert(utf8.encode('$salt::$password')).toString();
}

String? _passwordValidationError(String password) {
  if (password.isEmpty) {
    return 'Password is required.';
  }
  if (password.length < 6) {
    return 'Password must be at least 6 characters.';
  }
  if (password.length > 128) {
    return 'Password must be at most 128 characters.';
  }
  return null;
}

int _environmentInt(
  Map<String, String> environment,
  String name, {
  required int fallback,
  required int min,
  required int max,
}) {
  final parsed = int.tryParse(environment[name]?.trim() ?? '');
  if (parsed == null) {
    return fallback;
  }
  return math.min(max, math.max(min, parsed));
}

bool _environmentFlagEnabled(Map<String, String> environment, String name) {
  final value = environment[name]?.trim().toLowerCase();
  return value == '1' || value == 'true' || value == 'yes' || value == 'on';
}

bool _environmentFlagDisabled(Map<String, String> environment, String name) {
  final value = environment[name]?.trim().toLowerCase();
  return value == '0' || value == 'false' || value == 'no' || value == 'off';
}

String _randomUrlSafe(int byteCount) {
  final bytes = List<int>.generate(
    byteCount,
    (_) => _secureRandom.nextInt(256),
  );
  return _base64Url(bytes);
}

String _base64Url(List<int> bytes) {
  return base64Url.encode(bytes).replaceAll('=', '');
}

String _databaseLabel(String path) {
  return File(path).uri.pathSegments.isEmpty
      ? 'wayfare.sqlite'
      : File(path).uri.pathSegments.last;
}

String _authMode() {
  return _authSecretIsConfigured() ? 'configured' : 'development';
}

bool _authSecretIsConfigured() {
  return (Platform.environment['WAYFARE_AUTH_SECRET'] ?? '').trim().isNotEmpty;
}

String _authSecret() {
  final configured = Platform.environment['WAYFARE_AUTH_SECRET']?.trim();
  if (configured != null && configured.isNotEmpty) {
    return configured;
  }
  return _localDevelopmentSecret;
}

void _requireOpsToken(HttpRequest request) {
  final configured = Platform.environment['WAYFARE_OPS_TOKEN']?.trim();
  if (configured == null || configured.isEmpty) {
    throw const UnauthorizedException('Ops metrics are not configured');
  }
  final header = request.headers.value(HttpHeaders.authorizationHeader) ?? '';
  const tokenPrefix = 'bearer ';
  if (!header.toLowerCase().startsWith(tokenPrefix)) {
    throw const UnauthorizedException('Ops bearer token is required');
  }
  final token = header.substring(tokenPrefix.length).trim();
  if (!_constantTimeEquals(token, configured)) {
    throw const UnauthorizedException('Ops bearer token is invalid');
  }
}

bool _constantTimeEquals(String left, String right) {
  final leftUnits = left.codeUnits;
  final rightUnits = right.codeUnits;
  var diff = leftUnits.length ^ rightUnits.length;
  final length = math.max(leftUnits.length, rightUnits.length);
  for (var index = 0; index < length; index++) {
    final leftCode = index < leftUnits.length ? leftUnits[index] : 0;
    final rightCode = index < rightUnits.length ? rightUnits[index] : 0;
    diff |= leftCode ^ rightCode;
  }
  return diff == 0;
}

Duration _sessionDuration() {
  final raw = Platform.environment['WAYFARE_SESSION_DAYS'];
  final parsed = int.tryParse(raw ?? '');
  final days = parsed == null ? 7 : parsed.clamp(1, 30);
  return Duration(days: days);
}

Map<String, Object?> _issueSession(SqliteStore store, String userId) {
  final expiresAt = DateTime.now().toUtc().add(_sessionDuration());
  final token = _randomUrlSafe(32);
  store.createSession(
    userId: userId,
    tokenHash: _sessionTokenHash(token),
    expiresAt: expiresAt,
  );
  return {
    'token': token,
    'expiresAt': expiresAt.toIso8601String(),
  };
}

AuthSession _requireSession(HttpRequest request, SqliteStore store) {
  final header = request.headers.value(HttpHeaders.authorizationHeader) ?? '';
  final tokenPrefix = 'bearer ';
  if (!header.toLowerCase().startsWith(tokenPrefix)) {
    throw const UnauthorizedException('Bearer token is required');
  }
  final token = header.substring(tokenPrefix.length).trim();
  if (token.isEmpty) {
    throw const UnauthorizedException('Bearer token is invalid');
  }
  final tokenHash = _sessionTokenHash(token);
  final stored = store.sessionByTokenHash(tokenHash);
  if (stored == null || stored['revoked_at'] != null) {
    throw const UnauthorizedException('Bearer token is invalid');
  }

  final userId = stored['user_id']?.toString() ?? '';
  final expiresAt = DateTime.tryParse(stored['expires_at']?.toString() ?? '');
  if (userId.isEmpty || expiresAt == null) {
    throw const UnauthorizedException('Bearer token is invalid');
  }
  if (!DateTime.now().toUtc().isBefore(expiresAt.toUtc())) {
    store.revokeSession(tokenHash);
    throw const UnauthorizedException('Bearer token has expired');
  }
  if (store.userById(userId) == null) {
    throw const UnauthorizedException('Bearer token user is invalid');
  }
  return AuthSession(
    tokenHash: tokenHash,
    userId: userId,
    expiresAt: expiresAt.toUtc(),
  );
}

String _sessionTokenHash(String token) {
  final hmac = Hmac(sha256, utf8.encode(_authSecret()));
  return _base64Url(hmac.convert(utf8.encode(token)).bytes);
}

String? _identifierValidationError(String? identifier) {
  final value = identifier?.trim() ?? '';
  if (value.isEmpty) {
    return 'identifier, phone, or email is required';
  }
  if (value.contains('@')) {
    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return emailPattern.hasMatch(value) ? null : 'email format is invalid';
  }
  final phonePattern = RegExp(r'^\+?[0-9][0-9 -]{5,20}$');
  return phonePattern.hasMatch(value) ? null : 'phone format is invalid';
}

int _queryLimit(String? raw) {
  if (raw == null || raw.isEmpty) {
    return 20;
  }
  final parsed = int.tryParse(raw);
  if (parsed == null) {
    throw const FormatException('limit must be an integer');
  }
  if (parsed < 1) {
    return 1;
  }
  if (parsed > 50) {
    return 50;
  }
  return parsed;
}

Map<String, double> _queryPoint(Map<String, String> query) {
  return {
    'lat': _coordinate(query['lat'], 'lat', min: -90, max: 90),
    'lng': _coordinate(query['lng'], 'lng', min: -180, max: 180),
  };
}

Map<String, Object?> _validateCreateItinerary(Map<String, Object?> body) {
  final days = body['days'];
  if (days != null && days is! List) {
    throw const FormatException('days must be an array.');
  }
  return {
    if (_optionalText(body, 'id', maxLength: 80) case final id?) 'id': id,
    'userId': _requiredText(body, 'userId', maxLength: 120),
    'title': _requiredText(body, 'title', maxLength: 120),
    'destination': _requiredText(body, 'destination', maxLength: 120),
    'startDate': _requiredDate(body, 'startDate'),
    'endDate': _requiredDate(body, 'endDate'),
    'status': _status(body['status']),
    'days': days == null ? <Map<String, Object?>>[] : _validateDays(days),
  };
}

Map<String, Object?> _validateUpdateItinerary(Map<String, Object?> body) {
  final update = <String, Object?>{};
  if (body.containsKey('title')) {
    update['title'] = _requiredText(body, 'title', maxLength: 120);
  }
  if (body.containsKey('destination')) {
    update['destination'] = _requiredText(body, 'destination', maxLength: 120);
  }
  if (body.containsKey('startDate')) {
    update['startDate'] = _requiredDate(body, 'startDate');
  }
  if (body.containsKey('endDate')) {
    update['endDate'] = _requiredDate(body, 'endDate');
  }
  if (body.containsKey('status')) {
    update['status'] = _status(body['status']);
  }
  if (update.isEmpty) {
    throw const FormatException('No supported itinerary fields were provided.');
  }
  return update;
}

Map<String, Object?> _validateAddDay(Map<String, Object?> body) {
  final dayIndex = _optionalPositiveInt(body, 'dayIndex', max: 366);
  return {
    if (dayIndex != null) 'dayIndex': dayIndex,
    'title': _requiredText(body, 'title', maxLength: 80),
    'date': _requiredDate(body, 'date'),
    'city': _requiredText(body, 'city', maxLength: 80),
    'reminder': _optionalText(body, 'reminder', maxLength: 500) ?? '',
  };
}

Map<String, Object?> _validateAddItem(Map<String, Object?> body) {
  final item = <String, Object?>{
    'time': _requiredText(body, 'time', maxLength: 40),
    'placeName': _requiredPlaceName(body),
    'activity': _requiredText(body, 'activity', maxLength: 120),
    'note': _optionalText(body, 'note', maxLength: 1000) ?? '',
    'status': _status(body['status']),
  };
  if (_optionalText(body, 'placeId', maxLength: 120) case final placeId?) {
    item['placeId'] = placeId;
  }
  if (_optionalPositiveInt(body, 'order', max: 1000) case final order?) {
    item['order'] = order;
  }
  item.addAll(_optionalPoint(body));
  return item;
}

Map<String, Object?> _validateUpdateItem(Map<String, Object?> body) {
  final item = <String, Object?>{};
  if (_optionalText(body, 'targetDayId', maxLength: 120)
      case final targetDayId?) {
    item['targetDayId'] = targetDayId;
  }
  if (body.containsKey('time')) {
    item['time'] = _requiredText(body, 'time', maxLength: 40);
  }
  if (body.containsKey('placeName') || body.containsKey('place')) {
    item['placeName'] = _requiredPlaceName(body);
  }
  if (body.containsKey('activity')) {
    item['activity'] = _requiredText(body, 'activity', maxLength: 120);
  }
  if (body.containsKey('note')) {
    item['note'] = _optionalText(body, 'note', maxLength: 1000) ?? '';
  }
  if (body.containsKey('status')) {
    item['status'] = _status(body['status']);
  }
  item.addAll(_optionalPoint(body));
  if (item.isEmpty) {
    throw const FormatException(
        'No supported itinerary item fields were provided.');
  }
  return item;
}

Map<String, Object?> _validateReorder(Map<String, Object?> body) {
  final raw = body['itemIds'];
  if (raw is! List) {
    throw const FormatException('itemIds is required.');
  }
  if (raw.isEmpty) {
    throw const FormatException('itemIds must not be empty.');
  }
  if (raw.length > 200) {
    throw const FormatException('itemIds must contain at most 200 entries.');
  }
  final ids = <String>[];
  final seen = <String>{};
  for (final value in raw) {
    final id = value?.toString().trim() ?? '';
    if (id.isEmpty) {
      throw const FormatException('itemIds entries must be non-empty strings.');
    }
    if (!seen.add(id)) {
      throw const FormatException('itemIds must not contain duplicates.');
    }
    ids.add(id);
  }
  return {'itemIds': ids};
}

Map<String, Object?> _validateCreateSavedItem(Map<String, Object?> body) {
  final type = _savedType(body['type']);
  final refId = _optionalText(body, 'refId', maxLength: 120) ??
      _optionalText(body, 'destination', maxLength: 120);
  if (refId == null) {
    throw const FormatException('refId is required.');
  }
  return {
    'userId': _requiredText(body, 'userId', maxLength: 120),
    'type': type,
    'refId': refId,
    'label': _optionalText(body, 'label', maxLength: 120) ?? refId,
    'folder': _optionalText(body, 'folder', maxLength: 80) ?? 'Weekend',
  };
}

List<Map<String, Object?>> _validateDays(Object raw) {
  if (raw is! List) {
    throw const FormatException('days must be an array.');
  }
  if (raw.length > 31) {
    throw const FormatException('days must contain at most 31 entries.');
  }
  return raw.map((entry) {
    if (entry is! Map) {
      throw const FormatException('days entries must be objects.');
    }
    final day = entry.map<String, Object?>(
      (key, value) => MapEntry(key.toString(), value),
    );
    final items = day['items'];
    if (items != null && items is! List) {
      throw const FormatException('day items must be arrays.');
    }
    return {
      if (_optionalText(day, 'id', maxLength: 120) case final id?) 'id': id,
      'dayIndex': _optionalPositiveInt(day, 'dayIndex', max: 366) ?? 1,
      'title': _requiredText(day, 'title', maxLength: 80),
      'date': _requiredDate(day, 'date'),
      'city': _requiredText(day, 'city', maxLength: 80),
      'reminder': _optionalText(day, 'reminder', maxLength: 500) ?? '',
      'items': items == null ? <Map<String, Object?>>[] : _validateItems(items),
    };
  }).toList();
}

List<Map<String, Object?>> _validateItems(Object raw) {
  if (raw is! List) {
    throw const FormatException('items must be an array.');
  }
  if (raw.length > 200) {
    throw const FormatException('items must contain at most 200 entries.');
  }
  return raw.map((entry) {
    if (entry is! Map) {
      throw const FormatException('items entries must be objects.');
    }
    final item = entry.map<String, Object?>(
      (key, value) => MapEntry(key.toString(), value),
    );
    return {
      if (_optionalText(item, 'id', maxLength: 120) case final id?) 'id': id,
      ..._validateAddItem(item),
    };
  }).toList();
}

String _requiredPlaceName(Map<String, Object?> body) {
  final value = _optionalText(body, 'placeName', maxLength: 120) ??
      _optionalText(body, 'place', maxLength: 120);
  if (value == null) {
    throw const FormatException('placeName is required.');
  }
  return value;
}

String _requiredText(
  Map<String, Object?> body,
  String field, {
  required int maxLength,
}) {
  final value = _optionalText(body, field, maxLength: maxLength);
  if (value == null) {
    throw FormatException('$field is required.');
  }
  return value;
}

String? _optionalText(
  Map<String, Object?> body,
  String field, {
  required int maxLength,
}) {
  if (!body.containsKey(field) || body[field] == null) {
    return null;
  }
  final value = body[field];
  if (value is! String) {
    throw FormatException('$field must be a string.');
  }
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  if (trimmed.length > maxLength) {
    throw FormatException('$field must be at most $maxLength characters.');
  }
  return trimmed;
}

String _requiredDate(Map<String, Object?> body, String field) {
  final value = _requiredText(body, field, maxLength: 10);
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) {
    throw FormatException('$field must use YYYY-MM-DD format.');
  }
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final parsed = DateTime.utc(year, month, day);
  if (parsed.year != year || parsed.month != month || parsed.day != day) {
    throw FormatException('$field must be a real calendar date.');
  }
  return value;
}

int? _optionalPositiveInt(
  Map<String, Object?> body,
  String field, {
  required int max,
}) {
  if (!body.containsKey(field) || body[field] == null) {
    return null;
  }
  final value = body[field];
  final parsed = value is int ? value : int.tryParse(value.toString());
  if (parsed == null || parsed < 1 || parsed > max) {
    throw FormatException('$field must be an integer from 1 to $max.');
  }
  return parsed;
}

Map<String, Object?> _optionalPoint(Map<String, Object?> body) {
  final hasLat = body.containsKey('lat') && body['lat'] != null;
  final hasLng = body.containsKey('lng') && body['lng'] != null;
  if (!hasLat && !hasLng) {
    return {};
  }
  if (hasLat != hasLng) {
    throw const FormatException('lat and lng must be provided together.');
  }
  final lat = _coordinate(body['lat'], 'lat', min: -90, max: 90);
  final lng = _coordinate(body['lng'], 'lng', min: -180, max: 180);
  return {'lat': lat, 'lng': lng};
}

double _coordinate(
  Object? value,
  String field, {
  required double min,
  required double max,
}) {
  final parsed = value is num ? value.toDouble() : double.tryParse('$value');
  if (parsed == null || parsed < min || parsed > max || !parsed.isFinite) {
    throw FormatException('$field must be a coordinate from $min to $max.');
  }
  return parsed;
}

String _status(Object? value) {
  final status = value?.toString().trim() ?? 'draft';
  const allowed = {'draft', 'saved', 'archived'};
  if (!allowed.contains(status)) {
    throw const FormatException('status must be draft, saved, or archived.');
  }
  return status;
}

String _savedType(Object? value) {
  final type = value?.toString().trim() ?? 'destination';
  const allowed = {'destination', 'itinerary', 'place'};
  if (!allowed.contains(type)) {
    throw const FormatException(
        'type must be destination, itinerary, or place.');
  }
  return type;
}

String _displayName(String identifier) {
  if (identifier.contains('@')) {
    return identifier.split('@').first;
  }
  if (identifier.length >= 4) {
    return 'Traveler ${identifier.substring(identifier.length - 4)}';
  }
  return 'Traveler';
}
