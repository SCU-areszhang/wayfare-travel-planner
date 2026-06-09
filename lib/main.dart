import 'dart:math' as math;
import 'dart:convert';

import 'package:amap_flutter_base/amap_flutter_base.dart' as amap_base;
import 'package:amap_flutter_map/amap_flutter_map.dart' as amap_map;
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' hide Path;
import 'package:shared_preferences/shared_preferences.dart';

import 'amap_canvas_stub.dart' if (dart.library.html) 'amap_canvas_web.dart';
import 'login_identifier_field_stub.dart'
    if (dart.library.html) 'login_identifier_field_web.dart';
import 'search_query_field_stub.dart'
    if (dart.library.html) 'search_query_field_web.dart';

const _amapAndroidKey = String.fromEnvironment('AMAP_ANDROID_KEY');
const _amapIosKey = String.fromEnvironment('AMAP_IOS_KEY');
const _amapJsKey = String.fromEnvironment('AMAP_JS_KEY');
const _amapJsSecurityCode = String.fromEnvironment('AMAP_JS_SECURITY_CODE');

int _localIdCounter = 0;

String _nextLocalId(String prefix) {
  _localIdCounter += 1;
  return '$prefix-$_localIdCounter';
}

void main() {
  runApp(WayfareApp());
}

enum AppTab { home, explore, itinerary, saved, profile }

class AppUser {
  const AppUser({
    required this.id,
    required this.identifier,
    required this.displayName,
    this.sessionToken,
    this.sessionExpiresAt,
  });

  final String id;
  final String identifier;
  final String displayName;
  final String? sessionToken;
  final DateTime? sessionExpiresAt;

  String get initials {
    final source = displayName.trim().isEmpty ? identifier : displayName;
    return source.characters.take(1).toString().toUpperCase();
  }
}

class LocalAuthRepository {
  static const _sessionIdKey = 'wayfare.session.user_id';
  static const _sessionIdentifierKey = 'wayfare.session.identifier';
  static const _sessionNameKey = 'wayfare.session.display_name';
  static const _sessionTokenKey = 'wayfare.session.token';
  static const _sessionExpiresAtKey = 'wayfare.session.expires_at';

  Future<AppUser?> currentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_sessionIdKey);
    final identifier = prefs.getString(_sessionIdentifierKey);
    final displayName = prefs.getString(_sessionNameKey);
    final token = prefs.getString(_sessionTokenKey);
    final expiresAt = DateTime.tryParse(
      prefs.getString(_sessionExpiresAtKey) ?? '',
    );
    if (id == null ||
        identifier == null ||
        displayName == null ||
        token == null ||
        expiresAt == null ||
        !DateTime.now().toUtc().isBefore(expiresAt.toUtc())) {
      return null;
    }
    return AppUser(
      id: id,
      identifier: identifier,
      displayName: displayName,
      sessionToken: token,
      sessionExpiresAt: expiresAt,
    );
  }

  Future<void> saveSession(AppUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await _saveSession(prefs, user);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionIdKey);
    await prefs.remove(_sessionIdentifierKey);
    await prefs.remove(_sessionNameKey);
    await prefs.remove(_sessionTokenKey);
    await prefs.remove(_sessionExpiresAtKey);
  }

  Future<void> _saveSession(SharedPreferences prefs, AppUser user) async {
    await prefs.setString(_sessionIdKey, user.id);
    await prefs.setString(_sessionIdentifierKey, user.identifier);
    await prefs.setString(_sessionNameKey, user.displayName);
    final token = user.sessionToken;
    final expiresAt = user.sessionExpiresAt;
    if (token != null && expiresAt != null) {
      await prefs.setString(_sessionTokenKey, token);
      await prefs.setString(
        _sessionExpiresAtKey,
        expiresAt.toUtc().toIso8601String(),
      );
    }
  }

  static String _displayNameFromIdentifier(String identifier) {
    if (identifier.contains('@')) {
      return identifier.split('@').first;
    }
    if (identifier.length >= 4) {
      return 'Traveler ${identifier.substring(identifier.length - 4)}';
    }
    return 'Traveler';
  }
}

enum ThemeSource {
  system('System Dynamic Color', Color(0xFF386A8B)),
  ocean('Ocean Blue', Color(0xFF0B6B8A)),
  forest('Forest Green', Color(0xFF2E6F40)),
  sunrise('Sunrise Orange', Color(0xFFB65D21)),
  neutral('Neutral Gray', Color(0xFF5F6368)),
  custom('Custom Accent Color', Color(0xFF386A8B));

  const ThemeSource(this.label, this.seed);

  final String label;
  final Color seed;
}

class Destination {
  const Destination({
    required this.id,
    required this.name,
    required this.theme,
    required this.duration,
    required this.reason,
    required this.summary,
    required this.tone,
    required this.priority,
    required this.point,
  });

  final String id;
  final String name;
  final String theme;
  final String duration;
  final String reason;
  final String summary;
  final Color tone;
  final bool priority;
  final LatLng point;
}

class ItineraryDay {
  ItineraryDay({
    String? id,
    required this.title,
    required this.date,
    required this.city,
    required this.reminder,
    required this.items,
  }) : id = id ?? _nextLocalId('day');

  final String id;
  String title;
  String date;
  String city;
  String reminder;
  final List<ItineraryItem> items;
}

class ItineraryItem {
  ItineraryItem({
    String? id,
    required this.time,
    required this.place,
    required this.activity,
    required this.note,
    required this.status,
    this.point,
  }) : id = id ?? _nextLocalId('item');

  final String id;
  String time;
  String place;
  String activity;
  String note;
  String status;
  LatLng? point;
}

class MapPlace {
  const MapPlace({
    required this.id,
    required this.name,
    required this.category,
    required this.distance,
    required this.description,
    required this.rating,
    required this.point,
    required this.icon,
  });

  final String id;
  final String name;
  final String category;
  final String distance;
  final String description;
  final String rating;
  final LatLng point;
  final IconData icon;
}

class TravelSearchResult {
  const TravelSearchResult({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.intro,
    required this.level,
    required this.sourceType,
    required this.point,
    this.imageUrl,
  });

  final String id;
  final String name;
  final String subtitle;
  final String intro;
  final String level;
  final String sourceType;
  final LatLng point;
  final String? imageUrl;
}

class SavedTrip {
  const SavedTrip({
    required this.id,
    required this.destination,
    required this.dateRange,
    required this.itemCount,
    required this.lastUpdated,
    required this.folder,
    required this.upcoming,
  });

  final String id;
  final String destination;
  final String dateRange;
  final String itemCount;
  final String lastUpdated;
  final String folder;
  final bool upcoming;
}

class CityWalkStop {
  const CityWalkStop({
    required this.time,
    required this.place,
    required this.activity,
    required this.note,
    required this.point,
  });

  final String time;
  final String place;
  final String activity;
  final String note;
  final LatLng point;
}

class CityWalkTemplate {
  const CityWalkTemplate({
    required this.id,
    required this.title,
    required this.city,
    required this.summary,
    required this.duration,
    required this.stops,
  });

  final String id;
  final String title;
  final String city;
  final String summary;
  final String duration;
  final List<CityWalkStop> stops;
}

class FeaturedScenicSpot {
  const FeaturedScenicSpot({
    required this.name,
    required this.city,
    required this.level,
    required this.tags,
    required this.summary,
    required this.query,
    required this.icon,
  });

  final String name;
  final String city;
  final String level;
  final List<String> tags;
  final String summary;
  final String query;
  final IconData icon;
}

const _featuredScenicTags = ['自然', '人文', '购物', '探险', '都市', '街巷'];

const _featuredScenicSpots = [
  FeaturedScenicSpot(
    name: '黄山风景区',
    city: '黄山',
    level: '5A',
    tags: ['自然', '探险'],
    summary: '奇松、怪石、云海和山岳徒步路线。',
    query: '黄山风景区',
    icon: Icons.terrain_outlined,
  ),
  FeaturedScenicSpot(
    name: '九寨沟景区',
    city: '阿坝',
    level: '5A',
    tags: ['自然', '探险'],
    summary: '高山湖泊、彩林和轻徒步观景线。',
    query: '九寨沟景区',
    icon: Icons.water_outlined,
  ),
  FeaturedScenicSpot(
    name: '张家界武陵源',
    city: '张家界',
    level: '5A',
    tags: ['自然', '探险'],
    summary: '峰林峡谷、电梯索道和高视野观景台。',
    query: '张家界武陵源',
    icon: Icons.hiking_outlined,
  ),
  FeaturedScenicSpot(
    name: '故宫博物院',
    city: '北京',
    level: '5A',
    tags: ['人文', '都市'],
    summary: '明清宫城、皇家建筑和博物馆动线。',
    query: '故宫博物院',
    icon: Icons.account_balance_outlined,
  ),
  FeaturedScenicSpot(
    name: '秦始皇帝陵博物院',
    city: '西安',
    level: '5A',
    tags: ['人文'],
    summary: '兵马俑、秦文化和大型遗址博物馆。',
    query: '秦始皇帝陵博物院',
    icon: Icons.museum_outlined,
  ),
  FeaturedScenicSpot(
    name: '南京夫子庙秦淮风光带',
    city: '南京',
    level: '5A',
    tags: ['人文', '购物', '街巷'],
    summary: '秦淮夜游、街巷小吃和历史商业街区。',
    query: '南京夫子庙秦淮风光带',
    icon: Icons.storefront_outlined,
  ),
  FeaturedScenicSpot(
    name: '天津古文化街',
    city: '天津',
    level: '5A',
    tags: ['购物', '街巷'],
    summary: '津门民俗、传统商铺和老城街景。',
    query: '天津古文化街',
    icon: Icons.shopping_bag_outlined,
  ),
  FeaturedScenicSpot(
    name: '平遥古城',
    city: '晋中',
    level: '5A',
    tags: ['人文', '街巷'],
    summary: '古城墙、票号院落和北方街巷肌理。',
    query: '平遥古城',
    icon: Icons.location_city_outlined,
  ),
  FeaturedScenicSpot(
    name: '东方明珠',
    city: '上海',
    level: '5A',
    tags: ['都市'],
    summary: '浦江天际线、城市观景和夜景地标。',
    query: '东方明珠',
    icon: Icons.apartment_outlined,
  ),
  FeaturedScenicSpot(
    name: '广州长隆旅游度假区',
    city: '广州',
    level: '5A',
    tags: ['都市', '探险'],
    summary: '主题乐园、亲子演艺和高密度度假动线。',
    query: '广州长隆旅游度假区',
    icon: Icons.attractions_outlined,
  ),
  FeaturedScenicSpot(
    name: '乌镇景区',
    city: '嘉兴',
    level: '5A',
    tags: ['街巷', '购物'],
    summary: '江南水乡、夜游街巷和慢节奏商业体验。',
    query: '乌镇景区',
    icon: Icons.houseboat_outlined,
  ),
  FeaturedScenicSpot(
    name: '丽江古城',
    city: '丽江',
    level: '5A',
    tags: ['街巷', '人文', '购物'],
    summary: '纳西古城街巷、夜游和小店集群。',
    query: '丽江古城',
    icon: Icons.alt_route_outlined,
  ),
];

const _cityWalkTemplates = [
  CityWalkTemplate(
    id: 'citywalk-chengdu-kuanzhai',
    title: 'Chengdu Alley Walk',
    city: 'Chengdu',
    summary: 'Tea houses, alleys, snacks, and an easy evening pace.',
    duration: 'Half day',
    stops: [
      CityWalkStop(
        time: '10:00',
        place: 'People\'s Park',
        activity: 'Tea house stop',
        note: 'Start slow with tea and local street life.',
        point: LatLng(30.6598, 104.0633),
      ),
      CityWalkStop(
        time: '11:30',
        place: 'Kuanzhai Alley',
        activity: 'Walk historic lanes',
        note: 'Good for snacks, photos, and compact walking.',
        point: LatLng(30.6697, 104.0575),
      ),
      CityWalkStop(
        time: '14:00',
        place: 'Wenshu Monastery',
        activity: 'Quiet culture stop',
        note: 'A calmer afternoon contrast after the lanes.',
        point: LatLng(30.6813, 104.0783),
      ),
    ],
  ),
  CityWalkTemplate(
    id: 'citywalk-beijing-lake',
    title: 'Beijing Lake & Hutong',
    city: 'Beijing',
    summary: 'Lakeside views, hutong streets, and classic Beijing texture.',
    duration: '1 day',
    stops: [
      CityWalkStop(
        time: '09:30',
        place: 'Beihai Park',
        activity: 'Lakeside walk',
        note: 'Start with open water and palace garden views.',
        point: LatLng(39.9255, 116.3892),
      ),
      CityWalkStop(
        time: '12:00',
        place: 'Shichahai',
        activity: 'Lunch and lakeside route',
        note: 'Keep the middle of the day flexible.',
        point: LatLng(39.9371, 116.3865),
      ),
      CityWalkStop(
        time: '15:00',
        place: 'Nanluoguxiang',
        activity: 'Hutong walk',
        note: 'Finish with a dense, walkable hutong area.',
        point: LatLng(39.9405, 116.4036),
      ),
    ],
  ),
  CityWalkTemplate(
    id: 'citywalk-shanghai-riverside',
    title: 'Shanghai Riverside Loop',
    city: 'Shanghai',
    summary: 'Museum, riverfront, skyline, and compact metro transfers.',
    duration: 'Half day',
    stops: [
      CityWalkStop(
        time: '10:00',
        place: 'People\'s Square',
        activity: 'City center start',
        note: 'Easy metro access and a clean starting point.',
        point: LatLng(31.2304, 121.4737),
      ),
      CityWalkStop(
        time: '13:30',
        place: 'The Bund',
        activity: 'Riverside walk',
        note: 'Classic skyline views with simple routing.',
        point: LatLng(31.2400, 121.4900),
      ),
      CityWalkStop(
        time: '16:00',
        place: 'Yu Garden',
        activity: 'Old city finish',
        note: 'Snack stop and traditional architecture.',
        point: LatLng(31.2272, 121.4921),
      ),
    ],
  ),
];

class TravelDataRepository {
  TravelDataRepository({
    required this.destinations,
    required this.itineraryDays,
    required this.mapPlaces,
    required this.savedTrips,
    required this.activeItineraryId,
    required this.activeItineraryTitle,
  });

