# Goal Execution Notes

Date: 2026-06-08

## Control

- Goal document read first: root `goal.md`.
- Project root confirmed: `IDM/`.
- Required role model: exactly 8 logical subagents, A00 through A07.
- Business-code optimization starts only after `IDM/AGENTS.md` exists.

## Document Read Notes

PDF UI document:

- Product is a one-stop travel planning tool, not a booking or payment platform.
- Primary tabs are Home, Explore, Itinerary, Saved, and Profile.
- Core flows are login, search, recommendation, map marker details, itinerary editing, saved trips, support, and feedback.
- Itinerary is the core working screen and must support create, edit, delete, reorder, save, and clear validation feedback.
- Map is for spatial planning context, marker details, route context, and add-to-itinerary actions.
- Empty, loading, network, map failure, validation, saved, and error states should be explicit and recoverable.
- Material 3 components, dynamic color, accessible contrast, scalable text, and 44x44 touch targets are expected.
- Evaluation tasks T1 through T6 cover login, destination search, itinerary creation, map add, item edit/reorder/delete, saved trips, and support.

DOCX requirements file:

- Scope is destination discovery, personalized recommendation, itinerary planning, interactive map viewing, saved trip management, and in-trip adjustment.
- Non-goals include payment, hotel or flight transactions, deep merchant integration, large social/community features, and advanced recommendation infrastructure.
- Inputs require validation for login identifiers, search queries, dates, itinerary entries, and map selections.
- Outputs must reflect current data accurately and show clear error/status prompts.
- Fault handling must cover invalid input, network timeout, login failure, destination query failure, map unavailability, and itinerary save/update failure.
- Basic confidentiality is required for user identifiers, login status, and saved trip information.

History notes from `Codex` chat export:

- The project evolved from an Android prototype to the current Flutter implementation.
- Recent work added AMap Web/native setup, SQLite backend, CityWalk templates, revised Home/Profile layout, and updated widget tests.
- Prior Windows run reported Web build and `flutter test` passed, while browser screenshot verification was blocked.
- Current macOS workspace must be reverified independently.

## Repository Map

- `lib/main.dart`: main Flutter app, models, API client, screens, widgets, state.
- `lib/amap_canvas_web.dart`: Web AMap JS bridge.
- `lib/amap_canvas_stub.dart`: non-Web AMap bridge stub.
- `lib/login_identifier_field_*`: Web and non-Web login input field implementations.
- `lib/search_query_field_*`: Web and non-Web search input field implementations.
- `backend/bin/server.dart`: Dart HTTP server, routes, SQLite store, seed data.
- `backend/data/wayfare.sqlite`: local SQLite prototype data.
- `test/widget_test.dart`: login and Home render widget test with fake backend.
- `third_party/`: local AMap Flutter dependencies, vendor area.
- `web/`: Flutter Web shell and PWA metadata.
- `docs/`: UI and requirements source documents.

## Baseline Evidence

```text
pwd
/Users/ares/Documents/UI design for IDM
```

```text
git status --short --branch
## No commits yet on main
?? .DS_Store
?? Codex chat export
?? IDM/
?? goal.md
?? local AMap key text file
```

SQLite evidence:

```text
sqlite3 IDM/backend/data/wayfare.sqlite ".tables"
destinations feedback itineraries map_places saved_trips scenic_spots users
```

```text
users: 3
itineraries: 3
scenic_spots: 63
saved_trips: 0
search orange-isle equivalent: 2 matching scenic spot records
```

## Failure Records

### Missing Flutter

- Step: Environment check.
- Time: 2026-06-08 local.
- Environment: macOS shell in repository root.
- Command: `command -v flutter`
- Expected: Flutter executable path.
- Actual: not found.
- Error output: empty command output with non-zero exit.
- Screenshot: none.
- Suspected cause: Flutter is not installed or not on PATH in this environment.
- Next suggested action: Install Flutter or add it to PATH, then run `flutter doctor -v`.
- Blocking level: high for frontend analyze, test, run, and build.

### Missing Dart

