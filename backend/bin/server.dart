import 'dart:convert';
import 'dart:io';

void main(List<String> args) async {
  final port = int.tryParse(
        Platform.environment['PORT'] ?? (args.isEmpty ? '' : args.first),
      ) ??
      8080;
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  stdout
      .writeln('Wayfare backend scaffold listening on http://localhost:$port');

  await for (final request in server) {
    await _handle(request);
  }
}

final _store = _MemoryStore();

Future<void> _handle(HttpRequest request) async {
  _applyCors(request.response);
  if (request.method == 'OPTIONS') {
    request.response.statusCode = HttpStatus.noContent;
    await request.response.close();
    return;
  }

  try {
    final path = request.uri.pathSegments;
    final method = request.method;

    if (method == 'GET' && path.isEmpty) {
      return _json(request, {
        'name': 'Wayfare backend scaffold',
        'version': '0.1.0',
        'docs': '/health, /destinations, /itineraries, /saved',
      });
    }

    if (method == 'GET' && _matches(path, ['health'])) {
      return _json(request, {
        'status': 'ok',
        'storage': 'in-memory',
        'backendReadyFor': [
          'auth',
          'destinations',
          'recommendations',
          'mapPlaces',
          'itineraries',
          'savedTrips',
          'feedback',
        ],
      });
    }

    if (method == 'POST' && _matches(path, ['auth', 'send-code'])) {
      final body = await _body(request);
      return _json(request, {
        'requestId': _id('code'),
        'phone': body['phone'],
        'message': 'Verification code would be sent by SMS provider.',
      });
    }

    if (method == 'POST' && _matches(path, ['auth', 'login'])) {
      final body = await _body(request);
      final phone = (body['phone'] ?? 'guest').toString();
      return _json(request, {
        'token': 'dev-token-$phone',
        'user': _store.user..['phone'] = phone,
      });
    }

    if (method == 'GET' && _matches(path, ['me'])) {
      return _json(request, {'user': _store.user});
    }

    if (method == 'GET' && _matches(path, ['destinations'])) {
      return _json(request, {'items': _store.destinations});
    }

    if (method == 'GET' && path.length == 2 && path.first == 'destinations') {
      final item = _store.destinations.firstWhere(
        (destination) => destination['id'] == path[1],
        orElse: () => {},
      );
      if (item.isEmpty) {
        return _notFound(request, 'Destination not found');
      }
      return _json(request, {'item': item});
    }

    if (method == 'GET' && _matches(path, ['recommendations'])) {
      final items = _store.destinations
          .where((destination) => destination['priority'] == true)
          .toList();
      return _json(request, {'items': items, 'strategy': 'rule-based-dev'});
    }

    if (method == 'GET' && _matches(path, ['map', 'places'])) {
      return _json(request, {'items': _store.mapPlaces});
    }

    if (method == 'GET' && _matches(path, ['itineraries'])) {
      return _json(request, {'items': _store.itineraries});
    }

    if (method == 'POST' && _matches(path, ['itineraries'])) {
      final body = await _body(request);
      final item = {
        'id': _id('trip'),
        'userId': _store.user['id'],
        'title': body['title'] ?? 'Untitled trip',
        'destination': body['destination'] ?? 'TBD',
        'startDate': body['startDate'] ?? 'TBD',
        'endDate': body['endDate'] ?? 'TBD',
        'status': 'draft',
        'days': <Map<String, Object?>>[],
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };
      _store.itineraries.add(item);
      return _json(request, {'item': item}, status: HttpStatus.created);
    }

    if (path.length >= 2 && path.first == 'itineraries') {
      return _handleItinerary(request, path);
    }

    if (method == 'GET' && _matches(path, ['saved'])) {
      return _json(request, {'items': _store.savedTrips});
    }

    if (method == 'POST' && _matches(path, ['saved'])) {
      final body = await _body(request);
      final item = {
        'id': _id('saved'),
        'userId': _store.user['id'],
        'type': body['type'] ?? 'destination',
        'refId': body['refId'] ?? body['destination'] ?? 'unknown',
        'folder': body['folder'] ?? 'Weekend',
        'createdAt': DateTime.now().toIso8601String(),
      };
      _store.savedTrips.add(item);
      return _json(request, {'item': item}, status: HttpStatus.created);
    }

    if (method == 'DELETE' && path.length == 2 && path.first == 'saved') {
      final before = _store.savedTrips.length;
      _store.savedTrips.removeWhere((item) => item['id'] == path[1]);
      if (_store.savedTrips.length == before) {
        return _notFound(request, 'Saved item not found');
      }
      return _json(request, {'deleted': path[1]});
    }

    if (method == 'POST' && _matches(path, ['feedback'])) {
      final body = await _body(request);
      final item = {
        'id': _id('feedback'),
        'userId': _store.user['id'],
        'category': body['category'] ?? 'general',
        'description': body['description'] ?? '',
        'status': 'open',
        'createdAt': DateTime.now().toIso8601String(),
      };
      _store.feedback.add(item);
      return _json(request, {'item': item}, status: HttpStatus.created);
    }

    return _notFound(request, 'Route not found');
  } catch (error, stackTrace) {
    stderr.writeln(error);
    stderr.writeln(stackTrace);
    return _json(
      request,
      {'error': 'Internal server error', 'detail': error.toString()},
      status: HttpStatus.internalServerError,
    );
  }
}

