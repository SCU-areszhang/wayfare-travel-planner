# Wayfare Flutter Front-End Prototype

This project is a Flutter + Dart implementation of the travel planning app described in the UI design document.

## Scope

- Flutter app using Material 3 components.
- Material You support through the `dynamic_color` package on Android 12+.
- China itinerary map page with local zoom, drag, categorized markers, and route context. It does not depend on online OSM/Gaode tile loading.
- Manual theme sources in Profile settings: System Dynamic Color, Ocean Blue, Forest Green, Sunrise Orange, Neutral Gray, and Custom Accent Color.
- Flutter front end still uses mock data. A Dart backend scaffold is available in `backend/` for auth, destinations, map places, itineraries, saved trips, and feedback.

## Implemented Screens

- Home: search, filter chips, quick actions, recommendation cards, and planning guide cards.
- Explore Map: visual map preview, categorized markers, retry state, and location bottom sheets.
- Itinerary: day timeline, add-day flow, draggable item reorder, item cards, add/edit bottom sheet, delete confirmation, save status.
- Saved: upcoming trips, folders, saved destinations, and past travel history.
- Profile: phone login placeholder, social login placeholders, travel preferences, settings, Material You theme picker, help center, feedback, and onboarding.

## Backend Scaffold

Run the Dart-only backend prototype:

```powershell
$env:Path='C:\Program Files\Flutter\bin;'+$env:Path
cd backend
dart run bin/server.dart
```

Default health check: `http://localhost:8080/health`

## Run

Install Flutter, then run:

```powershell
$env:Path='C:\Program Files\Flutter\bin;'+$env:Path
flutter pub get
flutter run
flutter build web
```

For Android builds, make sure Android Studio / Android SDK is installed and Flutter can see it:

```powershell
flutter doctor
flutter build apk
```

For Windows desktop builds with plugins, enable Developer Mode so Flutter can create symlinks:

```powershell
start ms-settings:developers
```
