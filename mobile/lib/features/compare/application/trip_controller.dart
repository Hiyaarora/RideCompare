import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_failure.dart';
import '../../places/application/places_providers.dart';
import '../../places/domain/place.dart';

enum TripField {
  pickup('Pickup', 'Where should we pick you up?'),
  drop('Destination', 'Where are you going?');

  const TripField(this.label, this.hint);
  final String label;
  final String hint;
}

class TripState {
  const TripState({this.pickup, this.drop, this.detectingLocation = false, this.locationError});

  final Place? pickup;
  final Place? drop;
  final bool detectingLocation;
  final AppFailure? locationError;

  bool get isComplete => pickup != null && drop != null;

  Place? operator [](TripField f) => f == TripField.pickup ? pickup : drop;

  TripState copyWith({
    Place? pickup,
    Place? drop,
    bool? detectingLocation,
    AppFailure? locationError,
    bool clearError = false,
  }) => TripState(
    pickup: pickup ?? this.pickup,
    drop: drop ?? this.drop,
    detectingLocation: detectingLocation ?? this.detectingLocation,
    locationError: clearError ? null : (locationError ?? this.locationError),
  );
}

/// The trip being planned: pickup + destination.
class TripController extends Notifier<TripState> {
  @override
  TripState build() => const TripState();

  void set(TripField field, Place place) {
    state = field == TripField.pickup
        ? state.copyWith(pickup: place, clearError: true)
        : state.copyWith(drop: place, clearError: true);
  }

  void setBoth(Place pickup, Place drop) => state = TripState(pickup: pickup, drop: drop);

  void swap() => state = TripState(pickup: state.drop, drop: state.pickup);

  /// Fills the pickup with the device location.
  /// With [onlyIfPermitted], it does nothing unless permission was already granted,
  /// so the app never shows a permission prompt the user didn't ask for.
  Future<void> useCurrentLocation({bool onlyIfPermitted = false}) async {
    if (state.detectingLocation) return;
    if (onlyIfPermitted && !await ref.read(locationServiceProvider).hasPermission()) return;
    state = state.copyWith(detectingLocation: true, clearError: true);
    try {
      final place = await ref.read(currentPlaceLoader)();
      if (!ref.mounted) return;
      // Don't overwrite a pickup the user picked by hand while we were locating.
      final keepManual = onlyIfPermitted && state.pickup != null;
      state = state.copyWith(pickup: keepManual ? null : place, detectingLocation: false);
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(detectingLocation: false, locationError: onlyIfPermitted ? null : toFailure(e));
    }
  }
}

final tripProvider = NotifierProvider<TripController, TripState>(TripController.new);