  factory TravelDataRepository.empty() {
    return TravelDataRepository(
      destinations: [],
      itineraryDays: [],
      mapPlaces: [],
      savedTrips: [],
      activeItineraryId: null,
      activeItineraryTitle: 'My Travel Plan',
    );
  }

  final List<Destination> destinations;
  final List<ItineraryDay> itineraryDays;
  final List<MapPlace> mapPlaces;
  final List<SavedTrip> savedTrips;
  String? activeItineraryId;
  String activeItineraryTitle;

  static const supportFaqs = [
    'Login: unknown phone numbers or emails are registered automatically by the backend.',
    'Search: Home and Explore use AMap-backed place search through the backend.',
    'Itinerary editing: add, edit, delete, move, and save plan items from the backend timeline.',
    'Map: web uses AMap JS API; Android and iOS use native AMap SDK keys.',
    'Privacy: saved trips and personal travel data are stored in the local SQLite backend for this small team.',
  ];
}

class BackendLoginResult {
  const BackendLoginResult({
    required this.user,
    required this.registered,
    required this.sessionToken,
    required this.sessionExpiresAt,
  });

  final AppUser user;
  final bool registered;
  final String sessionToken;
  final DateTime sessionExpiresAt;
}

abstract interface class WayfareBackend {
  void setSessionToken(String? token);
  Future<BackendLoginResult> loginOrRegister(String identifier);
  Future<void> logout();
  Future<TravelDataRepository> loadTravelData(String userId);
  Future<List<TravelSearchResult>> searchPlaces(String query);
  Future<ItineraryDay> addDay(
    String itineraryId, {
    required String title,
    required String date,
    required String city,
    required String reminder,
  });
  Future<ItineraryItem> addItem(
    String itineraryId,
    String dayId, {
    required String time,
    required String place,
    required String activity,
    required String note,
    LatLng? point,
  });
  Future<ItineraryItem> updateItem(
    String itineraryId,
    String dayId,
    String itemId, {
    required String targetDayId,
    required String time,
    required String place,
    required String activity,
    required String note,
    LatLng? point,
  });
  Future<void> deleteItem(String itineraryId, String dayId, String itemId);
  Future<List<ItineraryItem>> reorderItems(
    String itineraryId,
    String dayId,
    List<String> itemIds,
  );
  Future<void> savePlan(String itineraryId);
  Future<SavedTrip> saveDestination(String userId, Destination destination);
  Future<void> deleteSavedTrip(String savedTripId);
  Future<void> submitFeedback({
    required String userId,
    required String category,
    required String description,
  });
}

class WayfareApiClient implements WayfareBackend {
  WayfareApiClient({
    this.baseUrl = const String.fromEnvironment(
      'WAYFARE_API_BASE',
      defaultValue: 'http://127.0.0.1:8080',
    ),
  });

  final String baseUrl;
  String? _sessionToken;

  @override
  void setSessionToken(String? token) {
    _sessionToken = token?.trim().isEmpty == true ? null : token;
  }

  @override
  Future<BackendLoginResult> loginOrRegister(String identifier) async {
    final body = await _post('/auth/login', {
      'identifier': identifier,
    });
    final sessionToken = body['token']?.toString() ?? '';
    final sessionExpiresAt = DateTime.tryParse(
          body['expiresAt']?.toString() ?? '',
        ) ??
        DateTime.now().toUtc();
    setSessionToken(sessionToken);
    final user = _userFromJson(
      _asMap(body['user']),
      sessionToken: sessionToken,
      sessionExpiresAt: sessionExpiresAt,
    );
    return BackendLoginResult(
      user: user,
      registered: body['registered'] == true,
      sessionToken: sessionToken,
      sessionExpiresAt: sessionExpiresAt,
    );
  }

  @override
  Future<void> logout() async {
    await _post('/auth/logout', <String, Object?>{});
    setSessionToken(null);
  }

  @override
  Future<TravelDataRepository> loadTravelData(String userId) async {
    final destinationsBody = await _get('/destinations');
    final placesBody = await _get('/map/places');
    final savedBody = await _get('/saved');
    var itineraryBody = await _get('/itineraries');

    var itineraries = _listOfMaps(itineraryBody['items']);
    if (itineraries.isEmpty) {
      final now = DateTime.now();
      final isoDate = _isoDate(now);
      final created = await _post('/itineraries', {
        'title': 'My Travel Plan',
        'destination': 'Current Trip',
        'startDate': isoDate,
        'endDate': isoDate,
        'status': 'draft',
        'days': <Map<String, Object?>>[],
      });
      itineraries = [_asMap(created['item'])];
      itineraryBody = {'items': itineraries};
    }

    final activeTrip = _asMap(_listOfMaps(itineraryBody['items']).first);
    return TravelDataRepository(
      destinations: _listOfMaps(destinationsBody['items'])
          .map(_destinationFromJson)
          .toList(),
      mapPlaces:
          _listOfMaps(placesBody['items']).map(_mapPlaceFromJson).toList(),
      savedTrips:
          _listOfMaps(savedBody['items']).map(_savedTripFromJson).toList(),
      itineraryDays: _daysFromJson(activeTrip),
      activeItineraryId: activeTrip['id']?.toString(),
      activeItineraryTitle:
          activeTrip['title']?.toString().trim().isEmpty == false
              ? activeTrip['title'].toString()
              : 'My Travel Plan',
    );
  }

  @override
  Future<List<TravelSearchResult>> searchPlaces(String query) async {
    final body = await _get('/search', query: {'q': query, 'limit': '20'});
    return _listOfMaps(body['items']).map(_searchResultFromJson).toList();
  }

  @override
  Future<ItineraryDay> addDay(
    String itineraryId, {
    required String title,
    required String date,
    required String city,
    required String reminder,
  }) async {
    final body = await _post('/itineraries/$itineraryId/days', {
      'title': title,
      'date': date,
      'city': city,
      'reminder': reminder,
    });
    return _dayFromJson(_asMap(body['item']));
  }

  @override
  Future<ItineraryItem> addItem(
    String itineraryId,
    String dayId, {
    required String time,
    required String place,
    required String activity,
    required String note,
    LatLng? point,
  }) async {
    final body = await _post('/itineraries/$itineraryId/days/$dayId/items', {
      'time': time,
      'placeName': place,
      'activity': activity,
      'note': note,
      'status': 'saved',
      if (point != null) 'lat': point.latitude,
      if (point != null) 'lng': point.longitude,
    });
    return _itemFromJson(_asMap(body['item']));
  }

  @override
  Future<ItineraryItem> updateItem(
    String itineraryId,
    String dayId,
    String itemId, {
    required String targetDayId,
    required String time,
    required String place,
    required String activity,
    required String note,
    LatLng? point,
  }) async {
    final body = await _patch(
      '/itineraries/$itineraryId/days/$dayId/items/$itemId',
      {
        'targetDayId': targetDayId,
        'time': time,
        'placeName': place,
        'activity': activity,
        'note': note,
        'status': 'saved',
        if (point != null) 'lat': point.latitude,
        if (point != null) 'lng': point.longitude,
      },
    );
    return _itemFromJson(_asMap(body['item']));
  }

  @override
  Future<void> deleteItem(
      String itineraryId, String dayId, String itemId) async {
    await _delete('/itineraries/$itineraryId/days/$dayId/items/$itemId');
  }

  @override
  Future<List<ItineraryItem>> reorderItems(
    String itineraryId,
    String dayId,
    List<String> itemIds,
  ) async {
    final body = await _patch(
      '/itineraries/$itineraryId/days/$dayId/items/reorder',
      {'itemIds': itemIds},
    );
    return _listOfMaps(body['items']).map(_itemFromJson).toList();
  }

  @override
  Future<void> savePlan(String itineraryId) async {
    await _patch('/itineraries/$itineraryId', {'status': 'saved'});
  }

  @override
  Future<SavedTrip> saveDestination(
      String userId, Destination destination) async {
    final body = await _post('/saved', {
      'type': 'destination',
      'refId': destination.id,
      'folder': destination.theme,
      'label': destination.name,
    });
    return _savedTripFromJson(_asMap(body['item']));
  }

  @override
  Future<void> deleteSavedTrip(String savedTripId) async {
    await _delete('/saved/$savedTripId');
  }

  @override
  Future<void> submitFeedback({
    required String userId,
    required String category,
    required String description,
  }) async {
    await _post('/feedback', {
      'category': category,
      'description': description,
    });
  }

  Future<Map<String, Object?>> _get(
    String path, {
    Map<String, String>? query,
  }) async {
    return _decode(await http.get(_uri(path, query), headers: _headers()));
  }

  Future<Map<String, Object?>> _post(String path, Object body) async {
    return _decode(
      await http.post(
        _uri(path),
        headers: _headers(json: true),
        body: jsonEncode(body),
      ),
    );
  }

  Future<Map<String, Object?>> _patch(String path, Object body) async {
    return _decode(
      await http.patch(
        _uri(path),
        headers: _headers(json: true),
        body: jsonEncode(body),
      ),
    );
  }

  Future<Map<String, Object?>> _delete(String path) async {
    return _decode(await http.delete(_uri(path), headers: _headers()));
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('$baseUrl$path').replace(queryParameters: query);
  }

  Map<String, String> _headers({bool json = false}) {
    final headers = <String, String>{};
    if (json) {
      headers['Content-Type'] = 'application/json';
    }
    final token = _sessionToken;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Map<String, Object?> _decode(http.Response response) {
    final body = response.body.trim().isEmpty
        ? <String, Object?>{}
        : _asMap(jsonDecode(response.body));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BackendException(
        body['error']?.toString() ??
            'Backend request failed with status ${response.statusCode}.',
        statusCode: response.statusCode,
      );
    }
    return body;
  }
}

class BackendException implements Exception {
  const BackendException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

bool _isExpiredSessionError(Object error) {
  return error is BackendException &&
      (error.statusCode == 401 ||
          error.message.toLowerCase().contains('bearer token'));
}

AppUser _userFromJson(
  Map<String, Object?> json, {
  String? sessionToken,
  DateTime? sessionExpiresAt,
}) {
  final identifier = json['identifier']?.toString() ?? '';
  final displayName = json['displayName']?.toString() ??
      json['display_name']?.toString() ??
      LocalAuthRepository._displayNameFromIdentifier(identifier);
  return AppUser(
    id: json['id']?.toString() ?? _nextLocalId('user'),
    identifier: identifier,
    displayName: displayName,
    sessionToken: sessionToken,
    sessionExpiresAt: sessionExpiresAt,
  );
}

Destination _destinationFromJson(Map<String, Object?> json) {
  final theme = json['theme']?.toString() ?? 'Trip';
  final lat = _doubleValue(json['lat']) ?? 30.2431;
  final lng = _doubleValue(json['lng']) ?? 120.1508;
  return Destination(
    id: json['id']?.toString() ?? _nextLocalId('dest'),
    name: json['name']?.toString() ?? 'Destination',
    theme: theme,
    duration: json['duration']?.toString() ?? '1 day',
    reason: json['priority'] == true
        ? 'Recommended by backend rules'
        : 'Available in destination catalog',
    summary: json['summary']?.toString() ?? '',
    tone: _toneForTheme(theme),
    priority: json['priority'] == true,
    point: LatLng(lat, lng),
  );
}

MapPlace _mapPlaceFromJson(Map<String, Object?> json) {
  final category = json['category']?.toString() ?? 'Place';
  final lat = _doubleValue(json['lat']) ?? 30.2431;
  final lng = _doubleValue(json['lng']) ?? 120.1508;
  return MapPlace(
    id: json['id']?.toString() ?? _nextLocalId('place'),
    name: json['name']?.toString() ?? 'Place',
    category: category,
    distance: json['distance']?.toString() ?? 'Backend place',
    description: json['description']?.toString() ?? '',
    rating: json['rating']?.toString() ?? 'Unrated',
    point: LatLng(lat, lng),
    icon: _iconForCategory(category),
  );
}

TravelSearchResult _searchResultFromJson(Map<String, Object?> json) {
  final lat = _doubleValue(json['lat']) ?? 30.2431;
  final lng = _doubleValue(json['lng']) ?? 120.1508;
  return TravelSearchResult(
    id: json['id']?.toString() ?? _nextLocalId('search'),
    name: json['name']?.toString() ?? 'Place',
    subtitle: json['subtitle']?.toString() ?? json['city']?.toString() ?? '',
    intro: json['intro']?.toString() ?? '',
    level: json['level']?.toString() ?? '',
    sourceType: json['type']?.toString() ?? 'place',
    point: LatLng(lat, lng),
    imageUrl: json['imageUrl']?.toString(),
  );
}

SavedTrip _savedTripFromJson(Map<String, Object?> json) {
  final label = json['label']?.toString() ??
      json['destination']?.toString() ??
      json['ref_id']?.toString() ??
      json['refId']?.toString() ??
      'Saved item';
  return SavedTrip(
    id: json['id']?.toString() ?? _nextLocalId('saved'),
    destination: label,
    dateRange: json['dateRange']?.toString() ?? 'Saved destination',
    itemCount: json['itemCount']?.toString() ?? 'Backend record',
    lastUpdated: json['created_at']?.toString() ??
        json['createdAt']?.toString() ??
        'Stored',
    folder: json['folder']?.toString() ?? 'Trips',
    upcoming: json['upcoming'] == false ? false : true,
  );
}

List<ItineraryDay> _daysFromJson(Map<String, Object?> trip) {
  return _listOfMaps(trip['days']).map(_dayFromJson).toList();
}

ItineraryDay _dayFromJson(Map<String, Object?> json) {
  return ItineraryDay(
    id: json['id']?.toString(),
    title: json['title']?.toString() ?? 'Day',
    date: json['date']?.toString() ?? _isoDate(DateTime.now()),
    city: json['city']?.toString() ?? 'Current city',
    reminder: json['reminder']?.toString() ?? '',
    items: _listOfMaps(json['items']).map(_itemFromJson).toList(),
  );
}

ItineraryItem _itemFromJson(Map<String, Object?> json) {
  final lat = _doubleValue(json['lat']);
  final lng = _doubleValue(json['lng']);
  return ItineraryItem(
    id: json['id']?.toString(),
    time: json['time']?.toString() ?? 'Flexible',
    place:
        json['placeName']?.toString() ?? json['place']?.toString() ?? 'Place',
    activity: json['activity']?.toString() ?? 'Visit',
    note: json['note']?.toString() ?? '',
    status: _displayStatus(json['status']?.toString()),
    point: lat == null || lng == null ? null : LatLng(lat, lng),
  );
}

Map<String, Object?> _asMap(Object? value) {
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  return <String, Object?>{};
}

List<Map<String, Object?>> _listOfMaps(Object? value) {
  if (value is List) {
    return value.map(_asMap).toList();
  }
  return <Map<String, Object?>>[];
}

double? _doubleValue(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}

String _displayStatus(String? status) {
  switch (status) {
    case 'saved':
      return 'Saved';
    case 'draft':
      return 'Draft';
    default:
      return status == null || status.isEmpty ? 'Saved' : status;
  }
}

String _isoDate(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

Color _toneForTheme(String theme) {
  final lower = theme.toLowerCase();
  if (lower.contains('nature')) {
    return const Color(0xFF4E8A7E);
  }
  if (lower.contains('food')) {
    return const Color(0xFFAA6046);
  }
  if (lower.contains('culture')) {
    return const Color(0xFF7A7D4E);
  }
  if (lower.contains('city')) {
    return const Color(0xFF4E6A96);
  }
  return const Color(0xFF5E6C5B);
}

IconData _iconForCategory(String category) {
  switch (category) {
    case 'Food':
      return Icons.restaurant_outlined;
    case 'Nature':
      return Icons.park_outlined;
    case 'Transport':
      return Icons.directions_transit_outlined;
    case 'Saved Place':
      return Icons.bookmark_border;
    default:
      return Icons.place_outlined;
  }
}

class WayfareApp extends StatefulWidget {
  WayfareApp({
    WayfareBackend? backend,
    super.key,
  }) : backend = backend ?? WayfareApiClient();

  final WayfareBackend backend;

  @override
  State<WayfareApp> createState() => _WayfareAppState();
}

class _WayfareAppState extends State<WayfareApp> {
  ThemeSource _themeSource = ThemeSource.system;
  final _authRepository = LocalAuthRepository();
  AppUser? _user;
  bool _authLoading = true;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    AppUser? user;
    try {
      user = await _authRepository.currentUser();
    } catch (_) {
      user = null;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _user = user;
      _authLoading = false;
    });
    widget.backend.setSessionToken(user?.sessionToken);
  }

