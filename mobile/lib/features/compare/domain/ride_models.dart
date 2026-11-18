import '../../places/domain/place.dart';

enum RideProvider {
  uber('Uber'),
  ola('Ola'),
  rapido('Rapido');

  const RideProvider(this.label);
  final String label;

  static RideProvider? tryParse(String? id) => RideProvider.values.where((p) => p.name == id).firstOrNull;
}

enum RideCategory {
  bike('Bike'),
  auto('Auto'),
  car('Car');

  const RideCategory(this.label);
  final String label;

  static RideCategory parse(String? id) =>
      RideCategory.values.firstWhere((c) => c.name == id, orElse: () => RideCategory.car);
}

/// How firm a live price is: one fixed upfront fare, or a low–high estimate range.
enum PriceType {
  upfront,
  estimate;

  static PriceType parse(String? v) => v == 'upfront' ? PriceType.upfront : PriceType.estimate;
}

/// unavailable = no authorised live integration for this provider, so there are no prices at all.
enum ProviderState { ok, error, noService, unavailable }

class Fare {
  const Fare({required this.min, required this.max, this.upfront, this.currency = 'INR'});
  final int min;
  final int max;

  /// Set only when the provider quoted a confirmed upfront fare.
  final int? upfront;
  final String currency;

  bool get isFixed => min == max;

  factory Fare.fromJson(Map<String, dynamic> j) => Fare(
    min: (j['min'] as num).round(),
    max: (j['max'] as num).round(),
    upfront: (j['upfront'] as num?)?.round(),
    currency: j['currency'] as String? ?? 'INR',
  );
}

class RideOption {
  const RideOption({
    required this.id,
    required this.provider,
    required this.productName,
    required this.description,
    required this.category,
    required this.fare,
    required this.priceType,
    required this.fetchedAt,
    this.available = true,
    this.capacity,
    this.pickupEtaMin,
    this.tripDurationMin,
    this.distanceKm,
    this.surgeMultiplier = 1,
  });

  final String id;
  final RideProvider provider;
  final String productName;
  final String description;
  final RideCategory category;
  final int? capacity;
  final Fare fare;
  final int? pickupEtaMin;
  final int? tripDurationMin;
  final double? distanceKm;
  final double surgeMultiplier;
  final PriceType priceType;

  /// False when the provider priced the trip but has no driver nearby right now.
  final bool available;

  /// When the provider's API returned this price.
  final DateTime fetchedAt;

  bool get isUpfront => priceType == PriceType.upfront;

  bool get hasSurge => surgeMultiplier > 1.0;

  /// Minutes from now until arrival: waiting for pickup + the ride itself.
  int get totalMinutes => (pickupEtaMin ?? 0) + (tripDurationMin ?? 0);

