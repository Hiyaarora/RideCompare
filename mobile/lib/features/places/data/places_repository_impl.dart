import '../../../core/network/api_client.dart';
import '../domain/place.dart';
import '../domain/places_repository.dart';

/// Location search through the RideCompare backend, which holds the Google Maps key.
class ApiPlacesRepository implements PlacesRepository {
  ApiPlacesRepository(this._api);
  final ApiClient _api;

  @override
  Future<PlaceSearchResult> autocomplete(String query, {double? lat, double? lng, String? sessionToken}) async {
    final json = await _api.get(
      '/places/autocomplete',
      query: {
        'q': query,
        if (lat != null && lng != null) ...{'lat': lat, 'lng': lng},
        'sessionToken': ?sessionToken,
      },
    );
    return (
      source: json['source'] as String? ?? 'demo',
      suggestions: (json['suggestions'] as List? ?? const [])
          .map((e) => PlaceSuggestion.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  @override
  Future<Place> details(String placeId, {String? sessionToken}) async {
    final json = await _api.get('/places/${Uri.encodeComponent(placeId)}', query: {'sessionToken': ?sessionToken});
    return Place.fromJson(json['place'] as Map<String, dynamic>);
  }

  @override
  Future<Place> reverseGeocode(double lat, double lng, {bool isCurrentLocation = false}) async {
    final json = await _api.get('/places/reverse', query: {'lat': lat, 'lng': lng});
    return Place.fromJson(json['place'] as Map<String, dynamic>, isCurrentLocation: isCurrentLocation);
  }
}
