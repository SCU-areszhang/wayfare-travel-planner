# Wayfare Backend Scaffold

This backend is a Dart-only API scaffold for the Flutter front end. It uses
`dart:io` and in-memory data so the team can start wiring user, trip, saved, map,
and feedback data before choosing a database.

## Run

```powershell
$env:Path='C:\Program Files\Flutter\bin;'+$env:Path
cd backend
dart run bin/server.dart
```

Default URL: `http://localhost:8080`

## Current Data Boundaries

- `User`: account id, phone, display name, preferences, budget, travel style.
- `Destination`: city, theme, summary, duration, tags, priority, coordinates.
- `MapPlace`: name, category, coordinates, rating.
- `Itinerary`: title, destination, dates, status, ordered days.
- `ItineraryDay`: day index, date, city, reminder, ordered items.
- `ItineraryItem`: time, place, activity, note, order, status.
- `SavedTrip`: saved destination/itinerary references and folder grouping.
- `Feedback`: category, description, status, created time.

## API Draft

- `GET /health`
- `POST /auth/send-code`
- `POST /auth/login`
- `GET /me`
- `GET /destinations`
- `GET /destinations/:id`
- `GET /recommendations`
- `GET /map/places`
- `GET /itineraries`
- `POST /itineraries`
- `GET /itineraries/:id`
- `PATCH /itineraries/:id`
- `DELETE /itineraries/:id`
- `POST /itineraries/:id/days`
- `POST /itineraries/:id/days/:dayId/items`
- `PATCH /itineraries/:id/days/:dayId/items/:itemId`
- `DELETE /itineraries/:id/days/:dayId/items/:itemId`
- `GET /saved`
- `POST /saved`
- `DELETE /saved/:id`
- `POST /feedback`

## Next Backend Steps

1. Replace in-memory lists with a database layer.
2. Add request validation and stable error codes.
3. Add JWT/session validation for user-specific routes.
4. Add persistence for itinerary item ordering after drag reorder.
5. Add a map provider adapter once the final China map service is selected.
