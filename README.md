# Wayfare Travel Planner

A Flutter travel planning prototype with AMap (Gaode) integration and a Dart + SQLite backend.

## Quick Start

### 1. Set up AMap keys

```bash
cp AmapExample.csv Amap.csv
# Edit Amap.csv with your real keys
```

`Amap.csv` format:

```text
Wayfare_WebSvc, <backend web-service key>
Wayfare_WebJS, <web js key>
Security_code, <js security code>
Wayfare_Android, <android native key>
Wayfare_iOS, <ios native key>
```

### 2. Start backend

```bash
dart run tool/start_backend.dart
```

Binds to `0.0.0.0:8080` by default. Reads `AMAP_WEB_SERVICE_KEY` from `Amap.csv` automatically.

### 3. Build & run

| Task | Command |
| --- | --- |
| **Web hot reload** | `dart run tool/flutter_run.dart` |
| **One-command demo** (backend + web + smoke test) | `dart run tool/local_demo.dart` |
| **Build Android APK** | `dart run tool/build_android.dart --api-base=http://<LAN_IP>:8080` |
| **Build iOS IPA** | `dart run tool/build_ios.dart --api-base=http://<LAN_IP>:8080` |
| **Smoke test** (backend must be running) | `dart run tool/local_smoke.dart` |
| **Release readiness check** | `dart run tool/release_readiness.dart --mode=local` |

All tools auto-read `Amap.csv` — no need to type keys on the command line.

## Android APK Install

```bash
adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

For emulators: `adb reverse tcp:8080 tcp:8080`

## Android Release Signing

Create `android/key.properties` (git-ignored):

```properties
storePassword=your-password
keyPassword=your-password
keyAlias=your-alias
storeFile=/path/to/your-release.keystore
```

Register the keystore's SHA1 with your AMap Android key at [console.amap.com](https://console.amap.com).

## AMap Key Reference

| Define | Used by | Purpose |
| --- | --- | --- |
| `AMAP_JS_KEY` | Web | AMap Web JS API key |
| `AMAP_JS_SECURITY_CODE` | Web | Security code paired with JS key |
| `AMAP_ANDROID_KEY` | Android | AMap Android native key |
| `AMAP_IOS_KEY` | iOS | AMap iOS native key |
| `WAYFARE_API_BASE` | all | Backend URL (default `http://127.0.0.1:8080`) |

## Backend Configuration

| Env var | Purpose |
| --- | --- |
| `WAYFARE_BIND_HOST` | Bind address (default `127.0.0.1`) |
| `PORT` | Server port (default `8080`) |
| `WAYFARE_DB_PATH` | SQLite path (default `data/wayfare.sqlite`) |
| `WAYFARE_AUTH_SECRET` | Session-token signing secret |
| `WAYFARE_OPS_TOKEN` | Protected metrics token |
| `WAYFARE_ALLOWED_ORIGINS` | CORS allowlist |
| `AMAP_WEB_SERVICE_KEY` | Auto-loaded from `Amap.csv` |

## Testing

```bash
flutter analyze
flutter test
dart run tool/release_readiness.dart --mode=local
```

## Project Structure

```text
├── lib/
│   ├── main.dart                 # app: models, API client, state, screens
│   ├── scenic_spots_5a.dart      # built-in 5A scenic spot library
│   └── amap_canvas_web.dart      # Web AMap JS bridge
├── backend/
│   ├── bin/server.dart           # HTTP server, routes, SQLite
│   └── data/wayfare.sqlite       # local prototype data
├── tool/
│   ├── start_backend.dart        # start backend (reads Amap.csv)
│   ├── build_android.dart        # build Android APK
│   ├── build_ios.dart            # build iOS IPA (macOS only)
│   ├── flutter_run.dart          # hot reload with AMap keys
│   ├── local_demo.dart           # one-command demo
│   ├── local_smoke.dart          # smoke test
│   └── release_readiness.dart    # release gate check
└── Amap.csv                      # your keys (git-ignored)
```

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| Map shows setup panel | No AMap key — ensure `Amap.csv` exists with valid keys |
| "Backend is not reachable" | Start backend: `dart run tool/start_backend.dart` |
| Android can't reach backend | Backend must bind to `0.0.0.0`, use `--api-base=http://<LAN_IP>:8080` |
| Stale UI after rebuild | Hard-refresh (Ctrl+Shift+R) |
