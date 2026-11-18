# RideCompare architecture

```
┌──────────── Flutter app (mobile/) ────────────┐        ┌──────────── Node API (backend/) ─────────────┐
│ presentation  screens, widgets (Material 3)   │        │ interfaces/http  routes, zod validation,      │
│ application   Riverpod notifiers / providers  │  REST  │                  error handler, rate limit    │
│ domain        entities, repository interfaces │ ─────▶ │ application      CompareRidesService,         │
│ data          Dio repositories, JSON mapping  │  JSON  │                  PlacesService                │
│ core          config, ApiClient, theme, router│        │ domain           types, errors                │
└───────────────────────────────────────────────┘        │ infrastructure   providers/ (uber, ola, rapido)│
                                                         │                  maps/ (Google | demo)         │
                                                         │                  db/ (MongoDB via Mongoose)    │
                                                         └───────────────────────────────────────────────┘
```

Dependencies point inward: presentation → application → domain ← data/infrastructure.
Both apps wire their dependencies in one place (`server.js` / Riverpod providers), so tests swap in fakes.

## Backend

| Layer | Files | Responsibility |
|---|---|---|
| Config | `src/config/env.js` | Validates env vars with zod; fails fast on bad config |
| Domain | `src/domain/` | Provider/category vocabulary, `DATA_SOURCE`, typed errors (`AppError` …) |
| Application | `src/application/compareRides.js` | Validates the trip, gets a route, queries providers in parallel with timeouts, sorts, picks cheapest/fastest, records history |
| | `src/application/placesService.js` | Autocomplete, place details, reverse geocode |
| Infrastructure | `providers/RideProvider.js` + `uber/ ola/ rapido/` + `normalize.js` | `UberProvider`/`OlaProvider`/`RapidoProvider`: official live API only, otherwise "Live pricing unavailable" |
| | `maps/googleMapsClient.js` | Places API (New), Geocoding, Routes API (key stays server-side) |
| | `maps/demoMapsClient.js` | Key-free fallback: landmark search and straight-line × road-factor routes |
| | `db/` | Mongoose connection, `Search` model (30-day TTL), repository |
| Interface | `interfaces/http/` | Express 5 routes, validation middleware, request IDs, central error handler |

### Centralised error handling

Every error response has the same shape:

```json
{ "error": { "code": "VALIDATION_ERROR", "message": "Pickup and destination are the same place",
             "details": { "reason": "SAME_LOCATION" }, "requestId": "4f1c…" } }
```

| Code | HTTP | When |
|---|---|---|
| `VALIDATION_ERROR` | 400 | Bad body/query, same pickup & drop, trip > 150 km |
| `INVALID_JSON` | 400 | Malformed JSON body |
| `NOT_FOUND` | 404 | Unknown route or place |
| `PAYLOAD_TOO_LARGE` | 413 | Body > 10 KB |
| `RATE_LIMITED` | 429 | > 120 requests/min per IP |
| `NO_PROVIDERS_AVAILABLE` | 502 | Every provider failed |
| `UPSTREAM_ERROR` | 502/504 | Maps/provider failure (routes fall back to an estimated route) |
| `INTERNAL_ERROR` | 500 | Anything else (details logged, never sent to clients) |

### REST API (`/api/v1`)

| Method | Path | Purpose |
|---|---|---|
| GET | `/health` | Status, DB up/down, maps source, provider modes |
| GET | `/providers` | Provider list with `live` (true/false) and a note |
| GET | `/places/autocomplete?q=&lat=&lng=&sessionToken=` | Location suggestions |
| GET | `/places/reverse?lat=&lng=` | Coordinates → place (current location, map pin) |
| GET | `/places/:placeId?sessionToken=` | Suggestion → coordinates |
| POST | `/compare` | Body `{pickup, drop, providers?, categories?}` → comparison |
| GET | `/searches/recent?limit=` | Recent comparisons from MongoDB |

`POST /compare` response (abridged):

```json
{
  "dataMode": "live", "generatedAt": "…",
  "route": { "distanceKm": 7.0, "durationMin": 17, "polyline": [{"lat":…,"lng":…}], "source": "osm" },
  "providers": [{ "id": "uber", "status": "ok", "live": true, "optionCount": 5 }, { "id": "rapido", "status": "unavailable", "message": "Live pricing unavailable", "reason": "Rapido has no official fare API" }, …],
  "options": [{
    "id": "uber:go", "provider": "uber", "productName": "Uber Go", "category": "car",
    "fare": { "min": 212, "max": 212, "upfront": 212, "currency": "INR" }, "pickupEtaMin": 5, "tripDurationMin": 14,
    "distanceKm": 7.0, "available": true, "priceType": "upfront", "surgeMultiplier": 1, "dataSource": "live", "fetchedAt": "…"
  }, …],
  "cheapestOptionId": "uber:go", "fastestOptionId": "uber:go"
}
```

## Mobile

| Folder | Contents |
|---|---|
| `lib/core/config` | `AppConfig`: API base URL (10.0.2.2 on Android emulator, localhost on iOS sim), `MAPS_ENABLED` |
| `lib/core/network` | `ApiClient` (Dio) that converts every failure into an `AppFailure` |
| `lib/core/error` | Sealed `AppFailure` hierarchy: Network / Timeout / Server / Location / Unexpected |
| `lib/core/theme` | Design tokens (colours, gaps, radii, motion) and Material 3 theme |
| `lib/core/router` | GoRouter: `/`, `/search/:field`, `/map/:field`, `/results`, `/results/option/:id` |
| `lib/core/widgets` | Shared: `FadeSlideIn` (staggered entrances), `Pressable`, `Pill`, `ErrorView`, `MessageView`, `SkeletonBox` |
| `lib/features/places` | Place entities, API repository, `LocationService` (geolocator), search & map-picker screens |
| `lib/features/compare` | Ride models, repository, `TripController`, `ComparisonController` (AsyncNotifier), `FiltersController`, home/results/details screens |

State: `tripProvider` (pickup/drop) → `comparisonProvider` (auto-fetches when the trip changes,
auto-disposes when no screen shows results) → `applyFilters()` (pure function, unit-tested) for
category / provider / sort, applied instantly on-device.

### States handled

| Screen | Loading | Error | Empty |
|---|---|---|---|
| Results | Skeleton cards, trip-summary skeleton | Full-screen `ErrorView` with Try again (or "Change trip" for invalid trips); failed **refresh** keeps old prices and shows a snackbar | "No rides match your filters" + Reset filters; "No rides available" |
| Search | Skeleton rows | Inline `ErrorView` with retry | "No places found for …" |
| Current location | Inline spinner in pickup field | Message + Settings shortcut if permanently denied | — |
| Map picker | Address skeleton while moving | Falls back to "Pinned location" | Without a Maps key: explains and offers search instead |
| Provider failure | — | Per-provider note under the list | — |

## Security

* API keys exist only in `backend/.env`, `android/local.properties` and `ios/Flutter/Secrets.xcconfig`, all git-ignored.
* Places/Routes calls go through the backend, so the server key is never shipped in the app. The Maps SDK
  key in the app should be restricted to the app's bundle ID / package + SHA-1 in Google Cloud Console.
* helmet, CORS allow-list, 10 KB body limit, rate limiting, input validation on every endpoint.
* Plain HTTP is allowed **only** for the local dev backend: Android debug builds (network security config
  for 10.0.2.2/localhost) and iOS `NSAllowsLocalNetworking`. Release builds require HTTPS.
* Dependencies are pinned to releases at least two weeks old (supply-chain hygiene); `npm audit`: 0 vulnerabilities.