- Step: Environment check.
- Time: 2026-06-08 local.
- Environment: macOS shell in repository root.
- Command: `command -v dart`
- Expected: Dart executable path.
- Actual: not found.
- Error output: empty command output with non-zero exit.
- Screenshot: none.
- Suspected cause: Dart SDK is not installed or not on PATH in this environment.
- Next suggested action: Install Dart or use the Dart bundled with Flutter.
- Blocking level: high for backend startup, backend dependency resolution, and Dart formatting.

### Missing adb

- Step: Environment check.
- Time: 2026-06-08 local.
- Environment: macOS shell in repository root.
- Command: `command -v adb`
- Expected: Android Debug Bridge executable path.
- Actual: not found.
- Error output: empty command output with non-zero exit.
- Screenshot: none.
- Suspected cause: Android platform tools are not installed or not on PATH.
- Next suggested action: Install Android SDK platform tools if Android device testing is required.
- Blocking level: medium for Android device testing.

### PDF/DOCX Visual Review Blocked

- Step: Document visual rendering check.
- Time: 2026-06-08 local.
- Environment: macOS shell in repository root.
- Command: `which pdftoppm` and `which soffice`
- Expected: Poppler and LibreOffice commands available for visual rendering.
- Actual: both not found.
- Error output: command-specific not found output.
- Screenshot: none.
- Suspected cause: rendering dependencies are not installed in this environment.
- Next suggested action: Install Poppler and LibreOffice for page-level layout review.
- Blocking level: low for text-based requirements extraction, medium for layout-fidelity review.

## Agent Specs

### A00

- Role: Orchestrator and Delivery Lead.
- Objective: Preserve stage gates, order work, and summarize delivery.
- Inputs: `goal.md`, repo map, verification output.
- Read scope: entire repository except generated/vendor details as needed.
- Write scope: execution notes and final integration only.
- Proposed changes: maintain this execution log and final traceability.
- Acceptance criteria: final answer lists files changed, phases, tests, blockers, risks.
- Tests: verify command outputs and changed file list.
- Risks: toolchain blockers prevent full runtime verification.
- Handoff dependencies: all roles report through A00.

### A01

- Role: Product Spec and AGENTS Owner.
- Objective: Convert goal and docs into project-specific operating rules.
- Inputs: goal, PDF UI document, DOCX requirements.
- Read scope: docs and root control files.
- Write scope: `AGENTS.md`, product/spec notes.
- Proposed changes: create `AGENTS.md` and this execution note.
- Acceptance criteria: 8 roles, workflow, file ownership, commands, testing, security, and failure format exist.
- Tests: inspect docs for required headings and absence of secrets.
- Risks: visual layout of source docs could not be rendered locally.
- Handoff dependencies: A01 to A06 for acceptance and test matrix.

### A02

- Role: Reproduction and Environment Agent.
- Objective: Verify local tools and data without modifying app code.
- Inputs: shell, git, SQLite, package files.
- Read scope: repository and environment.
- Write scope: none except evidence notes.
- Proposed changes: none.
- Acceptance criteria: runnable and blocked checks are clearly separated.
- Tests: command checks for Flutter, Dart, sqlite3, adb, and SQLite counts.
- Risks: missing Flutter/Dart prevents code-level verification.
- Handoff dependencies: A02 to A00 for blockers.

### A03

- Role: Flutter Architecture Agent.
- Objective: Keep state mutations and API-client behavior defensible.
- Inputs: `lib/main.dart`, widget test, backend contract.
- Read scope: `lib/`, `test/`.
- Write scope: Flutter state, models, API client, navigation boundaries.
- Proposed changes: add small defensive guards around day/item creation and target-day selection.
- Acceptance criteria: no user-visible crash when days are empty or a target day changes while a sheet is open.
- Tests: Flutter analyze/test when toolchain exists.
- Risks: unable to run Flutter checks in current PATH.
- Handoff dependencies: A03 to A05 for API contract assumptions.

### A04

- Role: UI/UX, Material 3 and Map Experience Agent.
- Objective: Improve explicit states and form validation in user-facing flows.
- Inputs: UI document, `lib/main.dart`.
- Read scope: screens, widgets, map UI, feedback UI.
- Write scope: `lib/main.dart`, Web/stub UI support if needed.
- Proposed changes: add Saved empty states and feedback description validation.
- Acceptance criteria: Saved page does not render empty sections silently, feedback cannot submit an empty description.
- Tests: widget test/manual smoke when Flutter exists.
- Risks: visual screenshot verification unavailable without Flutter/browser run.
- Handoff dependencies: A04 to A03 and A05 for state/API changes.

