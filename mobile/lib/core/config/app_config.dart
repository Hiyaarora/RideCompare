import 'package:flutter/foundation.dart';

/// Which map renders inside the app.
enum MapEngine {
  /// Free OpenStreetMap tiles via flutter_map. No key needed. Development default.
  osm,

  /// Google Maps SDK. Needs MAPS_API_KEY in android/local.properties and ios/Flutter/Secrets.xcconfig.
  google,
}

/// Build-time configuration, passed with `--dart-define` (see mobile/README.md).
abstract final class AppConfig {
  static const _apiBaseUrlOverride = String.fromEnvironment('API_BASE_URL');
  static const _mapEngine = String.fromEnvironment('MAP_ENGINE', defaultValue: 'osm');

  /// RideCompare backend. Defaults reach a backend running on this Mac:
  /// the Android emulator sees the host as 10.0.2.2; the iOS simulator shares localhost.
  static String get apiBaseUrl {
    if (_apiBaseUrlOverride.isNotEmpty) return _apiBaseUrlOverride;
    return defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:4000/api/v1'
        : 'http://localhost:4000/api/v1';
  }

  /// `--dart-define=MAP_ENGINE=google` switches the in-app map to Google once keys are configured.
  static MapEngine get mapEngine => _mapEngine == 'google' ? MapEngine.google : MapEngine.osm;

  /// Identifies the app to OpenStreetMap's tile servers, as their usage policy requires.
  static const osmUserAgentPackage = 'com.ridecompare.ridecompare';

  /// Map starting point when the device location is unknown (MG Road, Bengaluru).
  static const fallbackLat = 12.9755;
  static const fallbackLng = 77.6068;
}
