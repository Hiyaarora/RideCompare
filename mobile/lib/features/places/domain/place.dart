/// A resolved location with coordinates.
class Place {
  const Place({
    required this.name,
    required this.lat,
    required this.lng,
    this.address = '',
    this.placeId,
    this.isCurrentLocation = false,
  });

  final String name;
  final String address;
  final double lat;
  final double lng;
  final String? placeId;
  final bool isCurrentLocation;

  /// What to show in the trip card.
  String get label => isCurrentLocation ? 'Current location' : name;

  factory Place.fromJson(Map<String, dynamic> j, {bool isCurrentLocation = false}) => Place(
    name: j['name'] as String? ?? 'Unnamed place',
    address: j['address'] as String? ?? '',
    lat: (j['lat'] as num).toDouble(),
    lng: (j['lng'] as num).toDouble(),
    placeId: j['placeId'] as String?,
    isCurrentLocation: isCurrentLocation,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'address': address,
    'lat': lat,
    'lng': lng,
    if (placeId != null) 'placeId': placeId,
  };

  @override
  bool operator ==(Object other) =>
      other is Place &&
      other.lat == lat &&
      other.lng == lng &&
      other.name == name &&
      other.isCurrentLocation == isCurrentLocation;

  @override
  int get hashCode => Object.hash(lat, lng, name, isCurrentLocation);
}

/// Autocomplete results plus which service produced them (for the required attribution).
typedef PlaceSearchResult = ({String source, List<PlaceSuggestion> suggestions});

/// One autocomplete result. Coordinates are fetched only when it's chosen.
class PlaceSuggestion {
  const PlaceSuggestion({
    required this.placeId,
    required this.primaryText,
    required this.secondaryText,
    this.distanceKm,
  });

  final String placeId;
  final String primaryText;
  final String secondaryText;
  final double? distanceKm;

  factory PlaceSuggestion.fromJson(Map<String, dynamic> j) => PlaceSuggestion(
    placeId: j['placeId'] as String,
    primaryText: j['primaryText'] as String? ?? '',
    secondaryText: j['secondaryText'] as String? ?? '',
    distanceKm: (j['distanceKm'] as num?)?.toDouble(),
  );
}
