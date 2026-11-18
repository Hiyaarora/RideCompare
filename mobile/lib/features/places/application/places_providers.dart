import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../data/places_repository_impl.dart';
import '../domain/place.dart';
import '../domain/places_repository.dart';
import 'location_service.dart';

final placesRepositoryProvider = Provider<PlacesRepository>((ref) => ApiPlacesRepository(ref.watch(apiClientProvider)));

final locationServiceProvider = Provider<LocationService>((ref) => const LocationService());

/// Arguments for one autocomplete lookup. A record, so equal queries share a cached result.
typedef AutocompleteArgs = ({String query, String sessionToken, double? lat, double? lng});

final autocompleteProvider = FutureProvider.autoDispose.family<PlaceSearchResult, AutocompleteArgs>((ref, args) {
  return ref
      .watch(placesRepositoryProvider)
      .autocomplete(args.query, lat: args.lat, lng: args.lng, sessionToken: args.sessionToken);
});

/// Resolves the device position into a [Place] labelled "Current location".
final currentPlaceLoader = Provider<Future<Place> Function()>((ref) {
  return () async {
    final pos = await ref.read(locationServiceProvider).currentPosition();
    try {
      return await ref.read(placesRepositoryProvider).reverseGeocode(pos.lat, pos.lng, isCurrentLocation: true);
    } catch (_) {
      // Coordinates are what matter for pricing; the name is cosmetic.
      return Place(name: 'Current location', lat: pos.lat, lng: pos.lng, isCurrentLocation: true);
    }
  };
});
