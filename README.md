# RideCompare

A Flutter app (Android + iOS) with a Node.js backend that compares ride prices from **Uber, Ola and Rapido**
(Bike / Auto / Car) for a pickup and destination in India.

> **Live prices only.** The app shows a price only when an official, authorised provider API returns one.
> Otherwise it shows **"Live pricing unavailable"**. No demo, scraped or calculated prices.

## What's done so far
- **Mobile app (Flutter, Riverpod, GoRouter, Dio, Material 3):** pickup/destination search, current location,
  pick-on-map, route preview, results sorted cheapest first, filters (provider, Bike/Auto/Car), ride details,
  recent searches. Labels separate *upfront fares* from *estimates*.
- **Backend (Node.js, Express, MongoDB):** `/api/v1/compare`, place search, reverse geocoding, routes, search history.
  Providers are queried in parallel (`Promise.allSettled`), and one failing never breaks the others.
- **Maps (free for now):** Geoapify search + OpenStreetMap/OSRM routing and map tiles, with a switch to Google Maps later.
- **Provider integrations:** Uber (Guest Rides / Riders API) and Ola (partner API) clients are built and tested.
  They go live once credentials are added. Rapido has no official API yet.
- **Tests:** backend 45 tests, Flutter 16 widget/unit tests, plus integration tests on the iOS simulator and Android emulator.

## Project structure
```
backend/   Node.js API (Clean Architecture: domain / application / infrastructure / interfaces)
mobile/    Flutter app
docs/      Setup, architecture, maps, provider API research, partnership email drafts
```

## Run it

**Requirements:** Flutter 3.50+, Node.js 22+, MongoDB, Xcode (iOS) and/or Android Studio (Android).
Full machine setup: [docs/SETUP.md](docs/SETUP.md).

### 1. Backend
```bash
cd backend
cp .env.example .env          # add GEOAPIFY_API_KEY (free) and any provider credentials
npm install
npm start                     # http://localhost:4000/api/v1/health
npm test
```
MongoDB must be running at `mongodb://127.0.0.1:27017` (or set `MONGODB_URI`).

### 2. Mobile app
```bash
cd mobile
flutter pub get
flutter run                   # pick an iOS simulator or Android emulator
flutter test
```
The app uses `localhost:4000` on iOS and `10.0.2.2:4000` on the Android emulator.
For a real device: `flutter run --dart-define=API_BASE_URL=http://<your-computer-ip>:4000/api/v1`.

## Getting real prices
Uber and Ola only give API access to approved partners, and Rapido has no public API. Add credentials to
`backend/.env` once they're granted (`UBER_CLIENT_ID` / `UBER_CLIENT_SECRET` / `UBER_ORG_UUID` or `UBER_SERVER_TOKEN`,
`OLA_APP_TOKEN`) and restart the backend. Details: [docs/PROVIDER_APIS.md](docs/PROVIDER_APIS.md),
email drafts: [docs/PARTNERSHIP_EMAILS.md](docs/PARTNERSHIP_EMAILS.md).

Secrets live only in git-ignored files (`backend/.env`, `mobile/android/local.properties`,
`mobile/ios/Flutter/Secrets.xcconfig`). Never commit them.

## Docs
[Setup](docs/SETUP.md) · [Architecture](docs/ARCHITECTURE.md) · [Maps](docs/MAPS.md) ·
[Provider APIs](docs/PROVIDER_APIS.md) · [ONDC](docs/ONDC.md)
