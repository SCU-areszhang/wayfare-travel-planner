# Wayfare Travel Planner

![Flutter](https://img.shields.io/badge/Flutter-%E2%89%A53.41_stable-blue)
![Dart](https://img.shields.io/badge/Dart-%E2%89%A53.11-blue)
![Material 3](https://img.shields.io/badge/Material-3-purple)
![Backend](https://img.shields.io/badge/Backend-Dart_%2B_SQLite-green)
![Map](https://img.shields.io/badge/Map-AMap%2FGaode-orange)

A one-stop travel planning prototype: discover destinations, browse 5A scenic
spots by tag, plan day-by-day itineraries on an interactive AMap, and keep
saved trips in sync with a local Dart + SQLite backend.

> Works on **Windows, Linux, and macOS** for development. App targets are
> Web, Android, and iOS. All `flutter` / `dart` commands below are identical
> on every OS — only environment-variable syntax differs, see
> [Platform Notes](#platform-notes).

## Contents

- [Features](#features)
- [Requirements](#requirements)
- [Quick Start](#quick-start)
- [Platform Notes](#platform-notes)
- [AMap / Gaode Keys](#amap--gaode-keys)
- [Web Release Build](#web-release-build)
- [One-Command Local Demo](#one-command-local-demo)
- [Backend Configuration](#backend-configuration)
- [Testing & Quality Gates](#testing--quality-gates)
- [Android Release Signing](#android-release-signing)
- [Troubleshooting](#troubleshooting)
- [Project Structure](#project-structure)

## Features

- **Home** — backend scenic-spot search, built-in **5A scenic spot library**
  browsable by tag (自然 / 人文 / 购物 / 探险 / 都市 / 街巷), system CityWalk
  templates that copy into a chosen itinerary day, and a hero card showing the
  nearest upcoming plan item.
- **Explore Map** — AMap canvas with categorized markers, per-day route
  polylines, marker bottom sheets, and a point-pick mode that adds map points
  straight into the itinerary.
- **Itinerary** — day timeline backed by the server: add / edit / duplicate /
  delete, drag-to-reorder, Material date picker for new days, save status.
- **Saved** — searchable, folder-filtered collection of upcoming and past
  trips.
- **Profile** — travel preferences, Material You theme picker (System Dynamic
  Color, Ocean Blue, Forest Green, Sunrise Orange, Neutral Gray, Custom
  Accent), help center, feedback, onboarding.
- **Login** — phone/email sign-in with auto-registration. The backend issues a
  revocable Bearer session token stored in a SQLite `sessions` table; all
  user-owned routes require it.

The front end always talks to the real backend — it shows an explicit
connection error instead of silently falling back to fake data.

## Requirements

| Tool | Minimum version | Notes |
| --- | --- | --- |
| Flutter | **3.41 stable** | Team floor; newer stable versions work. Enforced via the Dart SDK constraint in `pubspec.yaml`. |
| Dart | **3.11** | Ships with Flutter ≥3.41. |
| Python | 3.x | Only for serving the web release build locally. |
| Android Studio / SDK | latest stable | Only for Android builds (`flutter doctor` must be green). |

Check your toolchain:

```bash
flutter --version
flutter doctor
```

## Quick Start

Two terminals: one for the backend, one for the app.

**Terminal 1 — backend** (serves `http://127.0.0.1:8080`):

```bash
cd backend
dart pub get
dart run bin/server.dart
```

Verify: open <http://127.0.0.1:8080/health>.

**Terminal 2 — app:**

```bash
flutter pub get
flutter run -d chrome        # or: flutter run (pick a device)
```

Without an AMap key the map page shows a setup panel instead of a blank map —
everything else works. To get a real map, see
[AMap / Gaode Keys](#amap--gaode-keys).

## Platform Notes

`flutter` / `dart` / `git` commands are identical everywhere. The only
differences are shell syntax:

| Task | macOS / Linux (bash, zsh) | Windows (PowerShell) |
| --- | --- | --- |
| Add Flutter to PATH | `export PATH="$HOME/flutter/bin:$PATH"` | `$env:Path='C:\Program Files\Flutter\bin;'+$env:Path` |
| Set an env var | `export WAYFARE_AUTH_SECRET='...'` | `$env:WAYFARE_AUTH_SECRET='...'` |
| Serve a folder over HTTP | `python3 -m http.server 8092 --bind 127.0.0.1 --directory build/web` | `python -m http.server 8092 --bind 127.0.0.1 --directory build/web` |
| Path separator | `/` | `\` (but `/` also works inside Flutter/Dart tooling) |

Platform-specific extras:

- **Windows:** for Windows *desktop* builds with plugins, enable Developer
  Mode so Flutter can create symlinks: `start ms-settings:developers`.
- **Linux:** install Chrome/Chromium and set `CHROME_EXECUTABLE` if
  `flutter run -d chrome` cannot find the browser.
- **macOS:** iOS builds additionally require Xcode and CocoaPods.

## AMap / Gaode Keys

Keys are passed at build time via `--dart-define` — **never commit keys to the
repo**. Android package/application id: `com.idm.travelplanner`.

| Define | Used by | Purpose |
| --- | --- | --- |
| `AMAP_JS_KEY` | Web | AMap Web JS API key |
| `AMAP_JS_SECURITY_CODE` | Web | Security code paired with the JS key (required if key security is enabled) |
| `AMAP_ANDROID_KEY` | Android | AMap Android native key |
| `AMAP_IOS_KEY` | iOS | AMap iOS native key |
| `WAYFARE_API_BASE` | all | Point the app at a non-default backend (default `http://127.0.0.1:8080`) |

Examples:

```bash
# Web build with a real map
flutter build web --release --pwa-strategy=none \
  --dart-define=AMAP_JS_KEY=your_web_js_key \
  --dart-define=AMAP_JS_SECURITY_CODE=your_security_code

# Run on Android with a real map
flutter run --dart-define=AMAP_ANDROID_KEY=your_amap_android_key
```

(PowerShell: same commands on one line, or use a backtick `` ` `` instead of
`\` for line continuation.)

Alternatively keep keys in a local **`Amap.csv`** next to `pubspec.yaml`
(git-ignored — copy [`AmapExample.csv`](AmapExample.csv) and fill in real
values). The demo tool picks it up automatically:

```text
Wayfare_WebSvc, <backend web-service key>
Wayfare_WebJS, <web js key>
Security_code, <js security code>
```

The legacy `Wayfare_WebJS api_key:<key>` / `Security_code:<code>` format is
still accepted.

## Web Release Build

```bash
flutter build web --release --pwa-strategy=none
```

Two important details:

1. **Always pass `--pwa-strategy=none`.** Earlier builds shipped a caching
   service worker; browsers that saw one keep serving a stale app shell.
2. `web/flutter_service_worker.js` is a **self-destructing service worker**
   that evicts those stale caches. The build wipes it from `build/web`, so
   copy it back after building:

```bash
cp web/flutter_service_worker.js build/web/flutter_service_worker.js   # macOS/Linux
```

```powershell
Copy-Item web\flutter_service_worker.js build\web\flutter_service_worker.js   # Windows
```

Then serve it (backend must be running):

```bash
python3 -m http.server 8092 --bind 127.0.0.1 --directory build/web   # Windows: python
```

App: <http://127.0.0.1:8092>

## One-Command Local Demo

The demo tool starts (or reuses) the backend on `:8080`, serves the web build
on `:8092`, runs the smoke check, and keeps both alive until you stop it:

```bash
dart run tool/local_demo.dart
```

Rebuild the web bundle from your local key file first (it also restores the
self-destruct service worker automatically):

```bash
dart run tool/local_demo.dart --rebuild-web                 # auto-detects Amap.csv
dart run tool/local_demo.dart --rebuild-web --amap-key-file=path/to/keys.csv
```

Standalone smoke check (backend health, login, authenticated `/me`, scenic
search, served web shell):

```bash
dart run tool/local_smoke.dart --web-base=http://127.0.0.1:8092
```

Full handoff checklist: [`docs/local_demo_runbook.md`](docs/local_demo_runbook.md).

## Backend Configuration

All optional for local development — the server runs with safe defaults and
reports `auth: development` from `/health` until a real secret is set.

| Env var | Purpose |
| --- | --- |
| `WAYFARE_AUTH_SECRET` | Session-token signing secret. **Required** for any shared/deployed environment. |
| `WAYFARE_ALLOWED_ORIGINS` | CORS allowlist, e.g. `http://127.0.0.1:8092,http://localhost:8092`. Keep narrow. |
| `WAYFARE_DB_PATH` | SQLite path (default `data/wayfare.sqlite`). |
| `WAYFARE_OPS_TOKEN` | Enables protected aggregate metrics at `/ops/metrics` and schema/migration info at `/ops/schema`. |
| `WAYFARE_BACKUP_DIR` | Target for verified SQLite backups: `dart run bin/backup.dart` (run from `backend/`). |

Useful endpoints: `/health`, `/search?q=橘子洲`. Per-client rate limiting for
auth, search, and write routes is on by default — overrides documented in
[`backend/README.md`](backend/README.md).

The seed data covers 4A+ scenic spots and urban-core attractions for
first-tier and 2025 new-first-tier cities; the in-app 5A library lives in
`lib/scenic_spots_5a.dart`.

## Testing & Quality Gates

```bash
flutter analyze          # static analysis — must be clean
flutter test             # widget + data tests
```

Release readiness gate:

```bash
dart run tool/release_readiness.dart --mode local     # repeatable CI/handoff check
dart run tool/release_readiness.dart --mode release   # production inputs required
```

`--mode release` demands a strong `WAYFARE_AUTH_SECRET`, HTTPS-only
`WAYFARE_ALLOWED_ORIGINS`, a production HTTPS `WAYFARE_API_BASE`, real AMap
keys, and Android release signing.

## Android Release Signing

Release builds refuse debug keys. Provide signing either via environment
variables:

| Env var | Meaning |
| --- | --- |
| `WAYFARE_ANDROID_KEYSTORE` | Path to the release `.jks` |
| `WAYFARE_ANDROID_STORE_PASSWORD` | Keystore password |
| `WAYFARE_ANDROID_KEY_ALIAS` | Key alias |
| `WAYFARE_ANDROID_KEY_PASSWORD` | Key password |

…or via a git-ignored `android/key.properties`:

```properties
storeFile=/secure/wayfare-release.jks        # Windows: C:\\secure\\wayfare-release.jks
storePassword=store-password
keyAlias=wayfare
keyPassword=key-password
```

Then:

```bash
flutter build apk
```

## Troubleshooting

| Symptom | Cause / fix |
| --- | --- |
| Old UI keeps showing after a rebuild (stale buttons, old badges) | A legacy service worker is serving cache. Make sure the self-destruct `flutter_service_worker.js` is in `build/web`, then hard-refresh once (Ctrl/Cmd+Shift+R). |
| Compile error `No named parameter ...` | Your Flutter is older than the 3.41 floor — run `flutter upgrade`. Conversely, don't introduce APIs newer than 3.41 stable; CI-less repo relies on this floor. |
| Map page shows a setup panel | No AMap key in the build — pass `AMAP_JS_KEY` (web) or the native key defines. If the key has security enabled, `AMAP_JS_SECURITY_CODE` is required too. |
| “Backend is not reachable” snackbar | Start the backend first: `cd backend && dart run bin/server.dart`, then check `/health`. |
| CORS errors in the browser console | Set `WAYFARE_ALLOWED_ORIGINS` to include the origin serving the web build (e.g. `http://127.0.0.1:8092`). |

## Project Structure

```text
IDM/
├── lib/
│   ├── main.dart                 # app: models, API client, state, screens
│   ├── scenic_spots_5a.dart      # built-in 5A scenic spot library (tagged)
│   ├── amap_canvas_web.dart      # Web AMap JS bridge (+ stub for non-web)
│   └── *_field_web/stub.dart     # platform-conditional input fields
├── backend/
│   ├── bin/server.dart           # Dart HTTP server, routes, SQLite store
│   ├── bin/backup.dart           # verified SQLite backups
│   └── data/wayfare.sqlite       # local prototype data (git-ignored)
├── web/                          # web shell + self-destruct service worker
├── test/                         # widget + scenic-data tests
├── tool/                         # local_demo, local_smoke, release_readiness
└── docs/                         # requirements, UI design, runbooks
```