Future<void> _handleItinerary(HttpRequest request, List<String> path) async {
  final trip = _store.itineraries.firstWhere(
    (item) => item['id'] == path[1],
    orElse: () => {},
  );
  if (trip.isEmpty) {
    return _notFound(request, 'Itinerary not found');
  }

  if (request.method == 'GET' && path.length == 2) {
    return _json(request, {'item': trip});
  }

  if (request.method == 'PATCH' && path.length == 2) {
    final body = await _body(request);
    for (final entry in body.entries) {
      if (entry.key != 'id' && entry.key != 'days') {
        trip[entry.key] = entry.value;
      }
    }
    trip['updatedAt'] = DateTime.now().toIso8601String();
    return _json(request, {'item': trip});
  }

  if (request.method == 'DELETE' && path.length == 2) {
    _store.itineraries.remove(trip);
    return _json(request, {'deleted': path[1]});
  }

  if (request.method == 'POST' && path.length == 3 && path[2] == 'days') {
    final body = await _body(request);
    final days = _days(trip);
    final day = {
      'id': _id('day'),
      'dayIndex': body['dayIndex'] ?? days.length + 1,
      'title': body['title'] ?? 'Day ${days.length + 1}',
      'date': body['date'] ?? 'TBD',
      'city': body['city'] ?? 'TBD',
      'reminder': body['reminder'] ?? '',
      'items': <Map<String, Object?>>[],
    };
    days.add(day);
    trip['updatedAt'] = DateTime.now().toIso8601String();
    return _json(request, {'item': day}, status: HttpStatus.created);
  }

  if (path.length >= 5 && path[2] == 'days') {
    final days = _days(trip);
    final day = days.firstWhere(
      (item) => item['id'] == path[3],
      orElse: () => {},
    );
    if (day.isEmpty) {
      return _notFound(request, 'Itinerary day not found');
    }

    if (request.method == 'POST' && path.length == 5 && path[4] == 'items') {
      final body = await _body(request);
      final items = _items(day);
      final item = {
        'id': _id('item'),
        'time': body['time'] ?? 'Flexible',
        'placeId': body['placeId'],
        'placeName': body['placeName'] ?? body['place'] ?? 'TBD',
        'activity': body['activity'] ?? 'Plan visit',
        'note': body['note'] ?? '',
        'order': body['order'] ?? items.length,
        'status': 'draft',
      };
      items.add(item);
      trip['updatedAt'] = DateTime.now().toIso8601String();
      return _json(request, {'item': item}, status: HttpStatus.created);
    }

    if (path.length == 6 && path[4] == 'items') {
      final items = _items(day);
      final item = items.firstWhere(
        (entry) => entry['id'] == path[5],
        orElse: () => {},
      );
      if (item.isEmpty) {
        return _notFound(request, 'Itinerary item not found');
      }

      if (request.method == 'PATCH') {
        final body = await _body(request);
        item.addAll(body);
        item['status'] = body['status'] ?? 'draft';
        trip['updatedAt'] = DateTime.now().toIso8601String();
        return _json(request, {'item': item});
      }

      if (request.method == 'DELETE') {
        items.remove(item);
        trip['updatedAt'] = DateTime.now().toIso8601String();
        return _json(request, {'deleted': path[5]});
      }
    }
  }

  return _notFound(request, 'Itinerary route not found');
}