### A05

- Role: Backend, SQLite and API Agent.
- Objective: Tighten API input validation and client-error handling.
- Inputs: DOCX fault handling requirements, backend README, `backend/bin/server.dart`.
- Read scope: `backend/`, API client call sites.
- Write scope: backend routes, validation helpers, SQLite store boundaries.
- Proposed changes: return 400 for malformed JSON/validation failures, validate login and feedback, clamp search limit.
- Acceptance criteria: bad request shapes do not fall through as generic 500 errors.
- Tests: `dart test` and curl smoke when Dart exists.
- Risks: Dart unavailable in current environment.
- Handoff dependencies: A05 to A03 for frontend error expectations.

### A06

- Role: QA and Test Agent.
- Objective: Keep verification explicit and trace skipped checks.
- Inputs: existing widget test, commands, blockers.
- Read scope: app, backend, tests.
- Write scope: tests and verification notes.
- Proposed changes: no broad test expansion until Flutter/Dart tools exist.
- Acceptance criteria: final summary states passed, blocked, and skipped checks.
- Tests: SQLite checks now; Flutter/Dart checks later.
- Risks: syntax errors could remain undetected without Dart/Flutter.
- Handoff dependencies: A06 to owning agent for any failing check.

### A07

- Role: Security, GitHub and Release Agent.
- Objective: Prevent local secrets and generated files from entering git.
- Inputs: git status, root files, secret scan.
- Read scope: git state and security-sensitive paths.
- Write scope: root ignore rules and security notes.
- Proposed changes: add a root `.gitignore` for local AMap key text, `.DS_Store`, logs, build, and tool caches.
- Acceptance criteria: local key file is ignored by git without deleting user data.
- Tests: `git status --short --ignored` review.
- Risks: repository has no commits and many pre-existing untracked files.
- Handoff dependencies: A07 to A00 for final release risk.

## Implementation Trace

### A01

- File: `AGENTS.md`
- Change: Added project-specific workflow, the required 8 logical roles, ownership boundaries, commands, testing expectations, security rules, and failure-record format.
- Acceptance link: Goal Phase 2.

### A00

- File: `docs/goal_execution.md`
- Change: Added document read notes, repository map, baseline evidence, agent specs, implementation trace, and verification results.
- Acceptance link: Goal Phases 0, 1, 3, 5, and 6.

### A07

- File: root `.gitignore`
- Change: Added root ignore rules for local key text files, environment files, `.DS_Store`, Flutter/Dart build outputs, backend runtime data, logs, and IDE metadata.
- Acceptance link: No local AMap keys or generated files should be staged accidentally.

### A03

- File: `lib/main.dart`
- Change: Added target-day index validation before item creation and edit save, and removed an unawaited default-day call from quick-add flow.
- Acceptance link: Add-to-itinerary actions should not crash if a target day changes while a sheet is open.

### A04

- File: `lib/main.dart`
- Change: Feedback now requires a non-empty description and shows an in-sheet submitting state. Saved page search and folder chips now filter trips and show explicit empty states for no results, upcoming trips, and past trips.
- Acceptance link: Fault handling and empty states are visible and recoverable.

### A05

- File: `backend/bin/server.dart`
- Change: Added 400 responses for malformed JSON and validation errors, login/send-code identifier validation, feedback description validation, search limit clamping, safer JSON object coercion, 404s for missing itinerary day/item IDs, configurable `WAYFARE_DB_PATH`, and less-detailed 500 responses.
- Acceptance link: API validation and fault handling match the requirements baseline.

### A06

- Files: `backend/pubspec.yaml`, `backend/analysis_options.yaml`, `backend/test/server_test.dart`
- Change: Added backend HTTP integration tests that run against a temporary SQLite database.
- Acceptance link: Backend validation and 404 behavior are covered by `dart test`.

### A03/A04