  /// Returns null for options from providers this app doesn't know.
  static RideOption? fromJson(Map<String, dynamic> j) {
    final provider = RideProvider.tryParse(j['provider'] as String?);
    if (provider == null) return null;
    return RideOption(
      id: j['id'] as String,
      provider: provider,
      productName: j['productName'] as String? ?? provider.label,
      description: j['description'] as String? ?? '',
      category: RideCategory.parse(j['category'] as String?),
      capacity: (j['capacity'] as num?)?.toInt(),
      fare: Fare.fromJson(j['fare'] as Map<String, dynamic>),
      pickupEtaMin: (j['pickupEtaMin'] as num?)?.round(),
      tripDurationMin: (j['tripDurationMin'] as num?)?.round(),
      distanceKm: (j['distanceKm'] as num?)?.toDouble(),
      surgeMultiplier: (j['surgeMultiplier'] as num?)?.toDouble() ?? 1,
      priceType: PriceType.parse(j['priceType'] as String?),
      available: j['available'] as bool? ?? true,
      fetchedAt: DateTime.tryParse(j['fetchedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

typedef GeoPoint = ({double lat, double lng});

class RouteInfo {
  const RouteInfo({
    required this.distanceKm,
    required this.durationMin,
    required this.polyline,
    required this.isEstimated,
  });
  final double distanceKm;
  final int durationMin;
  final List<GeoPoint> polyline;

  /// True when the route is a straight-line estimate rather than a real road route.
  final bool isEstimated;

  factory RouteInfo.fromJson(Map<String, dynamic> j) => RouteInfo(
    distanceKm: (j['distanceKm'] as num).toDouble(),
    durationMin: (j['durationMin'] as num).round(),
    polyline: (j['polyline'] as List? ?? const [])
        .map((p) => (lat: ((p as Map)['lat'] as num).toDouble(), lng: (p['lng'] as num).toDouble()))
        .toList(growable: false),
    isEstimated: j['source'] == 'demo',
  );
}

class ProviderStatus {
  const ProviderStatus({required this.provider, required this.state, required this.live, this.message, this.reason});
  final RideProvider provider;
  final ProviderState state;

  /// True when an authorised live integration is configured for this provider.
  final bool live;
  final String? message;

  /// Why there are no prices, e.g. "Rapido has no official fare API".
  final String? reason;

  static ProviderStatus? fromJson(Map<String, dynamic> j) {
    final provider = RideProvider.tryParse(j['id'] as String?);
    if (provider == null) return null;
    return ProviderStatus(
      provider: provider,
      state: switch (j['status']) {
        'ok' => ProviderState.ok,
        'no_service' => ProviderState.noService,
        'unavailable' => ProviderState.unavailable,
        _ => ProviderState.error,
      },
      live: j['live'] as bool? ?? false,
      message: j['message'] as String?,
      reason: j['reason'] as String?,
    );
  }
}

/// live = at least one real price; unavailable = no authorised source returned any price.
enum DataMode { live, unavailable }

class Comparison {
  const Comparison({
    required this.generatedAt,
    required this.dataMode,
    required this.pickup,
    required this.drop,
    required this.route,
    required this.providers,
    required this.options,
    this.cheapestOptionId,
    this.fastestOptionId,
  });

  final DateTime generatedAt;
  final DataMode dataMode;
  final Place pickup;
  final Place drop;
  final RouteInfo route;
  final List<ProviderStatus> providers;

  /// Sorted by the server: available first, then cheapest.
  final List<RideOption> options;
  final String? cheapestOptionId;
  final String? fastestOptionId;

  RideOption? optionById(String id) => options.where((o) => o.id == id).firstOrNull;

  factory Comparison.fromJson(Map<String, dynamic> j, {required Place pickup, required Place drop}) => Comparison(
    generatedAt: DateTime.tryParse(j['generatedAt'] as String? ?? '') ?? DateTime.now(),
    dataMode: j['dataMode'] == 'live' ? DataMode.live : DataMode.unavailable,
    // Keep the client's Place objects (they carry "current location" labels).
    pickup: pickup,
    drop: drop,
    route: RouteInfo.fromJson(j['route'] as Map<String, dynamic>),
    providers: (j['providers'] as List? ?? const [])
        .map((e) => ProviderStatus.fromJson(e as Map<String, dynamic>))
        .nonNulls
        .toList(growable: false),
    options: (j['options'] as List? ?? const [])
        .map((e) => RideOption.fromJson(e as Map<String, dynamic>))
        .nonNulls
        .toList(growable: false),
    cheapestOptionId: j['cheapestOptionId'] as String?,
    fastestOptionId: j['fastestOptionId'] as String?,
  );
}

class RecentSearch {
  const RecentSearch({
    required this.pickup,
    required this.drop,
    required this.createdAt,
    this.cheapestFare,
    this.cheapestProvider,
  });
  final Place pickup;
  final Place drop;
  final DateTime createdAt;
  final int? cheapestFare;
  final RideProvider? cheapestProvider;

  factory RecentSearch.fromJson(Map<String, dynamic> j) {
    final cheapest = j['cheapest'] as Map<String, dynamic>?;
    return RecentSearch(
      pickup: Place.fromJson(j['pickup'] as Map<String, dynamic>),
      drop: Place.fromJson(j['drop'] as Map<String, dynamic>),
      createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
      cheapestFare: (cheapest?['fareMin'] as num?)?.round(),
      cheapestProvider: RideProvider.tryParse(cheapest?['provider'] as String?),
    );
  }
}
