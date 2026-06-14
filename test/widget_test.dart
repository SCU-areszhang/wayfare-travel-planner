import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wayfare_travel_planner/main.dart';

void main() {
  testWidgets('login screen omits M3 badge and renders home dashboard', (
    tester,
  ) async {
    final backend = _FakeBackend();
    await _pumpLoggedOutApp(tester, backend);

    expect(find.text('Wayfare'), findsOneWidget);
    expect(find.text('M3'), findsNothing);

    await _login(tester);

    expect(find.text('Test Trip'), findsOneWidget);
    expect(find.text('Recommend for You'), findsOneWidget);
    expect(find.text('Featured 5A Scenic Spots'), findsOneWidget);
    expect(find.text('Plan'), findsOneWidget);
  });

  testWidgets('home search results use compact add buttons', (tester) async {
    final backend = _FakeBackend();
    await _pumpLoggedInApp(tester, backend);

    final searchField = find.byKey(const ValueKey('home-search-field'));
    await tester.enterText(
      find.descendant(of: searchField, matching: find.byType(EditableText)),
      'West Lake',
    );
    await tester.tap(
      find.descendant(of: searchField, matching: find.byTooltip('Search')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Quick Add'), findsNothing);
    expect(
      find.byKey(const ValueKey('search-result-add-spot-west')),
      findsOneWidget,
    );
  });

  testWidgets('citywalk copy asks for a target day and appends stops', (
    tester,
  ) async {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final backend = _FakeBackend(
      days: [
        ItineraryDay(
          id: 'day-future',
          title: 'Day 1',
          date: _testIsoDate(tomorrow),
          city: 'Chengdu',
          reminder: 'Existing schedule stays intact',
          items: [
            ItineraryItem(
              id: 'item-existing',
              time: '09:00',
              place: 'Existing Stop',
              activity: 'Already planned',
              note: 'Keep this item',
              status: 'Saved',
            ),
          ],
        ),
      ],
    );
    await _pumpLoggedInApp(tester, backend);

    // Hot Citywalks is collapsed by default; expand it before interacting.
    await tester.tap(find.text('Hot Citywalks'));
    await tester.pumpAndSettle();

    final copyButton = find.byKey(
      const ValueKey('copy-citywalk-citywalk-chengdu-kuanzhai'),
    );
    await tester.ensureVisible(copyButton.first);
    await tester.pumpAndSettle();
    await tester.tap(copyButton.first);
    await tester.pumpAndSettle();

    expect(find.text('Copy CityWalk to Day'), findsOneWidget);
    expect(find.textContaining('Existing activities are kept'), findsOneWidget);

    await tester.tap(find.text('Copy to selected day'));
    await tester.pumpAndSettle();

    expect(backend.addItemCalls, hasLength(3));
    expect(
      backend.addItemCalls.every((call) => call.dayId == 'day-future'),
      isTrue,
    );
  });

  testWidgets('home hero selects nearest unfinished itinerary item', (
    tester,
  ) async {
    final now = DateTime.now();
    final backend = _FakeBackend(
      days: [
        ItineraryDay(
          id: 'day-past',
          title: 'Past Day',
          date: _testIsoDate(now.subtract(const Duration(days: 1))),
          city: 'Past',
          reminder: '',
          items: [
            ItineraryItem(
              id: 'item-past',
              time: '09:00',
              place: 'Past Stop',
              activity: 'Done',
              note: '',
              status: 'Saved',
            ),
          ],
        ),
        ItineraryDay(
          id: 'day-future',
          title: 'Future Day',
          date: _testIsoDate(now.add(const Duration(days: 1))),
          city: 'Future',
          reminder: '',
          items: [
            ItineraryItem(
              id: 'item-future',
              time: '08:00',
              place: 'Future Museum',
              activity: 'Visit',
              note: '',
              status: 'Saved',
            ),
          ],
        ),
      ],
    );
    await _pumpLoggedInApp(tester, backend);

    final nextPlace = tester.widget<Text>(
      find.byKey(const ValueKey('home-next-itinerary-place')),
    );
    expect(nextPlace.data, 'Future Museum');
  });

  testWidgets('featured 5A spot searches silently before add sheet', (
    tester,
  ) async {
    final backend = _FakeBackend(
      days: [
        ItineraryDay(
          id: 'day-target',
          title: 'Day 1',
          date: _testIsoDate(DateTime.now().add(const Duration(days: 1))),
          city: 'Huangshan',
          reminder: '',
          items: [],
        ),
      ],
    );
    await _pumpLoggedInApp(tester, backend);

    // Featured 5A is collapsed by default; expand it before interacting.
    await tester.tap(find.text('Featured 5A Scenic Spots'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('featured-scenic-add-黄山风景区')));
    await tester.pumpAndSettle();

    expect(backend.searchQueries, contains('黄山风景区'));
    expect(find.text('Add to Itinerary'), findsOneWidget);
    expect(find.text('黄山风景区'), findsWidgets);
  });

  testWidgets('scenic tag chip swaps examples and browse-all opens the list', (
    tester,
  ) async {
    final backend = _FakeBackend(
      days: [
        ItineraryDay(
          id: 'day-target',
          title: 'Day 1',
          date: _testIsoDate(DateTime.now().add(const Duration(days: 1))),
          city: 'Pingyao',
          reminder: '',
          items: [],
        ),
      ],
    );
    await _pumpLoggedInApp(tester, backend);

    // Featured 5A is collapsed by default; expand it before interacting.
    await tester.tap(find.text('Featured 5A Scenic Spots'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('scenic-tag-街巷')));
    await tester.pumpAndSettle();

    // Selecting a tag only swaps the inline example chips; no sheet yet.
    expect(find.text('街巷 · 5A Scenic Spots'), findsNothing);
    expect(
      find.byKey(const ValueKey('featured-scenic-add-平遥古城')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('scenic-browse-all')));
    await tester.pumpAndSettle();

    expect(find.text('街巷 · 5A Scenic Spots'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('scenic-sheet-平遥古城')));
    await tester.pumpAndSettle();

    expect(backend.searchQueries, contains('平遥古城'));
    expect(find.text('Add to Itinerary'), findsOneWidget);
  });

  testWidgets('saved page renders workspace filters and compact actions', (
    tester,
  ) async {
    final backend = _FakeBackend(
      savedTrips: const [
        SavedTrip(
          id: 'saved-weekend',
          destination: 'West Lake',
          dateRange: 'Saved destination',
          itemCount: 'Backend record',
          lastUpdated: 'Stored',
          folder: 'Weekend',
          upcoming: true,
        ),
        SavedTrip(
          id: 'saved-history',
          destination: 'Old Town',
          dateRange: 'Archived',
          itemCount: 'Backend record',
          lastUpdated: 'Stored',
          folder: 'Street',
          upcoming: false,
          type: 'itinerary',
          refId: 'trip-history',
        ),
      ],
    );
    await _pumpLoggedInApp(tester, backend);

    await _tapRailDestination(tester, 'Saved');

    expect(find.text('Collections'), findsOneWidget);
    expect(find.text('Saved itineraries'), findsOneWidget);
    expect(find.text('Upcoming'), findsNothing);
    // The folder name shows on the filter chip and as the card label.
    expect(find.text('Weekend'), findsWidgets);
    expect(find.text('Plan'), findsWidgets);
    expect(find.byTooltip('Add to itinerary'), findsWidgets);
    expect(find.byTooltip('Remove'), findsWidgets);
  });

  testWidgets('saved page stacks card actions on narrow Android widths', (
    tester,
  ) async {
    final backend = _FakeBackend(
      savedTrips: const [
        SavedTrip(
          id: 'saved-mobile-plan',
          destination: 'A Very Detailed Chengdu Food And Culture Plan',
          dateRange: '2026-06-14 - 2026-06-21',
          itemCount: '12 stops',
          lastUpdated: 'Saved today',
          folder: 'Itineraries',
          upcoming: true,
          type: 'itinerary',
          refId: 'trip-mobile',
        ),
      ],
    );
    await _pumpLoggedInApp(tester, backend, viewSize: const Size(430, 900));

    await _tapBottomDestination(tester, 'Saved');

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Switch'), findsOneWidget);
    expect(find.text('Details'), findsOneWidget);
    expect(find.text('Remove'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('itinerary actions omit saved chip and move across dates', (
    tester,
  ) async {
    final firstDate = _testIsoDate(DateTime.now().add(const Duration(days: 1)));
    final secondDate = _testIsoDate(
      DateTime.now().add(const Duration(days: 2)),
    );
    final backend = _FakeBackend(
      days: [
        ItineraryDay(
          id: 'day-target',
          title: firstDate,
          date: firstDate,
          city: 'Hangzhou',
          reminder: '',
          items: [
            ItineraryItem(
              id: 'item-target',
              time: '10:00',
              place: 'West Lake',
              activity: 'Walk',
              note: 'Keep the morning easy.',
              status: 'Saved',
            ),
          ],
        ),
        ItineraryDay(
          id: 'day-target-2',
          title: secondDate,
          date: secondDate,
          city: 'Suzhou',
          reminder: '',
          items: [],
        ),
      ],
    );
    await _pumpLoggedInApp(tester, backend);

    await _tapRailDestination(tester, 'Itinerary');

    expect(find.text('Save Plan'), findsNothing);
    expect(find.widgetWithText(Chip, 'Saved'), findsNothing);
    expect(find.text('Test Trip'), findsOneWidget);
    expect(find.byTooltip('More actions'), findsOneWidget);
    expect(find.byTooltip('Drag to move within this date'), findsNothing);

    // Move was promoted into the overflow menu in the mobile UI pass.
    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move to date').last);
    await tester.pumpAndSettle();
    expect(find.text('Move Itinerary Item'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('move-item-day-0-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(secondDate).last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Move'));
    await tester.pumpAndSettle();

    expect(backend.updateItemCalls, hasLength(1));
    expect(backend.updateItemCalls.single.targetDayId, 'day-target-2');
  });

  testWidgets('saved itinerary selection switches the active itinerary', (
    tester,
  ) async {
    final backend = _FakeBackend(
      savedTrips: const [
        SavedTrip(
          id: 'itinerary:trip-history',
          destination: 'Old Town',
          dateRange: '2026-06-08',
          itemCount: '0 stops',
          lastUpdated: 'Stored',
          folder: 'Itineraries',
          upcoming: true,
          type: 'itinerary',
          refId: 'trip-history',
        ),
      ],
    );
    await _pumpLoggedInApp(tester, backend);

    await _tapRailDestination(tester, 'Saved');
    await tester.tap(find.text('Old Town'));
    await tester.pumpAndSettle();

    expect(backend.requestedActiveItineraryId, 'trip-history');
    expect(find.text('Selected Trip'), findsOneWidget);
  });

  testWidgets('itinerary date card can delete an entire day', (tester) async {
    final date = _testIsoDate(DateTime.now().add(const Duration(days: 1)));
    final backend = _FakeBackend(
      days: [
        ItineraryDay(
          id: 'day-delete',
          title: date,
          date: date,
          city: 'Hangzhou',
          reminder: 'Light day',
          items: [],
        ),
      ],
    );
    await _pumpLoggedInApp(tester, backend);

    await _tapRailDestination(tester, 'Itinerary');
    expect(find.text(date), findsOneWidget);
    await tester.tap(find.byTooltip('Delete date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(backend.deletedDayIds, ['day-delete']);
    expect(find.text(date), findsNothing);
  });
}

Future<void> _pumpLoggedOutApp(
  WidgetTester tester,
  _FakeBackend backend, {
  Size viewSize = const Size(1000, 1200),
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = viewSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(WayfareApp(backend: backend));
  await tester.pumpAndSettle();
}

Future<void> _pumpLoggedInApp(
  WidgetTester tester,
  _FakeBackend backend, {
  Size viewSize = const Size(1000, 1200),
}) async {
  await _pumpLoggedOutApp(tester, backend, viewSize: viewSize);
  await _login(tester);
}

Future<void> _login(WidgetTester tester) async {
  await tester.enterText(find.byType(EditableText).first, 'demo@wayfare.local');
  await tester.enterText(find.byType(EditableText).at(1), 'demo-password');
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
}

Future<void> _tapRailDestination(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationRail),
      matching: find.text(label),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapBottomDestination(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

String _testIsoDate(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

class _DayPatch {
  const _DayPatch({required this.dayId, this.city});
  final String dayId;
  final String? city;
}

class _AddItemCall {
  const _AddItemCall({required this.dayId, required this.place});

  final String dayId;
  final String place;
}

class _UpdateItemCall {
  const _UpdateItemCall({
    required this.dayId,
    required this.itemId,
    required this.targetDayId,
  });

  final String dayId;
  final String itemId;
  final String targetDayId;
}

class _FakeBackend implements WayfareBackend {
  _FakeBackend({List<ItineraryDay>? days, List<SavedTrip>? savedTrips})
    : days = days ?? <ItineraryDay>[],
      savedTrips = savedTrips ?? <SavedTrip>[];

  final List<ItineraryDay> days;
  final List<SavedTrip> savedTrips;
  final addItemCalls = <_AddItemCall>[];
  final updateItemCalls = <_UpdateItemCall>[];
  final searchQueries = <String>[];
  final deletedDayIds = <String>[];
  final updatedDayPatches = <_DayPatch>[];
  final createdItineraryTitles = <String>[];
  String? requestedActiveItineraryId;
  var _itemCounter = 0;
  var _dayCounter = 0;

  @override
  void setSessionToken(String? token) {}

  @override
  Future<BackendLoginResult> loginOrRegister(
    String identifier,
    String password,
  ) async {
    final expiresAt = DateTime.now().toUtc().add(const Duration(days: 7));
    return BackendLoginResult(
      registered: true,
      user: AppUser(
        id: 'user-test',
        identifier: identifier,
        displayName: 'Test Traveler',
        sessionToken: 'fake-session-token',
        sessionExpiresAt: expiresAt,
      ),
      sessionToken: 'fake-session-token',
      sessionExpiresAt: expiresAt,
    );
  }

  @override
  Future<void> logout() async {}

  @override
  Future<String> updateDisplayName(String displayName) async => displayName;

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {}

  @override
  Future<TravelDataRepository> loadTravelData(
    String userId, {
    String? activeItineraryId,
  }) async {
    requestedActiveItineraryId = activeItineraryId;
    return TravelDataRepository(
      activeItineraryId: activeItineraryId ?? 'trip-test',
      activeItineraryTitle: activeItineraryId == null
          ? 'Test Trip'
          : 'Selected Trip',
      destinations: const [
        Destination(
          id: 'dest-test',
          name: 'Hangzhou Lakeside',
          theme: 'Nature + Culture',
          duration: '2 days',
          reason: 'Recommended by backend rules',
          summary: 'West Lake, tea fields, evening streets, and easy walks.',
          tone: Color(0xFF4E8A7E),
          priority: true,
          point: LatLng(30.2431, 120.1508),
        ),
      ],
      itineraryDays: days,
      mapPlaces: <MapPlace>[],
      savedTrips: savedTrips,
    );
  }

  @override
  Future<TravelDataRepository> createItinerary(
    String userId, {
    required String title,
    required String destination,
    required String startDate,
    required String endDate,
  }) async {
    createdItineraryTitles.add(title);
    return TravelDataRepository(
      activeItineraryId: 'trip-created',
      activeItineraryTitle: title,
      destinations: const [],
      itineraryDays: [],
      mapPlaces: <MapPlace>[],
      savedTrips: [
        ...savedTrips,
        SavedTrip(
          id: 'itinerary:trip-created',
          destination: title,
          dateRange: '$startDate - $endDate',
          itemCount: '0 stops',
          lastUpdated: 'Saved just now',
          folder: 'Itineraries',
          upcoming: true,
          type: 'itinerary',
          refId: 'trip-created',
        ),
      ],
    );
  }

  @override
  Future<List<TravelSearchResult>> searchPlaces(String query) async {
    searchQueries.add(query);
    final normalizedName = query == 'West Lake' ? 'West Lake' : query;
    final id = query == 'West Lake' ? 'spot-west' : 'spot-$query';
    return [
      TravelSearchResult(
        id: id,
        name: normalizedName,
        subtitle: 'China · Scenic spot',
        intro: 'Search-backed scenic recommendation',
        level: '5A',
        sourceType: 'scenic_spot',
        point: const LatLng(30.1302, 118.1662),
      ),
    ];
  }

  @override
  Future<AmapPickResult> reverseGeocode(
    LatLng point, {
    String? fallbackName,
  }) async {
    final name = fallbackName?.trim();
    return AmapPickResult(
      point: point,
      name: name == null || name.isEmpty ? 'Selected map point' : name,
      address:
          'Lat ${point.latitude.toStringAsFixed(6)}, Lng ${point.longitude.toStringAsFixed(6)}',
    );
  }

  @override
  Future<ItineraryDay> addDay(
    String itineraryId, {
    required String title,
    required String date,
    required String city,
    required String reminder,
  }) async {
    _dayCounter += 1;
    return ItineraryDay(
      id: 'day-created-$_dayCounter',
      title: title,
      date: date,
      city: city,
      reminder: reminder,
      items: [],
    );
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
    _itemCounter += 1;
    addItemCalls.add(_AddItemCall(dayId: dayId, place: place));
    return ItineraryItem(
      id: 'item-created-$_itemCounter',
      time: time,
      place: place,
      activity: activity,
      note: note,
      status: 'Saved',
      point: point,
    );
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
    _itemCounter += 1;
    updateItemCalls.add(
      _UpdateItemCall(dayId: dayId, itemId: itemId, targetDayId: targetDayId),
    );
    return ItineraryItem(
      id: 'item-updated-$_itemCounter',
      time: time,
      place: place,
      activity: activity,
      note: note,
      status: 'Saved',
      point: point,
    );
  }

  @override
  Future<void> deleteItem(
    String itineraryId,
    String dayId,
    String itemId,
  ) async {}

  @override
  Future<void> deleteDay(String itineraryId, String dayId) async {
    deletedDayIds.add(dayId);
  }

  @override
  Future<ItineraryDay> updateDay(
    String itineraryId,
    String dayId, {
    String? title,
    String? city,
    String? reminder,
  }) async {
    for (final day in days) {
      if (day.id == dayId) {
        if (title != null) day.title = title;
        if (city != null) day.city = city;
        if (reminder != null) day.reminder = reminder;
        updatedDayPatches.add(_DayPatch(dayId: dayId, city: city));
        return day;
      }
    }
    throw StateError('Unknown day $dayId');
  }

  @override
  Future<List<ItineraryItem>> reorderItems(
    String itineraryId,
    String dayId,
    List<String> itemIds,
  ) async {
    return [];
  }

  @override
  Future<void> savePlan(String itineraryId) async {}

  @override
  Future<SavedTrip> saveDestination(
    String userId,
    Destination destination,
  ) async {
    return SavedTrip(
      id: 'saved-test',
      destination: destination.name,
      dateRange: 'Saved destination',
      itemCount: 'Backend record',
      lastUpdated: 'Stored',
      folder: destination.theme,
      upcoming: true,
    );
  }

  @override
  Future<void> deleteSavedTrip(String savedTripId) async {}

  @override
  Future<void> submitFeedback({
    required String userId,
    required String category,
    required String description,
  }) async {}
}