  Future<bool> _login(String identifier) async {
    final result = await widget.backend.loginOrRegister(identifier);
    widget.backend.setSessionToken(result.sessionToken);
    await _authRepository.saveSession(result.user);
    if (!mounted) {
      return result.registered;
    }
    setState(() => _user = result.user);
    return result.registered;
  }

  Future<void> _logout() async {
    try {
      await widget.backend.logout();
    } catch (_) {
      // Local logout must still work if the backend session is already gone.
    }
    widget.backend.setSessionToken(null);
    await _authRepository.logout();
    if (!mounted) {
      return;
    }
    setState(() => _user = null);
  }

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final fallbackLight = ColorScheme.fromSeed(
          seedColor: _themeSource.seed,
          brightness: Brightness.light,
        );
        final fallbackDark = ColorScheme.fromSeed(
          seedColor: _themeSource.seed,
          brightness: Brightness.dark,
        );

        final useDynamic = _themeSource == ThemeSource.system;
        final lightScheme = useDynamic && lightDynamic != null
            ? lightDynamic.harmonized()
            : fallbackLight;
        final darkScheme = useDynamic && darkDynamic != null
            ? darkDynamic.harmonized()
            : fallbackDark;

        return MaterialApp(
          title: 'Wayfare',
          debugShowCheckedModeBanner: false,
          theme: _themeData(lightScheme),
          darkTheme: _themeData(darkScheme),
          home: _authLoading
              ? const _AuthLoadingScreen()
              : _user == null
                  ? _LoginScreen(onLogin: _login)
                  : TravelPlannerShell(
                      backend: widget.backend,
                      user: _user!,
                      themeSource: _themeSource,
                      onThemeChanged: (source) =>
                          setState(() => _themeSource = source),
                      onLogout: _logout,
                    ),
        );
      },
    );
  }

  ThemeData _themeData(ColorScheme colorScheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      splashFactory: InkRipple.splashFactory,
      visualDensity: VisualDensity.standard,
      scaffoldBackgroundColor: colorScheme.surface,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: EdgeInsets.zero,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(44, 44),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(44, 44),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        filled: true,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      searchBarTheme: SearchBarThemeData(
        elevation: const WidgetStatePropertyAll(0),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 16),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      ),
    );
  }
}

class _AuthLoadingScreen extends StatelessWidget {
  const _AuthLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: SizedBox(
          width: 56,
          height: 56,
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}

class _LoginScreen extends StatefulWidget {
  const _LoginScreen({required this.onLogin});

  final Future<bool> Function(String identifier) onLogin;

  @override
  State<_LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<_LoginScreen> {
  final _identifier = TextEditingController();
  String? _identifierError;
  var _loginType = 'phone';
  var _remember = true;
  var _submitting = false;

  @override
  void dispose() {
    _identifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(24),
              children: [
                CircleAvatar(
                  radius: 38,
                  backgroundColor: scheme.primaryContainer,
                  foregroundColor: scheme.onPrimaryContainer,
                  child: const Icon(Icons.travel_explore, size: 36),
                ),
                const SizedBox(height: 22),
                Text(
                  'Wayfare',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign in to continue planning trips',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 28),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'phone',
                      icon: Icon(Icons.phone_android_outlined),
                      label: Text('Phone'),
                    ),
                    ButtonSegment(
                      value: 'email',
                      icon: Icon(Icons.alternate_email),
                      label: Text('Email'),
                    ),
                  ],
                  selected: {_loginType},
                  onSelectionChanged: _submitting
                      ? null
                      : (value) => setState(() => _loginType = value.first),
                ),
                const SizedBox(height: 14),
                LoginIdentifierField(
                  controller: _identifier,
                  loginType: _loginType,
                  enabled: !_submitting,
                  errorText: _identifierError,
                  onChanged: (_) {
                    if (_identifierError != null) {
                      setState(() => _identifierError = null);
                    }
                  },
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _remember,
                  onChanged: _submitting
                      ? null
                      : (value) => setState(() => _remember = value ?? true),
                  title: const Text('Keep me signed in'),
                  subtitle: const Text('Local session for this small team app'),
                ),
                const SizedBox(height: 12),
                if (_submitting) ...[
                  const LinearProgressIndicator(),
                  const SizedBox(height: 12),
                ],
                FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: const Icon(Icons.login),
                  label: const Text('Continue'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed:
                      _submitting ? null : () => _showPrivacyDialog(context),
                  icon: const Icon(Icons.privacy_tip_outlined),
                  label: const Text('Privacy Notice'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final validationError = _validateIdentifier(_identifier.text);
    if (validationError != null) {
      setState(() => _identifierError = validationError);
      return;
    }
    setState(() => _submitting = true);
    try {
      final registered = await widget.onLogin(_identifier.text);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            registered
                ? 'New user registered and signed in.'
                : 'Signed in successfully.',
          ),
        ),
      );
    } on FormatException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } on BackendException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Backend is not reachable. Start it from backend with: dart run bin/server.dart',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  String? _validateIdentifier(String value) {
    final text = value.trim();
    if (text.isEmpty) {
      return 'Required';
    }
    if (_loginType == 'email' && !text.contains('@')) {
      return 'Enter a valid email.';
    }
    if (_loginType == 'phone' && text.length < 6) {
      return 'Enter a valid phone number.';
    }
    return null;
  }

  void _showPrivacyDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.privacy_tip_outlined),
        title: const Text('Privacy Notice'),
        content: const Text(
          'Wayfare stores account identifiers, preferences, saved trips, and itinerary data for this course project. AMap requires its privacy statement to be shown and accepted before the map SDK works.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class TravelPlannerShell extends StatefulWidget {
  const TravelPlannerShell({
    required this.backend,
    required this.user,
    required this.themeSource,
    required this.onThemeChanged,
    required this.onLogout,
    super.key,
  });

  final WayfareBackend backend;
  final AppUser user;
  final ThemeSource themeSource;
  final ValueChanged<ThemeSource> onThemeChanged;
  final VoidCallback onLogout;

  @override
  State<TravelPlannerShell> createState() => _TravelPlannerShellState();
}

class _TravelPlannerShellState extends State<TravelPlannerShell> {
  AppTab _tab = AppTab.home;
  TravelDataRepository _repository = TravelDataRepository.empty();
  var _loadingData = true;
  var _syncing = false;
  String? _backendError;

  @override
  void initState() {
    super.initState();
    _loadBackendData();
  }