- Files: `analysis_options.yaml`, `pubspec.yaml`, `lib/main.dart`
- Change: Scoped Flutter analysis away from backend/vendor packages, added `cupertino_icons`, migrated itinerary reordering to `onReorderItem`, and pinned touch feedback to `InkRipple` to avoid Flutter 3.44 test shader incompatibility.
- Acceptance link: `flutter analyze`, `flutter test`, and web release build all pass on the installed toolchain.

## Commercialization Iteration

### Subagent Audit Results

- A05/A07 Backend/Security: identified prototype `dev-token-*`, default user fallback, weak user data isolation, predictable IDs, permissive CORS, request body limits, SQLite production gaps, and missing auth regression tests as the highest-risk commercial blockers.
- A03/A04 Flutter/UI: identified the monolithic `lib/main.dart`, mutable app state, weak API contract parsing, session/privacy copy, duplicate search state, map reliability, Web input accessibility, and low widget coverage as the main frontend blockers.
- A06/A07 QA/Release: identified dirty platform files, ignored lockfiles, missing CI, release signing, platform configuration drift, weak test coverage, and local-only deployment docs as release blockers.

### A05/A07

- Files: `backend/bin/server.dart`, `backend/pubspec.yaml`, `backend/test/server_test.dart`, `backend/README.md`
- Change: Replaced prototype `dev-token-*` with HMAC-signed Bearer session tokens, added token expiry validation, removed default/query/body user id trust for user-owned routes, scoped itinerary/saved/feedback operations to the authenticated user, added strong random IDs, request body size and JSON content-type checks, loopback/default CORS allow-list behavior, configurable bind host/auth/session settings, and backend tests for 401 and authorized `/me`.
- Acceptance link: User-owned backend data is no longer selected by arbitrary client-provided `userId` values.

### A03

- Files: `lib/main.dart`, `test/widget_test.dart`
- Change: Stored session token and expiry in `AppUser`/`LocalAuthRepository`, injected Bearer token into `WayfareApiClient` requests, removed userId query/body usage from user-owned API calls, and updated widget fake backend for the new auth contract.
- Acceptance link: Flutter app uses server-issued token for authenticated routes instead of relying on client-selected user ids.

### A07

- Files: `.gitignore`, `.gitattributes`, `.github/workflows/ci.yml`, `README.md`, `backend/README.md`, `pubspec.lock`, `backend/pubspec.lock`
- Change: Allowed lockfiles to be tracked, added line-ending policy, added GitHub Actions CI for format/analyze/test/web build/backend tests, and documented production-oriented environment variables.
- Acceptance link: Release checks are repeatable outside the local machine.

## Session Hardening Iteration

### A05/A07

- Files: `backend/bin/server.dart`, `backend/test/server_test.dart`, `backend/README.md`
- Change: Added a server-side `sessions` table, changed login tokens from stateless signed payloads to opaque random tokens stored only as HMAC hashes, added `POST /auth/logout`, revoked expired sessions during validation, and covered logout/session opacity in backend tests.
- Acceptance link: Sessions are now revocable server-side, which is required for credible production logout and incident response.

### A03/A06

- Files: `lib/main.dart`, `test/widget_test.dart`
- Change: Added `WayfareBackend.logout()`, made Flutter logout revoke the backend session on a best-effort basis before local cleanup, and updated the fake backend contract used by widget tests.
- Acceptance link: Frontend session lifecycle matches the backend revocation model.

## Release Gate Iteration

### A07/A06

- Files: `tool/release_readiness.dart`, `test/release_readiness_test.dart`, `.github/workflows/ci.yml`
- Change: Added a machine-readable release readiness gate with `local` and `release` modes, CI execution for local mode, and tests for missing and complete production inputs.
- Acceptance link: CI can prove local release hygiene, while production release mode fails when secrets, HTTPS origins, AMap keys, API base, or Android signing inputs are absent.

### A07

- Files: `android/app/build.gradle`, `android/gradle.properties`, `android/app/build.gradle.kts`, `android/settings.gradle.kts`, `.gitignore`
- Change: Replaced debug-key release signing with release signing backed by environment variables or ignored `android/key.properties`, kept Flutter's Gradle migration flags, removed duplicate ignored KTS Gradle files, and ignored local keystore material.
- Acceptance link: Android release tasks cannot silently ship a debug-signed artifact.

