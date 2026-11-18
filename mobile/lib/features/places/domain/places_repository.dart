import 'place.dart';

abstract interface class PlacesRepository {
  Future<PlaceSearchResult> autocomplete(String query, {double? lat, double? lng, String? sessionToken});
  Future<Place> details(String placeId, {String? sessionToken});
  Future<Place> reverseGeocode(double lat, double lng, {bool isCurrentLocation = false});
}
