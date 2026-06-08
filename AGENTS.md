# AGENTS.md

## Project

Wayfare is a Flutter, Dart, SQLite, Material 3, and AMap travel planning prototype.
The app root is this `IDM/` directory.

Important entrypoints:

- Flutter app: `lib/main.dart`
- Web AMap bridge: `lib/amap_canvas_web.dart`
- Backend server: `backend/bin/server.dart`
- Backend database: `backend/data/wayfare.sqlite`
- Frontend package: `pubspec.yaml`
- Backend package: `backend/pubspec.yaml`

## Scope And Non-Goals

Scope:

- Login or auto-register for a small course-project user set.
- Home discovery, search, and system CityWalk templates.
- Explore Map with AMap key setup states, markers, route context, and point pick.
- Itinerary create, edit, duplicate, delete, reorder, and save flows.
- Saved trips, Profile, Help, and Feedback.
- Local Dart backend with SQLite storage.

Non-goals:

- No real booking platform.
- No payment flow.
- No production identity provider unless explicitly requested.
- No committed AMap keys, API keys, tokens, private user data, or local secrets.

## Current Architecture

The current implementation is intentionally compact:

- `lib/main.dart` contains domain models, API client, state, screens, and shared widgets.
- `lib/*_web.dart` and `lib/*_stub.dart` provide conditional Web and non-Web behavior.
- `backend/bin/server.dart` contains routes, SQLite schema, seed data, and store methods.
- `third_party/` contains local AMap Flutter packages and should be treated as vendor code.

Large refactors should be staged. Prefer narrow fixes unless a task explicitly asks for a module split.

## Required Workflow

1. Read `goal.md` before changing code.
2. Record git state and current environment.
3. Reproduce what can be reproduced locally.
4. Update this file before business-code optimization.
5. Assign every implementation change to exactly one of the 8 roles below.
6. Keep edits within the owning role's file boundary.
7. Run verification commands when the toolchain exists.
8. Record blockers precisely instead of claiming success.

## 8 Subagent Roles

| ID | Role | Owns | Output |
| --- | --- | --- | --- |
| A00 | Orchestrator and Delivery Lead | Stage gates, implementation order, final integration | Execution log, decisions, delivery summary |
| A01 | Product Spec and AGENTS Owner | Requirements, scope, this file, acceptance criteria | AGENTS updates and product notes |
| A02 | Reproduction and Environment Agent | Repo map, SDK checks, dependency checks, baseline reproduction | Reproduction evidence and blockers |
| A03 | Flutter Architecture Agent | Flutter models, state, API client, navigation boundaries | Architecture and state changes |
| A04 | UI/UX, Material 3 and Map Experience Agent | Screens, widgets, theme, responsive layout, map UI states | UI and map improvements |
| A05 | Backend, SQLite and API Agent | `backend/`, SQLite access, API contracts, validation | Backend and data fixes |
| A06 | QA and Test Agent | `test/`, test strategy, smoke checks, regression notes | Test matrix and verification results |
| A07 | Security, GitHub and Release Agent | Secret handling, git hygiene, CI or release notes | Risk notes and release checklist |

Use exactly these logical roles. If actual subagent tools are not available or not useful for the current scope, simulate the roles serially and keep ownership traceable.

## Communication Rules

The Orchestrator is the default hub.

Allowed direct handoffs:

- A01 to A06 for acceptance criteria and tests.
- A03 to A05 for API, model, and error contracts.
- A04 to A03 for widget, state, and navigation interfaces.
- A04 to A05 for map, search, and itinerary data contracts.
- A06 to any owner when a failing test needs an owner action.
- A07 to any owner for security, secret, CI, or release blockers.

Handoff format:

```markdown
## Handoff
- From:
- To:
- Decision needed:
- Files/modules:
- Blocking status:
- Acceptance condition:
```

## File Ownership

- A00: `goal.md`, delivery summaries, execution logs.
- A01: `AGENTS.md`, requirements and acceptance notes.
- A02: read-only exploration, environment evidence, reproduction notes.
- A03: `lib/main.dart` architecture, state, API client, models, navigation boundaries.
- A04: `lib/main.dart` screens/widgets/theme/map UI, `lib/amap_canvas_*`, `lib/*field*`.
- A05: `backend/`, backend database access, API validation, endpoint behavior.
- A06: `test/`, verification notes, test fixtures and test documentation.
- A07: `.gitignore`, security notes, secret handling, release or CI files.

Avoid by default:

- `build/`
- `.dart_tool/`
- `.flutter-plugins-dependencies`
- `third_party/`
- `.DS_Store`
- generated IDE files

