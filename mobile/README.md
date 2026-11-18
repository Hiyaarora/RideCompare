# RideCompare mobile (Flutter)

Android + iOS app. Clean Architecture by feature (`lib/features/{places,compare}/{domain,data,application,presentation}`),
Riverpod 3 for state, GoRouter for navigation, Dio for HTTP, Material 3 (`package:material_ui`).

## Run

Start the backend first (`cd ../backend && npm run dev`).

```zsh
flutter pub get
flutter run                          # choose a device
flutter run -d "iPhone 17"
flutter emulators --launch RideCompare_Pixel && flutter run -d emulator-5554
```

### Build-time options (`--dart-define`)

| Define | Default | Purpose |
|---|---|---|
| `API_BASE_URL` | `http://10.0.2.2:4000/api/v1` (Android) / `http://localhost:4000/api/v1` (iOS) | Point at another backend, e.g. your Mac's LAN IP for a physical phone: `--dart-define=API_BASE_URL=http://192.168.1.20:4000/api/v1` (plain HTTP to a LAN IP also needs that IP added to the debug network config / ATS) |
| `MAPS_ENABLED` | `false` | Set `true` once a Maps SDK key is configured (below) to turn on map views |

## Google Maps (optional, requires a Google Cloud billing account)

1. In Google Cloud Console, create two keys:
   * **App key**: enable *Maps SDK for Android* and *Maps SDK for iOS*. Restrict it to package
     `com.ridecompare.ridecompare` (+ SHA-1) and bundle ID `com.ridecompare.ridecompare`.
   * **Server key**: enable *Places API (New)*, *Geocoding API* and *Routes API*. Put it in `backend/.env`
     as `GOOGLE_MAPS_API_KEY`.
2. Android: add to `android/local.properties` (git-ignored):
   ```
   MAPS_API_KEY=AIza...
   ```
3. iOS: create `ios/Flutter/Secrets.xcconfig` (git-ignored):
   ```
   MAPS_API_KEY=AIza...
   ```
4. Run with `flutter run --dart-define=MAPS_ENABLED=true`.

## Tests

```zsh
flutter analyze
flutter test                                   # unit + widget tests
flutter test integration_test -d <device-id>   # end-to-end against the running backend
```

The integration test taps "Use current location". Grant location permission first, since a test can't tap
the system dialog:

* iOS simulator: `xcrun simctl privacy booted grant location com.ridecompare.ridecompare` and
  `xcrun simctl location booted set 12.9716,77.5946`
* Android emulator: `adb shell pm grant com.ridecompare.ridecompare android.permission.ACCESS_FINE_LOCATION` and
  `adb emu geo fix 77.5946 12.9716`

The demo places cover Bengaluru, Delhi NCR, Mumbai, Hyderabad, Chennai and Pune. A simulator location in
California makes "current location" more than 150 km from any destination, and the app shows the
"trip too long" error. That's expected; set an Indian location as above.
