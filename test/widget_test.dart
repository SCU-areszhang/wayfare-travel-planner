import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wayfare_travel_planner/main.dart';

void main() {
  testWidgets('Wayfare app logs in and renders home dashboard', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(WayfareApp(backend: const _FakeBackend()));
    await tester.pumpAndSettle();

    expect(find.text('Wayfare'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);

    await tester.enterText(
      find.byType(EditableText),
      'demo@wayfare.local',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Test Trip'), findsOneWidget);
    expect(find.text('Find Places'), findsOneWidget);
    expect(find.text('System CityWalks'), findsOneWidget);
    expect(find.text('Plan'), findsOneWidget);
  });
}

class _FakeBackend implements WayfareBackend {
  const _FakeBackend();

  @override
  void setSessionToken(String? token) {}

  @override
  Future<BackendLoginResult> loginOrRegister(String identifier) async {
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
  Future<TravelDataRepository> loadTravelData(String userId) async {
    return TravelDataRepository(
      activeItineraryId: 'trip-test',
      activeItineraryTitle: 'Test Trip',
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
      itineraryDays: [],
      mapPlaces: [],
      savedTrips: [],
    );
  }

  @override
  Future<List<TravelSearchResult>> searchPlaces(String query) async {
    return const [
      TravelSearchResult(
        id: 'spot-test',
        name: 'West Lake',
        subtitle: 'Hangzhou · Xihu',
        intro: 'Classic lakeside views and easy walks',
        level: '4A',
        sourceType: 'scenic_spot',
        point: LatLng(30.2431, 120.1508),
      ),
    ];
  }

  @override
  Future<ItineraryDay> addDay(
    String itineraryId, {
    required String title,
    required String date,
    required String city,
    required String reminder,
  }) async {
    return ItineraryDay(
      id: 'day-test',
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
    return ItineraryItem(
      id: 'item-test',
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
    return addItem(
      itineraryId,
      targetDayId,
      time: time,
      place: place,
      activity: activity,
      note: note,
      point: point,
    );
  }

  @override
  Future<void> deleteItem(
      String itineraryId, String dayId, String itemId) async {}

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
      String userId, Destination destination) async {
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
