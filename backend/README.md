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
- `POST /auth/login` with `identifier`, `phone`, or `email`. Unknown identifiers are automatically registered and signed in.
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

## Next Backend Steps

1. Add request validation and stable error codes.
2. Add JWT/session validation for user-specific routes.
3. Split the growing server file into route/store/model modules.
4. Add a map provider adapter for the final Web AMap integration.