  @override
  void didUpdateWidget(TravelPlannerShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id ||
        oldWidget.backend != widget.backend) {
      _repository = TravelDataRepository.empty();
      _loadingData = true;
      _backendError = null;
      _loadBackendData();
    }
  }

  Future<void> _loadBackendData() async {
    setState(() {
      _loadingData = true;
      _backendError = null;
    });
    try {
      final repository = await widget.backend.loadTravelData(widget.user.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _repository = repository;
        _loadingData = false;
      });
    } catch (error) {
      if (_isExpiredSessionError(error)) {
        widget.onLogout();
        return;
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _backendError = error.toString();
        _loadingData = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        return Scaffold(
          appBar: AppBar(
            toolbarHeight: 76,
            scrolledUnderElevation: 1,
            titleSpacing: 16,
            title: _AppHeader(
              title: _title,
              subtitle: _subtitle,
              stopCount: _plannedStopCount,
              dayCount: _repository.itineraryDays.length,
            ),
            actions: [
              IconButton(
                tooltip: 'Help',
                icon: const Icon(Icons.help_outline),
                onPressed: _showHelpCenter,
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Tooltip(
                  message: widget.user.identifier,
                  child: CircleAvatar(
                    radius: 18,
                    child: Text(widget.user.initials),
                  ),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: Row(
              children: [
                if (wide) ...[
                  _AdaptiveNavigationRail(
                    selectedTab: _tab,
                    onSelected: (tab) => setState(() => _tab = tab),
                    user: widget.user,
                  ),
                  const VerticalDivider(thickness: 1, width: 1),
                ],
                Expanded(child: _animatedBody),
              ],
            ),
          ),
          floatingActionButton: _floatingActionButton,
          bottomNavigationBar: wide ? null : _bottomNavigationBar,
        );
      },
    );
  }

  Widget? get _floatingActionButton {
    switch (_tab) {
      case AppTab.home:
        final scheme = Theme.of(context).colorScheme;
        return FloatingActionButton.extended(
          tooltip: 'Plan actions',
          onPressed: _showHomeActionSheet,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          icon: const Icon(Icons.add),
          label: const Text('Plan'),
        );
      case AppTab.itinerary:
        return FloatingActionButton(
          tooltip: 'Add attraction or activity',
          onPressed: () => _showEditItemSheet(),
          child: const Icon(Icons.add),
        );
      case AppTab.explore:
      case AppTab.saved:
      case AppTab.profile:
        return null;
    }
  }

  void _showHomeActionSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return _SheetPadding(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.add_circle_outline),
                title: const Text('Create New Itinerary'),
                subtitle: const Text('Open the timeline and add a day'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _tab = AppTab.itinerary);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      _showAddDaySheet();
                    }
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.map_outlined),
                title: const Text('Explore Map'),
                subtitle: const Text(
                    'Search, pick points, and inspect route context'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _tab = AppTab.explore);
                },
              ),
              ListTile(
                leading: const Icon(Icons.bookmark_border),
                title: const Text('Saved Trips'),
                subtitle: const Text('Review saved plans and copied walks'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _tab = AppTab.saved);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget get _animatedBody {
    return _body;
  }

  int get _plannedStopCount {
    return _repository.itineraryDays
        .fold<int>(0, (sum, day) => sum + day.items.length);
  }

  Widget get _bottomNavigationBar {
    return NavigationBar(
      selectedIndex: _tab.index,
      onDestinationSelected: (index) {
        setState(() => _tab = AppTab.values[index]);
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.explore_outlined),
          selectedIcon: Icon(Icons.explore),
          label: 'Explore',
        ),
        NavigationDestination(
          icon: Icon(Icons.list_alt_outlined),
          selectedIcon: Icon(Icons.list_alt),
          label: 'Itinerary',
        ),
        NavigationDestination(
          icon: Icon(Icons.bookmark_border),
          selectedIcon: Icon(Icons.bookmark),
          label: 'Saved',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }

  String get _title {
    switch (_tab) {
      case AppTab.home:
        return 'Home';
      case AppTab.explore:
        return 'Explore Map';
      case AppTab.itinerary:
        return 'Itinerary';
      case AppTab.saved:
        return 'Saved Trips';
      case AppTab.profile:
        return 'Profile';
    }
  }

  String get _subtitle {
    switch (_tab) {
      case AppTab.home:
        return 'Search places, copy CityWalks, continue planning';
      case AppTab.explore:
        return 'Markers, route context, and bottom sheet details';
      case AppTab.itinerary:
        return 'Timeline with editable travel plan items';
      case AppTab.saved:
        return 'Upcoming, saved destinations, and history';
      case AppTab.profile:
        return 'Account, travel data, appearance, and support';
    }
  }

  Widget get _body {
    if (_loadingData) {
      return const _BackendLoadingPanel();
    }
    final backendError = _backendError;
    if (backendError != null) {
      return _BackendErrorPanel(
        message: backendError,
        onRetry: _loadBackendData,
      );
    }
    return IndexedStack(
      index: _tab.index,
      children: [
        _HomeScreen(
          repository: _repository,
          onOpenMap: () => setState(() => _tab = AppTab.explore),
          onSearch: widget.backend.searchPlaces,
          onAddSearchResult: (result) => _showAddPlaceToDaySheet(
            result.name,
            'Visit ${result.name}',
            result.intro,
            point: result.point,
          ),
          onCopyTemplate: _copyCityWalkTemplate,
          onFeaturedScenicSelected: _handleFeaturedScenicSpot,
        ),
        _ExploreScreen(
          places: _repository.mapPlaces,
          itineraryDays: _repository.itineraryDays,
          onPlaceSelected: _showPlaceSheet,
          onMapPointPicked: _showMapPointAddSheet,
          onSearch: widget.backend.searchPlaces,
          onAddSearchResult: (result) => _showAddPlaceToDaySheet(
            result.name,
            'Visit ${result.name}',
            result.intro,
            point: result.point,
          ),
          onRetry: _loadBackendData,
        ),
        _ItineraryScreen(
          days: _repository.itineraryDays,
          onAddDay: _showAddDaySheet,
          onEdit: (item) => _showEditItemSheet(item: item),
          onDelete: _confirmDelete,
          onReorder: _reorderItem,
          onDuplicate: _duplicateItem,
          onOpenMap: () => setState(() => _tab = AppTab.explore),
          onSave: _saveActivePlan,
        ),
        _SavedScreen(
          trips: _repository.savedTrips,
          onAdd: (trip) => _showAddPlaceToDaySheet(
            trip.destination,
            'Reused saved trip idea',
            'Added from saved trips.',
          ),
          onShowInfo: _showInfo,
          onRemove: _removeSavedTrip,
        ),
        _ProfileScreen(
          repository: _repository,
          user: widget.user,
          themeSource: widget.themeSource,
          onThemePick: _showThemeChooser,
          onHelp: _showHelpCenter,
          onFeedback: _showFeedbackSheet,
          onShowInfo: _showInfo,
          onLogout: widget.onLogout,
        ),
      ],
    );
  }

  Future<void> _handleFeaturedScenicSpot(FeaturedScenicSpot spot) async {
    final results = await _runBackendMutation(
      () => widget.backend.searchPlaces(spot.query),
    );
    if (results == null || results.isEmpty) {
      _toast('No search result found for ${spot.name}.');
      return;
    }
    final result = _bestSearchMatch(results, spot.query);
    await _showAddPlaceToDaySheet(
      result.name,
      'Visit ${result.name}',
      result.intro.trim().isEmpty ? spot.summary : result.intro,
      point: result.point,
    );
  }

  Future<void> _showAddPlaceToDaySheet(
    String place,
    String activity,
    String note, {
    LatLng? point,
  }) async {
    if (!await _ensureDefaultDay()) {
      return;
    }
    _showQuickAddToDaySheet(
      place: place,
      activity: activity,
      note: note,
      point: point,
    );
  }

  Future<bool> _ensureDefaultDay() async {
    if (_repository.itineraryDays.isNotEmpty) {
      return true;
    }
    final itineraryId = _repository.activeItineraryId;
    if (itineraryId == null) {
      _toast('Create or load a backend itinerary first.');
      return false;
    }
    final day = await _runBackendMutation(
      () => widget.backend.addDay(
        itineraryId,
        title: 'Day 1',
        date: _isoDate(DateTime.now()),
        city: 'Current city',
        reminder: 'Review route before departure',
      ),
    );
    if (day == null || !mounted) {
      return false;
    }
    setState(() => _repository.itineraryDays.add(day));
    return true;
  }

  void _showQuickAddToDaySheet({
    required String place,
    required String activity,
    required String note,
    LatLng? point,
  }) {
    if (_repository.itineraryDays.isEmpty) {
      _toast('Create a day before adding itinerary items.');
      return;
    }
    var selectedDayIndex = _nextAvailableDayIndex();
    var selectedTime = _parseTimeOfDay(null);

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return _SheetPadding(
              bottomInset: MediaQuery.viewInsetsOf(context).bottom,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Add to Itinerary',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(place, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    key: ValueKey(
                      'quick-add-day-$selectedDayIndex-${_repository.itineraryDays.length}',
                    ),
                    initialValue: selectedDayIndex,
                    decoration: const InputDecoration(labelText: 'Target day'),
                    items: [
                      for (var i = 0; i < _repository.itineraryDays.length; i++)
                        DropdownMenuItem<int>(
                          value: i,
                          child: Text(
                            '${_repository.itineraryDays[i].title} | ${_repository.itineraryDays[i].date}',
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setSheetState(() => selectedDayIndex = value);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _syncing
                          ? null
                          : () async {
                              final index =
                                  await _pickAndAddDayFromDropdown(context);
                              if (index != null && context.mounted) {
                                setSheetState(() => selectedDayIndex = index);
                              }
                            },
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: const Text('Add new day'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _TimePickerField(
                    value: selectedTime,
                    label: 'Time',
                    onChanged: (value) =>
                        setSheetState(() => selectedTime = value),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _syncing
                        ? null
                        : () async {
                            final created = await _createItem(
                              selectedDayIndex,
                              time: _formatTimeOfDay(selectedTime),
                              place: place,
                              activity: activity,
                              note: note,
                              point: point,
                            );
                            if (created == null || !context.mounted) {
                              return;
                            }
                            Navigator.pop(context);
                            _toast(
                              'Added to ${_repository.itineraryDays[selectedDayIndex].title}',
                            );
                          },
                    icon: const Icon(Icons.add),
                    label: const Text('Add Item'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<bool> _addDay({
    required String title,
    required String date,
    required String city,
    required String reminder,
  }) async {
    final existingIndex =
        _repository.itineraryDays.indexWhere((day) => day.date == date);
    if (existingIndex >= 0) {
      _toast(
          'Using existing ${_repository.itineraryDays[existingIndex].title}');
      return true;
    }
    final itineraryId = _repository.activeItineraryId;
    if (itineraryId == null) {
      _toast('Create or load a backend itinerary first.');
      return false;
    }
    final day = await _runBackendMutation(
      () => widget.backend.addDay(
        itineraryId,
        title: title,
        date: date,
        city: city,
        reminder: reminder,
      ),
    );
    if (day == null || !mounted) {
      return false;
    }
    setState(() => _repository.itineraryDays.add(day));
    _toast('New day created');
    return true;
  }

  Future<int?> _pickAndAddDayFromDropdown(
    BuildContext pickerContext, {
    String city = 'Current city',
    String reminder = 'Review route before departure',
  }) async {
    final picked = await showDatePicker(
      context: pickerContext,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );
    if (picked == null) {
      return null;
    }
    final existingIndex = _repository.itineraryDays
        .indexWhere((day) => day.date == _isoDate(picked));
    if (existingIndex >= 0) {
      _toast(
          'Using existing ${_repository.itineraryDays[existingIndex].title}');
      return existingIndex;
    }
    final created = await _addDay(
      title: 'Day ${_repository.itineraryDays.length + 1}',
      date: _isoDate(picked),
      city: city,
      reminder: reminder,
    );
    if (!created || !mounted) {
      return null;
    }
    return _repository.itineraryDays.length - 1;
  }

  int _nextAvailableDayIndex() {
    final today = _dateOnly(DateTime.now());
    var bestIndex = 0;
    DateTime? bestDate;
    for (var index = 0; index < _repository.itineraryDays.length; index++) {
      final date = _parseIsoDate(_repository.itineraryDays[index].date);
      if (date == null || date.isBefore(today)) {
        continue;
      }
      if (bestDate == null || date.isBefore(bestDate)) {
        bestDate = date;
        bestIndex = index;
      }
    }
    return bestIndex;
  }

  Future<void> _copyCityWalkTemplate(CityWalkTemplate template) async {
    final itineraryId = _repository.activeItineraryId;
    if (itineraryId == null) {
      _toast('Create or load a backend itinerary first.');
      return;
    }
    final dayIndex = await _showCityWalkTargetDaySheet(template);
    if (dayIndex == null || !mounted) {
      return;
    }
    final targetDay = _repository.itineraryDays[dayIndex];

    var copied = 0;
    for (final stop in template.stops) {
      final created = await _runBackendMutation(
        () => widget.backend.addItem(
          itineraryId,
          targetDay.id,
          time: stop.time,
          place: stop.place,
          activity: stop.activity,
          note: stop.note,
          point: stop.point,
        ),
      );
      if (created != null && mounted) {
        setState(() => _repository.itineraryDays[dayIndex].items.add(created));
        copied += 1;
      }
    }
    if (copied > 0) {
      _toast('Copied ${template.title} to your itinerary');
    }
  }

  Future<int?> _showCityWalkTargetDaySheet(CityWalkTemplate template) async {
    int? selectedDayIndex =
        _repository.itineraryDays.isEmpty ? null : _nextAvailableDayIndex();
    return showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final days = _repository.itineraryDays;
            return _SheetPadding(
              bottomInset: MediaQuery.viewInsetsOf(context).bottom,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Copy CityWalk to Day',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    template.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  if (days.isEmpty)
                    const _InfoTile(
                      icon: Icons.calendar_month_outlined,
                      text: 'Choose a date before copying this recommendation.',
                    )
                  else
                    DropdownButtonFormField<int>(
                      key: ValueKey(
                        'citywalk-target-${selectedDayIndex ?? -1}-${days.length}',
                      ),
                      initialValue: selectedDayIndex,
                      decoration: const InputDecoration(
                        labelText: 'Target day',
                        helperText:
                            'Existing activities are kept; copied stops append at the end.',
                      ),
                      items: [
                        for (var i = 0; i < days.length; i++)
                          DropdownMenuItem<int>(
                            value: i,
                            child: Text('${days[i].title} | ${days[i].date}'),
                          ),
                      ],
                      onChanged: (value) =>
                          setSheetState(() => selectedDayIndex = value),
                    ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _syncing
                          ? null
                          : () async {
                              final index = await _pickAndAddDayFromDropdown(
                                context,
                                city: template.city,
                                reminder:
                                    'Copied from system CityWalk template',
                              );
                              if (index != null && context.mounted) {
                                setSheetState(() => selectedDayIndex = index);
                              }
                            },
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: Text(
                          days.isEmpty ? 'Choose target date' : 'Add new day'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: selectedDayIndex == null || _syncing
                        ? null
                        : () => Navigator.pop(context, selectedDayIndex),
                    icon: const Icon(Icons.content_copy),
                    label: const Text('Copy to selected day'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _reorderItem(
      ItineraryDay day, int oldIndex, int newIndex) async {
    final itineraryId = _repository.activeItineraryId;
    if (itineraryId == null) {
      _toast('Create or load a backend itinerary first.');
      return;
    }
    final before = List<ItineraryItem>.from(day.items);
    setState(() {
      final item = day.items.removeAt(oldIndex);
      day.items.insert(newIndex, item);
    });
    final reordered = await _runBackendMutation(
      () => widget.backend.reorderItems(
        itineraryId,
        day.id,
        day.items.map((item) => item.id).toList(),
      ),
    );
    if (!mounted) {
      return;
    }
    if (reordered == null) {
      setState(() {
        day.items
          ..clear()
          ..addAll(before);
      });
      return;
    }
    setState(() {
      day.items
        ..clear()
        ..addAll(reordered);
    });
  }

  Future<void> _duplicateItem(ItineraryDay day, ItineraryItem item) async {
    final itineraryId = _repository.activeItineraryId;
    if (itineraryId == null) {
      _toast('Create or load a backend itinerary first.');
      return;
    }
    final created = await _runBackendMutation(
      () => widget.backend.addItem(
        itineraryId,
        day.id,
        time: item.time,
        place: item.place,
        activity: '${item.activity} copy',
        note: item.note,
        point: item.point,
      ),
    );
    if (created == null || !mounted) {
      return;
    }
    setState(() => day.items.add(created));
    _toast('Item duplicated');
  }

  void _showAddDaySheet() {
    final title = TextEditingController(
      text: 'Day ${_repository.itineraryDays.length + 1}',
    );
    var selectedDate =
        DateTime.now().add(Duration(days: _repository.itineraryDays.length));
    final city = TextEditingController();
    final reminder = TextEditingController(
      text: 'Review route before departure',
    );
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return _SheetPadding(
              bottomInset: MediaQuery.viewInsetsOf(context).bottom,
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Create New Day',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: title,
                      decoration: const InputDecoration(
                        labelText: 'Day title',
                        filled: true,
                      ),
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2024),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          setSheetState(() => selectedDate = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date',
                          filled: true,
                          prefixIcon: Icon(Icons.calendar_today_outlined),
                        ),
                        child: Text(_isoDate(selectedDate)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: city,
                      decoration: const InputDecoration(
                        labelText: 'City',
                        filled: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: reminder,
                      decoration: const InputDecoration(
                        labelText: 'Weather or reminder',
                        filled: true,
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _syncing
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) {
                                return;
                              }
                              final created = await _addDay(
                                title: title.text.trim(),
                                date: _isoDate(selectedDate),
                                city: city.text.trim().isEmpty
                                    ? 'Current city'
                                    : city.text.trim(),
                                reminder: reminder.text.trim().isEmpty
                                    ? 'Review route before departure'
                                    : reminder.text.trim(),
                              );
                              if (created && context.mounted) {
                                Navigator.pop(context);
                              }
                            },
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: const Text('Add Day'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showPlaceSheet(MapPlace place) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return _SheetPadding(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(place.name,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(
                [place.category, place.distance, place.rating]
                    .where((part) => part.trim().isNotEmpty)
                    .join(' | '),
              ),
              const SizedBox(height: 12),
              Text(place.description),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showAddPlaceToDaySheet(
                        place.name,
                        'Visit ${place.category}',
                        place.description,
                        point: place.point,
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add to Itinerary'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _showInfo(place.name, place.description),
                    icon: const Icon(Icons.search),
                    label: const Text('View Detail'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<bool> _showMapPointAddSheet(AmapPickResult pick) async {
    if (!await _ensureDefaultDay()) {
      return false;
    }
    if (!mounted) {
      return false;
    }
    final point = pick.point;
    final inferredName =
        pick.name.trim().isEmpty ? 'Selected map point' : pick.name.trim();
    final address = pick.address?.trim();
    var selectedDayIndex = _nextAvailableDayIndex();
    final place = TextEditingController(text: inferredName);
    var selectedTime = _parseTimeOfDay(null);
    final note = TextEditingController(
      text: address == null || address.isEmpty
          ? 'Added from AMap point selection.'
          : address,
    );
    final formKey = GlobalKey<FormState>();

    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return _SheetPadding(
              bottomInset: MediaQuery.viewInsetsOf(context).bottom,
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Add Selected Map Point',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      address == null || address.isEmpty
                          ? 'Lat ${point.latitude.toStringAsFixed(6)}, Lng ${point.longitude.toStringAsFixed(6)}'
                          : address,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      key: ValueKey(
                        'map-point-day-$selectedDayIndex-${_repository.itineraryDays.length}',
                      ),
                      initialValue: selectedDayIndex,
                      decoration:
                          const InputDecoration(labelText: 'Target day'),
                      items: [
                        for (var i = 0;
                            i < _repository.itineraryDays.length;
                            i++)
                          DropdownMenuItem<int>(
                            value: i,
                            child: Text(
                              '${_repository.itineraryDays[i].title} | ${_repository.itineraryDays[i].date}',
                            ),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setSheetState(() => selectedDayIndex = value);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _syncing
                            ? null
                            : () async {
                                final index =
                                    await _pickAndAddDayFromDropdown(context);
                                if (index != null && context.mounted) {
                                  setSheetState(() => selectedDayIndex = index);
                                }
                              },
                        icon: const Icon(Icons.calendar_month_outlined),
                        label: const Text('Add new day'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: place,
                      decoration:
                          const InputDecoration(labelText: 'Place name'),
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                    _TimePickerField(
                      value: selectedTime,
                      label: 'Time',
                      onChanged: (value) =>
                          setSheetState(() => selectedTime = value),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: note,
                      decoration: const InputDecoration(labelText: 'Notes'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () => Navigator.pop(context, false),
                          icon: const Icon(Icons.close),
                          label: const Text('Cancel'),
                        ),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: _syncing
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) {
                                    return;
                                  }
                                  final created = await _createItem(
                                    selectedDayIndex,
                                    time: _formatTimeOfDay(selectedTime),
                                    place: place.text.trim(),
                                    activity: 'Visit selected map point',
                                    note: note.text.trim(),
                                    point: point,
                                  );
                                  if (created == null || !context.mounted) {
                                    return;
                                  }
                                  Navigator.pop(context, true);
                                  _toast('Map point added to itinerary');
                                },
                          icon: const Icon(Icons.add_location_alt_outlined),
                          label: const Text('Add to Itinerary'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    return added ?? false;
  }

  Future<void> _showEditItemSheet({ItineraryItem? item}) async {
    final isNew = item == null;
    if (isNew && !await _ensureDefaultDay()) {
      return;
    }
    if (!mounted) {
      return;
    }
    final days = _repository.itineraryDays;
    final currentDayIndex = isNew
        ? math.max(0, days.length - 1)
        : days.indexWhere((day) => day.items.contains(item));
    var selectedDayIndex = currentDayIndex < 0 ? 0 : currentDayIndex;
    var selectedTime = _parseTimeOfDay(item?.time);
    final place = TextEditingController(text: item?.place ?? '');
    final activity = TextEditingController(text: item?.activity ?? '');
    final note = TextEditingController(text: item?.note ?? '');
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return _SheetPadding(
              bottomInset: MediaQuery.viewInsetsOf(context).bottom,
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isNew
                          ? 'Add Activity / Attraction'
                          : 'Edit Itinerary Item',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      key: ValueKey(
                        'edit-item-day-$selectedDayIndex-${days.length}',
                      ),
                      initialValue: selectedDayIndex,
                      decoration: const InputDecoration(
                        labelText: 'Target day',
                        filled: true,
                      ),
                      items: [
                        for (var i = 0; i < days.length; i++)
                          DropdownMenuItem<int>(
                            value: i,
                            child: Text('${days[i].title} | ${days[i].date}'),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setSheetState(() => selectedDayIndex = value);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _syncing
                            ? null
                            : () async {
                                final index =
                                    await _pickAndAddDayFromDropdown(context);
                                if (index != null && context.mounted) {
                                  setSheetState(() => selectedDayIndex = index);
                                }
                              },
                        icon: const Icon(Icons.calendar_month_outlined),
                        label: const Text('Add new day'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _TimePickerField(
                      value: selectedTime,
                      label: 'Time',
                      onChanged: (value) =>
                          setSheetState(() => selectedTime = value),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: place,
                      decoration: const InputDecoration(
                        labelText: 'Place or attraction',
                        filled: true,
                      ),
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: activity,
                      decoration: const InputDecoration(
                        labelText: 'Activity',
                        filled: true,
                      ),
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: note,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        filled: true,
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _syncing
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) {
                                return;
                              }
                              final itineraryId = _repository.activeItineraryId;
                              if (itineraryId == null) {
                                _toast(
                                    'Create or load a backend itinerary first.');
                                return;
                              }
                              final resolvedDayIndex =
                                  _resolveDayIndex(selectedDayIndex);
                              if (resolvedDayIndex == null) {
                                return;
                              }
                              final targetDay =
                                  _repository.itineraryDays[resolvedDayIndex];
                              ItineraryDay? oldDay;
                              if (!isNew) {
                                for (final day in _repository.itineraryDays) {
                                  if (day.items.contains(item)) {
                                    oldDay = day;
                                    break;
                                  }
                                }
                              }
                              final resolvedPoint =
                                  item?.point ?? _pointForPlaceName(place.text);
                              ItineraryItem? saved;
                              if (isNew) {
                                saved = await _runBackendMutation(
                                  () => widget.backend.addItem(
                                    itineraryId,
                                    targetDay.id,
                                    time: _formatTimeOfDay(selectedTime),
                                    place: place.text.trim(),
                                    activity: activity.text.trim(),
                                    note: note.text.trim(),
                                    point: resolvedPoint,
                                  ),
                                );
                                if (saved != null && mounted) {
                                  setState(() => targetDay.items.add(saved!));
                                }
                              } else if (oldDay != null) {
                                saved = await _runBackendMutation(
                                  () => widget.backend.updateItem(
                                    itineraryId,
                                    oldDay!.id,
                                    item.id,
                                    targetDayId: targetDay.id,
                                    time: _formatTimeOfDay(selectedTime),
                                    place: place.text.trim(),
                                    activity: activity.text.trim(),
                                    note: note.text.trim(),
                                    point: resolvedPoint,
                                  ),
                                );
                                final sourceDay = oldDay;
                                final savedItem = saved;
                                if (savedItem != null && mounted) {
                                  setState(() {
                                    final oldIndex =
                                        sourceDay.items.indexOf(item);
                                    if (sourceDay.id == targetDay.id &&
                                        oldIndex >= 0) {
                                      sourceDay.items[oldIndex] = savedItem;
                                    } else {
                                      sourceDay.items.remove(item);
                                      targetDay.items.add(savedItem);
                                    }
                                  });
                                }
                              }
                              if (saved == null || !context.mounted) {
                                return;
                              }
                              Navigator.pop(context);
                            },
                      icon: const Icon(Icons.save_outlined),
                      label: Text(isNew ? 'Add Item' : 'Save Item'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<ItineraryItem?> _createItem(
    int selectedDayIndex, {
    required String time,
    required String place,
    required String activity,
    required String note,
    LatLng? point,
  }) async {
    final itineraryId = _repository.activeItineraryId;
    if (itineraryId == null) {
      _toast('Create or load a backend itinerary first.');
      return null;
    }
    final resolvedDayIndex = _resolveDayIndex(selectedDayIndex);
    if (resolvedDayIndex == null) {
      return null;
    }
    final targetDay = _repository.itineraryDays[resolvedDayIndex];
    final item = await _runBackendMutation(
      () => widget.backend.addItem(
        itineraryId,
        targetDay.id,
        time: time,
        place: place,
        activity: activity,
        note: note,
        point: point,
      ),
    );
    if (item != null && mounted) {
      setState(() => targetDay.items.add(item));
    }
    return item;
  }

  int? _resolveDayIndex(int selectedDayIndex) {
    if (_repository.itineraryDays.isEmpty) {
      _toast('Create a day before adding itinerary items.');
      return null;
    }
    if (selectedDayIndex < 0 ||
        selectedDayIndex >= _repository.itineraryDays.length) {
      _toast('Selected day is no longer available. Choose a day again.');
      return null;
    }
    return selectedDayIndex;
  }

  Future<void> _saveActivePlan() async {
    final itineraryId = _repository.activeItineraryId;
    if (itineraryId == null) {
      _toast('Create or load a backend itinerary first.');
      return;
    }
    final saved = await _runBackendCommand(
      () => widget.backend.savePlan(itineraryId),
    );
    if (saved) {
      _toast('Plan saved to backend');
    }
  }

  Future<void> _removeSavedTrip(SavedTrip trip) async {
    final deleted = await _runBackendCommand(
      () => widget.backend.deleteSavedTrip(trip.id),
    );
    if (!deleted || !mounted) {
      return;
    }
    setState(() {
      _repository.savedTrips.removeWhere((item) => item.id == trip.id);
    });
    _toast('Removed from backend');
  }

  Future<T?> _runBackendMutation<T>(Future<T> Function() action) async {
    if (mounted) {
      setState(() => _syncing = true);
    }
    try {
      return await action();
    } catch (error) {
      if (mounted) {
        _toast('Backend sync failed: $error');
      }
      return null;
    } finally {
      if (mounted) {
        setState(() => _syncing = false);
      }
    }
  }

  Future<bool> _runBackendCommand(Future<void> Function() action) async {
    if (mounted) {
      setState(() => _syncing = true);
    }
    try {
      await action();
      return true;
    } catch (error) {
      if (mounted) {
        _toast('Backend sync failed: $error');
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _syncing = false);
      }
    }
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }
    return null;
  }

  LatLng? _pointForPlaceName(String placeName) {
    final normalized = placeName.trim().toLowerCase();
    for (final place in _repository.mapPlaces) {
      if (place.name.toLowerCase() == normalized) {
        return place.point;
      }
    }
    for (final destination in _repository.destinations) {
      if (destination.name.toLowerCase() == normalized) {
        return destination.point;
      }
    }
    return null;
  }

  void _confirmDelete(ItineraryItem item) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete item?'),
        content:
            const Text('This removes the item from the backend itinerary.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              ItineraryDay? targetDay;
              for (final day in _repository.itineraryDays) {
                if (day.items.contains(item)) {
                  targetDay = day;
                  break;
                }
              }
              final itineraryId = _repository.activeItineraryId;
              if (targetDay == null || itineraryId == null) {
                Navigator.pop(context);
                return;
              }
              final deleted = await _runBackendCommand(
                () => widget.backend.deleteItem(
                  itineraryId,
                  targetDay!.id,
                  item.id,
                ),
              );
              if (deleted && mounted) {
                setState(() => targetDay!.items.remove(item));
              }
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showThemeChooser() {
    var selected = widget.themeSource;
    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Color source'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Material You converts the selected source into coordinated Material 3 roles across buttons, cards, chips, sheets, and navigation.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  for (final source in ThemeSource.values)
                    ListTile(
                      leading: Icon(
                        selected == source
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                      ),
                      title: Text(source.label),
                      trailing: CircleAvatar(backgroundColor: source.seed),
                      onTap: () => setDialogState(() => selected = source),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  widget.onThemeChanged(selected);
                  Navigator.pop(context);
                },
                child: const Text('Apply'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showFeedbackSheet() {
    final category = TextEditingController();
    final description = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var submitting = false;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return _SheetPadding(
              bottomInset: MediaQuery.viewInsetsOf(context).bottom,
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Contact / Feedback',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: category,
                      enabled: !submitting,
                      decoration: const InputDecoration(
                        labelText: 'Issue category',
                        filled: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: description,
                      enabled: !submitting,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        helperText:
                            'Describe what happened and what you expected.',
                        filled: true,
                      ),
                      validator: _required,
                      maxLines: 3,
                    ),
                    if (submitting) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(),
                    ],
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: submitting
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) {
                                return;
                              }
                              setSheetState(() => submitting = true);
                              final ok = await _runBackendCommand(
                                () => widget.backend.submitFeedback(
                                  userId: widget.user.id,
                                  category: category.text.trim().isEmpty
                                      ? 'general'
                                      : category.text.trim(),
                                  description: description.text.trim(),
                                ),
                              );
                              if (!context.mounted) {
                                return;
                              }
                              setSheetState(() => submitting = false);
                              if (!ok) {
                                return;
                              }
                              Navigator.pop(context);
                              _toast('Feedback submitted to backend');
                            },
                      icon: const Icon(Icons.send_outlined),
                      label: const Text('Submit'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showHelpCenter() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return _SheetPadding(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Help Center',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              const SearchBar(
                leading: Icon(Icons.search),
                hintText: 'Search FAQ',
              ),
              const SizedBox(height: 12),
              for (final faq in TravelDataRepository.supportFaqs) ...[
                _InfoTile(icon: Icons.help_outline, text: faq),
                const SizedBox(height: 8),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showInfo(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

TimeOfDay _parseTimeOfDay(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) {
    final now = DateTime.now();
    return TimeOfDay(hour: now.hour, minute: now.minute);
  }
  final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(text);
  if (match == null) {
    return const TimeOfDay(hour: 9, minute: 0);
  }
  final hour = int.tryParse(match.group(1) ?? '') ?? 9;
  final minute = int.tryParse(match.group(2) ?? '') ?? 0;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
    return const TimeOfDay(hour: 9, minute: 0);
  }
  return TimeOfDay(hour: hour, minute: minute);
}

String _formatTimeOfDay(TimeOfDay value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

class _TimePickerField extends StatelessWidget {
  const _TimePickerField({
    required this.value,
    required this.label,
    required this.onChanged,
  });

  final TimeOfDay value;
  final String label;
  final ValueChanged<TimeOfDay> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: value,
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                alwaysUse24HourFormat: true,
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
        );
        if (picked != null) {
          onChanged(picked);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          prefixIcon: const Icon(Icons.schedule_outlined),
        ),
        child: Text(_formatTimeOfDay(value)),
      ),
    );
  }
}

class _BackendLoadingPanel extends StatelessWidget {
  const _BackendLoadingPanel();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 56,
        height: 56,
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _AppHeader extends StatelessWidget {
  const _AppHeader({
    required this.title,
    required this.subtitle,
    required this.stopCount,
    required this.dayCount,
  });

  final String title;
  final String subtitle;
  final int stopCount;
  final int dayCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 420;
        return Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.travel_explore,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Wayfare',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  if (!compact)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                ],
              ),
            ),
            if (!compact) ...[
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$dayCount days | $stopCount stops',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSecondaryContainer,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.icon,
    required this.label,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: filled
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: filled ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: filled
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _ProfileMetricCard extends StatelessWidget {
  const _ProfileMetricCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Card.filled(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.62),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: scheme.primary),
              const SizedBox(height: 10),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackendErrorPanel extends StatelessWidget {
  const _BackendErrorPanel({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card.outlined(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Backend connection required',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(message),
                  const SizedBox(height: 12),
                  const Text(
                      'Start the backend from backend/: dart run bin/server.dart'),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeScreen extends StatefulWidget {
  const _HomeScreen({
    required this.repository,
    required this.onOpenMap,
    required this.onSearch,
    required this.onAddSearchResult,
    required this.onCopyTemplate,
    required this.onFeaturedScenicSelected,
  });

  final TravelDataRepository repository;
  final VoidCallback onOpenMap;
  final Future<List<TravelSearchResult>> Function(String query) onSearch;
  final ValueChanged<TravelSearchResult> onAddSearchResult;
  final ValueChanged<CityWalkTemplate> onCopyTemplate;
  final Future<void> Function(FeaturedScenicSpot spot) onFeaturedScenicSelected;

  @override
  State<_HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<_HomeScreen> {
  final _searchController = TextEditingController();
  List<TravelSearchResult> _searchResults = [];
  var _searched = false;
  var _searching = false;
  var _scenicSearching = false;
  String? _scenicSearchingName;
  String? _searchError;
  String _selectedScenicTag = _featuredScenicTags.first;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openFeaturedScenicSpot(FeaturedScenicSpot spot) async {
    if (_scenicSearching) {
      return;
    }
    setState(() {
      _scenicSearching = true;
      _scenicSearchingName = spot.name;
    });
    try {
      await widget.onFeaturedScenicSelected(spot);
    } finally {
      if (mounted) {
        setState(() {
          _scenicSearching = false;
          _scenicSearchingName = null;
        });
      }
    }
  }

  Future<void> _runSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searched = false;
        _searchResults = [];
        _searchError = null;
      });
      return;
    }
    setState(() {
      _searching = true;
      _searched = true;
      _searchError = null;
    });
    try {
      final results = await widget.onSearch(query);
      if (!mounted) {
        return;
      }
      setState(() => _searchResults = results);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _searchError = error.toString();
        _searchResults = [];
      });
    } finally {
      if (mounted) {
        setState(() => _searching = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('home-list'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _TravelHeroPanel(
          repository: widget.repository,
        ),
        const SizedBox(height: 16),
        const _SectionHeader(
          title: 'Find Places',
          action: 'AMap search',
        ),
        const SizedBox(height: 10),
        SearchQueryField(
          key: const ValueKey('home-search-field'),
          controller: _searchController,
          enabled: !_searching,
          onSubmitted: (_) => _runSearch(),
          onSearch: _runSearch,
        ),
        if (_searching) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
        ],
        if (_searched) ...[
          const SizedBox(height: 12),
          _SearchResultsPanel(
            results: _searchResults,
            error: _searchError,
            onAdd: widget.onAddSearchResult,
            onOpenMap: widget.onOpenMap,
          ),
        ],
        const SizedBox(height: 16),
        _FeaturedScenicSection(
          selectedTag: _selectedScenicTag,
          busy: _scenicSearching,
          busyName: _scenicSearchingName,
          onTagSelected: (tag) => setState(() => _selectedScenicTag = tag),
          onSpotSelected: _openFeaturedScenicSpot,
        ),
        const SizedBox(height: 16),
        const _SectionHeader(
          title: 'System CityWalks',
          action: 'Copy to use',
        ),
        const SizedBox(height: 10),
        for (final template in _cityWalkTemplates) ...[
          _CityWalkTemplateCard(
            template: template,
            onCopy: () => widget.onCopyTemplate(template),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _FeaturedScenicSection extends StatelessWidget {
  const _FeaturedScenicSection({
    required this.selectedTag,
    required this.busy,
    required this.busyName,
    required this.onTagSelected,
    required this.onSpotSelected,
  });

  final String selectedTag;
  final bool busy;
  final String? busyName;
  final ValueChanged<String> onTagSelected;
  final ValueChanged<FeaturedScenicSpot> onSpotSelected;

  @override
  Widget build(BuildContext context) {
    final spots = _featuredScenicSpots
        .where((spot) => spot.tags.contains(selectedTag))
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeader(
          title: 'Featured 5A Scenic Spots',
          action: 'Curated tags',
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final tag in _featuredScenicTags) ...[
                FilterChip(
                  label: Text(tag),
                  selected: selectedTag == tag,
                  onSelected: (_) => onTagSelected(tag),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final expanded = constraints.maxWidth >= 680;
            final children = [
              for (final spot in spots)
                _FeaturedScenicCard(
                  spot: spot,
                  busy: busy && busyName == spot.name,
                  onSelected: () => onSpotSelected(spot),
                ),
            ];
            if (!expanded) {
              return Column(
                children: [
                  for (final child in children) ...[
                    child,
                    if (child != children.last) const SizedBox(height: 8),
                  ],
                ],
              );
            }
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final child in children)
                  SizedBox(
                    width: (constraints.maxWidth - 10) / 2,
                    child: child,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _FeaturedScenicCard extends StatelessWidget {
  const _FeaturedScenicCard({
    required this.spot,
    required this.busy,
    required this.onSelected,
  });

  final FeaturedScenicSpot spot;
  final bool busy;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card.outlined(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: busy ? null : onSelected,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  spot.icon,
                  color: scheme.onPrimaryContainer,
                  size: 21,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spot.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${spot.city} · ${spot.level} · ${spot.tags.join(" / ")}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      spot.summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox.square(
                dimension: 42,
                child: IconButton.filled(
                  key: ValueKey('featured-scenic-add-${spot.query}'),
                  tooltip: 'Add scenic spot',
                  onPressed: busy ? null : onSelected,
                  icon: busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchResultsPanel extends StatelessWidget {
  const _SearchResultsPanel({
    required this.results,
    required this.error,
    required this.onAdd,
    required this.onOpenMap,
  });

  final List<TravelSearchResult> results;
  final String? error;
  final ValueChanged<TravelSearchResult> onAdd;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final errorText = error;
    if (errorText != null) {
      return Card.outlined(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Text('Search failed: $errorText'),
        ),
      );
    }
    if (results.isEmpty) {
      return Card.outlined(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(Icons.map_outlined, color: scheme.primary),
              const SizedBox(width: 12),
              const Expanded(
                child:
                    Text('No matching scenic spot. Use map pick mode instead.'),
              ),
              TextButton.icon(
                onPressed: onOpenMap,
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text('Map'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          title: 'Search Results',
          action: '${results.length} results',
        ),
        const SizedBox(height: 8),
        for (final result in results.take(8)) ...[
          _SearchResultCard(
            result: result,
            onAdd: () => onAdd(result),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({
    required this.result,
    required this.onAdd,
  });

  final TravelSearchResult result;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shouldShowLevel =
        result.level.isNotEmpty && result.level.toLowerCase() != 'amap';
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          result.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                      ),
                      if (shouldShowLevel) ...[
                        const SizedBox(width: 8),
                        _CompactLabel(text: result.level),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _cleanSearchSubtitle(result.subtitle),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                  if (result.intro.trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      result.intro,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox.square(
              dimension: 44,
              child: IconButton.filled(
                key: ValueKey('search-result-add-${result.id}'),
                tooltip: 'Add to itinerary',
                onPressed: onAdd,
                icon: const Icon(Icons.add),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactLabel extends StatelessWidget {
  const _CompactLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _CityWalkTemplateCard extends StatelessWidget {
  const _CityWalkTemplateCard({
    required this.template,
    required this.onCopy,
  });

  final CityWalkTemplate template;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final previewStops = template.stops.take(3).toList(growable: false);
    return Card.filled(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.52),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.directions_walk,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        template.title,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        template.summary,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.tonalIcon(
                  key: ValueKey('copy-citywalk-${template.id}'),
                  onPressed: onCopy,
                  icon: const Icon(Icons.content_copy),
                  label: const Text('Copy'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetricPill(
                  icon: Icons.location_city_outlined,
                  label: template.city,
                  filled: true,
                ),
                _MetricPill(
                  icon: Icons.schedule_outlined,
                  label: template.duration,
                ),
                _MetricPill(
                  icon: Icons.route_outlined,
                  label: '${template.stops.length} stops',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: scheme.outlineVariant),
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < previewStops.length; index++) ...[
                  _CityWalkStopPreview(
                    index: index + 1,
                    stop: previewStops[index],
                  ),
                  if (index != previewStops.length - 1)
                    const SizedBox(height: 8),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CityWalkStopPreview extends StatelessWidget {
  const _CityWalkStopPreview({
    required this.index,
    required this.stop,
  });

  final int index;
  final CityWalkStop stop;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$index',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSecondaryContainer,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stop.place,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Text(
                '${stop.time} | ${stop.activity}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _cleanSearchSubtitle(String value) {
  return value
      .replaceAll(' 路 ', ' ')
      .replaceAll(' 璺?', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

TravelSearchResult _bestSearchMatch(
  List<TravelSearchResult> results,
  String query,
) {
  final normalizedQuery = _normalizeSearchText(query);
  for (final result in results) {
    if (_normalizeSearchText(result.name) == normalizedQuery) {
      return result;
    }
  }
  for (final result in results) {
    final normalizedName = _normalizeSearchText(result.name);
    if (normalizedName.contains(normalizedQuery) ||
        normalizedQuery.contains(normalizedName)) {
      return result;
    }
  }
  return results.first;
}

String _normalizeSearchText(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'\s+'), '').trim();
}

class _UpcomingPlanItem {
  const _UpcomingPlanItem({
    required this.day,
    required this.item,
    required this.startsAt,
  });

  final ItineraryDay day;
  final ItineraryItem item;
  final DateTime startsAt;
}

_UpcomingPlanItem? _nextUpcomingPlanItem(
  List<ItineraryDay> days, {
  DateTime? now,
}) {
  final current = now ?? DateTime.now();
  _UpcomingPlanItem? best;
  for (final day in days) {
    for (final item in day.items) {
      final startsAt = _scheduledItemDateTime(day.date, item.time);
      if (startsAt == null || startsAt.isBefore(current)) {
        continue;
      }
      if (best == null || startsAt.isBefore(best.startsAt)) {
        best = _UpcomingPlanItem(day: day, item: item, startsAt: startsAt);
      }
    }
  }
  return best;
}

DateTime? _scheduledItemDateTime(String date, String time) {
  final parsedDate = _parseIsoDate(date);
  if (parsedDate == null) {
    return null;
  }
  final parsedTime = _tryParseTimeOfDay(time);
  if (parsedTime == null) {
    return DateTime(parsedDate.year, parsedDate.month, parsedDate.day, 23, 59);
  }
  return DateTime(
    parsedDate.year,
    parsedDate.month,
    parsedDate.day,
    parsedTime.hour,
    parsedTime.minute,
  );
}

DateTime? _parseIsoDate(String value) {
  final parts = value.split('-');
  if (parts.length != 3) {
    return null;
  }
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) {
    return null;
  }
  return DateTime(year, month, day);
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

TimeOfDay? _tryParseTimeOfDay(String value) {
  final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value.trim());
  if (match == null) {
    return null;
  }
  final hour = int.tryParse(match.group(1) ?? '');
  final minute = int.tryParse(match.group(2) ?? '');
  if (hour == null ||
      minute == null ||
      hour < 0 ||
      hour > 23 ||
      minute < 0 ||
      minute > 59) {
    return null;
  }
  return TimeOfDay(hour: hour, minute: minute);
}

class _AdaptiveNavigationRail extends StatelessWidget {
  const _AdaptiveNavigationRail({
    required this.selectedTab,
    required this.onSelected,
    required this.user,
  });

  final AppTab selectedTab;
  final ValueChanged<AppTab> onSelected;
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return NavigationRail(
      selectedIndex: selectedTab.index,
      onDestinationSelected: (index) => onSelected(AppTab.values[index]),
      labelType: NavigationRailLabelType.all,
      minWidth: 92,
      leading: Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 18),
        child: Badge(
          label: const Text('Live'),
          child: CircleAvatar(
            backgroundColor: scheme.primaryContainer,
            foregroundColor: scheme.onPrimaryContainer,
            child: Text(user.initials),
          ),
        ),
      ),
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: Text('Home'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.explore_outlined),
          selectedIcon: Icon(Icons.explore),
          label: Text('Explore'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.list_alt_outlined),
          selectedIcon: Icon(Icons.list_alt),
          label: Text('Itinerary'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.bookmark_border),
          selectedIcon: Icon(Icons.bookmark),
          label: Text('Saved'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: Text('Profile'),
        ),
      ],
    );
  }
}

class _TravelHeroPanel extends StatelessWidget {
  const _TravelHeroPanel({
    required this.repository,
  });

  final TravelDataRepository repository;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final itemCount = repository.itineraryDays
        .fold<int>(0, (sum, day) => sum + day.items.length);
    final dayCount = repository.itineraryDays.length;
    final nextPlan = _nextUpcomingPlanItem(repository.itineraryDays);
    return Card.filled(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        repository.activeItineraryTitle,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: scheme.onPrimaryContainer,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        itemCount == 0
                            ? 'No planned stops yet. Copy a CityWalk or add a place from search.'
                            : 'Synced with backend and ready for route planning.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: scheme.onPrimaryContainer,
                            ),
                      ),
                    ],
                  ),
                ),
                CircleAvatar(
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                  child: const Icon(Icons.route_outlined),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetricPill(
                  icon: Icons.calendar_today_outlined,
                  label: '$dayCount days',
                ),
                _MetricPill(
                  icon: Icons.flag_outlined,
                  label: '$itemCount stops',
                ),
                _MetricPill(
                  icon: Icons.bookmark_border,
                  label: '${repository.savedTrips.length} saved',
                ),
              ],
            ),
            if (nextPlan != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(alpha: 0.62),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.next_plan_outlined, color: scheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${nextPlan.day.title} | ${nextPlan.day.date} | ${nextPlan.item.time}',
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                          Text(
                            nextPlan.item.place,
                            key: const ValueKey('home-next-itinerary-place'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _MapMode { explore, planned }

class _ExploreScreen extends StatefulWidget {
  const _ExploreScreen({
    required this.places,
    required this.itineraryDays,
    required this.onPlaceSelected,
    required this.onMapPointPicked,
    required this.onSearch,
    required this.onAddSearchResult,
    required this.onRetry,
  });

  final List<MapPlace> places;
  final List<ItineraryDay> itineraryDays;
  final ValueChanged<MapPlace> onPlaceSelected;
  final Future<bool> Function(AmapPickResult pick) onMapPointPicked;
  final Future<List<TravelSearchResult>> Function(String query) onSearch;
  final ValueChanged<TravelSearchResult> onAddSearchResult;
  final VoidCallback onRetry;

  @override
  State<_ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<_ExploreScreen> {
  _MapMode _mode = _MapMode.explore;
  final _searchController = TextEditingController();
  List<TravelSearchResult> _searchResults = [];
  var _searched = false;
  var _searching = false;
  String? _searchError;
  var _pickMode = false;
  var _mapInputLocked = false;
  LatLng? _selectedMapPoint;
  AmapPickResult? _selectedMapPick;
  late final Set<String> _selectedCategories =
      _allPlaces.map((place) => place.category).toSet();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MapPlace> get _scheduledPlaces {
    final items = <MapPlace>[];
    for (var dayIndex = 0; dayIndex < widget.itineraryDays.length; dayIndex++) {
      final day = widget.itineraryDays[dayIndex];
      for (final item in day.items) {
        final point = item.point;
        if (point == null) {
          continue;
        }
        items.add(
          MapPlace(
            id: 'scheduled-${item.id}',
            name: item.place,
            category: 'Day ${dayIndex + 1}',
            distance: day.title,
            description: '${item.time} | ${item.activity}',
            rating: item.status,
            point: point,
            icon: Icons.event_available_outlined,
          ),
        );
      }
    }
    return items;
  }

  List<MapPlace> get _allPlaces {
    return [
      ...widget.places,
      ..._searchPlaces,
      ..._scheduledPlaces,
    ];
  }

  List<MapPlace> get _searchPlaces {
    return _searchResults
        .map(
          (result) => MapPlace(
            id: 'search-${result.id}',
            name: result.name,
            category: 'Search',
            distance: _cleanSearchSubtitle(result.subtitle),
            description: result.intro,
            rating: result.level.toLowerCase() == 'amap' ? '' : result.level,
            point: result.point,
            icon: Icons.search,
          ),
        )
        .toList(growable: false);
  }

  List<MapPlace> get _visiblePlaces {
    final places = _mode == _MapMode.planned ? _scheduledPlaces : _allPlaces;
    return places
        .where((place) =>
            _selectedCategories.contains(place.category) ||
            place.category.startsWith('Day '))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final categories = _allPlaces.map((place) => place.category).toSet();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: SearchQueryField(
            key: const ValueKey('explore-search-field'),
            controller: _searchController,
            enabled: !_searching,
            onSubmitted: (_) => _runSearch(),
            onSearch: _runSearch,
          ),
        ),
        if (_searching) const LinearProgressIndicator(),
        if (_searched)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 230),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: _SearchResultsPanel(
                results: _searchResults,
                error: _searchError,
                onAdd: widget.onAddSearchResult,
                onOpenMap: () => setState(() => _pickMode = true),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: SegmentedButton<_MapMode>(
                  segments: const [
                    ButtonSegment(
                      value: _MapMode.explore,
                      icon: Icon(Icons.travel_explore),
                      label: Text('Explore'),
                    ),
                    ButtonSegment(
                      value: _MapMode.planned,
                      icon: Icon(Icons.route_outlined),
                      label: Text('Planned'),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (selection) {
                    setState(() => _mode = selection.first);
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              for (final category in categories) ...[
                FilterChip(
                  label: Text(category),
                  selected: _selectedCategories.contains(category),
                  onSelected: (selected) {
                    setState(() {
                      selected
                          ? _selectedCategories.add(category)
                          : _selectedCategories.remove(category);
                    });
                  },
                ),
                const SizedBox(width: 8),
              ],
              FilterChip(
                avatar: const Icon(Icons.add_location_alt_outlined, size: 18),
                label: const Text('Pick point mode'),
                selected: _pickMode,
                onSelected: (selected) {
                  setState(() => _pickMode = selected);
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  if (_canShowWebAmap)
                    AmapCanvas(
                      jsKey: _amapJsKey,
                      securityCode: _amapJsSecurityCode,
                      markers: _webMarkers,
                      routeSegments: _routeSegments,
                      selectedPoint: _selectedMapPoint,
                      pickMode: _pickMode,
                      interactive: !_mapInputLocked,
                      primaryColor: scheme.primary,
                      onMarkerTapped: _handleWebMarkerTap,
                      onPointPicked: (pick) {
                        _handleWebMapTap(pick);
                      },
                    )
                  else if (_canShowNativeAmap)
                    AbsorbPointer(
                      absorbing: _mapInputLocked,
                      child: amap_map.AMapWidget(
                        apiKey: const amap_base.AMapApiKey(
                          androidKey: _amapAndroidKey,
                          iosKey: _amapIosKey,
                        ),
                        privacyStatement: const amap_base.AMapPrivacyStatement(
                          hasContains: true,
                          hasShow: true,
                          hasAgree: true,
                        ),
                        initialCameraPosition: const amap_map.CameraPosition(
                          target: amap_base.LatLng(30.2431, 120.1508),
                          zoom: 12,
                        ),
                        scaleEnabled: true,
                        compassEnabled: true,
                        touchPoiEnabled: true,
                        onTap: _pickMode
                            ? (point) {
                                _handleAmapTap(point);
                              }
                            : null,
                        markers: _markers,
                        polylines: _polylines,
                      ),
                    )
                  else
                    _AmapSetupPanel(
                      selectedPoint: _selectedMapPoint,
                      places: _visiblePlaces,
                      message: _mapSetupMessage,
                    ),
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: _MapStatusBar(
                      mode: _mode,
                      pickMode: _pickMode,
                      visibleCount: _visiblePlaces.length,
                      onRetry: widget.onRetry,
                    ),
                  ),
                  if (_pickMode)
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 12,
                      child: Card.filled(
                        color: scheme.surface.withValues(alpha: 0.94),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Icon(Icons.add_location_alt_outlined,
                                  color: scheme.primary),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _canShowAmap
                                      ? 'Tap the AMap canvas to select a destination point.'
                                      : _mapSetupMessage,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (!_pickMode && _selectedMapPick != null)
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 12,
                      child: _SelectedMapPointBar(
                        pick: _selectedMapPick!,
                        busy: _mapInputLocked,
                        onEdit: () => _openMapPickSheet(_selectedMapPick!),
                        onClear: _clearSelectedMapPoint,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _runSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searched = false;
        _searchResults = [];
        _searchError = null;
      });
      return;
    }
    setState(() {
      _searched = true;
      _searching = true;
      _searchError = null;
    });
    try {
      final results = await widget.onSearch(query);
      if (!mounted) {
        return;
      }
      setState(() {
        _searchResults = results;
        if (results.isNotEmpty) {
          _selectedCategories.add('Search');
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _searchError = error.toString();
        _searchResults = [];
      });
    } finally {
      if (mounted) {
        setState(() => _searching = false);
      }
    }
  }

  bool get _canShowAmap {
    return _canShowWebAmap || _canShowNativeAmap;
  }

  bool get _canShowWebAmap {
    return kIsWeb && _amapJsKey.isNotEmpty;
  }

  bool get _canShowNativeAmap {
    if (kIsWeb) {
      return false;
    }
    final supportedPlatform = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    final hasKey = defaultTargetPlatform == TargetPlatform.android
        ? _amapAndroidKey.isNotEmpty
        : _amapIosKey.isNotEmpty;
    return supportedPlatform && hasKey;
  }

  String get _mapSetupMessage {
    if (kIsWeb) {
      return 'AMap Web JS key is not configured. Build with --dart-define=AMAP_JS_KEY=your_js_key. If your AMap key requires a security code, also provide --dart-define=AMAP_JS_SECURITY_CODE=your_security_code.';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'AMap Android key is not configured. Build with --dart-define=AMAP_ANDROID_KEY=your_android_key for package com.idm.travelplanner.';
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'AMap iOS key is not configured. Build with --dart-define=AMAP_IOS_KEY=your_ios_key.';
    }
    return 'AMap is available on Web, Android, and iOS builds.';
  }

  List<AmapCanvasMarker> get _webMarkers {
    return _visiblePlaces
        .map(
          (place) => AmapCanvasMarker(
            id: place.id,
            title: place.name,
            subtitle: '${place.category} | ${place.description}',
            category: place.category,
            point: place.point,
            color: _markerColor(place.category),
          ),
        )
        .toList(growable: false);
  }

  List<AmapRouteSegment> get _routeSegments {
    final segments = <AmapRouteSegment>[];
    for (var dayIndex = 0; dayIndex < widget.itineraryDays.length; dayIndex++) {
      final points = widget.itineraryDays[dayIndex].items
          .map((item) => item.point)
          .whereType<LatLng>()
          .toList(growable: false);
      if (points.length > 1) {
        segments.add(
          AmapRouteSegment(
            points: points,
            color: _dayColor(dayIndex),
          ),
        );
      }
    }
    return segments;
  }

  Set<amap_map.Marker> get _markers {
    final markers = <amap_map.Marker>{};
    for (final place in _visiblePlaces) {
      markers.add(
        amap_map.Marker(
          position: _toAmapLatLng(place.point),
          icon: amap_map.BitmapDescriptor.defaultMarkerWithHue(
            _markerHue(place.category),
          ),
          infoWindow: amap_map.InfoWindow(
            title: place.name,
            snippet: '${place.category} | ${place.description}',
          ),
          onTap: (_) => widget.onPlaceSelected(place),
        ),
      );
    }
    final selected = _selectedMapPoint;
    if (selected != null) {
      markers.add(
        amap_map.Marker(
          position: _toAmapLatLng(selected),
          icon: amap_map.BitmapDescriptor.defaultMarkerWithHue(
            amap_map.BitmapDescriptor.hueRose,
          ),
          draggable: true,
          infoWindow: const amap_map.InfoWindow(
            title: 'Selected point',
            snippet: 'Drag or tap again to adjust before adding.',
          ),
          onDragEnd: (_, position) {
            _handleAmapTap(position);
          },
        ),
      );
    }
    return markers;
  }

  Set<amap_map.Polyline> get _polylines {
    final lines = <amap_map.Polyline>{};
    for (var dayIndex = 0; dayIndex < widget.itineraryDays.length; dayIndex++) {
      final points = widget.itineraryDays[dayIndex].items
          .map((item) => item.point)
          .whereType<LatLng>()
          .map(_toAmapLatLng)
          .toList(growable: false);
      if (points.length > 1) {
        lines.add(
          amap_map.Polyline(
            points: points,
            width: 8,
            color: _dayColor(dayIndex),
          ),
        );
      }
    }
    return lines;
  }

  void _handleAmapTap(amap_base.LatLng point) {
    final selected = LatLng(point.latitude, point.longitude);
    final pick = AmapPickResult(
      point: selected,
      name: 'Selected map point',
    );
    _openMapPickSheet(pick);
  }

  void _handleWebMapTap(AmapPickResult pick) {
    _openMapPickSheet(pick);
  }

  Future<void> _openMapPickSheet(AmapPickResult pick) async {
    setState(() {
      _selectedMapPick = pick;
      _selectedMapPoint = pick.point;
      _pickMode = false;
      _mapInputLocked = true;
    });
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) {
      return;
    }
    final added = await widget.onMapPointPicked(pick);
    if (!mounted) {
      return;
    }
    setState(() {
      _mapInputLocked = false;
      if (added) {
        _selectedMapPick = null;
        _selectedMapPoint = null;
      }
    });
  }

  void _clearSelectedMapPoint() {
    setState(() {
      _selectedMapPick = null;
      _selectedMapPoint = null;
      _mapInputLocked = false;
    });
  }

  void _handleWebMarkerTap(String markerId) {
    for (final place in _visiblePlaces) {
      if (place.id == markerId) {
        widget.onPlaceSelected(place);
        return;
      }
    }
  }

  Color _markerColor(String category) {
    final dayIndex = _dayIndexFromCategory(category);
    if (dayIndex != null) {
      return _dayColor(dayIndex);
    }
    switch (category) {
      case 'Food':
        return const Color(0xFFEA580C);
      case 'Nature':
        return const Color(0xFF16A34A);
      case 'Transport':
        return const Color(0xFF0284C7);
      case 'Saved Place':
        return const Color(0xFF7C3AED);
      default:
        return const Color(0xFF2563EB);
    }
  }

  double _markerHue(String category) {
    final dayIndex = _dayIndexFromCategory(category);
    if (dayIndex != null) {
      return _dayHue(dayIndex);
    }
    switch (category) {
      case 'Food':
        return amap_map.BitmapDescriptor.hueOrange;
      case 'Nature':
        return amap_map.BitmapDescriptor.hueGreen;
      case 'Transport':
        return amap_map.BitmapDescriptor.hueAzure;
      case 'Saved Place':
        return amap_map.BitmapDescriptor.hueViolet;
      default:
        return amap_map.BitmapDescriptor.hueBlue;
    }
  }
}

int? _dayIndexFromCategory(String category) {
  if (!category.startsWith('Day ')) {
    return null;
  }
  final number = int.tryParse(category.substring(4).trim());
  if (number == null || number <= 0) {
    return null;
  }
  return number - 1;
}

Color _dayColor(int dayIndex) {
  const colors = [
    Color(0xFF2563EB),
    Color(0xFF16A34A),
    Color(0xFFEA580C),
    Color(0xFF7C3AED),
    Color(0xFFDC2626),
    Color(0xFF0891B2),
    Color(0xFFCA8A04),
  ];
  return colors[dayIndex % colors.length];
}

double _dayHue(int dayIndex) {
  const hues = [
    amap_map.BitmapDescriptor.hueBlue,
    amap_map.BitmapDescriptor.hueGreen,
    amap_map.BitmapDescriptor.hueOrange,
    amap_map.BitmapDescriptor.hueViolet,
    amap_map.BitmapDescriptor.hueRed,
    amap_map.BitmapDescriptor.hueAzure,
    amap_map.BitmapDescriptor.hueYellow,
  ];
  return hues[dayIndex % hues.length];
}

class _AmapSetupPanel extends StatelessWidget {
  const _AmapSetupPanel({
    required this.selectedPoint,
    required this.places,
    required this.message,
  });

  final LatLng? selectedPoint;
  final List<MapPlace> places;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 78, 18, 18),
        children: [
          Card.filled(
            color: scheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.key_outlined, color: scheme.onErrorContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message,
                      style: TextStyle(color: scheme.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (selectedPoint != null) ...[
            const SizedBox(height: 12),
            _InfoTile(
              icon: Icons.add_location_alt_outlined,
              text:
                  'Selected: ${selectedPoint!.latitude.toStringAsFixed(6)}, ${selectedPoint!.longitude.toStringAsFixed(6)}',
            ),
          ],
          const SizedBox(height: 12),
          const _SectionHeader(
              title: 'Current Map Markers', action: 'AMap data'),
          const SizedBox(height: 10),
          for (final place in places) ...[
            _InfoTile(
              icon: place.icon,
              text: '${place.name} | ${place.category} | ${place.description}',
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _SelectedMapPointBar extends StatelessWidget {
  const _SelectedMapPointBar({
    required this.pick,
    required this.busy,
    required this.onEdit,
    required this.onClear,
  });

  final AmapPickResult pick;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final address = pick.address?.trim();
    return Card.filled(
      color: scheme.surface.withValues(alpha: 0.96),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        child: Row(
          children: [
            Icon(Icons.add_location_alt_outlined, color: scheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pick.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    address == null || address.isEmpty
                        ? '${pick.point.latitude.toStringAsFixed(6)}, ${pick.point.longitude.toStringAsFixed(6)}'
                        : address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Edit selected point',
              onPressed: busy ? null : onEdit,
              icon: const Icon(Icons.edit_location_alt_outlined),
            ),
            IconButton(
              tooltip: 'Clear selected point',
              onPressed: busy ? null : onClear,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapStatusBar extends StatelessWidget {
  const _MapStatusBar({
    required this.mode,
    required this.pickMode,
    required this.visibleCount,
    required this.onRetry,
  });

  final _MapMode mode;
  final bool pickMode;
  final int visibleCount;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.map_outlined, color: scheme.primary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                pickMode
                    ? 'AMap point-pick mode | tap map to add itinerary'
                    : mode == _MapMode.explore
                        ? 'AMap exploration | drag and zoom normally'
                        : 'Planned route view | $visibleCount visible stops',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

amap_base.LatLng _toAmapLatLng(LatLng point) {
  return amap_base.LatLng(point.latitude, point.longitude);
}

class _ItineraryScreen extends StatelessWidget {
  const _ItineraryScreen({
    required this.days,
    required this.onAddDay,
    required this.onEdit,
    required this.onDelete,
    required this.onReorder,
    required this.onDuplicate,
    required this.onOpenMap,
    required this.onSave,
  });

  final List<ItineraryDay> days;
  final VoidCallback onAddDay;
  final ValueChanged<ItineraryItem> onEdit;
  final ValueChanged<ItineraryItem> onDelete;
  final void Function(ItineraryDay day, int oldIndex, int newIndex) onReorder;
  final void Function(ItineraryDay day, ItineraryItem item) onDuplicate;
  final VoidCallback onOpenMap;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
      children: [
        Card.filled(
          color: scheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.route_outlined,
                        color: scheme.onPrimaryContainer),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${days.length} day plan',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  color: scheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Local draft now supports day creation, targeted add, edit, duplicate, and drag reorder.',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: scheme.onPrimaryContainer,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: onSave,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Save Plan'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: onAddDay,
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: const Text('Add Day'),
                    ),
                    OutlinedButton.icon(
                      onPressed: onOpenMap,
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Open Map'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (days.isEmpty) ...[
          const SizedBox(height: 16),
          Card.outlined(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('No itinerary days yet',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const Text(
                      'Create a day first, then add attractions or activities.'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: onAddDay,
                    icon: const Icon(Icons.add),
                    label: const Text('Create Day'),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        for (final day in days) ...[
          _SectionHeader(title: day.title, action: '${day.date} | ${day.city}'),
          const SizedBox(height: 4),
          Text(day.reminder),
          const SizedBox(height: 10),
          if (day.items.isEmpty)
            Card.outlined(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No activities yet. Use the add button to create the first item.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: day.items.length,
              onReorderItem: (oldIndex, newIndex) =>
                  onReorder(day, oldIndex, newIndex),
              itemBuilder: (context, index) {
                final item = day.items[index];
                return Padding(
                  key: ValueKey(item.id),
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ItineraryItemCard(
                    item: item,
                    reorderIndex: index,
                    onEdit: () => onEdit(item),
                    onDelete: () => onDelete(item),
                    onDuplicate: () => onDuplicate(day, item),
                    onOpenMap: onOpenMap,
                  ),
                );
              },
            ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _ItineraryItemCard extends StatelessWidget {
  const _ItineraryItemCard({
    required this.item,
    required this.reorderIndex,
    required this.onEdit,
    required this.onDelete,
    required this.onDuplicate,
    required this.onOpenMap,
  });

  final ItineraryItem item;
  final int reorderIndex;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 64,
              child: Column(
                children: [
                  Icon(Icons.circle, color: scheme.primary, size: 14),
                  const SizedBox(height: 8),
                  Text(
                    item.time,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.activity,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(item.place),
                  const SizedBox(height: 8),
                  Text(item.note),
                  const SizedBox(height: 8),
                  Chip(label: Text(item.status)),
                  Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        tooltip: 'Edit',
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: 'Delete',
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline),
                      ),
                      IconButton(
                        tooltip: 'Duplicate',
                        onPressed: onDuplicate,
                        icon: const Icon(Icons.copy_outlined),
                      ),
                      Tooltip(
                        message: 'Drag to reorder',
                        child: ReorderableDragStartListener(
                          index: reorderIndex,
                          child: SizedBox.square(
                            dimension: 40,
                            child: Icon(
                              Icons.drag_indicator,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Open map',
                        onPressed: onOpenMap,
                        icon: const Icon(Icons.map_outlined),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedScreen extends StatefulWidget {
  const _SavedScreen({
    required this.trips,
    required this.onAdd,
    required this.onShowInfo,
    required this.onRemove,
  });

  final List<SavedTrip> trips;
  final ValueChanged<SavedTrip> onAdd;
  final void Function(String title, String message) onShowInfo;
  final ValueChanged<SavedTrip> onRemove;

  @override
  State<_SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<_SavedScreen> {
  final _savedSearch = TextEditingController();
  final _selectedFolders = <String>{};

  @override
  void dispose() {
    _savedSearch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _savedSearch.text.trim().toLowerCase();
    final availableFolders = widget.trips
        .map((trip) => trip.folder)
        .where((folder) => folder.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final filteredTrips = widget.trips.where((trip) {
      final matchesSearch = query.isEmpty ||
          trip.destination.toLowerCase().contains(query) ||
          trip.folder.toLowerCase().contains(query) ||
          trip.dateRange.toLowerCase().contains(query);
      final matchesFolder =
          _selectedFolders.isEmpty || _selectedFolders.contains(trip.folder);
      return matchesSearch && matchesFolder;
    }).toList(growable: false);
    final upcomingTrips =
        filteredTrips.where((trip) => trip.upcoming).toList(growable: false);
    final pastTrips =
        filteredTrips.where((trip) => !trip.upcoming).toList(growable: false);
    final filterActive = query.isNotEmpty || _selectedFolders.isNotEmpty;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _SavedWorkspaceSummary(
          total: widget.trips.length,
          upcoming: widget.trips.where((trip) => trip.upcoming).length,
          folders: availableFolders.length,
        ),
        const SizedBox(height: 12),
        SearchBar(
          controller: _savedSearch,
          leading: const Icon(Icons.search),
          hintText: 'Search saved items',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        _SectionHeader(
          title: 'Collections',
          action: _selectedFolders.isEmpty
              ? 'All folders'
              : _selectedFolders.join(' | '),
        ),
        const SizedBox(height: 10),
        if (availableFolders.isEmpty)
          const _InfoTile(
            icon: Icons.bookmark_border,
            text: 'Saved destinations and copied trips will appear here.',
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final folder in availableFolders) ...[
                  FilterChip(
                    label: Text(folder),
                    selected: _selectedFolders.contains(folder),
                    onSelected: (selected) {
                      setState(() {
                        selected
                            ? _selectedFolders.add(folder)
                            : _selectedFolders.remove(folder);
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        const SizedBox(height: 16),
        if (filterActive && filteredTrips.isEmpty) ...[
          const _EmptyStateCard(
            icon: Icons.search_off_outlined,
            title: 'No matching saved trips',
            message:
                'Clear search text or folder chips to see all saved trips.',
          ),
          const SizedBox(height: 16),
        ],
        _SectionHeader(
          title: 'Upcoming',
          action: '${upcomingTrips.length} items',
        ),
        const SizedBox(height: 10),
        if (upcomingTrips.isEmpty)
          const _EmptyStateCard(
            icon: Icons.event_busy_outlined,
            title: 'No upcoming trips yet',
            message:
                'Save a destination or copy a CityWalk to build your next trip.',
          )
        else ...[
          for (final trip in upcomingTrips) ...[
            _SavedTripCard(
              trip: trip,
              onAdd: () => widget.onAdd(trip),
              onDetail: () => widget.onShowInfo(
                trip.destination,
                '${trip.dateRange}\n${trip.itemCount}\n${trip.lastUpdated}',
              ),
              onRemove: () => widget.onRemove(trip),
            ),
            const SizedBox(height: 8),
          ],
        ],
        const SizedBox(height: 16),
        _SectionHeader(
          title: 'Past & Archive',
          action: '${pastTrips.length} items',
        ),
        const SizedBox(height: 10),
        if (pastTrips.isEmpty)
          const _EmptyStateCard(
            icon: Icons.history_outlined,
            title: 'No past trips',
            message: 'Completed or archived trips will appear here later.',
          )
        else ...[
          for (final trip in pastTrips) ...[
            _SavedTripCard(
              trip: trip,
              onAdd: () => widget.onAdd(trip),
              onDetail: () => widget.onShowInfo(
                trip.destination,
                '${trip.dateRange}\n${trip.itemCount}\n${trip.lastUpdated}',
              ),
              onRemove: () => widget.onRemove(trip),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }
}

class _SavedWorkspaceSummary extends StatelessWidget {
  const _SavedWorkspaceSummary({
    required this.total,
    required this.upcoming,
    required this.folders,
  });

  final int total;
  final int upcoming;
  final int folders;

  @override
  Widget build(BuildContext context) {
    return Card.filled(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            _SavedMetric(
              icon: Icons.bookmark,
              value: '$total',
              label: 'Saved',
            ),
            _SavedMetric(
              icon: Icons.event_available_outlined,
              value: '$upcoming',
              label: 'Upcoming',
            ),
            _SavedMetric(
              icon: Icons.folder_outlined,
              value: '$folders',
              label: 'Folders',
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedMetric extends StatelessWidget {
  const _SavedMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: scheme.onPrimaryContainer),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onPrimaryContainer,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SavedTripCard extends StatelessWidget {
  const _SavedTripCard({
    required this.trip,
    required this.onDetail,
    required this.onAdd,
    required this.onRemove,
  });

  final SavedTrip trip;
  final VoidCallback onDetail;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: trip.upcoming
                    ? scheme.primaryContainer
                    : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                trip.upcoming
                    ? Icons.event_available_outlined
                    : Icons.history_outlined,
                color: trip.upcoming
                    ? scheme.onPrimaryContainer
                    : scheme.onSurfaceVariant,
                size: 21,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trip.destination,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${trip.dateRange} | ${trip.itemCount}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${trip.folder} | ${trip.lastUpdated}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'View detail',
                  onPressed: onDetail,
                  icon: const Icon(Icons.search),
                ),
                IconButton.filledTonal(
                  tooltip: 'Add to itinerary',
                  onPressed: onAdd,
                  icon: const Icon(Icons.add),
                ),
                IconButton(
                  tooltip: 'Remove',
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileScreen extends StatefulWidget {
  const _ProfileScreen({
    required this.repository,
    required this.user,
    required this.themeSource,
    required this.onThemePick,
    required this.onHelp,
    required this.onFeedback,
    required this.onShowInfo,
    required this.onLogout,
  });

  final TravelDataRepository repository;
  final AppUser user;
  final ThemeSource themeSource;
  final VoidCallback onThemePick;
  final VoidCallback onHelp;
  final VoidCallback onFeedback;
  final void Function(String title, String message) onShowInfo;
  final VoidCallback onLogout;

  @override
  State<_ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<_ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final stopCount = widget.repository.itineraryDays
        .fold<int>(0, (sum, day) => sum + day.items.length);
    final dayCount = widget.repository.itineraryDays.length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Card.filled(
          color: scheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                  child: Text(
                    widget.user.initials,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.user.displayName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: scheme.onPrimaryContainer,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.user.identifier,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: scheme.onPrimaryContainer,
                            ),
                      ),
                      const SizedBox(height: 10),
                      const Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _MetricPill(
                            icon: Icons.storage_outlined,
                            label: 'SQLite data',
                          ),
                          _MetricPill(
                            icon: Icons.verified_user_outlined,
                            label: 'Signed in',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const _SectionHeader(title: 'Travel Data'),
        const SizedBox(height: 10),
        Row(
          children: [
            _ProfileMetricCard(
              icon: Icons.calendar_today_outlined,
              value: '$dayCount',
              label: 'Days',
            ),
            const SizedBox(width: 8),
            _ProfileMetricCard(
              icon: Icons.flag_outlined,
              value: '$stopCount',
              label: 'Stops',
            ),
            const SizedBox(width: 8),
            _ProfileMetricCard(
              icon: Icons.bookmark_border,
              value: '${widget.repository.savedTrips.length}',
              label: 'Saved',
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card.outlined(
          child: ListTile(
            leading: const Icon(Icons.route_outlined),
            title: Text(widget.repository.activeItineraryTitle),
            subtitle: const Text('Current backend itinerary'),
          ),
        ),
        const SizedBox(height: 16),
        const _SectionHeader(title: 'Account Settings'),
        const SizedBox(height: 10),
        Card.outlined(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Privacy'),
                subtitle: const Text('Local SQLite account and itinerary data'),
                onTap: () => widget.onShowInfo(
                  'Privacy',
                  'This prototype stores account identifiers, saved trips, and itinerary data in the local SQLite backend.',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('Appearance'),
                subtitle: Text(widget.themeSource.label),
                onTap: widget.onThemePick,
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Sign out'),
                subtitle: const Text('Return to login screen'),
                onTap: widget.onLogout,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const _SectionHeader(title: 'Support'),
        const SizedBox(height: 10),
        Card.outlined(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.help_outline),
                title: const Text('Help Center'),
                onTap: widget.onHelp,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Contact / Feedback'),
                onTap: widget.onFeedback,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.action});

  final String title;
  final String? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        if (action != null)
          Flexible(
            child: Text(
              action!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
          ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetPadding extends StatelessWidget {
  const _SheetPadding({required this.child, this.bottomInset = 0});

  final Widget child;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottomInset),
        child: child,
      ),
    );
  }
}