### A00/A01

- Files: `README.md`, `backend/README.md`, `AGENTS.md`, `docs/goal_execution.md`
- Change: Documented release readiness commands, production configuration expectations, Android signing inputs, and the updated role/SOP gate.
- Acceptance link: Future implementation and release work has traceable commands and acceptance conditions.

## Backend Abuse-Control Iteration

### A05/A07

- Files: `backend/bin/server.dart`, `backend/README.md`, `AGENTS.md`, `tool/release_readiness.dart`
- Change: Added configurable fixed-window in-memory rate limiting for auth, search, and write routes; added 429 JSON responses with `Retry-After` and `X-RateLimit-*` headers; documented environment variables and trusted-proxy behavior; and extended release readiness to check for backend rate limiting.
- Acceptance link: Login/code, search, and write endpoints now have default abuse controls instead of unlimited request volume.

### A06

- Files: `backend/test/server_test.dart`, `test/release_readiness_test.dart`
- Change: Added backend regression coverage for configured auth throttling and updated release readiness fixtures.
- Acceptance link: `dart test` proves the backend returns 429 after the configured auth limit.

## Backend Schema-Validation Iteration

### A05/A07

- Files: `backend/bin/server.dart`, `backend/README.md`, `tool/release_readiness.dart`
- Change: Added API-layer schema validation for itinerary create/update, day creation, item create/update, item reorder, and saved-trip creation. Validation now covers required intent fields, string lengths, allowed statuses/types, real `YYYY-MM-DD` dates, non-empty reorder IDs, duplicate reorder IDs, and paired/ranged coordinates.
- Acceptance link: User-owned mutation endpoints no longer silently accept malformed shapes or persist placeholder `TBD` data from bad requests.

### A06

- Files: `backend/test/server_test.dart`, `test/release_readiness_test.dart`
- Change: Added backend regression coverage for itinerary and saved mutation validation and extended release readiness fixtures.
- Acceptance link: `dart test` proves malformed itinerary/saved mutations return 400 with explicit errors.

## Backend Observability Iteration

### A05/A07

- Files: `backend/bin/server.dart`, `backend/README.md`, `README.md`, `AGENTS.md`, `tool/release_readiness.dart`
- Change: Added protected aggregate operational metrics at `GET /ops/metrics`, guarded by `WAYFARE_OPS_TOKEN`, plus route/status request counters, uptime, and average duration. Metrics use normalized route templates and omit bodies, identifiers, tokens, and concrete resource ids.
- Acceptance link: Backend deployments now have a minimal monitoring surface without exposing user data.

### A06

- Files: `backend/test/server_test.dart`, `test/release_readiness_test.dart`
- Change: Added regression coverage for missing/invalid ops token rejection and authorized aggregate metrics output; extended release readiness fixtures and production input checks for `WAYFARE_OPS_TOKEN`.
- Acceptance link: `dart test` proves metrics are protected and aggregate counters are emitted.

## SQLite Backup Iteration

### A05/A07

- Files: `backend/bin/backup.dart`, `backend/README.md`, `README.md`, `AGENTS.md`, `.gitignore`, `tool/release_readiness.dart`
- Change: Added a verified SQLite backup command that runs source `PRAGMA quick_check`, creates a consistent backup with `VACUUM INTO`, verifies the backup with `PRAGMA quick_check`, writes a manifest with size and SHA-256, ignores local backup artifacts, documents scheduling/storage expectations, and requires `WAYFARE_BACKUP_DIR` for release readiness.
- Acceptance link: The project now has a repeatable backup artifact path instead of only documenting backup as a residual risk.

### A06

- Files: `backend/test/backup_test.dart`, `test/release_readiness_test.dart`
- Change: Added backup tests for manifest creation, backup readability, SHA-256 metadata, and missing/empty database rejection; updated release readiness fixtures.
- Acceptance link: `dart test` proves local backup generation produces a readable, verified SQLite copy and manifest.

## SQLite Migration-Tracking Iteration

### A05/A07

