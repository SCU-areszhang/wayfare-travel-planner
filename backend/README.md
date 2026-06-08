# Wayfare Backend

This backend is a Dart-only API for the Flutter front end. It uses
`dart:io` and SQLite so the team can store the small project user set, trip,
saved, map, and feedback data locally.

## Run

```powershell
$env:Path='C:\Program Files\Flutter\bin;'+$env:Path
cd backend
dart run bin/server.dart
```

Default URL: `http://127.0.0.1:8080`

Database file: `backend/data/wayfare.sqlite`

Production-oriented configuration:

- `WAYFARE_AUTH_SECRET`: HMAC secret used to sign Bearer session tokens. Set this for any shared or deployed environment.
- `WAYFARE_SESSION_DAYS`: session lifetime in days, clamped to 1-30. Default: `7`.
- `WAYFARE_ALLOWED_ORIGINS`: comma-separated CORS allow-list. If unset, only loopback origins are allowed for local development.
- `WAYFARE_BIND_HOST`: bind address. Default: `127.0.0.1`.
- `WAYFARE_DB_PATH`: SQLite path. Default: `data/wayfare.sqlite`.
- `AMAP_WEB_SERVICE_KEY`: optional backend AMap Web Service key for live POI search.
- `WAYFARE_RATE_LIMIT_ENABLED`: set to `false` only for controlled local debugging. Default: enabled.
- `WAYFARE_RATE_LIMIT_WINDOW_SECONDS`: fixed-window duration, clamped to 1-3600 seconds. Default: `60`.
- `WAYFARE_RATE_LIMIT_AUTH_PER_WINDOW`: login/send-code attempts per client window. Default: `12`.
- `WAYFARE_RATE_LIMIT_SEARCH_PER_WINDOW`: search requests per client window. Default: `120`.
- `WAYFARE_RATE_LIMIT_WRITE_PER_WINDOW`: itinerary, saved-trip, and feedback writes per client window. Default: `120`.
- `WAYFARE_TRUST_PROXY`: set to `true` only behind a trusted reverse proxy that overwrites `X-Forwarded-For`.

Before deploying a shared or production backend, run the project-level release
gate from the repository root:

```powershell
dart run tool/release_readiness.dart --mode release
```

This check fails when the auth secret is weak, CORS origins are not HTTPS-only,
the Flutter API base is still local, AMap keys are missing, or Android release
signing inputs are unavailable.

Rate limiting is in-memory and per backend process. It is suitable for the
single-node prototype and smoke deployments; clustered production deployments
should move counters to a shared gateway, Redis, or platform rate limiter.

## Current Data Boundaries

- `User`: account id, phone, display name, preferences, budget, travel style.
- `Destination`: city, theme, summary, duration, tags, priority, coordinates.
- `MapPlace`: name, category, coordinates, rating.
- `ScenicSpot`: 4A+ scenic spots and first-tier/new-first-tier urban-core attraction name, province, city, district, intro, image URL, and coordinates.
- `Itinerary`: title, destination, dates, status, ordered days.
- `ItineraryDay`: day index, date, city, reminder, ordered items.
- `ItineraryItem`: time, place, activity, note, order, status.
- `SavedTrip`: saved destination/itinerary references and folder grouping.
- `Feedback`: category, description, status, created time.

## API Draft

- `GET /health`
- `POST /auth/send-code`
- `POST /auth/login` with `identifier`, `phone`, or `email`. Unknown identifiers are automatically registered and signed in. The response includes an opaque Bearer `token` and `expiresAt`.
- `POST /auth/logout`
- `GET /me`
- `GET /destinations`
- `GET /destinations/:id`
- `GET /recommendations`
- `GET /search?q=keyword`
- `GET /map/places`
- `GET /itineraries`
- `POST /itineraries`
- `GET /itineraries/:id`
- `PATCH /itineraries/:id`
- `DELETE /itineraries/:id`
- `POST /itineraries/:id/days`
- `POST /itineraries/:id/days/:dayId/items`
- `PATCH /itineraries/:id/days/:dayId/items/:itemId`
- `PATCH /itineraries/:id/days/:dayId/items/reorder`
- `DELETE /itineraries/:id/days/:dayId/items/:itemId`
- `GET /saved`
- `POST /saved`
- `DELETE /saved/:id`
- `POST /feedback`

User-specific routes require:

```text
Authorization: Bearer <token-from-auth-login>
```

The server derives the user id from a hashed, server-side session. Client-provided `userId` values in query strings or JSON bodies are ignored for user-owned resources. `POST /auth/logout` revokes the current session token.

## Next Backend Steps

1. Add full request schema validation for itinerary and saved-trip mutations.
2. Replace the built-in session table with a production identity provider when team or compliance needs require SSO, MFA, or centralized audit.
3. Split the growing server file into route/store/model modules.
4. Add a map provider adapter for the final Web AMap integration.
