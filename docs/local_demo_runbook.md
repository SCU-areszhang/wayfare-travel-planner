# Wayfare Local Demo Runbook

This runbook is the shortest repeatable path for reviewing the basic Wayfare
demo on this workstation.

## Scope

The local demo covers:

- Flutter Web shell on `http://127.0.0.1:8092`
- Dart backend on `http://127.0.0.1:8080`
- SQLite-backed login and session flow
- Home search
- Explore Map with AMap Web tiles when keys are supplied
- Itinerary create, day create, item create, list, and cleanup smoke
- Saved item create, list, and cleanup smoke
- Feedback validation smoke

## Start With AMap

From the `IDM/` project root:

```bash
dart run tool/local_demo.dart --rebuild-web --amap-key-file=Amap.csv
```

Expected key file fields:

```text
Wayfare_WebSvc api_key:<web-service-key>
Wayfare_WebJS api_key:<web-js-key>
Security_code:<security-code>
```

If `Security_code` exists in the key file, the explicit
`--amap-js-security-code` flag can be omitted. Prefer the key file or
`AMAP_JS_SECURITY_CODE` environment variable over command-line secrets.

The command:

- reads the external AMap key file without writing secrets to source files;
- passes Flutter Web dart-defines through a temporary file instead of exposing
  AMap keys in process arguments;
- rebuilds Flutter Web with `AMAP_JS_KEY` and optional
  `AMAP_JS_SECURITY_CODE`;
- starts or reuses the backend with `AMAP_WEB_SERVICE_KEY`;
- verifies that the backend returns live `amap_poi` search results when
  `Wayfare_WebSvc` is supplied;
- starts or reuses the local no-cache Web server;
- runs the local smoke check;
- keeps the demo available until interrupted.

## Start Without Rebuild

Use this when `build/web` already contains the desired AMap configuration:

```bash
dart run tool/local_demo.dart
```

## Verify

Run the smoke command against the running demo:

```bash
dart run tool/local_smoke.dart --web-base=http://127.0.0.1:8092
```

Expected result:

```text
Wayfare local smoke: pass
```

The smoke output should include passing checks for backend health, login,
authenticated `/me`, itinerary, saved item, feedback validation, search, and
the Web shell.

## Manual Browser Check

Open:

```text
http://127.0.0.1:8092/
```

Use `demo@wayfare.local` to sign in. The Explore tab should show an AMap canvas
with map tiles, zoom controls, and AutoNavi attribution when the Web JS key and
security code are valid.

## Regression Commands

Before handoff, run:

```bash
flutter analyze --no-pub
flutter test --no-pub
cd backend
dart test
```

From the project root, also run:

```bash
dart run tool/release_readiness.dart --mode local
```

Local readiness may warn about production secrets, production HTTPS origins,
AMap release keys, and Android signing material. Those warnings are expected on
this workstation unless production release inputs are supplied.

## Secret Handling

- Do not commit `Amap.csv` or local key files.
- Do not paste real AMap keys or security codes into source files.
- Do not commit `build/`.
- Pass secrets through `--amap-key-file`, `--amap-js-security-code`, or
  environment variables.

## Current Known Limits

- Android debug APK builds pass on this machine, but Android release builds
  still need real release signing inputs.
- iOS and macOS builds still need full Xcode and CocoaPods.
- The backend remains a local SQLite-backed service suitable for the current
  basic demo scope, not a multi-node production deployment.
