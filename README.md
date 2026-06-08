# Wayfare Flutter Front-End Prototype

This project is a Flutter + Dart implementation of the travel planning app described in the UI design document.

## Scope

- Flutter app using Material 3 components.
- Material You support through the `dynamic_color` package on Android 12+.
- AMap/Gaode map page with categorized markers, itinerary markers, route polyline, and a point-pick mode for adding map points into the itinerary.
- Manual theme sources in Profile settings: System Dynamic Color, Ocean Blue, Forest Green, Sunrise Orange, Neutral Gray, and Custom Accent Color.
- The Flutter front end calls the Dart + SQLite backend for login, scenic search, destinations, map places, itineraries, saved trips, and feedback. It shows a backend connection error instead of silently falling back to fake data.

## Implemented Screens

- Home: backend scenic-spot search, filter chips, quick actions, recommendation cards, and planning guide cards.
- Explore Map: visual map preview, categorized markers, retry state, and location bottom sheets.
- Itinerary: backend-backed day timeline, Material date picker for new days, draggable item reorder, item cards, add/edit bottom sheet, delete confirmation, and save status.
- Saved: upcoming trips, folders, saved destinations, and past travel history.
- Profile: travel preferences, settings, Material You theme picker, help center, feedback, and onboarding.

## Login

The app starts at a login screen unless a local session exists. Phone/email login calls
`POST /auth/login`: if the identifier exists, the user is signed in; if not, a small-team user
record is created in SQLite and the user is signed in. The backend returns an opaque
Bearer session token backed by a revocable SQLite `sessions` table. User-owned
itinerary, saved-trip, and feedback routes require that token.

## Backend Scaffold

Run the Dart + SQLite backend prototype:

```powershell
$env:Path='C:\Program Files\Flutter\bin;'+$env:Path
cd backend
dart run bin/server.dart
```

Default API base: `http://127.0.0.1:8080`

Default health check: `http://127.0.0.1:8080/health`

SQLite database path: `backend/data/wayfare.sqlite`

Search endpoint: `GET /search?q=橘子洲`

Recommended local environment:

```powershell
$env:WAYFARE_AUTH_SECRET='replace-with-a-long-random-local-secret'
$env:WAYFARE_ALLOWED_ORIGINS='http://127.0.0.1:8092,http://localhost:8092'
$env:WAYFARE_DB_PATH='data/wayfare.sqlite'
dart run bin/server.dart
```

For any shared or deployed environment, set `WAYFARE_AUTH_SECRET` and a narrow
`WAYFARE_ALLOWED_ORIGINS` value. Without `WAYFARE_AUTH_SECRET`, the backend uses
a local development signing secret and reports `auth: development` from `/health`.
The backend also enables per-client fixed-window rate limiting for auth, search,
and write routes by default; see `backend/README.md` for environment overrides.
Set `WAYFARE_OPS_TOKEN` to enable protected aggregate metrics at `/ops/metrics`.
Set `WAYFARE_BACKUP_DIR` and run `dart run bin/backup.dart` from `backend/` to
create verified SQLite backups with manifests.

The current seed data includes 4A+ scenic spots and urban-core attractions for first-tier and 2025 new first-tier-or-above cities. Full national 4A+ coverage can be imported by extending `scenic_spots` with an official CSV/source list.

## AMap / Gaode Key

Android package/application id: `com.idm.travelplanner`

Run with a real AMap Android key:

```powershell
$env:Path='C:\Program Files\Flutter\bin;'+$env:Path
flutter run --dart-define=AMAP_ANDROID_KEY=your_amap_android_key
```

Without a key, the map page shows a setup panel instead of a blank map.

## Run

Install Flutter, then run:

```powershell
$env:Path='C:\Program Files\Flutter\bin;'+$env:Path
flutter pub get
flutter run
flutter build web
```

For web release testing, run the backend first, then build and serve `build/web`:

```powershell
$env:Path='C:\Program Files\Flutter\bin;'+$env:Path
cd backend
dart run bin/server.dart
```

In another terminal:

```powershell
$env:Path='C:\Program Files\Flutter\bin;'+$env:Path
flutter build web --release --pwa-strategy=none
python -m http.server 8092 --bind 127.0.0.1 --directory build/web
```

To point the web build at another backend:

```powershell
flutter build web --release --pwa-strategy=none --dart-define=WAYFARE_API_BASE=https://api.example.com
```

## Release Readiness

Run the local release gate before handing off a build:

```powershell
dart run tool/release_readiness.dart --mode local
```

For a commercial release, provide production values and run:

```powershell
dart run tool/release_readiness.dart --mode release
```

Release mode requires a strong `WAYFARE_AUTH_SECRET`, HTTPS-only
`WAYFARE_ALLOWED_ORIGINS`, a production HTTPS `WAYFARE_API_BASE`, real
`AMAP_JS_KEY`, `AMAP_JS_SECURITY_CODE`, and `AMAP_ANDROID_KEY` values, plus
Android release signing credentials. Android signing can come from environment
variables:

```powershell
$env:WAYFARE_ANDROID_KEYSTORE='C:\secure\wayfare-release.jks'
$env:WAYFARE_ANDROID_STORE_PASSWORD='store-password'
$env:WAYFARE_ANDROID_KEY_ALIAS='wayfare'
$env:WAYFARE_ANDROID_KEY_PASSWORD='key-password'
```

or from an ignored `android/key.properties` file:

```properties
storeFile=C:\\secure\\wayfare-release.jks
storePassword=store-password
keyAlias=wayfare
keyPassword=key-password
```

The Gradle release build no longer signs with debug keys. If release signing is
missing, Android release tasks fail instead of producing a misleading package.

For Android builds, make sure Android Studio / Android SDK is installed and Flutter can see it:

```powershell
flutter doctor
flutter build apk
```

For Windows desktop builds with plugins, enable Developer Mode so Flutter can create symlinks:

```powershell
start ms-settings:developers
```
