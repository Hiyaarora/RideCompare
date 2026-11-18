import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../../../core/error/app_failure.dart';

typedef LatLngPoint = ({double lat, double lng});

/// Wraps geolocator so the rest of the app deals in [LocationFailure]s, not plugin exceptions.
class LocationService {
  const LocationService();

  /// True if the app may read location without showing a permission prompt.
  Future<bool> hasPermission() async {
    final p = await Geolocator.checkPermission();
    return p == LocationPermission.always || p == LocationPermission.whileInUse;
  }

  Future<LatLngPoint> currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationFailure(
        'Location services are turned off. Turn them on in Settings, or search for your pickup instead.',
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationFailure('Location permission was not granted. You can search for your pickup instead.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationFailure(
        'Location access is blocked for RideCompare. Allow it in Settings, or search for your pickup instead.',
        openSettings: true,
      );
    }
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 12)),
      );
      return (lat: pos.latitude, lng: pos.longitude);
    } on TimeoutException {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return (lat: last.latitude, lng: last.longitude);
      throw const LocationFailure("We couldn't find your location in time. Try again or search for your pickup.");
    } catch (_) {
      throw const LocationFailure("We couldn't determine your location. Try again or search for your pickup.");
    }
  }

  Future<void> openSettings() => Geolocator.openAppSettings();
}