List<Map<String, Object?>> _days(Map<String, Object?> trip) {
  return (trip['days'] as List).cast<Map<String, Object?>>();
}

List<Map<String, Object?>> _items(Map<String, Object?> day) {
  return (day['items'] as List).cast<Map<String, Object?>>();
}

Future<Map<String, Object?>> _body(HttpRequest request) async {
  final raw = await utf8.decoder.bind(request).join();
  if (raw.trim().isEmpty) {
    return {};
  }
  final decoded = jsonDecode(raw);
  if (decoded is Map<String, Object?>) {
    return decoded;
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

void _applyCors(HttpResponse response) {
  response.headers
    ..set('Access-Control-Allow-Origin', '*')
    ..set('Access-Control-Allow-Methods', 'GET,POST,PATCH,DELETE,OPTIONS')
    ..set('Access-Control-Allow-Headers', 'Content-Type,Authorization');
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

String _id(String prefix) {
  return '$prefix-${DateTime.now().microsecondsSinceEpoch}';
}

class _MemoryStore {
  final user = <String, Object?>{
    'id': 'user-dev-1',
    'phone': null,
    'displayName': 'Guest traveler',
    'avatarUrl': null,
    'preferences': ['Nature', 'Foodie'],
    'budget': 'Medium',
    'travelStyle': ['Short Trip'],
    'createdAt': '2026-05-18T00:00:00.000',
  };

  final destinations = <Map<String, Object?>>[
    {
      'id': 'dest-hangzhou',
      'name': 'Hangzhou Lakeside',
      'city': 'Hangzhou',
      'theme': 'Nature + Culture',
      'summary': 'West Lake, tea fields, evening streets, and easy walks.',
      'duration': '2 days',
      'tags': ['Nature', 'Culture', 'Weekend'],
      'priority': true,
      'lat': 30.2431,
      'lng': 120.1508,
    },
    {
      'id': 'dest-shanghai',
      'name': 'Shanghai City Break',
      'city': 'Shanghai',
      'theme': 'City Break',
      'summary': 'Museums, skyline viewpoints, food streets, and metro routes.',
      'duration': '1-2 days',
      'tags': ['City Break', 'Food', 'Culture'],
      'priority': true,
      'lat': 31.2304,
      'lng': 121.4737,
    },
  ];

  final mapPlaces = <Map<String, Object?>>[
    {
      'id': 'place-west-lake',
      'name': 'West Lake',
      'category': 'Attraction',
      'lat': 30.2431,
      'lng': 120.1508,
      'rating': 4.8,
    },
    {
      'id': 'place-hefang',
      'name': 'Hefang Street',
      'category': 'Food',
      'lat': 30.2416,
      'lng': 120.1784,
      'rating': 4.5,
    },
    {
      'id': 'place-longjing',
      'name': 'Longjing Village',
      'category': 'Nature',
      'lat': 30.2207,
      'lng': 120.0912,
      'rating': 4.7,
    },
  ];

  final itineraries = <Map<String, Object?>>[
    {
      'id': 'trip-dev-hangzhou',
      'userId': 'user-dev-1',
      'title': 'Hangzhou Weekend',
      'destination': 'Hangzhou',
      'startDate': '2026-05-24',
      'endDate': '2026-05-25',
      'status': 'draft',
      'days': [
        {
          'id': 'day-dev-1',
          'dayIndex': 1,
          'title': 'Day 1',
          'date': '2026-05-24',
          'city': 'Hangzhou',
          'reminder': 'Light rain possible, keep outdoor stops flexible',
          'items': [
            {
              'id': 'item-dev-1',
              'time': '09:00',
              'placeName': 'West Lake',
              'activity': 'Walk the lakeside route',
              'note': 'Start near Broken Bridge.',
              'order': 0,
              'status': 'saved',
            },
          ],
        },
      ],
      'createdAt': '2026-05-18T00:00:00.000',
      'updatedAt': '2026-05-18T00:00:00.000',
    },
  ];

  final savedTrips = <Map<String, Object?>>[
    {
      'id': 'saved-hangzhou',
      'userId': 'user-dev-1',
      'type': 'itinerary',
      'refId': 'trip-dev-hangzhou',
      'folder': 'Weekend',
      'createdAt': '2026-05-18T00:00:00.000',
    },
  ];

  final feedback = <Map<String, Object?>>[];
}
