# Maps: free now, Google later

RideCompare uses maps in four places. Each has a free provider for development and a Google option for launch.
Screens and API endpoints are identical either way; switching is configuration only.

| Need | Free (default) | Fallback | Google (later) |
|---|---|---|---|
| Type-ahead search | **Geoapify** (free key, 3,000 req/day) | Photon (no key) → offline landmark list | Places API (New) |
| Pin / GPS → address | Geoapify reverse geocoding | Photon → nearest landmark | Geocoding API |
| Road distance, time, route line | **OSRM** (no key) | Straight-line × 1.35 estimate | Routes API |
| In-app map (picker, route preview) | **OpenStreetMap tiles** via `flutter_map` | — | Maps SDK for Android/iOS |

## How it's built

* **Backend** `src/infrastructure/maps/`: `GeoapifyMapsClient`, `OsmMapsClient` (Photon + Nominatim + OSRM),
  `GoogleMapsClient` and `DemoMapsClient` all expose the same methods (`autocomplete`, `placeDetails`,
  `reverseGeocode`, `route`). `ResilientMapsClient` chains them: if one fails (outage, rate limit, IP block,
  bad key) the next answers, and the failed one is skipped for 60 s.
* **App** `lib/core/maps/app_maps.dart`: `PickerMap` and `RouteMap` render with `flutter_map` (OSM) or
  `google_maps_flutter`, chosen by `--dart-define=MAP_ENGINE=osm|google`. Screens never import a map SDK.
* Place ids carry their source (`geo:`, `osm:`, `demo:`), so a suggestion is always resolved by the service that issued it.
* Free-tier etiquette: one search request per keystroke batch (300 ms debounce), nearby-first then India-wide
  only if needed, 5–60 min caches, a proper User-Agent, and the attributions each service requires
  ("Powered by Geoapify", "© OpenStreetMap") shown in the app.

## Free setup (development)

1. Sign up at https://myprojects.geoapify.com (email only, no card) → create a project → copy the API key.
2. In `backend/.env`: `GEOAPIFY_API_KEY=<key>` (keep `MAPS_PROVIDER=osm`).
3. Restart the backend. `GET /api/v1/health` shows `"maps": "geoapify"`.

Without a Geoapify key, search uses the public Photon server. It works, but it can rate-limit or block an IP
(this happened during development), and then search drops to the offline landmark list.

**Limits:** the public OSRM, Photon and OSM tile servers are community-run "fair use" services: fine for
development, **not for production traffic**. Geoapify's free plan allows commercial use within 3,000 credits/day
with attribution.

## Switch to Google (launch)

1. Google Cloud Console: create a project, link billing, enable *Maps SDK for Android*, *Maps SDK for iOS*,
   *Places API (New)*, *Geocoding API* and *Routes API*. Create an **app key** (Maps SDKs only) and a
   **server key** (Places/Geocoding/Routes only). Set a budget alert.
2. Backend `.env`: `MAPS_PROVIDER=google` and `GOOGLE_MAPS_API_KEY=<server key>`.
3. App keys (git-ignored): `mobile/android/local.properties` → `MAPS_API_KEY=<app key>`, and
   `mobile/ios/Flutter/Secrets.xcconfig` → `MAPS_API_KEY=<app key>`.
4. Run/build the app with `--dart-define=MAP_ENGINE=google`.

Rollback is the reverse: `MAPS_PROVIDER=osm` and drop the dart-define.

## Other options

* **Self-host** Photon + OSRM + a tile server (all open source) for unlimited free use at the cost of running servers.
* **Ola Maps** (India-focused, has a free tier) could be added as another client with the same interface.