- Files: `backend/bin/server.dart`, `backend/README.md`, `README.md`, `AGENTS.md`, `tool/release_readiness.dart`
- Change: Added a `schema_migrations` table, checksumed schema signature, SQLite `PRAGMA user_version`, `/health` schema version reporting, protected `GET /ops/schema`, and release readiness checks for migration tracking.
- Acceptance link: Deployments can verify the running database schema state before promoting a backend.

### A06

- Files: `backend/test/server_test.dart`, `test/release_readiness_test.dart`
- Change: Added regression coverage for `/health` schema version output, unauthorized `/ops/schema` rejection, authorized migration metadata output, and release readiness fixture coverage.
- Acceptance link: `dart test` proves schema state is tracked and protected by the ops token.

## Verification Results

Runnable:

```text
git status --short --branch --ignored
branch: codex/goal-implementation
local AMap key text file: ignored
```

```text
sqlite3 backend/data/wayfare.sqlite ".tables"
destinations feedback itineraries map_places saved_trips scenic_spots users
```

```text
SQLite counts
users: 3
itineraries: 3
scenic_spots: 63
saved_trips: 0
```

```text
SQLite search evidence
orange-isle equivalent query returned 2 Changsha 5A records
```

Toolchain installed:

```text
Flutter 3.44.1
Dart 3.12.1
adb 37.0.0-14910828
```

```text
flutter doctor -v
Flutter: ok
Chrome/web: ok
Connected devices: macOS and Chrome
Network resources: ok
Android toolchain: cmdline-tools missing
Xcode: full Xcode and CocoaPods missing
```

```text
flutter analyze
No issues found.
```

```text
flutter test
4 tests passed.
```

```text
flutter build web --release --pwa-strategy=none
Built build/web.
```

```text
dart analyze
backend: No issues found.
```

```text
dart test
backend: 14 tests passed.
```

```text
Session hardening tests
backend: logout revokes token, opaque session token format covered.
```

```text
Release readiness
local mode: pass with warnings for missing production auth/ops secrets, backup directory, HTTPS origins, AMap keys, and Android signing inputs on this workstation.
release mode with complete production-like inputs: pass.
```

```text
SQLite backup smoke
dart run bin/backup.dart --database data/wayfare.sqlite --backup-dir /private/tmp/wayfare-backups --label smoke
Result: created a verified SQLite backup and manifest with quickCheck: ok.
```

```text
Android debug build
Initial result: blocked by Android SDK state because cmdline-tools were missing and the NDK 28.2.13676358 license was not accepted.
Follow-up: installed Android command-line tools, accepted SDK licenses, installed platform-tools, platforms android-36/android-34, build-tools 36/35, NDK 28.2.13676358, and CMake 3.22.1.
Repository fix: aligned Android Java/Kotlin JVM targets to 17 in the active Groovy Gradle file and extended the release readiness gate to catch regressions.
Final result: `flutter build apk --debug --no-pub` built `build/app/outputs/flutter-apk/app-debug.apk`.
```

```text
Browser smoke test
http://127.0.0.1:8092 loaded build/web.
Temporary backend on http://127.0.0.1:8080 passed /health.
Browser error/warning logs: none.
Browser automation could not type into the Flutter Web platform text field because the virtual clipboard was unavailable.
Backend curl smoke proved login returned a signed token, unauthenticated /me returned 401, and authenticated /me returned demo@wayfare.local.
```

Residual risk:

- Android toolchain is now usable for debug APK builds on this machine, but Android release/appbundle verification still needs real signing credentials and production AMap/API/auth values supplied by CI or a release workstation.
- Android debug builds currently pass with a Flutter warning that the app and `dynamic_color` still apply Kotlin Gradle Plugin; future Flutter releases may require migration to Built-in Kotlin.
- iOS/macOS builds still need full Xcode and CocoaPods.
- Backend is still SQLite-based and single-process; production deployment still needs migration review/promotion, scheduled external backup storage/retention, external log/metric shipping, distributed/shared rate limiting, and eventually a production identity provider for SSO/MFA/compliance needs.
- Frontend search concurrency, map point confirmation UX, broader widget/E2E tests, and API parsing strictness remain future commercial hardening work.
- PDF and DOCX layout fidelity could not be visually rendered because Poppler and LibreOffice are missing.