## Skills

Relevant local workflows:

- Documentation for this file and execution notes.
- Design-system guidance for Material 3 consistency, accessible touch targets, and responsive layout.
- Flutter architecture guidance for keeping UI, state, API client, and data parsing boundaries understandable.
- Flutter responsive guidance for LayoutBuilder, constrained widths, and mobile/desktop behavior.
- Testing guidance for focused widget/API tests and smoke checks.
- Security guidance is used as general secret and input-validation hygiene because no Dart-specific reference was available.

## Commands

Baseline:

```bash
pwd
git status --short --branch
find IDM -maxdepth 2 -type f | sort | sed -n '1,200p'
```

Environment:

```bash
command -v flutter
command -v dart
command -v sqlite3
command -v adb
flutter --version
dart --version
flutter doctor -v
```

SQLite:

```bash
sqlite3 backend/data/wayfare.sqlite ".tables"
sqlite3 backend/data/wayfare.sqlite "SELECT COUNT(*) FROM users;"
sqlite3 backend/data/wayfare.sqlite "SELECT COUNT(*) FROM itineraries;"
sqlite3 backend/data/wayfare.sqlite "SELECT COUNT(*) FROM scenic_spots;"
sqlite3 backend/data/wayfare.sqlite "SELECT COUNT(*) FROM saved_trips;"
```

Frontend, when Flutter exists:

```bash
flutter pub get
flutter analyze
flutter test
flutter build web --release --pwa-strategy=none
```

Backend, when Dart exists:

```bash
cd backend
dart pub get
dart run bin/server.dart
curl http://127.0.0.1:8080/health
curl "http://127.0.0.1:8080/search?q=orange"
```

Local demo startup:

```bash
dart run tool/local_demo.dart
dart run tool/local_demo.dart --rebuild-web --amap-key-file=../高德.txt --amap-js-security-code=<security-code>
```

Local demo smoke:

```bash
dart run tool/local_smoke.dart --web-base=http://127.0.0.1:8092
```

Local demo handoff checklist:

```bash
docs/local_demo_runbook.md
```

Release readiness:

```bash
dart run tool/release_readiness.dart --mode local
dart run tool/release_readiness.dart --mode release
```

Use `--mode local` for repeatable CI and handoff checks. Use `--mode release`
only when production `WAYFARE_*`, `AMAP_*`, and Android signing inputs are
available.

## Testing

Test priorities:

- Login or auto-register reaches Home.
- Backend unavailable state is explicit and recoverable.
- Search handles empty, no-result, success, and backend failure states.
- Map shows a real AMap surface when keys exist, otherwise a readable key setup panel.
- Marker details and map point pick can add itinerary items.
- Itinerary add, edit, duplicate, delete, reorder, and save remain consistent with backend state.
- Saved page shows empty and populated states.
- Feedback requires useful input and reports submission errors.

## Security

- Never commit real AMap keys, API keys, tokens, private user data, or local credential files.
- Use `--dart-define` or environment variables for AMap keys.
- Treat the checked SQLite data as course prototype data only.
- Do not include secrets in logs, screenshots, docs, tests, or final summaries.
- Public resource IDs are prototype IDs; use stronger random IDs before production.
- Backend validation must reject malformed JSON, empty identifiers, empty feedback, and invalid request shapes with client errors.
- Backend abuse controls must keep auth, search, and write rate limiting enabled
  by default; proxy-derived client IPs are allowed only when the proxy is
  trusted and overwrites forwarded headers.
- Operational metrics must stay aggregate and protected by `WAYFARE_OPS_TOKEN`;
  do not log or expose request bodies, tokens, identifiers, or concrete
  resource ids.
- SQLite schema changes must update the schema version, migration signature,
  migration tests, and release readiness checks in the same change.
- SQLite backups must be generated through the verified backend backup command,
  stored outside build/runtime cache directories, and kept out of git.
- Android release builds must use release signing credentials from environment
  variables or ignored `android/key.properties`; debug signing is not acceptable
  for release artifacts.

## Failure Records

Use this format:

```markdown
## Failure Record

- Step:
- Time:
- Environment:
- Command:
- Expected:
- Actual:
- Error output:
- Screenshot:
- Suspected cause:
- Next suggested action:
- Blocking level: low / medium / high
```

## PR And Git Rules

- Do not revert user changes.
- Do not edit generated/vendor/build outputs unless explicitly required.
- Keep changes small and tied to one owning role.
- Run available checks before delivery.
- If committing later, review untracked local secret files first and stage intentionally.
